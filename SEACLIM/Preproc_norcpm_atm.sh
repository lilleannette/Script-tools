#!/bin/bash
# Preprocesses NorCPM atmospheric hindcast output for a given start year and ensemble member.
# Downloads raw data, extracts variables, applies bias correction, fixes the calendar,
# inserts leap days, and prepends a synthetic first timestep to satisfy downstream requirements.
#
# Usage: ./Preproc_norcpm_atm.sh <start_year> <member> [atmdir]
#   atmdir: optional root data directory, defaults to current directory
#
# Dependencies: CDO 2.0.6, NCO 5.1.3 (uncomment module load lines for HPC)
module load CDO/2.0.6-gompi-2022a
module load NCO/5.1.3-foss-2022a

export OMP_NUM_THREADS=8

syear=$1 # Start year
eyear=$(( syear + 5)) # End year
member=$2 # Ensemble member number
atmdir=${3:-$PWD}/noresm2-mm-seaclim_hindcast # Root data directory, defaults to current directory
biasdir=/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/
griddir=/cluster/projects/nn9481k/Climate_downscaling/ESM_grids/
atmvars=(UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS)

#./Download_norcpm_atm.sh $syear $member

memstr=`echo -n 00${member} | tail -3c`
memdir=${atmdir}/noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}/

# Check if a directory exists
if [ -d "$memdir" ]; then
    echo "Directory found: $memdir"
else
    echo "ERROR: Directory not found: $memdir"
    exit 1
fi

# Helper: delete files and warn if deletion fails
cleanup() {
    for f in "$@"; do
        rm -f "$f" || echo "WARNING: could not remove $f" >&2
    done
}

ATM_NAME_SUFFIX="_0e_to_360e_20n_to_90n" # Constant suffix for variable selection

# Construct the list of original input files
input_files_array=()
for ((year=$syear; year<=$eyear; year+=1)); do
    input_files_array+=("${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${year}-11-01-10800.nc")
done

# --- Stage 2: merge, bias-correct, set grid, split by year ---
echo "Stage 2: Merging, bias-correcting, setting grid, and splitting by year..."
#./Update_cal_biasfiles_fix.sh ${syear} ${biasdir}

for atmvar in "${atmvars[@]}"; do
    (
        echo "  Processing $atmvar using $OMP_NUM_THREADS threads..."

        # Output prefix for the final split files
        out_prefix="${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_"

        # Unique temporary file to hold the merged & extracted variable stream
        tmp_merged="${memdir}tmp_stage1_${atmvar}.nc"

        # Step 1: Merge files and extract the variable to the temporary file
        # We wrap the -mergetime command and its inputs in [ ... ] to satisfy the CDO parser.
        echo "    Merging and extracting $atmvar..."
        cdo -O -setname,${atmvar} -delete,timestep=15560 -selvar,${atmvar}${ATM_NAME_SUFFIX} \
            [ -mergetime ${input_files_array[@]} ] "$tmp_merged"

        # Base operator config for Stage 2
        cdo_base="-O splityear -setgrid,${griddir}cdogrid_norcpm_atm_20n"

        # Step 2: Apply bias correction using the temporary file as input
        if [[ "$atmvar" == "FSDS" || "$atmvar" == "TREFHT" ]]; then
            echo "    $atmvar: no bias correction"
            cdo $cdo_base "$tmp_merged" "$out_prefix"
        elif [[ "$atmvar" == "PRECT" ]]; then
            echo "    $atmvar: factorial bias correction"
            cdo $cdo_base -mul "$tmp_merged" "${biasdir}/RATIO_PRECT_nobc_vs_bc_cal.nc" "$out_prefix"
        elif [[ "$atmvar" == "QREFHT" ]]; then
            echo "    $atmvar: additive bias correction with humidity floor"
            cdo $cdo_base -setrtoc,-inf,6.0e-5,6.0e-5 -monsub "$tmp_merged" \
                "${biasdir}/bias_NorCPM_ERA5_64M_${atmvar}_20n_cal.nc" "$out_prefix"
        else
            echo "    $atmvar: standard additive bias correction"
            cdo $cdo_base -monsub "$tmp_merged" \
                "${biasdir}/bias_NorCPM_ERA5_64M_${atmvar}_20n_cal.nc" "$out_prefix"
        fi

        # Cleanup the temporary file
        rm -f "$tmp_merged"
    ) &
done
wait # Wait for all atmospheric variable processing to complete

# --- Stage 3: prepend synthetic first timestep to the start year ---
echo "Stage 3: Prepending synthetic first timestep for start year $syear..."
for atmvar in "${atmvars[@]}"; do
    (
        base="${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${syear}.nc"
        echo "  Processing $atmvar"
        # Use unique temporary files for parallel execution
        cdo seldate,${syear}-11-01T03:00:00 "$base" "${memdir}tmp_${atmvar}.nc"
        cdo setdate,${syear}-11-01 "${memdir}tmp_${atmvar}.nc" "${memdir}tmp1_${atmvar}.nc"
        cdo settime,00:00:00 "${memdir}tmp1_${atmvar}.nc" "${memdir}tmp2_${atmvar}.nc"
        cdo setdate,${syear}-10-31 "${memdir}tmp_${atmvar}.nc" "${memdir}tmp3_${atmvar}.nc"
        cdo settime,21:00:00 "${memdir}tmp3_${atmvar}.nc" "${memdir}tmp4_${atmvar}.nc"
        cdo mergetime "${memdir}tmp4_${atmvar}.nc" "${memdir}tmp2_${atmvar}.nc" "$base" "${memdir}tmp5_${atmvar}.nc"
        mv "${memdir}tmp5_${atmvar}.nc" "$base"
        cleanup "${memdir}tmp_${atmvar}.nc" "${memdir}tmp1_${atmvar}.nc" "${memdir}tmp2_${atmvar}.nc" "${memdir}tmp3_${atmvar}.nc" "${memdir}tmp4_${atmvar}.nc" "${memdir}tmp5_${atmvar}.nc"
    ) &
done
wait # Wait for all atmospheric variable processing to complete

# --- Stage 5: add leap day to leap years, set standard calendar elsewhere ---
mkdir -p "${memdir}bckup/" # Backup directory exists
echo "Stage 5: Applying calendar fixes and leap day insertion..."
for ((year=$syear; year<=$eyear; year+=1)); do
    if [ $(($year % 4)) -eq 0 ]; then
        echo "  Processing leap year: $year"
        for atmvar in "${atmvars[@]}"; do
            (
                base="${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc"
                echo "    Fixing calendar for $atmvar in leap year $year"
                # Fix calendar
                cdo setreftime,1950-01-01,0,1day -settaxis,${year}-01-01,00:00:00,3hour -setcalendar,standard \
                    "$base" "${memdir}tmp_leap_${atmvar}_${year}.nc"
                # Extract Feb 28 and duplicate as Feb 29
                cdo seldate,${year}-02-28 "${memdir}tmp_leap_${atmvar}_${year}.nc" "${memdir}tmp_leap_${atmvar}_${year}_1.nc"
                cdo setdate,${year}-02-29   "${memdir}tmp_leap_${atmvar}_${year}_1.nc" "${memdir}tmp_leap_${atmvar}_${year}_2.nc"
                cleanup "${memdir}tmp_leap_${atmvar}_${year}_1.nc"
                # Merge back
                cdo -z zip_6 mergetime "${memdir}tmp_leap_${atmvar}_${year}.nc" "${memdir}tmp_leap_${atmvar}_${year}_2.nc" \
                    "${memdir}tmp_leap_${atmvar}_${year}_3.nc"
                cleanup "${memdir}tmp_leap_${atmvar}_${year}.nc" "${memdir}tmp_leap_${atmvar}_${year}_2.nc"
                # Backup original and replace
                cp "$base" "${memdir}bckup/"
                mv "${memdir}tmp_leap_${atmvar}_${year}_3.nc" "$base"
            ) &
        done
        wait
    elif [ $year -eq $syear ]; then
        echo "  Processing start year (non-leap): $year"
        for atmvar in "${atmvars[@]}"; do
            (
                base="${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc"
                echo "    Fixing calendar for $atmvar in start year $year"
                cdo -z zip_6 setreftime,1950-01-01,0,1day -settaxis,${year}-10-31,21:00:00,3hour -setcalendar,standard \
                    "$base" "${memdir}tmp_cal_${atmvar}_${year}.nc"
                mv "${memdir}tmp_cal_${atmvar}_${year}.nc" "$base"
            ) &
        done
        wait
    else
        echo "  Processing regular year (non-leap): $year"
        for atmvar in "${atmvars[@]}"; do
            (
                base="${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc"
                echo "    Fixing calendar for $atmvar in year $year"
                cdo -z zip_6 setreftime,1950-01-01,0,1day -settaxis,${year}-01-01,00:00:00,3hour -setcalendar,standard \
                    "$base" "${memdir}tmp_cal_${atmvar}_${year}.nc"
                mv "${memdir}tmp_cal_${atmvar}_${year}.nc" "$base"
            ) &
        done
        wait
    fi
done
