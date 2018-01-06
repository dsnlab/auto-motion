. ~/.bashrc
. ${FSLDIR}/etc/fslconf/fsl.sh

# define paths
subDir='/Volumes/FP/research/dsnlab/Studies/FP/subjects/'
funcDir='ppc/functionals/'
outputDir='/Volumes/psych-cog/dsnlab/auto-motion-output/AFNI/'

# define variables
study=FP
subPrefix=FP
runs=(run1 run2 run3)
funcPrefix=o

# loop through subjects and runs and calculate outlier counts
cd ${subDir}
for sub in ${subPrefix}*; do 
    echo -----------------------------
    echo ${sub}
    echo -----------------------------
    cd ${subDir}/${sub}/${funcDir}

    for run in ${runs[@]}; do
    echo -----------------------------
    echo ${run}
    echo -----------------------------
    	cd $run
    	if [ ! -f ${funcPrefix}_${run}_4d.nii.gz ]; then
            fslmerge -t ${funcPrefix}_${run}_4d.nii.gz ${funcPrefix}*.nii
        fi
        3dToutcount -automask -fraction -polort 2 -legendre ${funcPrefix}_${run}_4d.nii.gz > ${outputDir}${study}/${sub}_${run}_p2.csv
    	#3dToutcount -automask -fraction -polort 3 -legendre ${funcPrefix}_${run}_4d.nii.gz > ${outputDir}${study}/${sub}_${run}_p3.csv
    	cd ${subDir}/${sub}/${funcDir}
    done

    cd ${subDir}
done