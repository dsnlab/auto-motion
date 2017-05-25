# author: Dani Cosme, John Flournoy
# email: dcosme@uoregon.edu
# version: 0.2
# date: 2017-05-25

# This script loads functional volumes, calculates the mean global intensity value,
# and returns a csv file 'study_globalIntensities.csv'
# 
# Inputs (in ..._config.R):
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
#
# Outputs:
# * study_globalIntensities.csv = CSV file with global intensity value for each image

#------------------------------------------------------
# load packages
#------------------------------------------------------
osuRepo = 'http://ftp.osuosl.org/pub/cran/'
nopackage_message = "Required packages not found\nPlease run 'bash install_packages.bash' or 'sbatch install_packages.bash'"

if(!require(devtools)){
  stop(nopackage_message)
}
if(!require(RNifti)){
  stop(nopackage_message)
}
require(RNifti)
if(!require(tidyverse)){
  stop(nopackage_message)
}
require(tidyverse)
if(!require(parallel)){
  stop(nopackage_message)
}
require(parallel)

source('calculate_global_intensities_config.R')

#------------------------------------------------------
# calculate mean intensity for each functional image
#------------------------------------------------------

# get subjects list from subject directory
subjects = list.files(subjectDir, pattern = subPattern)

message(paste0("Found ", length(unique(subjects)), " subject directories."))

globint_for_sub <- function(sub, subjectDir, functionalDir, runPattern, prefix, threshold){
  runs = list.files(paste0(subjectDir,sub,functionalDir), pattern=runPattern)
  
  for (run in runs){
    # assign pattern based on prefix and run
    filePattern = paste0('^',prefix,'.*',run,'_*([0-9]{4}).nii.*')
    
    # generate file path
    path = file.path(subjectDir,sub,'/',functionalDir,run)
    file_list = list.files(path, pattern = filePattern)
    
    message(paste0("Subject ", sub, ", run ", run, ": Found ", length(unique(file_list)), " files."))

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
                         run = NA,
                         volMean = NA,
                         volSD = NA,
                         volume = NA)
  }
  return(dataset)
}

if(parallelize){
  time_it_took <- system.time({
    parallelCluster <- parallel::makeCluster(parallel::detectCores() - leave_n_free_cores, outfile="")
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
message(paste0("For ", length(subjects), " participant IDs, the system logged this much time: \n"))
print(time_it_took)


#------------------------------------------------------
# write csv
#------------------------------------------------------
if (!dir.exists(dirname(final_output_csv))){
  dir.create(dirname(final_output_csv))
}
write.csv(outdata, final_output_csv, row.names = FALSE)
