# Inputs (for motion_check.R):
# * subjectDir = path to subject directory
# * functionalDir = path from subject's directory to to functional files
# * outputDir = path where study_globalIntensities.csv will be written
# * study = study name
# * subPattern = regular expression for subject IDs
# * prefix = SPM prefix appended to functional images; use "" to ignore
# * runPattern = regular expression for run names; use "" to specify all directories in $functionalDir
# * threshold = voxel intensity value used to truncate the distribution
# * final_output_csv = path and file name for 'study_globalIntensities.csv'
# * parallelize = use TRUE to parallelize, FALSE if not
# * leave_n_free_cores = number of cores to leave free

#------------------------------------------------------
# define variables
# these variables are all you should need to change
# to run the script
#------------------------------------------------------

# Directories
#######################
#	!!: Make sure the directories below exist. This script will not make them.
# base directory for subjects
subjsDir<-'/home/research/tds/subjects_G80' 
# requires trailing '/' - this is the path to prepend to output pdf filename. 
motionPDFdir<-'/home/research/tds/motion_QC/G80/' 
# requires trailing '/' - this is where the augmented rp_*txt files go
motion_rp_txt_dir<-'/home/research/tds/motion_QC/G80/rp_txt/'


# Extracting Subject and Run ids
#######################
# We need to extract subject id and run id from the path. To do so, 
# you need to set the regular expressions below to capture the correct 
# information. The expression needs to match the whole path -- for example:
# '^(t[0-9]{3})/.*txt' will match
# "t165/ppc/functionals/vid2/rp_vid2_0001.txt" in its entirety, but the 
# parentheses will allow us to pick out just the 't165'.
#
sid_regex<-'^(t[0-9]{3})/.*txt' #add regular expression for subject ID between the `()`
rid_regex<-'^t[0-9]{3}/ppc/functionals/(\\w+)/.*txt' #add regular expression for run ID between `()`

# Document options
#######################
# Do you want to export PDF files into the above motionPDFdir?
PLOT_EXPORT = FALSE
# can also be html_document
docType<-'pdf_document' 
# change according to docType
docTypeExtension<-'.pdf' 
figureWidth<-7.75
figureHeight<-10.25
dpi=300
dev='svg' #Can change to png or pdf if you prefer.

# rp_txt output options
#######################
# Do you want to export new rp_txt files into the above rp_txt_dir?
RP_EXPORT = TRUE
# These are the first 3 columns in the raw rp_*txt file output by SPM
# units: mm
raw_trans = FALSE
# These are the second 3 columns in the raw rp_*txt file output by SPM
# units: mm on a circle where r=50mm
raw_rot = FALSE
# These next two are the above two but with their lag-1 values subtracted - volume to volume change
# units: mm
raw_trans_deriv = FALSE
raw_rot_deriv = FALSE
# These next four are the same as the above 4 but detrended with `detrend`
# units: mm
dt_raw_trans = FALSE
dt_raw_rot = FALSE
dt_raw_trans_deriv = FALSE
dt_raw_rot_deriv = FALSE
# Absolute displacement, calc'd below
# units: mm
euclidian_trans = TRUE
# This is proportional to absolute rotation, calc'd below
# units: mm
euclidian_rot = TRUE
# These next two are the volume to volume differences in the above two
# units: mm
euclidian_trans_deriv = TRUE
euclidian_rot_deriv = TRUE

## Trash regressor options
#######################
TRASH_REGRESSOR = TRUE
#`trash_expression` is a logical expression using *only* the variable names above.
#For example `(raw_trans_deriv > 2)` would check each of the x, y, and z
#translational derivatives, and if any are over 2mm, would put a 1 in the
#trash regressor column, and a 0 otherwise.  
#trash_expression<-'(raw_trans_deriv > 2) & (raw_rot_deriv > 10) | (euclidian_rot_deriv > 1)'
trash_expression<-'(euclidian_trans_deriv < -1 ) | (euclidian_rot_deriv < -1) | (euclidian_trans_deriv > 1 ) | (euclidian_rot_deriv > 1)'
