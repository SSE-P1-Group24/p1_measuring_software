# Group 24: Measuring Energy Use of Spotify Web Player vs Apple Music Web vs YouTube Music Web

This repository contains the automated script for our experiment, the results and the jupyter notebook used to generate the plots based on the results.

## The script

The script runs 30 times. It first closes Safari, then randomly picks the order of the three services. It opens the link to the song on the first platform and plays it (either by pressing space for Spotify, or by pressing the play button for Apple Music). While the song plays, EnergiBridge measures the energy consumption. The results are saved in a csv file with the name of the platform and the number of the run. Then the song is played on the next platform, which generates another csv file. Once all three platforms have been opened, the run finishes, and the entire process repeats 30 times.

To run the script, first make sure that [EnergiBridge](https://github.com/tdurieux/EnergiBridge) is set up on your device. Then update the path for EnergiBridge inside the script with your path.

```bash
ENERGIBRIDGE="YOUR PATH"
```

Then make the script executable:

```bash
chmod +x run.sh
```

Make sure to be loged on all three platforms: Spotify, Apple Music and YouTube Music. The run the script:

```bash
./run.sh
```

## The results

After the experiment was finished, we noticed that some csv files didn’t generate correctly. For the first few rows, the columns were moved to the left one or two spaces. We had to modify the table for these files in order to correctly analyse the energy consumption. It's important to pay attention to this in order to have a correct analysis.

## The plots

The code for generating the plots can be found in `DataPlot.ipynb`. This script loads the CSV files for all three platforms, computes a summary of three metrics (CPU usage, RAM, total energy) per-run, and visualises the results using a violin plot. It also performs a statistical test to check if the differences are significant.