# author: dani cosme
# email: dcosme@uoregon.edu
# version: 0.1
# date: 2017-03-03

# This script loads manually coded rp_txt files for each subject and run, concatenates them,
# and returns a csv file 'study_manuallyCoded.csv'

#------------------------------------------------------
# load packages
#------------------------------------------------------
osuRepo = 'http://ftp.osuosl.org/pub/cran/'

if(!require(tidyverse)){
  install.packages('tidyverse',repos=osuRepo)
}

#------------------------------------------------------
# define variables
#------------------------------------------------------

# paths
artifactDir = "/Volumes/FP/research/dsnlab/Studies/FP/motion/rp_art_txt/"
outputDir = "/Volumes/psych-cog/dsnlab/auto-motion-output/"

# variables
study = "FP"
rpPattern = "^rp_(FP[0-9]{3})_(.*).txt"
rpCols = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash")

#------------------------------------------------------
# load files and concatenate them
#------------------------------------------------------

# generate file list
file_list = list.files(artifactDir, pattern = rpPattern)

for (file in file_list){
  # if the merged dataset doesn't exist, create it
  if (!exists("dataset")){
    temp = read.table(paste0(artifactDir,file))
    colnames(temp) = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash")
    dataset = data.frame(temp, file = rep(file,count(temp))) %>% 
      mutate(volume = sprintf("%04d",row_number())) %>%
      extract(file,c("subjectID","run"), rpPattern)
  }

# if the merged dataset does exist, append to it
  else {
    temp_dataset = read.table(paste0(artifactDir,file))
    colnames(temp_dataset) = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash")
    temp_dataset = data.frame(temp_dataset, file = rep(file,count(temp_dataset))) %>% 
      mutate(volume = sprintf("%04d",row_number())) %>%
      extract(file,c("subjectID","run"), rpPattern)
    dataset = rbind(dataset, temp_dataset)
    rm(temp_dataset)
  }
}

#------------------------------------------------------
# write csv
#------------------------------------------------------
write.csv(dataset, paste0(outputDir,study,'_manuallyCoded.csv'), row.names = FALSE)
