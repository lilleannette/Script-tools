#!/usr/bin/env python
# coding: utf-8

# Usage: python Make_bias_from_refrun.py
# Creates bias files for NorCPM based on the reference run (REFRUN) climatology.

import xarray as xr
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import numpy as np
from matplotlib.colors import TwoSlopeNorm
from glob import glob
import cftime
import xesmf as xe

# Corrected variables
varlist = ["templvl","salnlvl","no3lvl","silvl","o2lvl","dissiclvl","talklvl","po4lvl","sealv"]

NORCPM_PATH = "/cluster/projects/nn9481k/arnaud/Script-tools/SEACLIM/norcpm_clim/"
REFRUN_PATH = "/cluster/work/users/arnelt/clim_ave/"

filelist_norcpm = sorted(glob(NORCPM_PATH + "noresm2-mm-seaclim*"))
filelist_refrun = sorted(glob(REFRUN_PATH + "clim_1993_2024_*"))

# Creates a common time coordinate for both datasets
common_time = [
    cftime.DatetimeNoLeap(1999, m, 15)
    for m in range(11, 13)
] + [
    cftime.DatetimeNoLeap(y, m, 15)
    for y in range(2000,2005)
    for m in range(1, 13)
] + [
    cftime.DatetimeNoLeap(2005, m, 15)
    for m in range(1, 3)
]

# Load NorCPM datasets and drop unnecessary variables
norcpm_datasets = []

for f in filelist_norcpm:
    ds_temp = xr.open_dataset(f, use_cftime=True)

    if "depth_bnds" in ds_temp.variables:
        ds_temp = ds_temp.drop_vars("depth_bnds")
    if ds_temp.attrs.get("bounds") is not None:
        ds_temp["depth"].attrs.pop("bounds")

    # Replace the existing time coordinate
    ds_temp = ds_temp.assign_coords(time=common_time)

    norcpm_datasets.append(ds_temp)

ds_norcpm = xr.merge(norcpm_datasets)
ds_temp.close()

ds_norcpm = ds_norcpm.drop_vars(["plon", "plat"])
ds_norcpm = ds_norcpm[varlist]

# Load REFRUN datasets and rename variables to match NorCPM
ds_refrun = xr.open_mfdataset(filelist_refrun, combine="by_coords", use_cftime=True, chunks={"time": 1})

ds_refrun = xr.concat([ds_refrun] * 7, dim="time")
ds_refrun = ds_refrun.isel(time=slice(10, 74))

# replace the existing time coordinate with the common time coordinate
ds_refrun = ds_refrun.assign_coords(time=common_time)

rename_dict = {
    "thetao":"templvl",
    "so":"salnlvl",
    "no3":"no3lvl",
    "si":"silvl",
    "o2":"o2lvl",
    "dissic":"dissiclvl",
    "TA":"talklvl",
    "po4":"po4lvl",
    "zos":"sealv"
}
ds_refrun = ds_refrun.rename(rename_dict)

# Correct the longitude and latitude coordinates
lon2d = ds_refrun.longitude.isel(time=0).drop_vars("time")
lat2d = ds_refrun.latitude.isel(time=0).drop_vars("time")

ds_refrun = (
    ds_refrun
    .drop_vars(["longitude", "latitude"])
    .assign_coords(
        lon=((lon2d + 360) % 360),
        lat=lat2d
    )
)

# Drop unnecessary variables
ds_refrun = ds_refrun[varlist]

# Interpolate REFRUN data to the NorCPM grid
regridder = xe.Regridder(
    ds_refrun,
    ds_norcpm,
    method="bilinear",
    periodic=False
)

ds_refrun_interp = regridder(ds_refrun)
ds_refrun.close()

# Interpolate REFRUN data to the NorCPM depth levels saving 2d variable sealv separately to avoid interpolation
ds_sealv = ds_refrun_interp["sealv"]

ds_refrun_interp_depth = ds_refrun_interp.drop_vars("sealv").interp(
    depth=ds_norcpm.depth,
    method="linear"
)

# Merge 2d variable sealv back into the interpolated dataset
ds_refrun_interp = xr.merge([ds_refrun_interp_depth, ds_sealv])

ds_refrun_interp_depth.close()
ds_sealv.close()
print("Interpolation done")

# Correct units for oxygen and nutrients
ds_refrun_interp[["o2lvl","no3lvl","po4lvl","silvl"]] *= 0.001

# Compute biases
ds_bias = ds_norcpm - ds_refrun_interp
print("Biases computed")

# Mask out the biases to the arctic region (reference run only present there)
ds_bias = ds_bias.where(ds_bias.salnlvl <= 20, 0)
ds_bias["sealv"] = ds_bias["sealv"].isel(depth=0, drop=True)

# Save biases to netCDF files
for var in varlist:
    print(var)
    temp = ds_bias[var]
    temp.to_netcdf(f"NorCPM_bias/bias_NorCPM_REFRUN_64M_{var}.nc")

