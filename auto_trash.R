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

source('auto_trash_config.R')

#------------------------------------------------------
# load global intensity data
#------------------------------------------------------
# global intensity file created using calculate_global_intensities.R
intensities = read.csv(paste0(outputDir,study,'_globalIntensities.csv'))

#------------------------------------------------------
# load stripe data
#------------------------------------------------------
# stripe file created using stripe_detect.R
file_list = list.files(outputDir, pattern = stripePattern)

for (file in file_list){
  # if the merged dataset doesn't exist, create it
  if (!exists("stripes")){
    temp = read.csv(paste0(outputDir,file))
    stripes = data.frame(temp) %>% 
      rename("volume" = t) %>%
      select(-file)
    rm(temp)
  }
  
  # if the merged dataset does exist, append to it
  else {
    temp_dataset = read.csv(paste0(outputDir,file))
    temp_dataset = data.frame(temp_dataset) %>% 
      rename("volume" = t) %>%
      select(-file)
    stripes = rbind(stripes, temp_dataset)
    rm(temp_dataset)
  }
}

#------------------------------------------------------
# load rp_txt files and concatenate them
#------------------------------------------------------
# generate file list
file_list = list.files(rpDir, pattern = rpPattern)

for (file in file_list){
  # if the merged dataset doesn't exist, create it
  if (!exists("rp")){
    temp = read.table(paste0(rpDir,file))
    colnames(temp) = rpCols
    rp = data.frame(temp, file = rep(file,count(temp))) %>% 
      mutate(volume = row_number()) %>%
      extract(file,c("subjectID","run"), rpPattern)
    rm(temp)
  }
  
  # if the merged dataset does exist, append to it
  else {
    temp_dataset = read.table(paste0(rpDir,file))
    colnames(temp_dataset) = rpCols
    temp_dataset = data.frame(temp_dataset, file = rep(file,count(temp_dataset))) %>% 
      mutate(volume = row_number()) %>%
      extract(file,c("subjectID","run"), rpPattern)
    rp = rbind(rp, temp_dataset)
    rm(temp_dataset)
  }
}

#------------------------------------------------------
# merge dataframes
#------------------------------------------------------
joined = left_join(stripes, intensities, by = c("subjectID", "run", "volume")) %>%
  left_join(., rp, by = c("subjectID", "run", "volume")) %>%
  mutate(tile = paste0("tile_",tile)) %>%
  group_by(subjectID, run, tile) %>%
  mutate(Diff.mean = volMean - lag(volMean),
         Diff.sd = volSD - lag(volSD)) %>%
  spread(tile, freqtile_power)

#------------------------------------------------------
# create trash regressors 
#------------------------------------------------------
trash = joined %>%
  gather(tile, freqtile_power, starts_with("tile")) %>%
  filter(tile %in% c("tile_1", "tile_10")) %>%
  
  # code trash based on mean, sd, and rp
  ungroup %>%
  mutate(meanDiff.mean = mean(Diff.mean, na.rm=TRUE),
         sdDiff.mean = sd(Diff.mean, na.rm=TRUE),
         meanDiff.sd = mean(Diff.sd, na.rm=TRUE),
         sdDiff.sd = sd(Diff.sd, na.rm=TRUE),
         
         # code volumes above mean thresholds as trash
         upper.mean = meanDiff.mean + 2*sdDiff.mean,
         lower.mean = meanDiff.mean - 2*sdDiff.mean,
         trash.mean = ifelse(Diff.mean > upper.mean | Diff.mean < lower.mean, 1, 0),
         trash.mean = ifelse(is.na(Diff.mean),0,trash.mean),
         
         upper.sd = meanDiff.sd + 2*sdDiff.sd,
         lower.sd = meanDiff.sd - 2*sdDiff.sd,
         trash.sd = ifelse(Diff.sd > upper.sd | Diff.sd < lower.sd, 1, 0),
         trash.sd = ifelse(is.na(Diff.sd),0,trash.sd),
         
         # code volumes with more than +/- .25mm translation or rotation in Euclidian distance
         trash.rp.tr = ifelse(euclidian_trans_deriv > .25 | euclidian_trans_deriv < -.25, 1, 0),
         trash.rp.rot = ifelse(euclidian_rot_deriv > .25 | euclidian_rot_deriv < -.25, 1, 0)) %>%
  select(-meanDiff.mean, -meanDiff.sd, -sdDiff.mean, -sdDiff.sd) %>%
  
  # code trash based on striping
  group_by(subjectID, run, tile) %>%
  mutate(freqtile_power_c = freqtile_power - mean(freqtile_power, na.rm=TRUE)) %>%
  ungroup() %>%
  select(-freqtile_power) %>%
  spread(tile,freqtile_power_c) %>%
  mutate(trash.stripe = ifelse(tile_1 < -.035 & tile_10 > .00025, 1, 0)) %>%
  
  # combine trash
  mutate(trash.combined = ifelse(trash.stripe == 1, 1, 0),
         trash.sum = trash.rp.tr + trash.rp.rot + trash.mean + trash.sd + trash.stripe,
         trash.combined = ifelse((trash.rp.tr + trash.rp.rot + trash.mean + trash.sd) > 1, 1, trash.combined)) %>%
  
  # recode as trash if volume behind and in front are both marked as trash
  mutate(trash.combined = ifelse(trash.combined == 0 & lag(trash.combined) == 1 & lead(trash.combined) == 1, 1, trash.combined)) %>%
  
  # code first volume as trash if second volume is trash
  mutate(trash.combined = ifelse(volume == 1 & lead(trash.combined) == 1, 1, trash.combined)) %>%
  select(subjectID, run, volume, Diff.mean, Diff.sd, volMean, volSD, starts_with("euclidian"), tile_1, tile_10, trash.rp.tr, trash.rp.rot, trash.mean, trash.sd, trash.stripe, trash.combined)

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
  if(!file.exists(rpOutputDir)){
    message(paste0(rpOutputDir, ' does not exist. Creating it...'))
    dir.create(rpOutputDir)
  }
  
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
  if(!file.exists(plotDir)){
    message(paste0(plotDir, ' does not exist. Creating it...'))
    dir.create(plotDir)
  }
  
  # visualize for each subject subject
  trash.plot = trash %>%
    mutate(trash.combined = ifelse(trash.combined == 0, NA, trash.combined),
          code = ifelse(trash.combined == 1, "trash", ""),
          label = ifelse(regexpr('.*', trash.combined), as.character(volume), '')) %>%
    select(-volMean, -volSD, -euclidian_trans, -euclidian_rot, -starts_with("trash")) %>%
    gather(measure, value, -c(subjectID, run, volume, code, label))
  
  nada = trash.plot %>% group_by(subjectID) %>%
    do({
      plot = ggplot(., aes(volume, value)) + 
        geom_line(size = .25) +
        geom_point(data = subset(., !is.na(code)), aes(color = code), size = 3) +
        geom_text(aes(label = label), size = 1.5) +
        facet_grid(measure ~ run, scales= "free") +
        scale_colour_manual(values = "#E4B80E", drop = FALSE)
        labs(title = .$subjectID[[1]])
      print(plot)
      ggsave(plot, file=paste0(plotDir,.$subjectID[[1]],'.pdf'), height = 12, width = 14)
      data.frame()
    })
}
