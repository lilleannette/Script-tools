#!/bin/bash
# Downloads NorCPM ocean hindcast output for a given start year and ensemble member.
# Fetches two variable groups via wget_seaclim_hindcasts.sh:
#   blom.hmphyglb — global monthly hydrography (temperature, salinity, sea level, barotropic flow)
#   blom.hmphy20n — >20N monthly currents (u/v velocities)
#
# Usage: ./Download_norcpm_ocn.sh <year> <member>

year=$1
member=$2
variable_group=blom.hmphyglb #global, monthly, contains hydrography
echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
./wget_seaclim_hindcasts.sh . $year $member $variable_group

year=$1
member=$2
variable_group=blom.hmphy20n #>20N, monthly
echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
./wget_seaclim_hindcasts.sh . $year $member $variable_group
