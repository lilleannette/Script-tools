#!/bin/bash
# =============================================================================
# Script: Make_bias_from_refrun.sh
# Description: Creates 64-month ocean bias correction files for NorCPM by
#              comparing NorCPM model climatology against a reference run
#              (e.g., TOPAZ/NERSC-HYCOM reanalysis) climatology.
#
#              The reference run provides 12 monthly climatology files on its
#              own grid (e.g., 400x380, 40 depth levels). This script:
#                1. Extracts target variables from the reference files
#                2. Concatenates 12 months into one file per variable
#                3. Extends from 12 to 64 months by cyclic duplication
#                   (starting from November = lead month 1)
#                4. Sets proper NorCPM-compatible time axis
#                5. Regrids the reference data to the NorCPM ocean grid
#                   (horizontal remapping + vertical interpolation)
#                6. Computes bias = NorCPM_clim - reference_regridded
#
# Usage: ./Make_bias_from_refrun.sh <refdir> <norcpm_clim_dir> <outdir> \
#                                   [syear]
#
#   refdir          : Directory with reference climatology files
#                     (clim_1993_2024_01.nc ... clim_1993_2024_12.nc)
#   norcpm_clim_dir : Directory with NorCPM model climatology files
#   outdir          : Output directory for bias correction files
#   syear           : (optional) Start year (default: 1993)
#
# Dependencies: CDO >= 2.0.6, NCO >= 5.1.3
#
# Example:
#   ./Make_bias_from_refrun.sh \
#       /path/to/refrun_clim/ \
#       /path/to/norcpm_clim/ \
#       ./NorCPM_ocn_biascorr/ \
#       1993
# =============================================================================

set -euo pipefail

# --- Load modules (uncomment on HPC) ---
module load CDO/2.0.6-gompi-2022a
module load NCO/5.1.3-foss-2022a

# Parse arguments
usagestr="Usage: $0 <refdir> <norcpm_clim_dir> <outdir> [syear]"

if [ "$#" -lt 3 ]; then
    echo "ERROR: Not enough arguments."
    echo "$usagestr"
    exit 1
fi

REFDIR="$1"
NORCPM_DIR="$2"
OUTDIR="$3"
SYEAR="${4:-1993}"

# Validate inputs
if [ ! -d "$REFDIR" ]; then
    echo "ERROR: Reference run directory not found: $REFDIR"
    exit 1
fi

if [ ! -d "$NORCPM_DIR" ]; then
    echo "NorCPM climatology directory not found: $NORCPM_DIR"
    echo "Downloading NorCPM biogeochemistry climatology file..."
    mkdir -p "$NORCPM_DIR"
    cp /cluster/projects/nn9481k/Climate_downscaling/Example_Files/NorCPM2_climatology/noresm2-mm-seaclim_hindcast.blom.hmphyglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_templvl.nc "$NORCPM_DIR"
    cp /cluster/projects/nn9481k/Climate_downscaling/Example_Files/NorCPM2_climatology/noresm2-mm-seaclim_hindcast.blom.hmphyglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_salnlvl.nc "$NORCPM_DIR"
    cp /cluster/projects/nn9481k/Climate_downscaling/Example_Files/NorCPM2_climatology/noresm2-mm-seaclim_hindcast.blom.hmphyglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_sealv.nc "$NORCPM_DIR"
    cp /cluster/projects/nn9481k/Climate_downscaling/Example_Files/NorCPM2_climatology/noresm2-mm-seaclim_hindcast.blom.hmphyglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_ubaro.nc "$NORCPM_DIR"
    cp /cluster/projects/nn9481k/Climate_downscaling/Example_Files/NorCPM2_climatology/noresm2-mm-seaclim_hindcast.blom.hmphyglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_vbaro.nc "$NORCPM_DIR"
    cp /cluster/projects/nn9481k/Climate_downscaling/Example_Files/NorCPM2_climatology/noresm2-mm-seaclim_hindcast.blom.hmphy20n.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10.nc "$NORCPM_DIR"
    cp /cluster/home/arnelt/NERSC-HYCOM-CICE/TP2a0.10/topo/cice_grid.nc "$NORCPM_DIR"
    URL="https://ns11071k.web.sigma2.no/shared/seaclim/wp2/calibration/noresm2-mm-seaclim_hindcast.blom.hmbgcglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10.nc"
    URLgrid="https://ns11071k.web.sigma2.no/shared/seaclim/wp2/aux/NorESM2-MM_ocean_grid.nc"
    if command -v wget &> /dev/null; then
        wget -q --show-progress -P "$NORCPM_DIR" "$URL"
        wget -q --show-progress -P "$NORCPM_DIR" "$URLgrid"
        
        ncks -A -v plon,plat "$NORCPM_DIR/NorESM2-MM_ocean_grid.nc" "$NORCPM_DIR/noresm2-mm-seaclim_hindcast.blom.hmbgcglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10.nc"
        ncks -A -v ulon,ulat,vlon,vlat "$NORCPM_DIR/NorESM2-MM_ocean_grid.nc" "$NORCPM_DIR/noresm2-mm-seaclim_hindcast.blom.hmphy20n.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10.nc"
    else
        echo "ERROR: wget not found. Please download the file manually to $NORCPM_DIR."
        exit 1
    fi
fi

mkdir -p "$OUTDIR"

TMPDIR="${OUTDIR}/tmp_bias_$$"
mkdir -p "$TMPDIR"

# Variable mapping: reference_varname -> norcpm_varname
# ref_name:norcpm_name
VARMAP=(
    "thetao:templvl"
    #"so:salnlvl"
    #"no3:no3lvl"
    #"si:silvl"
    #"o2:o2lvl"
    #"dissic:dissiclvl"
    #"TA:talklvl"
    #"po4:po4lvl"
    #"zos:sealv"
)

# Expected files: ${REFDIR}/clim_1993_2024_MM.nc
REF_PATTERN="clim_1993_2024"

cleanup() {
    for f in "$@"; do
        rm -f "$f" || echo "WARNING: could not remove $f" >&2
    done
}

trap 'echo "Cleaning up temporary files..."; rm -rf "$TMPDIR"' EXIT

# Build the 64-month sequence
# NorCPM hindcasts start in November.
MONTH_SEQ=()
mon=11  # start in November
for ((i=1; i<=64; i++)); do
    MONTH_SEQ+=( $(printf "%02d" $mon) )
    mon=$(( mon % 12 + 1 ))
done

# Process each variable
for entry in "${VARMAP[@]}"; do
    REF_VAR="${entry%%:*}"
    NCP_VAR="${entry##*:}"

    echo " Processing: ${REF_VAR} (ref) -> ${NCP_VAR} (NorCPM)"

    # Step 1: Extract variable from each of the 12 reference monthly files
    echo "  Step 1: Extracting ${REF_VAR} from reference files..."
    
    for mm in $(seq -w 1 12); do
        ncatted -O -a coordinates,${REF_VAR},o,c,"longitude latitude" "${REFDIR}/${REF_PATTERN}_${mm}.nc" "${TMPDIR}/${REF_PATTERN}_${mm}_corr.nc"
        cdo -s selvar,${REF_VAR} "${TMPDIR}/${REF_PATTERN}_${mm}_corr.nc" \
            "${TMPDIR}/${REF_VAR}_month_${mm}.nc"
    done

    # Check that we got all 12 months
    nfiles=$(ls "${TMPDIR}/${REF_VAR}_month_"*.nc 2>/dev/null | wc -l)
    if [ "$nfiles" -ne 12 ]; then
        echo "  ERROR: Expected 12 monthly files for ${REF_VAR}, found ${nfiles}. Skipping."
        cleanup "${TMPDIR}/${REF_VAR}_month_"*.nc
        continue
    fi

    echo "  Step 2: Merging 12 months into single file..."
    cdo -s -O mergetime \
        "${TMPDIR}/${REF_VAR}_month_01.nc" \
        "${TMPDIR}/${REF_VAR}_month_02.nc" \
        "${TMPDIR}/${REF_VAR}_month_03.nc" \
        "${TMPDIR}/${REF_VAR}_month_04.nc" \
        "${TMPDIR}/${REF_VAR}_month_05.nc" \
        "${TMPDIR}/${REF_VAR}_month_06.nc" \
        "${TMPDIR}/${REF_VAR}_month_07.nc" \
        "${TMPDIR}/${REF_VAR}_month_08.nc" \
        "${TMPDIR}/${REF_VAR}_month_09.nc" \
        "${TMPDIR}/${REF_VAR}_month_10.nc" \
        "${TMPDIR}/${REF_VAR}_month_11.nc" \
        "${TMPDIR}/${REF_VAR}_month_12.nc" \
        "${TMPDIR}/${REF_VAR}_12M.nc"

    # Cleanup individual month files
    cleanup "${TMPDIR}/${REF_VAR}_month_"*.nc

    # Step 3: Extend from 12 to 64 months by cyclic duplication

    echo "  Step 3: Extending to 64 months (cyclic)..."

    lead_files=""
    for ((i=0; i<64; i++)); do
        mm="${MONTH_SEQ[$i]}"
        # The 12M file has time indices 1-12 corresponding to Jan=1,...,Dec=12
        # Month mm maps to time index mm (1-based)
        tidx=$(( 10#$mm ))  # remove leading zero for arithmetic
        outf="${TMPDIR}/${REF_VAR}_lead_$(printf '%03d' $((i+1))).nc"
        cdo -s seltimestep,${tidx} "${TMPDIR}/${REF_VAR}_12M.nc" "$outf"
        lead_files="${lead_files} ${outf}"
    done

    # Concatenate all 64 lead-month files
    cdo -s -O mergetime ${lead_files} "${TMPDIR}/${REF_VAR}_64M_raw.nc"

    # Cleanup lead files
    cleanup ${lead_files}
    cleanup "${TMPDIR}/${REF_VAR}_12M.nc"

    # Step 4: Set proper time axis (matching NorCPM convention)
    echo "  Step 4: Setting time axis..."
    cdo -s -O \
        setreftime,1950-01-01,0,1day \
        -settaxis,${SYEAR}-11-15,00:00:00,1mon \
        -setcalendar,standard \
        "${TMPDIR}/${REF_VAR}_64M_raw.nc" \
        "${TMPDIR}/${REF_VAR}_64M_taxis.nc"

    cleanup "${TMPDIR}/${REF_VAR}_64M_raw.nc"

    # Step 5: Regrid to NorCPM ocean grid
    echo "  Step 5: Regridding to NorCPM grid..."

    # Vertical interpolation to NorCPM depth levels
    # Find NorCPM climatology file with the variable
    NORCPM_FILE=""
    for f in "${NORCPM_DIR}"/*.nc; do
        if [ -f "$f" ]; then
            # Verify if the variable NCP_VAR is inside this file
            if cdo showname "$f" 2>/dev/null | grep -w "$NCP_VAR" &>/dev/null; then
                NORCPM_FILE="$f"
                break
            fi
        fi
    done

    # Extract target depth levels for the specific variable from NorCPM file
    levels=$(cdo -s showlevel -selname,${NCP_VAR} "$NORCPM_FILE" 2>/dev/null || true)
    TARGET_LEVELS=$(echo $levels | tr ' ' ',')
    if [ -n "$TARGET_LEVELS" ] && [ "$TARGET_LEVELS" != "," ] && [ "$REF_VAR" != "zos" ]; then
        echo "    Vertical interpolation to NorCPM levels..."
        cdo -s -O intlevel,${TARGET_LEVELS} \
            "${TMPDIR}/${REF_VAR}_64M_taxis.nc" \
            "${TMPDIR}/${REF_VAR}_64M_regrid.nc"
        cleanup "${TMPDIR}/${REF_VAR}_64M_taxis.nc"
    else
        echo "    Could not extract depth levels. Skipping vertical interpolation."
        mv "${TMPDIR}/${REF_VAR}_64M_taxis.nc" \
           "${TMPDIR}/${REF_VAR}_64M_regrid.nc"
    fi
    
# Horizontal remapping (bilinear interpolation)
    echo "    Horizontal remapping..."
    cdo -s -O remapbil,${NORCPM_FILE} \
        "${TMPDIR}/${REF_VAR}_64M_regrid.nc" \
        "${TMPDIR}/${REF_VAR}_64M_hregrid.nc"

    cleanup "${TMPDIR}/${REF_VAR}_64M_regrid.nc"
    
    # Step 6: Compute bias = NorCPM_clim - reference_regridded
    echo "  Step 6: Computing bias..."

    BIAS_OUT="${OUTDIR}/bias_NorCPM_REFRUN_64M_${NCP_VAR}.nc"

    # Extract only the target variable from NorCPM file
    cdo -s -O selvar,${NCP_VAR} "$NORCPM_FILE" \
        "${TMPDIR}/${NCP_VAR}_norcpm.nc"

    cdo -s -O \
        setreftime,1950-01-01,0,1day \
        -settaxis,${SYEAR}-11-15,00:00:00,1mon \
        -setcalendar,standard \
        "${TMPDIR}/${NCP_VAR}_norcpm.nc" \
        "${TMPDIR}/${NCP_VAR}_norcpm_temp.nc"

    cleanup "${TMPDIR}/${NCP_VAR}_norcpm.nc"

    # Correct units
    if [[ "$REF_VAR" == "no3" || "$REF_VAR" == "si" || "$REF_VAR" == "o2" || "$REF_VAR" == "po4" ]]; then
        cdo -mulc,0.001 "${TMPDIR}/${REF_VAR}_64M_hregrid.nc" "${TMPDIR}/${REF_VAR}_64M_unit.nc"
        mv "${TMPDIR}/${REF_VAR}_64M_unit.nc" "${TMPDIR}/${REF_VAR}_64M_hregrid.nc"
    fi

    # Subtract: bias = model - reference
    cdo -s -O sub \
        "${TMPDIR}/${NCP_VAR}_norcpm_temp.nc" \
        "${TMPDIR}/${REF_VAR}_64M_hregrid.nc" \
        "$BIAS_OUT"

    cleanup "${TMPDIR}/${NCP_VAR}_norcpm_temp.nc"
    echo "  -> Bias file written: $BIAS_OUT"

    # Cleanup remaining temp files for this variable
    cleanup "${TMPDIR}/${REF_VAR}_64M_hregrid.nc"
    cleanup "${TMPDIR}/${REF_VAR}_64M_unit.nc"

    echo "  Done with ${REF_VAR}/${NCP_VAR}."
    echo ""
done

# Final cleanup
rm -rf "$TMPDIR"

echo " All bias files created in: $OUTDIR"
