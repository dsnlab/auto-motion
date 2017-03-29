#TEMPORARY
file="/data/jflournoy/FP/FP034/run1/run1.nii"
img = RNifti::readNifti(file, internal = FALSE)
#temporary

require(pracma)
require(bspec)

quickscale <- function(timeseries){
  vmin <- min(timeseries)
  vmax <- max(timeseries)
  
  scaled <- (timeseries-vmin)/(vmax-vmin)
  return(scaled)
}

quickbox <- function(slice, threshold = .2){
  #slice is a 2d brain slice, assumed to contain values range 0-1
  #threshold is the brain cutoff
  brain_idx <- which(slice > threshold, arr.ind = T)
  xybounds <- list(c(min(brain_idx[,1]):max(brain_idx[,1])),
                   c(min(brain_idx[,2]):max(brain_idx[,2])))
  return(xybounds)
}

welchPSD_from_slice <- function(slice){
  #slice is a 2d matrix encoding a coronal slice in a normal orientation
  require(bspec)
  slice.ts <- ts(t(slice))
  wl <- welchPSD(slice.ts, seglength = dim(slice.ts)[1]-1, two.sided = TRUE, windowfun = hammingwindow)
  slice.power <- as.data.frame(t(wl$power))
  names(slice.power) <- wl$frequency
  return(slice.power)
}

get_power_density_from_slice <- function(scaled_volume, coronal_index = 50, usebox = T, boxthreshold=.2){
  #scaled_volume is a volume with values ranging 0-1
  if(usebox){
    abox <- quickbox(scaled_volume[,coronal_index,], threshold = boxthreshold)
    scaled_volume <- scaled_volume[abox[[1]],coronal_index,abox[[2]]]
  }
  power_density <- welchPSD_from_slice(scaled_volume)
  return(power_density)
}

scaled_img <- quickscale(img)
image(scaled_img[,50,,1])

img.power <- get_power_density_from_slice(scaled_img[,,,9], coronal_index = 50)

plot(names(img.power), img.power, log='y', type = 'l')

power_across_t <- lapply(as.list(1:dim(scaled_img)[4]), function(t) {
  power_at_t <- get_power_density_from_slice(scaled_img[,,,t],
                                             coronal_index = 50)
  return(power_at_t)
  })

library(tidyverse)
adf <- bind_rows(power_across_t)

plot(1:dim(adf)[1], adf[,30], type = 'l')
