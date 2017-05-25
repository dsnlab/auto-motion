# auto-motion
Scripts for automated assessment of motion artifacts in fMRI data based on changes in global intensity and translation and rotation parameters.

## To use this package, run the scripts in the following order:
### 1. calculate_global_intensities.r
This script reads in nifti files and calculates the mean global intensity and standard deviation for each functional volume specified.

Edit options for this script in "calculate_global_intensities_config.R". If you are running this on a SLURM cluster, use "sbatch run_calc_glob_intens.bash" to run this job across 28 cores (or however many you prefer to specify in the header of the bash script).

### 2.motion_check.r
This script takes the rp text files generated during realignment and calculates Euclidian composite scores for X,Y,Z translation and pitch, yaw, roll rotation.

### 3. auto_trash.r
This script integrates global intensity values and Euclidian distance measures to determine which volumes have motion artifacts. Outputs include new rp_txt files with a trash regressor for motion artifacts, summaries of number and percent of trash volumes per subject and run, and plots of volumes by trash status for mean intensity, intensity standard deviation, and Euclidian rotation and traslation.

**Example plot**
![plot example](https://github.com/brainhack-eugene/auto-motion/blob/master/plot_example.png)
