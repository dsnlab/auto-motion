#Functions for doing the work -- these would be packegized
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
  require(bspec)
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

getPSD <- function(aNiceNii, margins = c(1,4), parallel = T, mc.cores = 8){
  library(parallel)
  if(parallel){
    cl <- makeCluster(mc.cores)
    somepower <- parApply(cl, aNiceNii, margins, welchPSD_from_slice)
    stopCluster(cl)
  } else {
    somepower <- apply(aNiceNii, margins, welchPSD_from_slice)
  }
  slice_power <- apply(somepower, 2, bind_rows)
  
  slice_power_per_t <- bind_rows(lapply(as.list(1:length(slice_power)),
                                        function(t){
                                          adf <- as.data.frame(slice_power[t])
                                          adf$t <- t
                                          adf
                                        }))
}

#TEMPORARY
file="~/code_new/automotion-test-set/vids/projects/dsnlab/tds/fMRI/subjects_tds2/102/stop7/_rustop7_4d.nii.gz"
img = RNifti::readNifti(file, internal = FALSE)
#temporary

#do the work
library(tidyverse)

niceNii <- normalize_nii(img)
image(niceNii[floor(dim(boxed_scaled_img)[1]/2 + 2),,,31])

slice_power_per_t <- getPSD(niceNii)

#if you inspect the data frame, it doesn't return the same list of frequencies every time. so I want to
#group them into octiles to compute average power within each
freq_tiles <- quantile(unique(slice_power_per_t$freq), seq(0, 1, .125))
slice_power_per_t$tile <- findInterval(slice_power_per_t$freq, seq(0,.55,.05))
unique(slice_power_per_t$tile)

#summarize and plot
#let's ignore the lower frequencies because they don't show motion
slice_power_per_t %>% 
  group_by(t, tile) %>%
  summarize(freqtile_power = max(power)) %>%
  group_by(tile) %>%
  mutate(freqtile_power_c = freqtile_power - min(freqtile_power)) %>%
  filter(tile > 8) %>%
  mutate(red_zone = freqtile_power_c > .0003,
         label = ifelse(red_zone, as.character(t), '')) %>%
  ggplot(aes(x = t, y = freqtile_power_c)) +
  geom_line(aes(group = tile, alpha = tile), size = .25) +
  geom_point(aes(group = tile, alpha = tile, color = red_zone, size = red_zone)) +
  geom_text(aes(label = label), size = 3, position = position_nudge(x = 2, y = .000075)) + 
  # geom_segment(aes(xend = t, group = tile, alpha = tile), yend = 0) +
  # coord_trans(y = 'log') +
  scale_x_continuous(breaks = c(1, seq(5, max(slice_power_per_t$t), 5)), minor_breaks = 1:max(slice_power_per_t$t)) + 
  scale_color_manual(breaks = c(F, T), values = c('black', 'red')) +
  scale_alpha_continuous(range = c(.5, 1), breaks = 1:max(slice_power_per_t$tile)) + 
  scale_size_manual(breaks = c(F, T), values = c(.25, 1)) + 
  theme(axis.text.x = element_text(size = 6))
# +
#   geom_rect(aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), 
#             data = data.frame(xmin=c(10,80),xmax=c(40, 120), ymin=c(0,0), ymax=c(.016,.016), freqtile_power=c(0,0), t=c(0,0)))
