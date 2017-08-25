#!/bin/bash
#--------------------------------------------------------------
#
#SBATCH --job-name=stripe_detect
#SBATCH --output=output/stripe_detect_%A_%a.out
#
#SBATCH --cpus-per-task=28
#SBATCH --mem=6000
#SBATCH --partition=short,fat,long,longfat

module load R
srun Rscript stripe_detect.r $SLURM_ARRAY_TASK_ID 
