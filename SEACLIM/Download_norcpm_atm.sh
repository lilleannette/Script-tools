#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Missing input:" 
    echo "Usage: $0 <year> <member> [download_dir]" >&2
    echo "download_dir: optional, defaults to current directory (.)" >&2
    exit 1
fi

if [[ $# -ge 3 && ! -d "$BASE_DIR" ]]; then
    echo "ERROR: base_dir '$BASE_DIR' does not exist or is not a directory" >&2
    exit 1
fi

year=$1
member=$2
DOWNLOAD_DIR="${3:-.}"   # or an absolute path like "/data/seaclim"

# Uncomment the desired variable group:
# variable_group="cam.h0"  # Testing/calibration
# variable_group="cam.h1"  # Global, daily
variable_group="cam.h2"    # >20N, 3-hourly

echo ./wget_seaclim_hindcasts.sh $DOWNLOAD_DIR $year $member $variable_group
./wget_seaclim_hindcasts.sh "$DOWNLOAD_DIR" "$year" "$member" "$variable_group"

# --- Resolve script location ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Log and run ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running: wget_seaclim_hindcasts.sh . $year $member $variable_group" >&2

"$SCRIPT_DIR/wget_seaclim_hindcasts.sh" . "$year" "$member" "$variable_group" || {
    echo "ERROR: wget_seaclim_hindcasts.sh failed (exit $?)" >&2
    exit 1
}
