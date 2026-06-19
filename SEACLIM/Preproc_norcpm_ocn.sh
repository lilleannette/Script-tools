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
    ./Download_norcpm_ocn.sh $syear $member
fi

# Define which varibales to process
OCN_VARS_WBS=(salnlvl templvl)   # ocean variables to process with bias correction
OCN_VARS_NBS=(ubaro vbaro sealv uvellvl vvellvl)  # ocean variables to process without bias correction
OCN_VARS_GLB=(salnlvl templvl ubaro vbaro sealv)  # ocean variables in the global datasat
OCN_VARS_20N=(uvellvl vvellvl)   # ocean variables in the dataset > 20N
OCN_VARS_ALL=("${OCN_VARS_WBS[@]}" "${OCN_VARS_NBS[@]}")

Testing=false
# For testing with just few variables
if $Testing; then
    OCN_VARS_WBS=(salnlvl)   # ocean variables to process with bias correction 
    OCN_VARS_NBS=(sealv)  # ocean variables to process without bias correction
    OCN_VARS_GLB=(salnlvl sealv)  # ocean variables in the global datasat
    OCN_VARS_20N=()   # ocean variables in the dataset > 20N
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

    for ((mon=smon; mon<=emon; mon+=1)); do
        monstr=$(echo -n 0${mon} | tail -2c)

	# Paths to intermediate processed single-variable files from the previous loops
	t_file="${memdir}/templvl_S${syear}_${year}_${monstr}_ntb.nc"
        s_file="${memdir}/salnlvl_S${syear}_${year}_${monstr}_ntb.nc"
        ssh_file="${memdir}/sealv_S${syear}_${year}_${monstr}_ntb.nc"
        ubaro_file="${memdir}/ubaro_S${syear}_${year}_${monstr}_ntb.nc"
        vbaro_file="${memdir}/vbaro_S${syear}_${year}_${monstr}_ntb.nc"
	# Regional velocity grids (>20N)
        u_file="${memdir}/uvellvl_S${syear}_${year}_${monstr}_ntb.nc"
        v_file="${memdir}/vvellvl_S${syear}_${year}_${monstr}_ntb.nc"

        echo "Aligning grids and remapping regional velocities to global domain for ${year}-${monstr}..."
	# 1. Standard global parameters get set to the global grid template
        cdo setgrid,cdogrid_norcpm_ocn_glb "$t_file" "${t_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$s_file" "${s_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$ssh_file" "${ssh_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$ubaro_file" "${ubaro_file}_grid.nc"
        cdo setgrid,cdogrid_norcpm_ocn_glb "$vbaro_file" "${vbaro_file}_grid.nc"
	# 2. CRITICAL: Remap the regional velocities (>20N) onto the Global grid footprint
        # Using remapnn preserves the structure while filling non-covered areas safely with missing values.
        cdo remapnn,cdogrid_norcpm_ocn_glb "$u_file" "${u_file}_grid.nc"
        cdo remapnn,cdogrid_norcpm_ocn_glb "$v_file" "${v_file}_grid.nc"

	echo "Extrapolating missing data using nearest neighbor for ${year}-${monstr}..."

	# 3. Apply setmisstonn to fill land/missing data points for each individual file
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$t_file" "${t_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$s_file" "${s_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$ssh_file" "${ssh_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$u_file" "${u_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$v_file" "${v_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$ubaro_file" "${ubaro_file}_extr.nc"
        cdo setmisstonn -setgrid,cdogrid_norcpm_ocn_glb "$vbaro_file" "${vbaro_file}_extr.nc"

        # Define the target unified file name
        merged_out="${memdir}/${exp}_${syear}1101_mem${memstr}.blom.hmphyglb.merged_${year}-${monstr}.nc"

        echo "Merging standard physical arrays..."

        # 4. Merge perfectly sized fields together and translate names to the CMIP syntax
        cdo -O -merge \
            -chname,templvl,thetao "${t_file}_extr.nc" \
            -chname,salnlvl,so "${s_file}_extr.nc" \
            -chname,sealv,zos "${ssh_file}_extr.nc" \
            -chname,uvellvl,uo "${u_file}_extr.nc" \
            -chname,vvellvl,vo "${v_file}_extr.nc" \
            -chname,ubaro,ubaro_netcdf "${ubaro_file}_extr.nc" \
            -chname,vbaro,vbaro_netcdf "${vbaro_file}_extr.nc" \
            "$merged_out"

	# 5. Fix time-axis rules cleanly
        cdo -O setreftime,1950-01-01,0,1day -settaxis,${year}-${monstr}-15,00:00:00,1mon \
            -setcalendar,standard "$merged_out" "${merged_out}.tmp"
        mv "${merged_out}.tmp" "$merged_out"

	# Clean up intermediate scratch layers
        cleanup "$t_file" "${t_file}_grid.nc" "${t_file}_extr.nc"
        cleanup "$s_file" "${s_file}_grid.nc" "${s_file}_extr.nc"
        cleanup "$ssh_file" "${ssh_file}_grid.nc" "${ssh_file}_extr.nc"
        cleanup "$u_file" "${u_file}_grid.nc" "${u_file}_extr.nc"
        cleanup "$v_file" "${v_file}_grid.nc" "${v_file}_extr.nc"
        cleanup "$ubaro_file" "${ubaro_file}_grid.nc" "${ubaro_file}_extr.nc"
        cleanup "$vbaro_file" "${vbaro_file}_grid.nc" "${vbaro_file}_extr.nc"

    done
done

