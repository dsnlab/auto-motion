# author: Dani Cosme
# email: dcosme@uoregon.edu
# version: 0.1
# date: 2017-03-03

# This script loads functional volumes, calculates the mean global intensity value,
# and returns a csv file 'study_globalIntensities.csv'
# 
# Inputs:
# * subjectDir = path to subject directory
# * functionalDir = path from subject's directory to to functional files
# * outputDir = path where study_globalIntensities.csv will be written
# * study = study name
# * subPattern = regular expression for subject IDs
# * prefix = SPM prefix appended to functional images; use "" to ignore
# * runPattern = regular expression for run names; use "" to specify all directories in $functionalDir
# * threshold = voxel intensity value used to truncate the distribution
# 
# Outputs:
# * study_globalIntensities.csv = CSV file with global intensity value for each image

#------------------------------------------------------
# load packages
#------------------------------------------------------
osuRepo = 'http://ftp.osuosl.org/pub/cran/'

if(!require(devtools)){
  install.packages('devtools',repos=osuRepo)
}
if(!require(RNifti)){
  devtools::install_github("jonclayden/RNifti")
}
require(RNifti)
if(!require(tidyverse)){
  install.packages('tidyverse',repos=osuRepo)
}
require(tidyverse)
if(!require(parallel)){
  install.packages('parallel',repos=osuRepo)
}
require(parallel)

#------------------------------------------------------
# define variables
# these variables are all you should need to change
# to run the script
#------------------------------------------------------

# paths
subjectDir = "/Users/ralph/Documents/tds/fMRI/subjects/" #"/Volumes/FP/research/dsnlab/Studies/FP/subjects/" #"/Volumes/psych-cog/dsnlab/TDS/archive/subjects_G80/"
functionalDir = "" #"/ppc/functionals/"
outputDir = "/Users/ralph/Documents/tds/fMRI/analysis/fx/motion/auto-motion-output/" #"/Volumes/psych-cog/dsnlab/auto-motion-output/" 

# variables
study = "tds" #"FP"
subPattern = "^[0-9]{3}" #"^FP[0-9]{3}"
prefix = "ru" #"o" 
runPattern = "(cyb|stop|vid)[1-8]" #"^run*" 
threshold = 5000
final_output_csv = file.path(outputDir,paste0(study,'_globalIntensities_test_par.csv'))
parallelize = TRUE
leave_n_free_cores = 1

#------------------------------------------------------
# calculate mean intensity for each functional image
#------------------------------------------------------

# get subjects list from subject directory
subjects = list.files(subjectDir, pattern = subPattern)

globint_for_sub <- function(sub, subjectDir, functionalDir, runPattern, prefix, threshold){
  runs = list.files(paste0(subjectDir,sub,functionalDir), pattern=runPattern)
  
  for (run in runs){
    # assign pattern based on prefix and run
    filePattern = paste0('^',prefix,'.*',run,'_*([0-9]{4}).nii.*')
    
    # generate file path
    path = file.path(subjectDir,sub,'/',functionalDir,run)
    file_list = list.files(path, pattern = filePattern)
    
    for (file in file_list){
      # if the merged dataset doesn't exist, create it
      if (!exists("dataset")){
        img = RNifti::readNifti(paste0(path,"/",file), internal = FALSE) #using `::` allows us to not load the package when parallelized
        dataset = tidyr::extract(data.frame(subjectID = sub,
                                            file = file,
                                            run = run,
                                            volMean = mean(img[img > threshold], na.rm=TRUE),
                                            volSD = sd(img[img > threshold], na.rm=TRUE)),
                                 file, c("volume"), filePattern)
      }
      
      # if the merged dataset does exist, append to it
      else {
        img = RNifti::readNifti(paste0(path,"/",file), internal = FALSE)
        temp_dataset = tidyr::extract(data.frame(subjectID = sub,
                                                 file = file,
                                                 run = run,
                                                 volMean = mean(img[img > threshold], na.rm=TRUE),
                                                 volSD = sd(img[img > threshold], na.rm=TRUE)),
                                      file, c("volume"), filePattern)
        dataset <- dplyr::bind_rows(dataset, temp_dataset)
        rm(temp_dataset)
      }
    }
  }
  if (!exists("dataset")){
    dataset = data.frame(subjectID = sub,
                         file = NA,
                         run = NA,
                         volMean = NA,
                         volSD = NA)
  }
  return(dataset)
}

if(parallelize){
  time_it_took <- system.time({
    parallelCluster <- parallel::makeCluster(parallel::detectCores() - leave_n_free_cores)
    print(parallelCluster)
    datasets <- parallel::parLapply(parallelCluster, 
                                    subjects, 
                                    globint_for_sub, subjectDir, functionalDir, runPattern, prefix, threshold)
    outdata <- bind_rows(datasets)
    # Shutdown cluster neatly
    cat("Shutting down cluster...")
    if(!is.null(parallelCluster)) {
      parallel::stopCluster(parallelCluster)
      parallelCluster <- c()
    }
  })
} else {
  time_it_took <- system.time({
    datasets <- lapply(subjects, 
                       globint_for_sub, subjectDir, functionalDir, runPattern, prefix, threshold)
    outdata <- bind_rows(datasets)
  })
}
cat(paste0("For ", length(subjects), " participant IDs, the system logged this much time: \n"))
print(time_it_took)


#------------------------------------------------------
# write csv
#------------------------------------------------------
if (!dir.exists(dirname(final_output_csv))){
  dir.create(dirname(final_output_csv))
}
write.csv(dataset, final_output_csv, row.names = FALSE)
