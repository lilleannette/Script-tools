#!/bin/sh
# Computes ocean section transports for a single year using m2transport.
# Copies required config and binary files into the year directory (Y<year>/),
# runs m2transport against the archived monthly files, then moves output back.
#
# Usage: ./Transport_1year.sh <year>
#!/bin/sh 

year=$1

pwd
cp transport_atl.in Y${year}/transport.in
cp sections.in Y${year}/
cp section_intersect Y${year}/
cp section_transport2 Y${year}/
cp section_transport Y${year}/
cp m2transport Y${year}/
cp regional.* Y${year}/
cp section*.dat Y${year}/
cp transport*.dat Y${year}/
cd Y${year}/

./m2transport archm.${year}*.b

for sec in {001..008}; do
   mv tst${sec}.nc ../tst${sec}.nc 
done
mv transports.nc ../transports_${year}.nc

cd ..
