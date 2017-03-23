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

if(!require(fslr)){
  install.packages('fslr',repos=osuRepo)
}
if(!require(tidyverse)){
  install.packages('tidyverse',repos=osuRepo)
}

#------------------------------------------------------
# define variables
# these variables are all you should need to change
# to run the script
#------------------------------------------------------

# paths
subjectDir = "/Volumes/FP/research/dsnlab/Studies/FP/subjects/" #"/Volumes/psych-cog/dsnlab/TDS/archive/subjects_G80/"
functionalDir = "/ppc/functionals/"
outputDir = "/Volumes/psych-cog/dsnlab/auto-motion-output/" 

# variables
study = "FP"
subPattern = "^FP[0-9]{3}"
prefix = "o" 
runPattern = "^run*" 
threshold = 5000
final_output_csv = file.path(outputDir,paste0(study,'_globalIntensities.csv'))

#------------------------------------------------------
# calculate mean intensity for each functional image
#------------------------------------------------------

# get subjects list from subject directory
subjects = list.files(subjectDir, pattern = subPattern)

for (sub in subjects){
  # get runs from functional directory
  runs = list.files(paste0(subjectDir,sub,functionalDir), pattern=runPattern)
  
  for (run in runs){
    # assign pattern based on prefix and run
    # filePattern = paste0('^',prefix,'.*',run,'.nii.*') # MVPA file pattern
    filePattern = paste0('^',prefix,'.*',run,'_*([0-9]{4}).nii.*')
    
    # generate file path
    path = paste0(subjectDir,sub,functionalDir,run)
    file_list = list.files(path, pattern = filePattern)
    
    for (file in file_list){
      # if the merged dataset doesn't exist, create it
      if (!exists("dataset")){
        img = readnii(paste0(path,"/",file))
        dataset = data.frame(subjectID = sub,
                             file = file,
                             run = run,
                             volMean = mean(img[img > threshold], na.rm=TRUE),
                             volSD = sd(img[img > threshold], na.rm=TRUE)) %>%
          extract(file, c("volume"), filePattern)
      }
      
      # if the merged dataset does exist, append to it
      else {
        img = readnii(paste0(path,"/",file))
        temp_dataset = data.frame(subjectID = sub,
                                  file = file,
                                  run = run,
                                  volMean = mean(img[img > threshold], na.rm=TRUE),
                                  volSD = sd(img[img > threshold], na.rm=TRUE)) %>%
          extract(file, c("volume"), filePattern)
        dataset <- rbind(dataset, temp_dataset)
        rm(temp_dataset)
      }
    }
  }
} 

#------------------------------------------------------
# write csv
#------------------------------------------------------
if (!dir.exists(dirname(final_output_csv))){
  dir.create(dirname(final_output_csv))
}
write.csv(dataset, final_output_csv, row.names = FALSE)
