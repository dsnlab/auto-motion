# author: dani cosme
# email: dcosme@uoregon.edu
# version: 0.1
# date: 2017-03-03

# This script loads afni 3dToutCount files and returns 'study_outcount.csv'

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
afniDir = "/Volumes/psych-cog/dsnlab/auto-motion-output/AFNI/FP/"
outputDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/'

# variables
study = "FP"
pattern = "(FP[0-9]{3})_(.*)_(p[0-9]{1}).csv"

#------------------------------------------------------
# load files and concatenate them
#------------------------------------------------------

# generate file list
file_list = list.files(afniDir, pattern = pattern)

for (file in file_list){
  # if the merged dataset doesn't exist, create it
  if (!exists("dataset")){
    temp = read.table(paste0(afniDir,file)) %>% rename("outliers" = V1)
    dataset = data.frame(file = rep(file,count(temp)), temp) %>% 
      mutate(volume = sprintf("%04d",row_number())) %>%
      extract(file,c("subjectID","run","poly"), pattern)
  }
  
  # if the merged dataset does exist, append to it
  else {
    temp = read.table(paste0(afniDir,file)) %>% rename("outliers" = V1)
    temp_dataset = data.frame(file = rep(file,count(temp)), temp) %>% 
      mutate(volume = sprintf("%04d",row_number())) %>%
      extract(file,c("subjectID","run","poly"), pattern)
    dataset = rbind(dataset, temp_dataset)
    rm(temp_dataset)
  }
}


#------------------------------------------------------
# write csv
#------------------------------------------------------
write.csv(dataset, paste0(outputDir,study,'_outcount.csv'), row.names = FALSE)
