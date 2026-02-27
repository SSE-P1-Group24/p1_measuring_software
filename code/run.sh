#!/bin/bash
set -euo pipefail

# =========================
# Config
# =========================
ENERGIBRIDGE="/Users/snehaprashanth/.cargo/bin/energibridge"
OUTPUT_DIR="results"

RUNS=30
MEASURE=163        # seconds to measure
PAGE_WAIT=8       # seconds to wait for page load
COOLDOWN=30       # seconds between runs/platforms

mkdir -p "$OUTPUT_DIR"

# =========================
# sudo keepalive (quiet)
# =========================
sudo -v
(
  while true; do
    sudo -n true >/dev/null 2>&1 || exit 0
    sleep 50
    kill -0 "$$" 2>/dev/null || exit 0
  done
) >/dev/null 2>&1 &
SUDO_KEEP_ALIVE_PID=$!

cleanup() {
  kill "$SUDO_KEEP_ALIVE_PID" >/dev/null 2>&1 || true
  osascript -e 'tell application "Safari" to quit' >/dev/null 2>&1 || true
}
trap cleanup EXIT

# =========================
# Helpers
# =========================
open_url() {
  local URL="$1"
  osascript \
    -e 'tell application "Safari" to activate' \
    -e "tell application \"Safari\" to open location \"$URL\"" \
    >/dev/null 2>&1
}

play_with_spacebar() {
  osascript <<'EOF' >/dev/null 2>&1
tell application "Safari" to activate
delay 0.5
tell application "System Events" to keystroke space
EOF
}

# Apple Music: click Play/Preview in the hero area (top of page)
play_apple_music() {
  osascript -e 'tell application "Safari" to activate' >/dev/null 2>&1
  sleep 0.8

  osascript <<'EOF' >/dev/null 2>&1
tell application "Safari"
  tell front document
    do JavaScript "
      (function () {
        window.scrollTo(0, 0);

        const clickIf = (el) => {
          if (!el) return false;
          const r = el.getBoundingClientRect();
          if (r.width < 2 || r.height < 2) return false;
          el.click();
          return true;
        };

        const hero = document.querySelector('main') || document.body;

        const candidates = Array.from(hero.querySelectorAll('button'))
          .filter(b => {
            const a = (b.getAttribute('aria-label') || '').toLowerCase();
            return a === 'play' || a === 'preview' || a.includes('play') || a.includes('preview');
          })
          .filter(b => b.getBoundingClientRect().top >= 0 && b.getBoundingClientRect().top < 700);

        if (candidates.length && clickIf(candidates[0])) return 'clicked hero play/preview';

        const previewBtn = Array.from(hero.querySelectorAll('button,a'))
          .find(el =>
            (el.textContent || '').trim().toLowerCase() === 'preview' &&
            el.getBoundingClientRect().top >= 0 &&
            el.getBoundingClientRect().top < 700
          );

        if (previewBtn && clickIf(previewBtn)) return 'clicked preview';

        return 'no suitable hero control';
      })();
    "
  end tell
end tell
EOF
}

# Force playback to start at t=0 for Apple Music (and generally works for other sites too)
force_start_from_beginning() {
  osascript <<'EOF' >/dev/null 2>&1
tell application "Safari"
  tell front document
    do JavaScript "
      (function () {
        const m = document.querySelector('audio, video');
        if (m) {
          try { m.currentTime = 0; } catch(e) {}
          try { m.pause(); } catch(e) {}
          try { m.currentTime = 0; } catch(e) {}
          try { m.play(); } catch(e) {}
          return 'reset media element';
        }
        return 'no media element found';
      })();
    "
  end tell
end tell
EOF
}

# YouTube Music: if paused, click play; if already playing, do nothing.
ensure_youtube_music_playing() {
  osascript <<'EOF' >/dev/null 2>&1
tell application "Safari"
  tell front document
    do JavaScript "
      (function () {
        const btn =
          document.querySelector('tp-yt-paper-icon-button[aria-label*=\"Play\" i]') ||
          document.querySelector('button[aria-label*=\"Play\" i]');

        const pauseBtn =
          document.querySelector('tp-yt-paper-icon-button[aria-label*=\"Pause\" i]') ||
          document.querySelector('button[aria-label*=\"Pause\" i]');

        // If we can see a Pause button, we are already playing
        if (pauseBtn) return 'already playing';

        // If Play exists, click it
        if (btn) { btn.click(); return 'clicked play'; }

        return 'no play/pause button found';
      })();
    "
  end tell
end tell
EOF
}

go_blank() {
  osascript <<'EOF' >/dev/null 2>&1
tell application "Safari"
  activate
  try
    tell front document to set URL to "about:blank"
  end try
end tell
EOF
}

dismiss_leave_prompt() {
  osascript <<'EOF' >/dev/null 2>&1
tell application "System Events"
  tell process "Safari"
    repeat 8 times
      try
        if (count of windows) > 0 and (exists sheet 1 of window 1) then
          tell sheet 1 of window 1
            if exists button "Leave" then click button "Leave"
            if exists button "Leave Page" then click button "Leave Page"
            if exists button "Quit" then click button "Quit"
            if exists button "Close" then click button "Close"
            if exists button "Don't Save" then click button "Don't Save"
          end tell
        end if
      end try
      delay 0.2
    end repeat
  end tell
end tell
EOF
}

quit_safari_cleanly() {
  # light pause toggle (best effort), then navigate away, then quit
  osascript -e 'tell application "Safari" to activate' >/dev/null 2>&1 || true
  sleep 0.3
  osascript -e 'tell application "System Events" to keystroke space' >/dev/null 2>&1 || true

  go_blank
  sleep 1.2

  osascript -e 'tell application "Safari" to quit' >/dev/null 2>&1 || true
  sleep 0.5

  dismiss_leave_prompt
}

run_subject() {
  local NAME="$1"
  local URL="$2"
  local RUN="$3"
  local CSV="$OUTPUT_DIR/${NAME}_run$(printf '%02d' "$RUN").csv"

  echo "--- $NAME run $RUN ---"

  # Clean run: quit Safari before starting
  osascript -e 'tell application "Safari" to quit' >/dev/null 2>&1 || true
  sleep 2

  open_url "$URL"
  sleep "$PAGE_WAIT"

  # Start playback (platform-specific)
  if [[ "$NAME" == "spotify" ]]; then
    play_with_spacebar
  elif [[ "$NAME" == "apple_music" ]]; then
    play_apple_music
    sleep 1
    force_start_from_beginning   # ensures it starts from t=0
  elif [[ "$NAME" == "youtube_music" ]]; then
    # DO NOT press space; it often autoplays and space would pause it.
    sleep 1
    ensure_youtube_music_playing
  fi

  # Let playback stabilize briefly
  sleep 2

  # Measure
  sudo "$ENERGIBRIDGE" --output "$CSV" --summary sleep "$MEASURE"

  echo "  saved: $CSV"

  # Quit Safari without prompts
  quit_safari_cleanly
  sleep 2
}

# =========================
# Experiment loop
# =========================
for ((run=1; run<=RUNS; run++)); do
  echo "====== RUN $run / $RUNS ======"

  # Randomize order each run
  apps=(
    "spotify|https://open.spotify.com/track/4WZE6JnKn3jacgnaJOTF9T"
    "apple_music|https://music.apple.com/us/album/chanakya-single/1580178175"
    "youtube_music|https://music.youtube.com/watch?v=_FJoweJ21q4&si=1CZIhwJP4XGUbfBG"
  )

  # Shuffle in-place (Fisher–Yates)
  for ((i=${#apps[@]}-1; i>0; i--)); do
    j=$((RANDOM % (i+1)))
    tmp="${apps[i]}"
    apps[i]="${apps[j]}"
    apps[j]="$tmp"
  done

  for entry in "${apps[@]}"; do
    NAME="${entry%%|*}"
    URL="${entry#*|}"
    run_subject "$NAME" "$URL" "$run"
    sleep "$COOLDOWN"
  done

  # Extra cooldown between runs (keeps your old behavior)
  if [[ "$run" -lt "$RUNS" ]]; then
    sleep "$COOLDOWN"
  fi
done

echo "Done! Results in ./$OUTPUT_DIR/"