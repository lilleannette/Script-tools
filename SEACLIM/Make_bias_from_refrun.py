#!/usr/bin/env python
# coding: utf-8

# In[1]:


#get_ipython().system("bash -lc 'module load Miniforge3/24.1.2-0 && source $EBROOTMINIFORGE3/bin/activate && conda activate hycom-cice'")
import xarray as xr


# In[2]:


import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import numpy as np
from matplotlib.colors import TwoSlopeNorm

def ArcticMap():

    fig, ax = plt.subplots(
        figsize=(8, 8),
        subplot_kw={"projection": ccrs.NorthPolarStereo(central_longitude=0.0)},
    )

    ax.set_extent([-180, 180, 48, 90], crs=ccrs.PlateCarree())
    ax.add_feature(cfeature.LAND, facecolor=cfeature.COLORS["land"], edgecolor="grey", zorder=2)
    ax.add_feature(cfeature.COASTLINE.with_scale("50m"), edgecolor="grey", linewidth=0.4, zorder=3)
    ax.gridlines()

    return fig, ax

def pcolormesh_curvilinear(lon, lat, data, ax=None, **kwargs):

    proj = ax.projection
    pxy = proj.transform_points(ccrs.PlateCarree(), lon, lat)
    px, py = pxy[:, :, 0], pxy[:, :, 1]
    invalid = ~np.isfinite(px) | ~np.isfinite(py)
    px = np.where(invalid, 0.0, px)
    py = np.where(invalid, 0.0, py)
    data = np.where(invalid, np.nan, data)
    return ax.pcolormesh(px, py, data, **kwargs)


# In[3]:


from glob import glob
import cftime

varlist = ["templvl","salnlvl","no3lvl","silvl","o2lvl","dissiclvl","talklvl","po4lvl","sealv"]

NORCPM_PATH = "/cluster/projects/nn9481k/arnaud/Script-tools/SEACLIM/norcpm_clim/"
REFRUN_PATH = "/cluster/work/users/arnelt/clim_ave/"
#REFRUN_PATH = "/cluster/projects/nn9481k/arnaud/Script-tools/SEACLIM/ref_clim/"

filelist_norcpm = sorted(glob(NORCPM_PATH + "noresm2-mm-seaclim*"))
#filelist_norcpm = sorted(glob(NORCPM_PATH + "noresm2-mm-seaclim_hindcast.blom.hmphyglb.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_templvl.nc"))
filelist_refrun = sorted(glob(REFRUN_PATH + "clim_1993_2024_*"))

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

ds_refrun = xr.open_mfdataset(filelist_refrun, combine="by_coords", use_cftime=True, chunks={"time": 1})

ds_refrun = xr.concat([ds_refrun] * 7, dim="time")
ds_refrun = ds_refrun.isel(time=slice(10, 74))

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

ds_refrun = ds_refrun[varlist]


# In[4]:


import xesmf as xe

regridder = xe.Regridder(
    ds_refrun,
    ds_norcpm,
    method="bilinear",
    periodic=False
)

ds_refrun_interp = regridder(ds_refrun)
ds_refrun.close()


# In[5]:


ds_sealv = ds_refrun_interp["sealv"]

ds_refrun_interp_depth = ds_refrun_interp.drop_vars("sealv").interp(
    depth=ds_norcpm.depth,
    method="linear"
)

ds_refrun_interp = xr.merge([ds_refrun_interp_depth, ds_sealv])

ds_refrun_interp_depth.close()
ds_sealv.close()
print("Interpolation done")

# In[6]:


ds_refrun_interp[["o2lvl","no3lvl","po4lvl","silvl"]] *= 0.001


# In[7]:


ds_bias = ds_norcpm - ds_refrun_interp
print("Biases computed")

# In[ ]:


ds_bias = ds_bias.where(ds_bias.salnlvl <= 20, 0)
ds["sealv"] = ds["sealv"].isel(depth=0, drop=True)


# In[ ]:


for var in varlist:
    print(var)
    temp = ds_bias[var]
    temp.to_netcdf(f"NorCPM_bias/bias_NorCPM_REFRUN_64M_{var}.nc")


# In[ ]:




