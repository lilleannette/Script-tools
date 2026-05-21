#!/bin/bash
#module load CDO/2.0.6-gompi-2022a
#module load NCO/5.1.3-foss-2022a
syear=$1
eyear=(( $syear + 6))
member=$3

echo $syear $eyear $memeber

"./Download_norcpm_ocn.sh $syear $member

memstr=`echo -n 00${member} | tail -3c`
exp=noresm2-mm-seaclim_hindcast
memdir=${exp}/${exp}_${syear}1101_mem${memstr}

for ((year=syear; year<=eyear; year+=1)); do
    if $year == $syear;
        smon=11; emon=12
    elif $year == $eyear;
        smon=1; emon=2
    else
        smon=1; emon=12
    fi

    for ((mon=smon; mon<=emon; mon+=1)); do
       monstr=`echo -n 0${member} | tail -2c`
       monfile=${memdir}/${exp}_${syear}1101_mem${memstr}.cam.h2.${year}-11-01-10800.nc

       #take out each variable
       for ocnvar in salnlvl templvl ubaro vbaro uvellvl uvellvl sealv; do
        echo $year $mon $ocnvar
        atmname=${atmvar}_0e_to_360e_20n_to_90n

    	# 1 take out each variable
        # 2 split the files in years
	    # 3 merge the year
	    ls $file1
        cdo selvar,$atmname $file1 ${memdir}${atmvar}_S${syear}_${year}.nc
    done
done

# me
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    cdo mergetime ${memdir}${atmvar}_S${syear}_*.nc ${memdir}${atmvar}_S${syear}_all.nc
    ncks -C -O -x -v bnds,time_bnds ${memdir}${atmvar}_S${syear}_all.nc ${memdir}${atmvar}_S${syear}_all_ntb.nc
    cdo setgrid,cdogrid_norcpmforce ${memdir}${atmvar}_S${syear}_all_ntb.nc ${memdir}${atmvar}_S${syear}_all_ntb_grid.nc
    cdo splityear ${memdir}${atmvar}_S${syear}_all_ntb_grid.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_
done


# add the first time-step to the first year:
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
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    rm ${memdir}${atmvar}*
done
    
