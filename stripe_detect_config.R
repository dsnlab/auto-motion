# Inputs:
# * subjectDir = path to subject directory
# * functionalDir = path from subject's directory to to functional files
# * outputDir = path where study_globalIntensities.csv will be written
# * study = study name
# * subPattern = regular expression for subject IDs
# * prefix = SPM prefix appended to functional images; use "" to ignore
# * runPattern = regular expression for run names; use "" to specify all directories in $functionalDir
# * threshold = voxel intensity value used to truncate the distribution
# * final_output_csv = path and file name for 'study_globalIntensities.csv'
# * parallelize = use TRUE to parallelize, FALSE if not
# * leave_n_free_cores = number of cores to leave free

#------------------------------------------------------
# define variables
# these variables are all you should need to change
# to run the script
#------------------------------------------------------

# paths
subjectDir = "/Volumes/FP/research/dsnlab/Studies/FP/subjects/"
functionalDir = "/ppc/functionals/"
outputDir = "/Users/danicosme/Documents/code/dsnlab/automotion-test-set/output/FP" 

# variables
study = "FP"
nii4dFilePattern = "o.*_4d.nii.gz" #"_ru.*_4d.nii.gz"
subPattern = "FP[0-9]{3}"
prefix = "o" #"_run" 
runPattern = "run[1-3]" #"(?:cyb|stop|vid)[1-8]"
remove_old_output = F # For now, remove it manually.
parallelize = T #is.na(index)
leave_n_free_cores = 0