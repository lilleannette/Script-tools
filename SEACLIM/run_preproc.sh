#!/bin/bash

# Usage:
# ./run_preproc.sh 2005 2006 2007
# Downloads and preprocesses NorCPM data for members 1 to 4 of the years given
# Runs both ocean and atmospheric preprocessing scripts for each year and member combination.

#SBATCH --job-name OcnAtmProc   ## Name of the job
#SBATCH --output slurm-%j.out   ## Name of the output-script (%j will be replaced with job number)
#SBATCH --account nn9481k   ## The billed account
#SBATCH --partition=preproc
#SBATCH --time=15:00:00   ## Walltime of the job
#SBATCH --mem=32G   ## Memory allocated to each task
#SBATCH --ntasks=1   ## Number of tasks that will be allocated
#SBATCH --cpus-per-task=64   ## Number of CPUs allocated for each task

set -o errexit   ## Exit the script on any error
set -o nounset   ## Treat any unset variables as an error

cd $SLURM_SUBMIT_DIR

module load Miniforge3/24.1.2-0 && source $EBROOTMINIFORGE3/bin/activate && conda activate hycom-cice

for year in "$@"; do
    for member in {1..4}; do
        ./Preproc_norcpm_ocn.sh "$year" "$member" &
        python Preproc_norcpm_atm.py "$year" "$member" /cluster/work/users/arnelt &
    done
    wait
done

echo "All jobs completed."
