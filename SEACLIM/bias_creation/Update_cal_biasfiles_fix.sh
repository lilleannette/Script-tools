#!/bin/bash
# =============================================================================
# Script: bias_correction_calendar_fix.sh
# Description: Applies calendar standardization and time axis corrections to
#              NorCPM bias correction files for atmospheric variables and
#              precipitation ratios. Uses CDO (Climate Data Operators) to
#              reformat NetCDF files for use in seasonal climate hindcasts.
#
# Usage: ./bias_correction_calendar_fix.sh <start_year>
#   <start_year>      The starting year for the time axis (e.g., 1993)
#   [bias_directory]  Optional directory for bias files
#
# Dependencies: CDO (Climate Data Operators) v2.0.6 or compatible
#               (uncomment 'module load' line if running in an HPC environment)
#
# Input files (read from biasdir):
#   - bias_NorCPM_ERA5_64M_<VAR>_20n.nc  : Bias correction files per variable
#   - RATIO_PRECT_nobc_vs_bc.nc          : Precipitation ratio file
#
# Output files (written to biasdir):
#   - bias_NorCPM_ERA5_64M_<VAR>_20n_cal.nc : Calendar-corrected bias files
#   - RATIO_PRECT_nobc_vs_bc_cal.nc          : Calendar-corrected precip ratio
# =============================================================================

# Uncomment the line below when running on an HPC cluster with the module system
#module load CDO/2.0.6-gompi-2022a

# --- Inputs ---
syear=$1  # First argument: the starting year for the time axis

# Directory containing input bias correction files (passed as 2nd arg or default)
biasdir=${2:-./noresm2-mm-seaclim_hindcast/}

# Check if a directory exists                                                                                                         
if [ -d "$biasdir" ]; then
    echo "Directory found: $biasdir"
else
    echo "ERROR: Directory not found: $biasdir"
    exit 1
fi

# --- Process atmospheric variables ---
# Loop over each atmospheric variable that requires calendar correction:
#   UAS    - Eastward near-surface wind
#   VAS    - Northward near-surface wind
#   TREFHT - Reference height temperature
#   QREFHT - Reference height specific humidity
#   PSL    - Sea level pressure
#   FSDS   - Downwelling shortwave flux at surface
#   FLDS   - Downwelling longwave flux at surface
for atmvar in UAS VAS TREFHT QREFHT PSL FSDS FLDS; do
      echo $syear $atmvar  # Print progress: current year and variable being processed

      cdo -O \
          setreftime,1950-01-01,0,1day \
          -settaxis,${syear}-11-15,00:00:00,1mon \
          -setcalendar,standard \
          ${biasdir}bias_NorCPM_ERA5_64M_${atmvar}_20n.nc \
          ${biasdir}bias_NorCPM_ERA5_64M_${atmvar}_20n_cal.nc
done

# --- Process precipitation ratio file ---
# Apply the same calendar and time axis corrections to the precipitation
# ratio file (ratio of non-bias-corrected vs. bias-corrected precipitation)
cdo -O \
    setreftime,1950-01-01,0,1day \
    -settaxis,${syear}-11-15,00:00:00,1mon \
    -setcalendar,standard \
    ${biasdir}RATIO_PRECT_nobc_vs_bc.nc \
    ${biasdir}RATIO_PRECT_nobc_vs_bc_cal.nc


    
