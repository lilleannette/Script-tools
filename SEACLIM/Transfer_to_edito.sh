#!/bin/bash
# Transfers TOPAZ2 hindcast output from NIRD to the EDITO platform.
# Covers BGC and PHY 3D/2D variables and CICE sea ice variables (1993–2024).
# Requires the MinIO client (mc) at ./Progs/mc with EDITO credentials configured.
#
# Usage: ./Transfer_to_edito.sh

local_dir=/nird/datalake/NS9481K/shuang/seaclim/output
edito_dir=edito/seaclim/reference_simulations/hindcast

# BCG 3D-variables
for vari in alk chl dic nh4 no3 o2 ph phyc po4 si zooc; do
for year in {1993..2024}; do
./Progs/mc cp ${local_dir}/3D/BGC/3DT-${vari}/TOPAZ2_1m-m_3DT-${vari}_${year}*.nc ${edito_dir}/ARC/BGC/Monthly/3DT-${vari}/
done
done

# BGC 2D-variables
for vari in cflx npp o2b phsurf zeu; do
for year in {1993..2024}; do
./Progs/mc cp ${local_dir}/2D/BGC/2DT-${vari}/TOPAZ2_1d-m_2DT-${vari}_${year}*.nc ${edito_dir}/ARC/BGC/Daily/2DT-${vari}/
done
done

# PHY 3D-variables 
for vari in so thetao uo vo wo; do
for year in {1993..2024}; do
./Progs/mc cp ${local_dir}/3D/PHY/3DT-${vari}/TOPAZ2_1m-m_3DT-${vari}_${year}*.nc ${edito_dir}/ARC/PHY/Monthly/3DT-${vari}/
done
done

# PHY 2D-variables                                                                                                                                                                   
for vari in mld sbs sbt sss sst; do
for year in {1993..2024}; do
./Progs/mc cp ${local_dir}/2D/PHY/2DT-${vari}/TOPAZ2_1d-m_2DT-${vari}_${year}*.nc ${edito_dir}/ARC/PHY/Daily/2DT-${vari}/
done
done

# CICE 2D-variables
for vari in aice hi; do
for year in {1993..2024}; do
./Progs/mc cp ${local_dir}/2D/cice/2DT-${vari}/TOPAZ2_1d-m_2DT-${vari}_${year}*.nc ${edito_dir}/ARC/SEAICE/Daily/2DT-${vari}/
done
done
