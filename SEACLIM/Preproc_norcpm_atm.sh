#!/bin/bash
#module load CDO/2.0.6-gompi-2022a
#module load NCO/5.1.3-foss-2022a
syear=$1
eyear=$(( $syear + 6 ))
echo $eyear
member=$2
atmdir=${3:-$PWD}

./Download_norcpm_atm.sh $syear $member

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

# --- Stage 1: extract variables per year ---
for ((year=$syear; year<$eyear; year+=1)); do
    file1=${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${year}-11-01-10800.nc

    for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
        echo $year $atmvar
        atmname=${atmvar}_0e_to_360e_20n_to_90n
        ls $file1
        cdo selvar,$atmname $file1 ${memdir}${atmvar}_S${syear}_${year}.nc
    done
done

# --- Stage 2: merge, bias-correct, set grid, split by year ---
./Update_cal_biasfiles_fix.sh ${syear}
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    # Merge all yearly extracts into one file
    cdo -O mergetime ${memdir}${atmvar}_S${syear}_*.nc ${memdir}${atmvar}_S${syear}all.nc
    cleanup ${memdir}${atmvar}_S${syear}_*.nc          # no longer needed after merge

    # Remove spurious timestep
    cdo delete,timestep=15560 ${memdir}${atmvar}_S${syear}all.nc ${memdir}${atmvar}_S${syear}all1.nc
    cleanup ${memdir}${atmvar}_S${syear}all.nc

    # Bias correction
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
        cleanup ${memdir}${atmvar}_S${syear}all_bc1.nc
    else
        echo $atmvar "standard bias correction"
        cdo monsub ${memdir}${atmvar}_S${syear}all1.nc ${memdir}/../bias_NorCPM_ERA5_64M_${atmvar}_20n_cal.nc ${memdir}${atmvar}_S${syear}all_bc.nc
    fi
    cleanup ${memdir}${atmvar}_S${syear}all1.nc

    # Remove bounds variables
    ncks -C -O -x -v bnds,time_bnds ${memdir}${atmvar}_S${syear}all_bc.nc ${memdir}${atmvar}_S${syear}all_ntb.nc
    cleanup ${memdir}${atmvar}_S${syear}all_bc.nc

    # Set grid and split by year
    cdo setgrid,cdogrid_norcpm_atm_20n ${memdir}${atmvar}_S${syear}all_ntb.nc ${memdir}${atmvar}_S${syear}all_ntb_grid.nc
    cleanup ${memdir}${atmvar}_S${syear}all_ntb.nc

    cdo splityear ${memdir}${atmvar}_S${syear}all_ntb_grid.nc ${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_
    cleanup ${memdir}${atmvar}_S${syear}all_ntb_grid.nc
done

# --- Stage 3: prepend synthetic first timestep to the start year ---
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    base=${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${syear}.nc
    cdo seldate,${syear}-11-01T03:00:00 "$base" ${memdir}tmp.nc
    cdo setdate,${syear}-11-01 ${memdir}tmp.nc ${memdir}tmp1.nc
    cdo settime,00:00:00 ${memdir}tmp1.nc ${memdir}tmp2.nc
    cdo setdate,${syear}-10-31 ${memdir}tmp.nc ${memdir}tmp3.nc
    cdo settime,21:00:00 ${memdir}tmp3.nc ${memdir}tmp4.nc
    cdo mergetime ${memdir}tmp4.nc ${memdir}tmp2.nc "$base" ${memdir}tmp5.nc
    mv ${memdir}tmp5.nc "$base"
    cleanup ${memdir}tmp.nc ${memdir}tmp1.nc ${memdir}tmp2.nc ${memdir}tmp3.nc ${memdir}tmp4.nc
done

# --- Stage 4: clean up per-variable merge intermediates ---
for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
    cleanup ${memdir}${atmvar}*
    # Note: this removes the _S${syear}all* files; the final per-year
    # files (cam.h2.${atmvar}_YYYY.nc) are kept — they don't match this glob
done

# --- Stage 5: add leap day to leap years, set standard calendar elsewhere ---
for ((year=$syear; year<=$eyear; year+=1)); do
    if [ $(($year % 4)) -eq 0 ]; then
        echo ${year}
        for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
            base=${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
            # Fix calendar
            cdo setreftime,1950-01-01,0,1day -settaxis,${year}-01-01,00:00:00,3hour -setcalendar,standard \
                "$base" ${memdir}tmp_leap_${atmvar}_${year}.nc
            # Extract Feb 28 and duplicate as Feb 29
            cdo seldate,${year}-02-28 ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}_1.nc
            cdo setdate,${year}-02-29   ${memdir}tmp_leap_${atmvar}_${year}_1.nc ${memdir}tmp_leap_${atmvar}_${year}_2.nc
            cleanup ${memdir}tmp_leap_${atmvar}_${year}_1.nc
            # Merge back
            cdo -z zip_6 mergetime ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}_2.nc \
                ${memdir}tmp_leap_${atmvar}_${year}_3.nc
            cleanup ${memdir}tmp_leap_${atmvar}_${year}.nc ${memdir}tmp_leap_${atmvar}_${year}_2.nc
            # Backup original and replace
            cp "$base" ${memdir}bckup/
            mv ${memdir}tmp_leap_${atmvar}_${year}_3.nc "$base"
        done

    elif [ $year -eq $syear ]; then
        for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
            base=${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
            cdo -z zip_6 setreftime,1950-01-01,0,1day -settaxis,${year}-10-31,21:00:00,3hour -setcalendar,standard \
                "$base" ${memdir}tmp_leap_${atmvar}_${year}.nc
            mv ${memdir}tmp_leap_${atmvar}_${year}.nc "$base"
        done

    else
        for atmvar in UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS; do
            base=${memdir}noresm2-mm-seaclim_hindcast_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
            cdo -z zip_6 setreftime,1950-01-01,0,1day -settaxis,${year}-01-01,00:00:00,3hour -setcalendar,standard \
                "$base" ${memdir}tmp_leap_${atmvar}_${year}.nc
            mv ${memdir}tmp_leap_${atmvar}_${year}.nc "$base"
        done
    fi
done
