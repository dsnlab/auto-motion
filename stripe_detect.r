#!/usr/bin/env Rscript
# This script loads functional volumes, generates info for detecting stripes,
# and returns a csv file specified in the options below.
#
# To use this efficiently on the grid, see 'run_stripe_detect.bash'
# 
# Inputs:
# * subjectDir = path to subject directory
# * functionalDir = path from subject's directory to to functional files
# * outputDir = path where study_globalIntensities.csv will be written
# * study = study name
# * subPattern = regular expression for subject IDs
# * prefix = SPM prefix appended to functional images; use "" to ignore
# * runPattern = regular expression for run names; use "" to specify all directories in $functionalDir
# * final_output_csv = path and file name for 'study_globalIntensities.csv'
# * parallelize = use TRUE to parallelize locally only, FALSE if not
# * leave_n_free_cores = number of cores to leave free
#
# Outputs:
# * study_globalIntensities.csv = CSV file with global intensity value for each image

#Command-line form:
#  Rscript script.R [index]
#or
#  Rscript script.R filecount
#where "index" is a number indexing the row for this particular call.
#If the command line argument exists, we turn off multi-core, assuming that
#the script is being run once per file across multiple CPUs on one or more
#HPC nodes.
#
#If you are running this on HPC/Talapas, first run
#  Rscript stripe_detect.r filecount
#and then follow the resulting instructions.
#
#The option "filecount" allows the script to merely return the number of
#files to be processed so one can set the HPC script up properly
options(warn=-1)
args = commandArgs(trailingOnly=T)

# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  file_n_only=F
  index=NA #not using nodes
} else if (length(args)==1 & !is.na(as.numeric(args[1]))) {
  #args is a single numeric value
  file_n_only=F
  index=as.numeric(args[1])
} else if (length(args)==1 & args[1] == 'filecount') {
  file_n_only=T
  index=NA
  message('Calculating number of files to be processed...')
} else {
  stop("Wrong arguments supplied.
Command-line form:
  Rscript script.R [index]
or
  Rscript script.R filecount")
}
options(warn=0)

#------------------------------------------------------
# load packages
#------------------------------------------------------
osuRepo = 'http://ftp.osuosl.org/pub/cran/'
nopackage_message = "Required packages not found\nPlease run 'bash install_packages.bash' or 'sbatch install_packages.bash'"

if(!require(bspec)){
  stop(nopackage_message)
}
require(bspec)
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

#------------------------------------------------------
# source variables
#------------------------------------------------------

source('stripe_detect_config.R')

#------------------------------------------------------
# Functions
#------------------------------------------------------

quickscale <- function(timeseries){
  vmin <- min(timeseries)
  vmax <- max(timeseries)
  
  scaled <- (timeseries-vmin)/(vmax-vmin)
  return(scaled)
}

quickbox <- function(volume, threshold = .2){
  #slice is a 2d brain slice, assumed to contain values range 0-1
  #threshold is the brain cutoff
  brain_idx <- which(volume > threshold, arr.ind = T)
  xybounds <- list(c(min(brain_idx[,1]):max(brain_idx[,1])),
                   c(min(brain_idx[,2]):max(brain_idx[,2])),
                   c(min(brain_idx[,3]):max(brain_idx[,3])))
  return(xybounds)
}

welchPSD_from_slice <- function(slice){
  #slice is a 2d matrix encoding a coronal slice in a normal orientation
  options(warn=-1)
  require(bspec)
  options(warn=0)
  slice.ts <- ts(t(slice))
  wl <- welchPSD(slice.ts, seglength = dim(slice.ts)[1]-1, two.sided = TRUE, windowfun = hammingwindow)
  powerDF <- data.frame(power = wl$power,
                        freq = wl$freq,
                        kappa = wl$kappa)
  return(powerDF)
}

get_power_density_from_slice <- function(scaled_slice, usebox = T, boxthreshold=.2){
  #scaled_volume is a volume with values ranging 0-1
  if(usebox){
    abox <- quickbox(scaled_slice, threshold = boxthreshold)
    scaled_slice <- scaled_slice[abox[[1]], abox[[2]]]
  }
  power_density <- welchPSD_from_slice(scaled_slice)
  return(power_density)
}

normalize_nii <- function(aNii) {
  scaled_img <- quickscale(aNii)
  abox <- quickbox(scaled_img[,,,1], threshold = .3)
  scaled_img[abox[[1]],abox[[2]],abox[[3]],]
}

getPSD <- function(aNiceNii, margins = c(1,4), parallel = T, aCluster = NA){
  #parlallel = T helps this go fast on a local computer
  if(parallel){
    if(length(aCluster) == 1 && is.na(aCluster)) aCluster <- makeCluster(getOption("mc.cores", 2L))
    somepower <- parApply(aCluster, aNiceNii, margins, welchPSD_from_slice)
  } else {
    somepower <- apply(aNiceNii, margins, welchPSD_from_slice)
  }
  slice_power <- apply(somepower, 2, dplyr::bind_rows)
  slice_power_per_t <- dplyr::bind_rows(lapply(as.list(1:length(slice_power)),
                                        function(t){
                                          adf <- as.data.frame(slice_power[t])
                                          adf$t <- t
                                          adf
                                        }))
}

stripes_for_nii <- function(filepath, parallel = F, aCluster = NA){
  img = RNifti::readNifti(filepath, internal = FALSE)
  
  niceNii <- normalize_nii(img)
  image(niceNii[floor(dim(niceNii)[1]/2 + 2),,,31])
  
  slice_power_per_t <- getPSD(niceNii, parallel = parallel, aCluster = aCluster)
  
  #list of frequencies isn't the same every time, so we want to
  #bin them
  freq_tiles <- quantile(unique(slice_power_per_t$freq), seq(0, 1, .125))
  slice_power_per_t$tile <- findInterval(slice_power_per_t$freq, seq(0,.55,.05))
  slice_power_per_t_reduced <- dplyr::summarize(dplyr::group_by(slice_power_per_t, t, tile), freqtile_power = max(power))
  return(slice_power_per_t_reduced)
}

#------------------------------------------------------
# Run the things
#------------------------------------------------------

final_output_csv = file.path(outputDir,paste0(study,'_stripes_', ifelse(is.na(index), 1, index), '.csv'))

if(parallelize){
  options(warn=-1)
  library(parallel)
  options(warn=0)
  mc.cores <- parallel::detectCores() - leave_n_free_cores
  cl <- makeCluster(mc.cores)
} else {
  cl <- NA
}

#extractSubRunPattern <- paste0('.*/*(', subPattern, ')/.*(', runPattern,').*', nii4dFilePattern)
filelist = data.frame(file = list.files(subjectDir, pattern = nii4dFilePattern, recursive = T))
fileListDF <- tidyr::extract(data = filelist,
                             col = file, into = c('subjectID', 'run'),
                             regex = paste0('.*/*(', subPattern, ')/.*(', runPattern,').*', nii4dFilePattern),
                             remove = F)
fileListDF$subjectDir <- subjectDir

if(file_n_only){
  message(paste0("Number of files to process: ", dim(fileListDF)[1],"\n",
		 "Run: sbatch --array=1-[number of files] run_stripe_detect.bash"))
} else {
  if(!file.exists(outputDir)){
      message(paste0(outputDir, ' does not exist. Creating it...'))
      dir.create(outputDir)
  }
  if(is.na(index)){
    options(warn=-1)
    library(dplyr,tidyr)
    options(warn=0)
    slice_power_per_t <- fileListDF %>%
      #slice(1:2) %>% ###TESTING
      group_by(file, subjectID, run) %>%
      do({
        file = paste0(.$subjectDir[[1]], .$file[[1]])
        message('Processing file: ', file)
        file_power_per_t <- stripes_for_nii(file, parallel = parallelize, aCluster = cl)
      })
    write.csv(slice_power_per_t, final_output_csv, row.names = F)
  } else {
    #index is set, so only do it for on the of the files.
    if(index > dim(fileListDF)[1]){
      stop("Index exceeds file list length.")
    }
    options(warn=-1)
    library(dplyr,tidyr)
    options(warn=0)
    slice_power_per_t <- fileListDF %>%
      slice(index) %>%
      group_by(file, subjectID, run) %>%
      do({
        file = paste0(.$subjectDir[[1]], .$file[[1]])
        message(file)
        file_power_per_t <- stripes_for_nii(file, parallel = parallelize, aCluster = cl)
      })
    if(file.exists(final_output_csv)){
      write.table(slice_power_per_t, final_output_csv, row.names = F, append = T, sep = ',', col.names = F)  
    } else {
      write.csv(slice_power_per_t, final_output_csv, row.names = F)  
    }
  }
  
  if(FALSE){
    # library(tidyverse)
    #summarize and plot
    #let's ignore the lower frequencies because they don't show motion
    # slice_power_per_t  %>%
    #   group_by(tile) %>%
    #   mutate(freqtile_power_c = freqtile_power - min(freqtile_power)) %>%
    #   filter(tile > 8) %>%
    #   mutate(red_zone = freqtile_power_c > .0003,
    #          label = ifelse(red_zone, as.character(t), '')) %>%
    #   ggplot(aes(x = t, y = freqtile_power_c)) +
    #   geom_line(aes(group = tile, alpha = tile), size = .25) +
    #   geom_point(aes(group = tile, alpha = tile, color = red_zone, size = red_zone)) +
    #   geom_text(aes(label = label), size = 3, position = position_nudge(x = 2, y = .000075)) + 
    #   # geom_segment(aes(xend = t, group = tile, alpha = tile), yend = 0) +
    #   # coord_trans(y = 'log') +
    #   scale_x_continuous(breaks = c(1, seq(5, max(slice_power_per_t$t), 5)), minor_breaks = 1:max(slice_power_per_t$t)) + 
    #   scale_color_manual(breaks = c(F, T), values = c('black', 'red')) +
    #   scale_alpha_continuous(range = c(.5, 1), breaks = 1:max(slice_power_per_t$tile)) + 
    #   scale_size_manual(breaks = c(F, T), values = c(.25, 1)) + 
    #   facet_wrap(~subjectID+run) + 
    #   theme(axis.text.x = element_text(size = 6))
    # +
    #   geom_rect(aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), 
    #             data = data.frame(xmin=c(10,80),xmax=c(40, 120), ymin=c(0,0), ymax=c(.016,.016), freqtile_power=c(0,0), t=c(0,0)))
  }
  if(parallelize){
    didTry <- try(stopCluster(cl))
  }
}



