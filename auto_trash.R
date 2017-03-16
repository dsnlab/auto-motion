# author: dani cosme
# email: dcosme@uoregon.edu
# version: 0.1
# date: 2017-03-04

# This script loads globalIntensity file, codes volues as trash, and 
# returns 'study_autoTrash.csv'

#------------------------------------------------------
# define variables
#------------------------------------------------------
# paths
outputDir = '/Volumes/psych-cog/dsnlab/auto-motion-output/'

# variables
study = "FP"

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
               thresholdDiff.mean = sdDiff.mean*2.5, 

               meanDiff.sd = mean(Diff.sd, na.rm=TRUE),
               sdDiff.sd = sd(Diff.sd, na.rm=TRUE),
               thresholdDiff.sd = sdDiff.sd*2.5, 
               
               trashDiff = ifelse(Diff.mean > (meanDiff.mean + thresholdDiff.mean) | Diff.mean < (meanDiff.mean - thresholdDiff.mean), 1, 0),
               #trashDiff = ifelse(Diff.sd > (meanDiff.sd + thresholdDiff.sd) | Diff.sd < (meanDiff.sd - thresholdDiff.sd), 2, 0),
               behind = lead(trashDiff), 
               ahead = lag(trashDiff), 
               # recode as trash if volume behind and in front are both marked as trash
               trashDiff = ifelse(trashDiff == 0 & behind == 1 & ahead == 1, 1, trashDiff)) %>%
               #aheadVal. = lead(Diff.mean)) %>%
               # reduce false positives on last volume in motion sequence
               #trashDiff = ifelse(trashDiff == 1 & behind == 1 & ahead == 0 & aheadVal < (meanDiff + sdDiff) & aheadVal > (meanDiff - sdDiff), 0, trashDiff)) %>%
        select(subjectID, run, volume, Diff.mean, Diff.sd, volMean, volSD, trashDiff)

#------------------------------------------------------
# write csv
#------------------------------------------------------
write.csv(trash, paste0(outputDir,study,'_autoTrash.csv'), row.names = FALSE)

