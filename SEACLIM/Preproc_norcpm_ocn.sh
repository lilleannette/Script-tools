#!/bin/bash
<<<<<<< HEAD
#module load CDO/2.0.6-gompi-2022a
#module load NCO/5.1.3-foss-2022a
syear=$1
eyear=(( $syear + 6))
member=$3

echo $syear $eyear $memeber

"./Download_norcpm_ocn.sh $syear $member
=======
# Preprocesses NorCPM ocean hindcast output for a given start year and ensemble member.
# Optionally downloads the raw data, then extracts, bias-corrects, and calendar-fixes
# ocean variables (temperature, salinity, currents, sea level) from BLOM output files.
#
# Usage: ./Preproc_norcpm_ocn.sh <start_year> <member> [download]
#   download: true (default) or false — whether to run Download_norcpm_ocn.sh first
#
# Dependencies: CDO 2.0.6, NCO 5.1.3
# Bias correction files expected in: ./NorCPM_ocn_biascorr/
module load CDO/2.0.6-gompi-2022a
module load NCO/5.1.3-foss-2022a

#!/bin/bash

usagestr="Usage: $0 <start year> <member> [download: default=true]"
download=true
if [ "$#" -lt 2 ]; then
    echo "No arguments given"
    echo $usagestr
    exit 1
elif [ "$#" -gt 3 ]; then
    echo "Too many arguments given"
    echo $usagestr
    exit 1
fi

echo "Start year is: $1"
echo "Member is: $2"
if [ "$#" -eq 3 ]; then
    echo "Download is" $3
    download=$3
fi

syear=$1
eyear=$(( $syear + 6))
member=$2

if $download; then
    ./Download_norcpm_ocn.sh $syear $member
fi

# Define which varibales to process
OCN_VARS_WBS=(salnlvl templvl)   # ocean variables to process with bias correction
OCN_VARS_NBS=(ubaro vbaro sealv uvellvl vvellvl)  # ocean variables to process without bias correction
OCN_VARS_GLB=(salnlvl templvl ubaro vbaro sealv)  # ocean variables in the global datasat
OCN_VARS_20N=(uvellvl vvellvl)   # ocean variables in the dataset > 20N
OCN_VARS_ALL=("${OCN_VARS_WBS[@]}" "${OCN_VARS_NBS[@]}")

Testing=false
# For testing with just few varuables
if $Testing; then
    OCN_VARS_WBS=(salnlvl)   # ocean variables to process with bias correction 
    OCN_VARS_NBS=(sealv)  # ocean variables to process without bias correction
    OCN_VARS_GLB=(salnlvl sealv)  # ocean variables in the global datasat
    OCN_VARS_20N=()   # ocean variables in the dataset > 20N
    OCN_VARS_ALL=("${OCN_VARS_WBS[@]}" "${OCN_VARS_NBS[@]}")
fi
>>>>>>> f4bbdc75897c464ff3fb0ec3b970fabd37accb5d

memstr=`echo -n 00${member} | tail -3c`
exp=noresm2-mm-seaclim_hindcast
memdir=${exp}/${exp}_${syear}1101_mem${memstr}

<<<<<<< HEAD
for ((year=syear; year<=eyear; year+=1)); do
    if $year == $syear;
        smon=11; emon=12
    elif $year == $eyear;
=======
# Helper: delete files and warn if deletion fails
cleanup() {
    for f in "$@"; do
        rm -f "$f" || echo "WARNING: could not remove $f" >&2
    done
}

# extract the files for each variable
for ((year=syear; year<=eyear; year+=1)); do
    if [ $year -eq $syear ]; then
        smon=11; emon=12
    elif [ $year -eq $eyear ]; then
>>>>>>> f4bbdc75897c464ff3fb0ec3b970fabd37accb5d
        smon=1; emon=2
    else
        smon=1; emon=12
    fi

    for ((mon=smon; mon<=emon; mon+=1)); do
<<<<<<< HEAD
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
    
=======
        monstr=`echo -n 0${mon} | tail -2c`
        monfile20n=${memdir}/${exp}_${syear}1101_mem${memstr}.blom.hmphy20n.${year}-${monstr}.nc
        monfileglb=${memdir}/${exp}_${syear}1101_mem${memstr}.blom.hmphyglb.${year}-${monstr}.nc

        #take out each variable
        for ocnvar in "${OCN_VARS_GLB[@]}"; do
           echo $year $mon $ocnvar
           cdo selvar,$ocnvar $monfileglb ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc
	done
        for ocnvar in "${OCN_VARS_20N[@]}"; do
           echo $year $mon $ocnvar
           cdo selvar,$ocnvar $monfile20n ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc
	done
    done
done

# bias correction for temperature and salinity
for ocnvar in "${OCN_VARS_WBS[@]}"; do
    # set the times in the bias-file	    
    cdo setreftime,1950-01-01,0,1day -settaxis,${syear}-11-15,00:00:00,1mon \
	NorCPM_ocn_biascorr/bias_NorCPM_WOA2018_64M_${ocnvar}.nc \
	NorCPM_ocn_biascorr/bias_NorCPM_WOA2018_64M_${ocnvar}_cal.nc
    for ((year=syear; year<=eyear; year+=1)); do
        if [ $year -eq $syear ]; then
            smon=11; emon=12
        elif [ $year -eq $eyear ]; then
            smon=1; emon=2
        else
           smon=1; emon=12
        fi

        for ((mon=smon; mon<=emon; mon+=1)); do
    	    monstr=`echo -n 0${mon} | tail -2c`
	    # set grid on the montly file
	    cdo setgrid,cdogrid_norcpm_ocn_glb \
		${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc \
		${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_grid.nc
	    # no longer needed after setgrid
	    cleanup ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc          

	    #extract the right month from the bias-files
	    cdo -O seldate,${year}-${monstr}-15 \
		NorCPM_ocn_biascorr/bias_NorCPM_WOA2018_64M_${ocnvar}_cal.nc \
	        NorCPM_ocn_biascorr/bias_NorCPM_WOA2018_64M_${ocnvar}_mon.nc
	    
	    # subtract the bias
    	    cdo monsub ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_grid.nc \
		NorCPM_ocn_biascorr/bias_NorCPM_WOA2018_64M_${ocnvar}_mon.nc \
		${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_bc.nc
	    # no longer needed after monsub
	    cleanup ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_grid.nc    
        done
    done
done


for ((year=syear; year<=eyear; year+=1)); do
    if [ $year -eq $syear ]; then
        smon=11; emon=12
    elif [ $year -eq $eyear ]; then
        smon=1; emon=2
    else
        smon=1; emon=12
    fi

    for ocnvar in "${OCN_VARS_WBS[@]}"; do
        for ((mon=smon; mon<=emon; mon+=1)); do
	    monstr=`echo -n 0${mon} | tail -2c`
            ncks -C -O -x -v bnds,time_bnds ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_bc.nc \
	         ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_ntb.nc
	    # no longer needed after bnds remove
            cleanup ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_bc.nc    
	done
    done

    for ocnvar in "${OCN_VARS_NBS[@]}"; do
        for ((mon=smon; mon<=emon; mon+=1)); do
	    monstr=`echo -n 0${mon} | tail -2c`
            ncks -C -O -x -v bnds,time_bnds ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc \
	         ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_ntb.nc
	    # no longer needed after mergetime
            cleanup ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc       
	done
    done
done

# just change to standard calendar.
for ((year=syear; year<=eyear; year+=1)); do
    if [ $year -eq $syear ]; then
        smon=11; emon=12
    elif [ $year -eq $eyear ]; then
        smon=1; emon=2
    else
        smon=1; emon=12
    fi
    smonstr=`echo -n 0${smon} | tail -2c`
    for ocnvar in "${OCN_VARS_ALL[@]}"; do
        for ((mon=smon; mon<=emon; mon+=1)); do
	    monstr=`echo -n 0${mon} | tail -2c`
	    cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb \
		${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_ntb.nc \
		${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_extr.nc
            cdo setreftime,1950-01-01,0,1day -settaxis,${year}-${monstr}-15,00:00:00,1mon \
	        -setcalendar,standard \
	        ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_extr.nc \
	        ${memdir}/${exp}_${syear}1101_mem${memstr}.blom.hmphyglb.${ocnvar}_${year}_${monstr}.nc
	    # not longer needed after remapnn and setreftime
            cleanup ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_extr.nc
            cleanup ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_ntb.nc
	done
    done
done

>>>>>>> f4bbdc75897c464ff3fb0ec3b970fabd37accb5d
