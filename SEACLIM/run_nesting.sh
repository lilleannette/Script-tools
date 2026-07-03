#!/bin/bash

# Usage:
# ./run_nesting.sh 2005 2006 2007

for year in "$@"; do

    echo "Processing year $year"

    mkdir -p /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/

# in {1..4}
    for member in 2; do
    (
        echo "Year=${year} Member=${member}"

        cd ../../CPMa1.00/expt_01.0 || exit 1
        rm -rf ../Nesting_files/${year}_${member}/
        mkdir ../Nesting_files/${year}_${member}/
        cp ../../Script-tools/SEACLIM/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/*merged* ../Nesting_files/${year}_${member}/
        
        cd ../../TP2a0.10/ || exit 1
        rm -rf nest/08${member}/
        rm -rf expt_08.${member}/
        ./bin/expt_new.sh 08.0 08.${member}
        cd ../CPMa1.00/expt_01.0 || exit 1

        ../bin/Nesting_noresm/cpm_to_hycom.sh ../../TP2a0.10/expt_08.${member}/ ../Nesting_files/${year}_${member}/*merged_*.nc

        cd ../../TP2a0.10/expt_08.${member}/ || exit 1

        python ../bin/calc_montg1.py ../nest/08${member}/archv.[12]*.a ./restart.1993_305_00_0000.a ./

        ./Renames.sh ${year} $((year + 7))

        mkdir -p /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/mem00${member}/
        cp archv.[12]* /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/mem00${member}/

        echo "Finished year=${year} member=${member}"

    )
    done

    echo "Completed all members for year $year"

done

echo "All years completed."