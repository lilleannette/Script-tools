#!/bin/bash
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
    variable_group=blom.hmbgcglb
    echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
    ./wget_seaclim_hindcasts.sh . $year $member $variable_group
fi

# Define which varibales to process
OCN_VARS_WBS=(no3lvl po4lvl silvl o2lvl dissiclvl talklvl)   # ocean variables to process with bias correction
OCN_VARS_NBS=()  # ocean variables to process without bias correction
OCN_VARS_ALL=("${OCN_VARS_WBS[@]}" "${OCN_VARS_NBS[@]}")

Testing=false
# For testing with just few variables
if $Testing; then
    OCN_VARS_WBS=(no3lvl)   # ocean variables to process with bias correction 
    OCN_VARS_NBS=(po4lvl silvl o2lvl dissiclvl talklvl)  # ocean variables to process without bias correction
    OCN_VARS_ALL=("${OCN_VARS_WBS[@]}" "${OCN_VARS_NBS[@]}")
fi

memstr=`echo -n 00${member} | tail -3c`
exp=noresm2-mm-seaclim_hindcast
memdir=${exp}/${exp}_${syear}1101_mem${memstr}

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
        smon=1; emon=2
    else
        smon=1; emon=12
    fi

    for ((mon=smon; mon<=emon; mon+=1)); do
        monstr=`echo -n 0${mon} | tail -2c`
        monfileglb=${memdir}/${exp}_${syear}1101_mem${memstr}.blom.hmbgcglb.${year}-${monstr}.nc

        #take out each variable
        for ocnvar in "${OCN_VARS_ALL[@]}"; do
           echo $year $mon $ocnvar
           cdo selvar,$ocnvar $monfileglb ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}.nc
	done
    done
done

cp -r NorCPM_bias/ NorCPM_bias_${syear}_${member}/

# bias correction
for ocnvar in "${OCN_VARS_WBS[@]}"; do
    # set the times in the bias-file	    
    cdo setreftime,1950-01-01,0,1day -settaxis,${syear}-11-15,00:00:00,1mon \
	NorCPM_bias_${syear}_${member}/bias_NorCPM_REFRUN_64M_${ocnvar}.nc \
	NorCPM_bias_${syear}_${member}/bias_NorCPM_REFRUN_64M_${ocnvar}_cal.nc
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
		NorCPM_bias_${syear}_${member}/bias_NorCPM_REFRUN_64M_${ocnvar}_cal.nc \
	    NorCPM_bias_${syear}_${member}/bias_NorCPM_REFRUN_64M_${ocnvar}_mon.nc
	    
	    # subtract the bias
    	cdo monsub ${memdir}/${ocnvar}_S${syear}_${year}_${monstr}_grid.nc \
		NorCPM_bias_${syear}_${member}/bias_NorCPM_REFRUN_64M_${ocnvar}_mon.nc \
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

    for ((mon=smon; mon<=emon; mon+=1)); do
        monstr=$(echo -n 0${mon} | tail -2c)

	# Paths to intermediate processed single-variable files from the previous loops
	no3_file="${memdir}/no3lvl_S${syear}_${year}_${monstr}_ntb.nc"
        po4_file="${memdir}/po4lvl_S${syear}_${year}_${monstr}_ntb.nc"
        si_file="${memdir}/silvl_S${syear}_${year}_${monstr}_ntb.nc"
        o2_file="${memdir}/o2lvl_S${syear}_${year}_${monstr}_ntb.nc"
        dissic_file="${memdir}/dissiclvl_S${syear}_${year}_${monstr}_ntb.nc"
        talk_file="${memdir}/talklvl_S${syear}_${year}_${monstr}_ntb.nc"

        echo "Aligning grids and remapping regional velocities to global domain for ${year}-${monstr}..."
	# 1. Standard global parameters get set to the global grid template
        cdo setgrid,cdogrid_norcpm_ocn_glb "$no3_file" "${no3_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$po4_file" "${po4_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$si_file" "${si_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$o2_file" "${o2_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$dissic_file" "${dissic_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$talk_file" "${talk_file}_grid.nc"

	echo "Extrapolating missing data using nearest neighbor for ${year}-${monstr}..."

	# 2. Apply setmisstonn to fill land/missing data points for each individual file
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$no3_file" "${no3_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$po4_file" "${po4_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$si_file" "${si_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$o2_file" "${o2_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$dissic_file" "${dissic_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$talk_file" "${talk_file}_extr.nc"

        # Define the target unified file name
        merged_out="${memdir}/${exp}_${syear}1101_mem${memstr}.blom.hmphyglb.biomerged_${year}-${monstr}.nc"

        echo "Merging standard physical arrays..."

        # 3. Merge perfectly sized fields together and translate names to the CMIP syntax
        cdo -O -merge \
            -chname,no3lvl,no3 "${no3_file}_extr.nc" \
            -chname,po4lvl,po4 "${po4_file}_extr.nc" \
            -chname,silvl,si "${si_file}_extr.nc" \
            -chname,o2lvl,o2 "${o2_file}_extr.nc" \
            -chname,dissiclvl,dissic "${dissic_file}_extr.nc" \
            -chname,talklvl,TA "${talk_file}_extr.nc" \
            "$merged_out"

	# 4. Fix time-axis rules cleanly
        cdo -O setreftime,1950-01-01,0,1day -settaxis,${year}-${monstr}-15,00:00:00,1mon \
            -setcalendar,standard "$merged_out" "${merged_out}.tmp"
        mv "${merged_out}.tmp" "$merged_out"

	# Clean up intermediate scratch layers
        cleanup "$no3_file" "${no3_file}_grid.nc" "${no3_file}_extr.nc"
        cleanup "$po4_file" "${po4_file}_grid.nc" "${po4_file}_extr.nc"
        cleanup "$si_file" "${si_file}_grid.nc" "${si_file}_extr.nc"
        cleanup "$o2_file" "${o2_file}_grid.nc" "${o2_file}_extr.nc"
        cleanup "$dissic_file" "${dissic_file}_grid.nc" "${dissic_file}_extr.nc"
        cleanup "$talk_file" "${talk_file}_grid.nc" "${talk_file}_extr.nc"

    done
done

