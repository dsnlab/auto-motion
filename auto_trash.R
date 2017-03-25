# author: dani cosme
# email: dcosme@uoregon.edu
# date: 2017-03-04

# This script loads globalIntensity file, codes volues as trash, and 
# returns 'study_autoTrash.csv' as well as summaries by subject, subject and run,
# and trash volumes only. It will also write new rp_txt files 
# if writeRP = TRUE and plots if writePlots = TRUE.

# Inputs:
# * outputDir = path where study_globalIntensities.csv and summary csv files will be written
# * rpDir = path to original rp_txt file directory 
# * rpOutputDir = path to output directory to write new rp_txt files; this directory must exist
# * plotDir = path to output directory to write plots; this directory must exist.
# * study = study name
# * rpPattern = regular expression for rp_txt files
# * rpCols = rp column names
# * writeRP = whether to write out new rp_txt files; use TRUE or FALSE
# * writePlots = whether to write plots for each subject; use TRUE or FALSE
# 
# Outputs:
# * study_globalIntensities.csv = CSV file with global intensity value for each image
# * study_summaryRun.csv = CSV file with summary by subject and run
# * study_summarySubject.csv = CSV file with summary by subject only
# * study_trashVols.csv = CSV file with trash volumes only
# * if writeRP = TRUE, new rp_txt files will be written
# * if writePlots = TRUE, plots for each subjects will be written to plotDir

#------------------------------------------------------
# load packages
#------------------------------------------------------
osuRepo = 'http://ftp.osuosl.org/pub/cran/'

if(!require(tidyverse)){
  install.packages('tidyverse',repos=osuRepo)
}

#------------------------------------------------------
# define variables
# these variables are all you should need to change
# to run the script
#------------------------------------------------------
# paths
rpDir = '/Volumes/FP/research/dsnlab/Studies/FP/motion/rp_txt/'
outputDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/'
rpOutputDir = '/Volumes/FP/research/dsnlab/Studies/FP/motion/rp_auto_txt/'
plotDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/plots/FP/'

# variables
study = "FP"
rpPattern = "^rp_(FP[0-9]{3})_(.*).txt"
rpCols = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash.rp")

# write new rp_txt and plots files?
writeRP = TRUE
writePlots = TRUE

#------------------------------------------------------
# load global intensity data
#------------------------------------------------------
# global intensity file created using calculate_global_intensities.R
intensities = read.csv(paste0(outputDir,study,'_globalIntensities.csv'))

#------------------------------------------------------
# load rp_txt files and concatenate them
#------------------------------------------------------
# generate file list
file_list = list.files(rpDir, pattern = rpPattern)

for (file in file_list){
  # if the merged dataset doesn't exist, create it
  if (!exists("dataset")){
    temp = read.table(paste0(rpDir,file))
    colnames(temp) = rpCols
    dataset = data.frame(temp, file = rep(file,count(temp))) %>% 
      mutate(volume = row_number()) %>%
      extract(file,c("subjectID","run"), rpPattern)
  }
  
  # if the merged dataset does exist, append to it
  else {
    temp_dataset = read.table(paste0(rpDir,file))
    colnames(temp_dataset) = rpCols
    temp_dataset = data.frame(temp_dataset, file = rep(file,count(temp_dataset))) %>% 
      mutate(volume = row_number()) %>%
      extract(file,c("subjectID","run"), rpPattern)
    dataset = rbind(dataset, temp_dataset)
    rm(temp_dataset)
  }
}

#------------------------------------------------------
# merge and create trash regressors
#------------------------------------------------------
trash = intensities %>% 
  mutate(subjectID = as.character(subjectID),
         run = as.character(run)) %>%
  left_join(., dataset, by = c("subjectID", "run", "volume")) %>%
  group_by(subjectID, run) %>%
  mutate(Diff.mean = volMean - lag(volMean),
         Diff.sd = volSD - lag(volSD)) %>%
  ungroup %>%
  mutate(meanDiff.mean = mean(Diff.mean, na.rm=TRUE),
         sdDiff.mean = sd(Diff.mean, na.rm=TRUE),
         meanDiff.sd = mean(Diff.sd, na.rm=TRUE),
         sdDiff.sd = sd(Diff.sd, na.rm=TRUE),
         
         # code volumes above mean thresholds as trash
         trash.auto = ifelse(Diff.mean > (meanDiff.mean + 3*sdDiff.mean) | Diff.mean < (meanDiff.mean - 1.5*sdDiff.mean), 1, 0),
         trash.auto = ifelse(Diff.sd > (meanDiff.sd + 3*sdDiff.sd) | Diff.sd < (meanDiff.sd - 3*sdDiff.sd), 1, trash.auto),
         
         # code volumes with more than +/- .3mm translation in Euclidian distance
         trash.auto = ifelse(euclidian_trans_deriv > .3 | euclidian_trans_deriv < -.3, 1, trash.auto),
         # code volumes with more than +/- .3mm translation in Euclidian distance
         trash.auto = ifelse(euclidian_rot_deriv > .3 | euclidian_rot_deriv < -.3, 1, trash.auto),
         
         # recode as trash if volume behind and in front are both marked as trash
         trash.auto = ifelse(trash.auto == 0 & lag(trash.auto) == 1 & lead(trash.auto) == 1, 1, trash.auto),
         
         # reduce false positives on last volume in motion sequence
         trash.auto = ifelse((trash.auto == 1 & lag(trash.auto == 1) & lead(trash.auto == 0)) & lag(!is.na(Diff.mean)) & (Diff.mean < (meanDiff.mean + 1.5*sdDiff.mean) & Diff.mean > (meanDiff.mean - 3*sdDiff.mean)), 0, trash.auto),
         # reduce false negatives before trash volume
         trash.auto = ifelse((trash.auto == 0 & lead(trash.auto == 1)) & (Diff.mean > (meanDiff.mean + sdDiff.mean) | Diff.mean < (meanDiff.mean - sdDiff.mean)), 1, trash.auto),
         
         # code first volume as trash if second volume is trash
         trash.auto = ifelse(volume == 1 & lead(trash.auto) == 1, 1, trash.auto)) %>%
  mutate(trash.combined = ifelse(trash.rp == 1 | trash.auto == 1, 1, 0)) %>%
  select(subjectID, run, volume, Diff.mean, Diff.sd, volMean, volSD, starts_with("euclidian"), trash.rp, trash.auto, trash.combined)

#------------------------------------------------------
# write auto trash csv
#------------------------------------------------------
write.csv(trash, paste0(outputDir,study,'_autoTrash.csv'), row.names = FALSE)

#------------------------------------------------------
# summarize data and output csv files
#------------------------------------------------------
summary.run = trash %>% 
  group_by(subjectID, run) %>% 
  summarise(nVols = sum(trash.combined, na.rm = T),
            percent = round((sum(trash.combined, na.rm = T) / n())* 100,1))

summary.sub = trash %>% 
  group_by(subjectID) %>% 
  summarise(nVols = sum(trash.combined, na.rm = T),
            percent = round((sum(trash.combined, na.rm = T) / n())* 100,1))

summary.trash = trash %>%
  filter(trash.combined == 1) %>%
  select(subjectID, run, volume, trash.combined)

write.csv(summary.run, paste0(outputDir,study,'_summaryRun.csv'), row.names = FALSE)
write.csv(summary.sub, paste0(outputDir,study,'_summarySubject.csv'), row.names = FALSE)
write.csv(summary.trash, paste0(outputDir,study,'_trashVols.csv'), row.names = FALSE)

#------------------------------------------------------
# write rp_txt files
#------------------------------------------------------
if (writeRP){
rp = trash %>%
  select(subjectID, run, volume, starts_with("euclidian"), trash.combined) %>%
  mutate(trash.combined = ifelse(is.na(trash.combined), 0, trash.combined))
  
rp_files_written = rp %>% 
  arrange(subjectID, run, volume) %>% 
  group_by(subjectID, run) %>% 
  do({
    fname=paste(
      rpOutputDir,
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
  trash.plot = trash %>%
    mutate(trash.combined = ifelse(is.na(trash.combined), 0, trash.combined),
          code = ifelse(trash.combined == 1, "trash", "not trash")) %>%
    select(-starts_with("Diff"), -starts_with("trash")) %>%
    gather(measure, value, -c(subjectID, run, volume, code))
  
  nada = trash.plot %>% group_by(subjectID) %>%
    do({
      plot = ggplot(., aes(volume, value)) + 
        geom_point(aes(color = code)) + 
        geom_line() + 
        facet_grid(measure ~ run, scales= "free") +
        scale_colour_discrete(drop = FALSE) + 
        labs(title = .$subjectID[[1]])
      print(plot)
      ggsave(plot, file=paste0(plotDir,.$subjectID[[1]],'.pdf'), height = 10, width = 12)
      data.frame()
    })
}
