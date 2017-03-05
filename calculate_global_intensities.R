# author: dani cosme
# email: dcosme@uoregon.edu
# version: 0.1
# date: 2017-03-03

# This script loads functional volumes, calculates the mean global intensity value,
# and returns a csv file 'study_globalIntensities.csv'

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
#------------------------------------------------------

# paths
subjectDir = "/Volumes/psych-cog/dsnlab/TDS/archive/subjects_G80/"
functionalDir = "/ppc/functionals/"
motionDir = "/Volumes/psych-cog/dsnlab/TDS/archive/motion_QC/G80/"
outputDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/'

# variables
study = "tds"
subPattern = "^t[0-9]{3}"
prefix = "or" #prefix for functional files (or = reoriented, realigned)

#------------------------------------------------------
# calculate mean intensity for each functional image
#------------------------------------------------------

# get subjects list from subject directory
subjects = list.files(subjectDir, pattern = subPattern)

for (sub in subjects){
  # get runs from functional directory
  runs = list.files(paste0(subjectDir,sub,functionalDir))
  
  for (run in runs){
    # assign pattern based on prefix and run
    filePattern = paste0('^',prefix,'.*',run,'_([0-9]{4}).nii.*')
    
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
                             volMean = mean(img[img > 4000], na.rm=TRUE),
                             volSD = sd(img[img > 4000], na.rm=TRUE)) %>%
          extract(file, c("volume"), filePattern)
      }
    
    # if the merged dataset does exist, append to it
      else {
        img = readnii(paste0(path,"/",file))
        temp_dataset = data.frame(subjectID = sub,
                                  file = file,
                                  run = run,
                                  volMean = mean(img[img > 4000], na.rm=TRUE),
                                  volSD = sd(img[img > 4000], na.rm=TRUE)) %>%
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
write.csv(dataset, paste0(outputDir,study,'_globalIntensities.csv'), row.names = FALSE)
