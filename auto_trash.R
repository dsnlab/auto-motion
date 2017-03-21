# author: dani cosme
# email: dcosme@uoregon.edu
# version: 0.1
# date: 2017-03-04

# This script loads globalIntensity file, codes volues as trash, and 
# returns 'study_autoTrash.csv'. It will also write new rp_txt files 
# if writeRP = TRUE and plots if writePlots = TRUE.

# 
# Inputs:
# * outputDir = path where study_globalIntensities.csv will be written
# * rpDir = path to original rp_txt file directory 
# * rpOutpuDir = path to output directory to write new rp_txt files; this directory must exist
# * plotDir = path to output directory to write plots; this directory must exist.
# * study = study name
# * rpPattern = regular expression for rp_txt files
# * rpCols = rp column names
# * writeRP = whether to write out new rp_txt files; use TRUE or FALSE
# * writePlots = whether to write plots for each subject; use TRUE or FALSE
# 
# Outputs:
# * study_globalIntensities.csv = CSV file with global intensity value for each image
# * if writeRP = TRUE, new rp_txt files will be written
# * if writePlots = TRUE, plots for each subjects will be written to outputDir

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
outputDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/'
rpDir = '/Volumes/FP/research/dsnlab/Studies/FP/motion/rp_txt/'
rpOutpuDir = '/Volumes/FP/research/dsnlab/Studies/FP/motion/rp_auto_txt/'
plotDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/plots/FP/'

# variables
study = "FP"
rpPattern = "^rp_(FP[0-9]{3})_(.*).txt"
rpCols = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash")

# write new rp_txt files?
writeRP = TRUE
writePlots = TRUE

#------------------------------------------------------
# load data
#------------------------------------------------------
# global intensity file created using calculate_global_intensities.R
intensities = read.csv(paste0(outputDir,study,'_globalIntensities.csv'))

#------------------------------------------------------
# create trash regressors
#------------------------------------------------------
trash = intensities %>% group_by(subjectID, run) %>%
        mutate(Diff.mean = volMean - lag(volMean),
               Diff.sd = volSD - lag(volSD)) %>%
        ungroup %>%
        mutate(meanDiff.mean = mean(Diff.mean, na.rm=TRUE),
               sdDiff.mean = sd(Diff.mean, na.rm=TRUE),
               thresholdDiff.mean = sdDiff.mean*2, 

               meanDiff.sd = mean(Diff.sd, na.rm=TRUE),
               sdDiff.sd = sd(Diff.sd, na.rm=TRUE),
               thresholdDiff.sd = sdDiff.sd*4, 
               trashDiff = ifelse(Diff.mean > (meanDiff.mean + thresholdDiff.mean) | Diff.mean < (meanDiff.mean - thresholdDiff.mean), 1, 0),
               trashDiff = ifelse(Diff.sd > (meanDiff.sd + thresholdDiff.sd) | Diff.sd < (meanDiff.sd - thresholdDiff.sd), 1, trashDiff),
               behind = lead(trashDiff), 
               ahead = lag(trashDiff), 
               # recode as trash if volume behind and in front are both marked as trash
               trashDiff = ifelse(trashDiff == 0 & behind == 1 & ahead == 1, 1, trashDiff),
               # reduce false negatives before trash volume
               trashDiff = ifelse((trashDiff == 0 & lead(trashDiff == 1)) & (Diff.mean > (meanDiff.mean + .75*thresholdDiff.mean) | Diff.mean < (meanDiff.mean - .75*thresholdDiff.mean)), 1, trashDiff)) %>%
               #aheadVal = lead(Diff.mean)) %>%
               # reduce false positives on last volume in motion sequence
               #trashDiff = ifelse(trashDiff == 1 & behind == 1 & ahead == 0 & aheadVal < (meanDiff + sdDiff) & aheadVal > (meanDiff - sdDiff), 0, trashDiff)) %>%
        select(subjectID, run, volume, Diff.mean, Diff.sd, volMean, volSD, trashDiff)

#------------------------------------------------------
# write csv
#------------------------------------------------------
write.csv(trash, paste0(outputDir,study,'_autoTrash.csv'), row.names = FALSE)

#------------------------------------------------------
# merge with rp_txt and write new trash regressors
#------------------------------------------------------
if (writeRP){
  #------------------------------------------------------
  # load rp_txt files and concatenate them
  #------------------------------------------------------
  # generate file list
  file_list = list.files(rpDir, pattern = rpPattern)
  
  for (file in file_list){
    # if the merged dataset doesn't exist, create it
    if (!exists("dataset")){
      temp = read.table(paste0(rpDir,file))
      colnames(temp) = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash")
      dataset = data.frame(temp, file = rep(file,count(temp))) %>% 
        mutate(volume = sprintf("%04d",row_number())) %>%
        extract(file,c("subjectID","run"), rpPattern)
    }
    
    # if the merged dataset does exist, append to it
    else {
      temp_dataset = read.table(paste0(rpDir,file))
      colnames(temp_dataset) = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash")
      temp_dataset = data.frame(temp_dataset, file = rep(file,count(temp_dataset))) %>% 
        mutate(volume = sprintf("%04d",row_number())) %>%
        extract(file,c("subjectID","run"), rpPattern)
      dataset = rbind(dataset, temp_dataset)
      rm(temp_dataset)
    }
  }
  
  #------------------------------------------------------
  # merge trash regressors
  #------------------------------------------------------
  trash.merge = trash %>% 
    select(subjectID, run, volume, trashDiff) %>%
    mutate(subjectID = as.character(subjectID),
           run = as.character(run))
  
  rp = dataset %>%
    mutate(volume = as.integer(volume)) %>%
    left_join(., trash.merge, by = c("subjectID", "run", "volume")) %>%
    mutate(trashCombined = ifelse(is.na(trashDiff), 0, 
                                  ifelse(trash == 1 | trashDiff == 1, 1, 0))) %>%
    select(subjectID, run, volume, starts_with("euclidian"), trashCombined)
  
  #------------------------------------------------------
  # write rp_txt files
  #------------------------------------------------------
  rp_files_written = rp %>% 
    arrange(subjectID, run, volume) %>% 
    group_by(subjectID, run) %>% 
    do({
      fname=paste(
        rpOutpuDir,
        'rp_',.$subjectID[[1]],'_',.$run[[1]],'.txt',
        sep='')
      write.table(
        .[,c(-1,-2,-3)],
        fname,
        quote=F,
        sep='   ',
        row.names=F,
        col.names=F)
      data.frame(rp_file_name=fname)
    })
}

#------------------------------------------------------
# plot data for each subject
#------------------------------------------------------
if (writePlots){
  # visualize for each subject subject
  trash.plot = dataset %>%
    mutate(volume = as.integer(volume)) %>%
    left_join(., trash, by = c("subjectID", "run", "volume")) %>%
    mutate(code = ifelse(trashDiff == 1 & trash == 1, 2, 
                         ifelse(trashDiff == 1 & trash == 0, 3, trash))) %>%
    select(-starts_with("euclidian"), -starts_with("Diff"), -starts_with("trash")) %>%
    gather(measure, value, -c(subjectID, run, volume, code))
  
  nada = trash.plot %>% group_by(subjectID) %>%
    do({
      plot = ggplot(., aes(volume, value)) + 
        geom_point(aes(color = as.factor(code))) + 
        geom_line() + 
        facet_grid(measure ~ run, scales= "free") +
        scale_colour_discrete(drop = FALSE, labels=c("not trash", "motion script only", "motion + auto", "auto only")) + 
        labs(title = .$subjectID[[1]])
      print(plot)
      ggsave(plot, file=paste0(plotDir,.$subjectID[[1]],'.png'), width = 12)
      data.frame()
    })
}
