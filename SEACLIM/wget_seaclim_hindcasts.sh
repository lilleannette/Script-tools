#!/bin/sh -evx

# check input arguments and print help blurb if check fails
if [[ $# -lt 4 || $1 == "-h" || $1 == "--help" ]]
then
cat <<EOF

Usage: 

  $0  <output location> <start years> <members> <variable groups>  

Example: 

  $0 . 1993,1994,1995 1,2,3,4 cam.h0,cam.h1  

Description: 

  The script downloads NorESM2-MM hindcast and forecast output prepared for SEACLIM.    

  Mandatory arguments are 

    <output location>: path to folder to store the data (created if necessary) 

    <start years>: comma separated list without blanks, available years 1982 to 2024  

    <members>: comma separated list without blanks, available members 1 to 10 

    <variable groups>: comma separated list without blanks, available groups:  
                       cam.h0        - atmospheric, monthly, global      
                       cam.h1        - atmospheric, daily, global   
                       cam.h2        - atmospheric, 3-hourly, >20degN  
                       cam.h3        - atmospheric, hourly, >20degN  
                       cice.h        - sea ice, monthly, global
                       clm2.h0       - land, monthly, global  
                       blom.hmphyglb - ocean physics, monthly, global   
                       blom.hmphy20n - ocean physics, monthly, >20degN 
                       blom.hdphy20n - ocean physics, daily, >20degN
                       blom.hdphyibi - ocean physics, daily, extended IBI 
                       blom.hmbgcglb - ocean bgc, monthly, global 
                       blom.hdbgcglb - ocean bgc, daily, global 
                       blom.hdbgcibi - ocean bgc, daily, extended IBI 
                       mosart.h0     - river runoff, monthly, global    

  The downloaded data is stored in a folder structure like  
    noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_19931101_mem001

  Re-execution of the script will continue a partial download. 

  The data comprises 40 TB in total (61 GB per start date, per member).   

Change history:	
  2025.11.24 (ingo.bethke@uib.no) fixed another bug related to output location and member selection
  2025.09.30 (ingo.bethke@uib.no) fixed bug related to member selection
  2025.09.23 (ingo.bethke@uib.no) created script

EOF
  exit 1
fi
OBASE=`readlink -f $1` 
YEARS=`echo $2 | sed 's/,/ /g'` 
MEMBERS=`echo $3 | sed 's/,/ /g'`
VARGROUPS=`echo $4 | sed 's/,/ /g'` 

# loop over start years, members and variable groups
for YEAR in $YEARS
do
for MEMBER in $MEMBERS
do
for VARGROUP in $VARGROUPS
do

# create output folder and change directory 
PREFIX=noresm2-mm-seaclim_hindcast
SDATE=${YEAR}1101
MEMBERTAG=mem`printf %03d $MEMBER`
ODIR=$OBASE/$PREFIX/${PREFIX}_${SDATE}_$MEMBERTAG 
echo Downloading output for start year $YEAR, member $MEMBER and variable group $VARGROUP to ${ODIR}. This may take a while... 
mkdir -p $ODIR
cd $ODIR

# download files 
wget --no-use-server-timestamps --no-directories -rc -q -A "*${MEMBERTAG}.${VARGROUP}.*" https://ns11071k.web.sigma2.no/shared/seaclim/wp2/raw/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${SDATE}/noresm2-mm-seaclim_hindcast_${SDATE}_${MEMBERTAG}
#wget --no-use-server-timestamps --no-directories -rc -q -A "*${MEMBERTAG}.${VARGROUP}.*" https://ns11071k.web.sigma2.no/seaclim/wp2/raw/noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_${SDATE}/noresm2-mm-seaclim_hindcast_${SDATE}_${MEMBERTAG} 

# end loop over start years, members and variable groups
done
done
done
echo $0 COMPLETE
