#!/bin/bash


year=$1
member=$2
variable_group=blom.hmphyglb #global, monthly, contains hydrography
echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
./wget_seaclim_hindcasts.sh . $year $member $variable_group


year=$1
member=$2
variable_group=blom.hmphy20n #>20N, monthly, contains the currents
echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
./wget_seaclim_hindcasts.sh . $year $member $variable_group
