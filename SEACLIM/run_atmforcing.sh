#!/bin/bash

# Usage:
# ./run_atmforcing.sh 2005 2006 2007
# Generates atmospheric forcing ab file for hycom from netcdf files for the specified years across all members (1-4).
# The script assumes that the Preproc_norcpm_atm.py script has already been executed for the specified years.

for year in "$@"; do

    echo "Processing year $year"

    #mkdir -p /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/
    # in {1..4} or 1
    for member in {1..4}; do
    (
        echo "Year=${year} Member=${member}"

        cd $WORK/Script-tools/SEACLIM/ || exit 1

        /cluster/projects/nn9481k/conda/arnelt/hycom-cice/bin/python Preproc_norcpm_atm.py "$year" "$member" $USERWORK

        cd $WORK/TP2a0.10/expt_01.0/ || exit 1

        source ../REGION.src
        source ./EXPT.src
        source ${BINDIR}/common_functions.sh
        source $NHCROOT/environment/betzy_env.sh
        
        mkdir -p $USERWORK/TP2a0.10/force/synoptic/${year: -2}${member}/SCRATCH
        cd $USERWORK/TP2a0.10/force/synoptic/${year: -2}${member}/SCRATCH
        cp ../../010/SCRATCH/blkdat.input .
        cp ../../010/SCRATCH/regional.* .

        /cluster/projects/nn9481k/conda/arnelt/hycom-cice/bin/python /cluster/home/arnelt/NERSC-HYCOM-CICE/bin/hycom_atmfor.py --rootpath=$USERWORK/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}.cam.h2 "${year}-11-01T00:00:00" "$((year + 6))-01-01T00:00:00" /cluster/home/arnelt/NERSC-HYCOM-CICE/input/norcpm_3h.xml norcpm_3h+lw

        for f in forcing.*; do
            [ -e "$f" ] || continue
            mv -i -- "$f" "../${f#forcing.}"
        done

        echo "Finished year=${year} member=${member}"

    )
    done

    echo "Completed all members for year $year"

done

echo "All years completed."

