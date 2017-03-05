. ~/.bashrc

cd /Volumes/psych-cog/dsnlab/TDS/archive/subjects_G80/

for i in t*;

do 

    cd $i/ppc/functionals/

    for f in cyb1 cyb2 stop3 stop4 stop5 stop6 stop7 stop8 vid1 vid2;

    do
    	
    	cd $f

    	3dToutcount -automask -fraction -polort 2 -legendre _oru${f}_4d.nii.gz > ${i}_${f}_p2.csv

    	3dToutcount -automask -fraction -polort 3 -legendre _oru${f}_4d.nii.gz > ${i}_${f}_p3.csv

    	cp ${i}_${f}_p*.csv ../../../../../../../auto-motion-output/AFNI

    	cd ../

    done

done