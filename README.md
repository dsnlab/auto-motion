[![DOI](https://zenodo.org/badge/96470945.svg)](https://zenodo.org/badge/latestdoi/96470945)

# auto-motion
Scripts for automated assessment of motion artifacts in fMRI data based on changes in global intensity and translation and rotation parameters.

** Please note this code base is no longer being supported. Please check out recent work here: https://github.com/dcosme/auto-motion-fmriprep. **

## Pacakge installation on a SLURM cluster

To install the required packages you can use the SLURM-ready script, "install_packages.bash" by running `sbatch install_packages.bash`. 

### First time using R on a SLURM cluster

However, if you have not already specified a user-writable package location (e.g., if you've never run R on your SLURM cluster), this is likely to fail because
it will try to save packages in the system package library. You can easily set a default user library by running R and installing an arbitrary package:

```bash
SLURM-system $ srun --pty --mem 8000 /bin/bash
SLURM-system-n002 $ module load R gcc
SLURM-system-n002 $ R
> install.packages('devtools')
```

When asked if you want to create a new library directory, answer "y" and allow installation to complete. When done, you can exit R using `q()` and answering "n" 
to the question you're asked about saving the workspace image, and then log out of the temporary node you logged into with `srun` by typing `exit`. You can now 
run the above instructions.

## To use this package, run the scripts in the following order:

### 1. `calculate_global_intensities.r`
This script reads in nifti files and calculates the mean global intensity and standard deviation for each functional volume specified.

Edit options for this script in "calculate_global_intensities_config.R". If you are running this on a SLURM cluster, use `sbatch run_calc_glob_intens.bash` to run this job across 28 cores (or however many you prefer to specify in the header of the bash script).

### 1.2. stripe_detect.r (see below)

Optional, and experimental!

### 2.motion_check.r
This script takes the rp text files generated during realignment and calculates Euclidian composite scores for X,Y,Z translation and pitch, yaw, roll rotation.

### 3. `auto_trash.r`
This script integrates global intensity values and Euclidian distance measures to determine which volumes have motion artifacts. Outputs include new rp_txt files with a trash regressor for motion artifacts, summaries of number and percent of trash volumes per subject and run, and plots of volumes by trash status for mean intensity, intensity standard deviation, and Euclidian rotation and traslation.

**Example plot**
![plot example](plot_example.png)

## Stripe Detection

The `stripe_detect.r` script attempts to automatically detect striping on volumes.

This is even more experimental than the above intensity change detection. The main file for running this is `stripe_detect.r`. To set the proper paths, open the file and edit lines below `# define variables`. 

It is set up to allow parallelization on an HPC cluster using array indexing. If you are running it on a local computer, it will still attempt to parallize across cores if `parallelize = T`. Once options are set, you can simply run `Rscript stripe_detect.r` from the command line.

If you are running it on an HPC cluster, you will need to edit the file `run_stripe_detect.bash` for your cluster. To index this properly, you need to know how many files it will process. If you run `Rscript stripe_detect.r filecount` from the command line, it will provide you with the command line you need to run for proper indexing on a SLURM system.

Make sure you specify output directories in both `run_stripe_detect.bash` and `stripe_detect.r` correctly -- this is probably the biggest cause of errors (for me, so far).

When the script finishes, the output file(s) will be in the output directory specified in the script.

**Striping Detection Example Plot**
![stripe plot](example_stripe_detect.png)
