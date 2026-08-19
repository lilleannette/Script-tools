#!/bin/bash

# Usage:
# ./run_preproc.sh 2005 2006 2007
# It does the preprocessing for members 1 to 4 of the years given

#SBATCH --job-name OcnAtmProc   ## Name of the job
#SBATCH --output log/slurm-%j.out   ## Name of the output-script (%j will be replaced with job number)
#SBATCH --account nn9481k   ## The billed account
#SBATCH --partition=preproc
#SBATCH --time=15:00:00   ## Walltime of the job
#SBATCH --mem=32G   ## Memory allocated to each task
#SBATCH --ntasks=1   ## Number of tasks that will be allocated
#SBATCH --cpus-per-task=64   ## Number of CPUs allocated for each task

set -o errexit   ## Exit the script on any error
set -o nounset   ## Treat any unset variables as an error

cd $SLURM_SUBMIT_DIR

for year in "$@"; do
    for member in {1..4}; do
    (
        ./Preproc_norcpm_ocn.sh "$year" "$member"
        ./Preproc_norcpm_ocnbio.sh "$year" "$member"
        
        mkdir -p $USERWORK/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/
        mv $WORK/Script-tools/SEACLIM/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/* $USERWORK/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/
        rm -rf $WORK/Script-tools/SEACLIM/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${year}1101_mem00${member}/

    ) &
    done

    wait
    
done

echo "All jobs completed."
