#!/bin/bash

# Usage:
# ./run_nesting.sh 2005 2006 2007
# The script creates nesting files and experiment setups for members 1 to 4 of the years given.

for year in "$@"; do

    echo "Processing year $year"

    #mkdir -p /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/
    # in {1..4} or 1
    for member in {1..4}; do
    (
        echo "Year=${year} Member=${member}"

        cd $USERWORK/CPMa1.00 || exit 1
        rm -rf Nesting_files/${year}_${member}/
        mkdir Nesting_files/${year}_${member}/
        cp $WORK/Script-tools/SEACLIM/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/*merged* Nesting_files/${year}_${member}/
        
        cd $WORK/TP2a0.10/ || exit 1
        rm -rf nest/${year: -2}${member}/
        rm -rf expt_${year: -2}.${member}/
        ./bin/expt_new.sh 01.0 ${year: -2}.${member}
        cd $USERWORK/CPMa1.00/expt_01.0 || exit 1

        ../bin/Nesting_noresm/cpm_to_hycom.sh $WORK/TP2a0.10/expt_${year: -2}.${member}/ ../Nesting_files/${year}_${member}/*merged_*.nc

        cd $WORK/TP2a0.10/expt_${year: -2}.${member}/ || exit 1

        cp /nird/datalake/NS9481K/shuang/TP2_output/expt_02.8/restart/restart.${year}_30[56]* .
        python ../bin/calc_montg1.py ../nest/${year: -2}${member}/archv.[12]*.a ./restart.${year}_30[56]_00_0000.a ./

        ./Renames.sh ${year} $((year + 7))

        cd $WORK/TP2a0.10/ || exit 1
        rm -rf nest/${year: -2}${member}/archv.*
        mv expt_${year: -2}.${member}/archv.* nest/${year: -2}${member}/

        #mkdir -p /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/mem00${member}/
        #cp archv.[12]* /nird/datalake/NS9481K/www/NorCPM_nesting/${year}/mem00${member}/

        mkdir -p force/rivers/${year: -2}${member}/
        cp force/rivers/010/* force/rivers/${year: -2}${member}/
        mkdir -p relax/${year: -2}${member}/
        cp -r relax/010/* relax/${year: -2}${member}/
        cp nest/010/rmu* nest/${year: -2}${member}/
        cp nest/010/ports.input nest/${year: -2}${member}/

        cd $USERWORK/TP2a0.10/ || exit 1
        mkdir -p expt_${year: -2}.${member}/data/cice
        cp expt_01.0/hycom_opt expt_${year: -2}.${member}/
        cd expt_${year: -2}.${member}/data/ || exit 1
        cp /nird/datalake/NS9481K/shuang/TP2_output/expt_02.8/restart/restart.${year}_30[56]* .
        cd cice || exit 1
        cp /nird/datalake/NS9481K/shuang/TP2_output/expt_02.8/cice/iced.${year}-11-01-00000.nc .
        

        echo "Finished year=${year} member=${member}"

    )
    done

    echo "Completed all members for year $year"

done

echo "All years completed."

