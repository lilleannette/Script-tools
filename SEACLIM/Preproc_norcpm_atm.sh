#!/bin/bash
#module load CDO/2.0.6-gompi-2022a
#module load NCO/5.1.3-foss-2022a
syear=$1
eyear=$(( $syear + 6 ))
echo $eyear
member=$2

./Download_norcpm_atm.sh $syear $member

memstr=`echo -n 00${member} | tail -3c`
atmdir=/Users/annettes/Downloads/Tools_SEACLIM/noresm2-mm-seaclim_hindcast/
memdir=${atmdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}/

# Check if a directory exists
if [ -d "$memdir" ]; then
    echo "Directory found: $biasdir"
else
    echo "ERROR: Directory not found: $biasdir"
    exit 1
fi

for ((year=$syear; year<$eyear; year+=1)); do
    file1=${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${year}-11-01-10800.nc

    #first take out each variable
#    for atmvar in FSDS; do
    for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
        echo $year $atmvar
        atmname=${atmvar}_0e_to_360e_20n_to_90n

    	# 1 take out each variable
        # 2 split the files in years
	    # 3 merge the year
	    ls $file1
        cdo selvar,$atmname $file1 ${memdir}${atmvar}_S${syear}_${year}.nc
    done
done

# me
#for atmvar in FSDS; do
./Update_cal_biasfiles_fix.sh ${syear}
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    cdo -O mergetime ${memdir}${atmvar}_S${syear}_*.nc ${memdir}${atmvar}_S${syear}all.nc
    cdo delete,timestep=15560 ${memdir}${atmvar}_S${syear}all.nc ${memdir}${atmvar}_S${syear}all1.nc
    # bias correction
    if [[ "$atmvar" == "FSDS" || "$atmvar" == "TREFHT" ]]; then
	echo $atmvar "no bias correction applied"
	cp ${memdir}${atmvar}_S${syear}all1.nc ${memdir}${atmvar}_S${syear}all_bc.nc
    elif [[ "$atmvar" == "PRECT" ]]; then
	echo $atmvar "factorial bias correction"
	cdo mul ${memdir}${atmvar}_S${syear}all1.nc ${memdir}/../RATIO_PRECT_nobc_vs_bc_cal.nc ${memdir}${atmvar}_S${syear}all_bc.nc
    elif [[ "$atmvar" == "QREFHT" ]]; then
	echo $atmvar "standard bias correction with cap on negative values"
        cdo monsub ${memdir}${atmvar}_S${syear}all1.nc ${memdir}/../bias_NorCPM_ERA5_64M_${atmvar}_20n_cal.nc ${memdir}${atmvar}_S${syear}all_bc1.nc
	cdo setrtoc,-inf,6.0e-5,6.0e-5 ${memdir}${atmvar}_S${syear}all_bc1.nc ${memdir}${atmvar}_S${syear}all_bc.nc
    else
        echo $atmvar "standard bias correction"
        cdo monsub ${memdir}${atmvar}_S${syear}all1.nc ${memdir}/../bias_NorCPM_ERA5_64M_${atmvar}_20n_cal.nc ${memdir}${atmvar}_S${syear}all_bc.nc
    fi
    ncks -C -O -x -v bnds,time_bnds ${memdir}${atmvar}_S${syear}all_bc.nc ${memdir}${atmvar}_S${syear}all_ntb.nc
    cdo setgrid,cdogrid_norcpm_atm_20n ${memdir}${atmvar}_S${syear}all_ntb.nc ${memdir}${atmvar}_S${syear}all_ntb_grid.nc
    cdo splityear ${memdir}${atmvar}_S${syear}all_ntb_grid.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_
done

# add the first time-step to the first year:
#for atmvar in UAS VAS; do
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    cdo seldate,${syear}-11-01T03:00:00 ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${syear}.nc ${memdir}tmp.nc
    cdo setdate,${syear}-11-01 ${memdir}tmp.nc ${memdir}tmp1.nc
    cdo settime,00:00:00 ${memdir}tmp1.nc ${memdir}tmp2.nc
    cdo setdate,${syear}-10-31 ${memdir}tmp.nc ${memdir}tmp3.nc
    cdo settime,21:00:00 ${memdir}tmp3.nc ${memdir}tmp4.nc
    cdo mergetime ${memdir}tmp4.nc ${memdir}tmp2.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${syear}.nc ${memdir}tmp5.nc
    mv ${memdir}tmp5.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${syear}.nc
    rm ${memdir}tmp*.nc
done

# clear up
#for atmvar in UAS VAS; do
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    rm ${memdir}${atmvar}*
done

# add the leap day to leap years
for ((year=$syear; year<=$eyear; year+=1)); do
    if [ $(($year % 4)) -eq 0 ]; then
        echo ${year}
        #for atmvar in UAS VAS; do
        for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
# extract 28. february
            cdo setreftime,1950-01-01,0,1day -settaxis,${year}-01-01,00:00:00,3hour -setcalendar,standard ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}.nc
            cdo seldate,${year}-02-28 ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}_1.nc 
# set the date to 29. february
            cdo setdate,${year}-02-29 ${memdir}tmp_leap_${atmvar}_${year}_1.nc ${memdir}tmp_leap_${atmvar}_${year}_2.nc
# add it back into the file
            cdo -z zip_6 mergetime ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}_2.nc ${memdir}tmp_leap_${atmvar}_${year}_3.nc
	    cp ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc ${memdir}bckup/
	    mv ${memdir}tmp_leap_${atmvar}_${year}_3.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
	    rm ${memdir}tmp_leap_${atmvar}_${year}*.nc
       done
    elif [ $year -eq $syear ]; then
# just change to standard calendar.
       #for atmvar in UAS VAS; do
       for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
           cdo -z zip_6 setreftime,1950-01-01,0,1day -settaxis,${year}-10-31,21:00:00,3hour -setcalendar,standard ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}.nc
           mv ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
       done    
    else
# just change to standard calendar.
       #for atmvar in UAS VAS; do
       for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
           cdo -z zip_6 setreftime,1950-01-01,0,1day -settaxis,${year}-01-01,00:00:00,3hour -setcalendar,standard ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}.nc
           mv ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
       done
    fi
done


    
