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

# Outputs:
# * study_globalIntensities.csv = CSV file with global intensity value for each image
# * study_summaryRun.csv = CSV file with summary by subject and run
# * study_summarySubject.csv = CSV file with summary by subject only
# * study_trashVols.csv = CSV file with trash volumes only
# * if writeRP = TRUE, new rp_txt files will be written
# * if writePlots = TRUE, plots for each subjects will be written to plotDir

#------------------------------------------------------
# define variables
# these variables are all you should need to change
# to run the script
#------------------------------------------------------

# paths
rpDir = '~/Documents/code/tds_auto-motion/auto-motion-output/rp_txt/'
outputDir = '~/Documents/code/tds_auto-motion/auto-motion-output/'
rpOutputDir = '~/Documents/code/tds_auto-motion/auto-motion-output/rp_auto_txt/'
plotDir = '~/Documents/code/tds_auto-motion/auto-motion-output/plots/'

# variables
study = "tds2"
rpPattern = "^rp_([0-9]{3})_(.*).txt"
rpCols = c("euclidian_trans","euclidian_rot","euclidian_trans_deriv","euclidian_rot_deriv","trash.rp")

# write new rp_txt and plots files?
writeRP = TRUE
writePlots = TRUE
