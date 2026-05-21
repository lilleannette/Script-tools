#!/bin/bash


year=$1
member=$2
variable_group=blom.hmphy20n #>20N, monthly
echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
./wget_seaclim_hindcasts.sh . $year $member $variable_group


year=$1
member=$2
variable_group=blom.hmbgc20n #>20N, monthly
echo ./wget_seaclim_hindcasts.sh . $year $member $variable_group
./wget_seaclim_hindcasts.sh . $year $member $variable_group
