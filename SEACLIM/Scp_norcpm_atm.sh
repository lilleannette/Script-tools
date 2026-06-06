#!/bin/bash
# Copies processed single-variable atmospheric files for a NorCPM hindcast
# (all years in the 7-year window) to a remote machine via scp.
# Uses SSH connection multiplexing so two-factor authentication is only
# required once at the start, not for every file.
#
# Usage: ./Scp_norcpm_atm.sh <start_years> <members>
#   start_years: comma-separated list of hindcast start years, e.g. 1993,1994,1995
#   members:     comma-separated list of ensemble members, e.g. 1,2,3

# --- Remote connection settings ---
REMOTE_USER=annettes
REMOTE_HOST=nird.sigma2.no
REMOTE_DIR=/nird/datalake/NS9481K/www/NorCPM_atm_forcing/

# --- Local data root ---
LOCAL_DIR=/Users/annettes/Desktop/Process_Atm/noresm2-mm-seaclim_hindcast

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <start_years> <members>" >&2
    echo "  start_years: comma-separated, e.g. 1993,1994,1995" >&2
    echo "  members:     comma-separated, e.g. 1,2,3" >&2
    exit 1
fi

SYEARS=$(echo "$1" | tr ',' ' ')
MEMBERS=$(echo "$2" | tr ',' ' ')

exp=noresm2-mm-seaclim_hindcast
atmvars=(UAS VAS TREFHT QREFHT PSL PRECT FSDS FLDS)

# --- SSH multiplexing: authenticate once, reuse connection for all copies ---
SSH_SOCKET=/tmp/ssh_mux_${REMOTE_USER}_${REMOTE_HOST}
SSH_OPTS="-o ControlMaster=auto -o ControlPath=${SSH_SOCKET} -o ControlPersist=yes"

echo "Opening SSH connection to ${REMOTE_HOST} (authenticate once here)..."
ssh "$SSH_OPTS" -N ${REMOTE_USER}@${REMOTE_HOST} &
SSH_PID=$!
sleep 10  # give the master connection time to establish

cleanup() {
    echo "Closing SSH connection..."
    ssh -o ControlPath=${SSH_SOCKET} -O exit ${REMOTE_USER}@${REMOTE_HOST} 2>/dev/null
}
trap cleanup EXIT

for syear in $SYEARS; do
    eyear=$(( syear + 6 ))
    for member in $MEMBERS; do
        memstr=$(echo -n "00${member}" | tail -3c)
        memdir=${LOCAL_DIR}/${exp}_${syear}1101_mem${memstr}

        if [ ! -d "$memdir" ]; then
            echo "WARNING: Directory not found, skipping: $memdir" >&2
            continue
        fi

        for (( year=syear; year<=eyear; year++ )); do
            for atmvar in "${atmvars[@]}"; do
                file=${memdir}/${exp}_${syear}1101_mem${memstr}.cam.h2.${atmvar}_${year}.nc
                if [ -f "$file" ]; then
                    echo "Copying: $(basename "$file")"
                    scp -o ControlPath=${SSH_SOCKET} "$file" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
                else
                    echo "WARNING: File not found, skipping: $(basename "$file")" >&2
                fi
            done
        done
    done
done
