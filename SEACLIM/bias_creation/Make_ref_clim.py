# Usage: python Make_ref_clim.py
# Creates reference climatology files from the hycom reference run

import xhycom
import xarray as xr
from pathlib import Path
from glob import glob
from datetime import datetime, timedelta

#DATA_PATH = "/nird/datalake/NS9481K/shuang/TP2_output/expt_02.8/"
DATA_PATH = "/cluster/work/users/arnelt/hyc2proj_test/"
GRID_PATH = "/cluster/home/arnelt/NERSC-HYCOM-CICE/TP2a0.10/topo/regional.grid"

rename_dict = {
    "ubarotrop": "ubaro",
    "vbarotrop": "vbaro",
}

outdir = Path("ref_clim")
outdir.mkdir(exist_ok=True)

years = range(1993, 2025)

# To load less data into memory, we process one month at a time, openning each year separately
for month in range(1, 13):

    print(f"\nProcessing month {month:02d}")

    monthly_sum = None
    monthly_count = None
    month_time = None

    for year in years:

        print(f"  Year {year}")

        files = sorted(glob(f"{DATA_PATH}/archm_{year}{month:02d}*"))

        if not files:
            print("    No files found")
            continue

        ds = xr.open_mfdataset(
            files,
            #grid=GRID_PATH,
            chunks={"time": 1},
        )

        ds = ds[list(rename_dict.keys())].rename(rename_dict)

        if month_time is None:
            month_time = ds.time.isel(time=0).item()

        year_sum = ds.sum(dim="time").compute()
        year_count = ds.count(dim="time").compute()

        if monthly_sum is None:
            monthly_sum = year_sum
            monthly_count = year_count
        else:
            monthly_sum += year_sum
            monthly_count += year_count

        ds.close()

    if monthly_sum is None:
        print(f"No data for month {month:02d}, skipping")
        continue

    print("Computing climatology")

    # Compute the climatology for the month and correcting time axis
    clim_month = monthly_sum / monthly_count

    clim_month = clim_month.expand_dims(
        time=[month_time]
    )

    clim_month["time"].attrs = {
        "standard_name": "time",
        "long_name": "time",
    }

    outfile = outdir / f"clim_1993_2024_{month:02d}_uv.nc"

    # Saving the results
    clim_month.to_netcdf(
        outfile,
        unlimited_dims=["time"]
    )

    print(f"Saved {outfile}")

print("Done")

