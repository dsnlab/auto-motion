#TEMPORARY
file="./s002_t1_ob_4D.nii.gz"
img = RNifti::readNifti(file, internal = FALSE)
#temporary


#Functions for doing the work -- these would be packegized
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
  powerDF <- data.frame(power = wl$power,
                        freq = wl$freq)
  return(powerDF)
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

#do the work
library(tidyverse)

#user is responsible for scaling the image so values range 0-1
#luckily there is a function for that
scaled_img <- quickscale(img)
image(scaled_img[,50,,1])

#test the power getting function to see what it returns
(img.power <- get_power_density_from_slice(scaled_img[,,,9], coronal_index = 50))

#I know that slice 9 is striped, so let's see what the power density looks like
plot(img.power$freq,img.power$power, log='y', type = 'l')

#now do it for every t in scaled_image using lapply
power_across_t <- lapply(as.list(1:dim(scaled_img)[4]), #create a list of t values to loop through
                         function(t) { #for each t, get power df and add the t marker
                           power_at_t <- get_power_density_from_slice(scaled_img[,,,t],
                                             coronal_index = 50)
                           power_at_t$t <- t
                           return(power_at_t)
                           })

#bind the dfs in the list into a single df
adf <- bind_rows(power_across_t)
head(adf)

#if you inspect the data frame, it doesn't return the same list of frequencies every time. so I want to
#group them into octiles to compute average power within each
freq_tiles <- quantile(unique(adf$freq), seq(0, 1, .125))
adf$tile <- findInterval(adf$freq, freq_tiles)

#summarize and plot
#let's ignore the lower frequencies because they don't show motion
adf %>% 
  group_by(t, tile) %>%
  summarize(freqtile_power = mean(power)) %>%
  filter(tile > 6) %>%
  mutate(red_zone = freqtile_power > .003,
         label = ifelse(red_zone, as.character(t), '')) %>%
  ggplot(aes(x = t, y = freqtile_power)) +
  geom_line(aes(group = tile, alpha = tile), size = .25) +
  geom_point(aes(group = tile, alpha = tile, color = red_zone, size = red_zone)) +
  geom_text(aes(label = label), size = 3, position = position_nudge(x = 2, y = .000075)) + 
  # geom_segment(aes(xend = t, group = tile, alpha = tile), yend = 0) +
  # coord_trans(y = 'log') +
  scale_x_continuous(breaks = c(1, seq(5, max(adf$t), 5)), minor_breaks = 1:max(adf$t)) + 
  scale_color_manual(breaks = c(F, T), values = c('black', 'red')) +
  scale_size_manual(breaks = c(F, T), values = c(-1, 1)) + 
  theme(axis.text.x = element_text(size = 6))+
  geom_rect(aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), 
            data = data.frame(xmin=c(10,80),xmax=c(40, 120), ymin=c(0,0), ymax=c(.016,.016), freqtile_power=c(0,0), t=c(0,0)))
