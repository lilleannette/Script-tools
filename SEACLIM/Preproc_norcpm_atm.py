#!/usr/bin/env python3

import sys
import os
import shutil
import subprocess
import numpy as np
import xarray as xr
import pandas as pd
import cftime
import concurrent.futures
try:
    import dask
    HAS_DASK = True
except Exception:
    HAS_DASK = False
from datetime import datetime, timedelta
from pathlib import Path


def cleanup(*files):
    """Delete files and warn if deletion fails."""
    for f in files:
        try:
            if os.path.exists(f):
                os.remove(f)
        except Exception as e:
            print(f"WARNING: could not remove {f}: {e}", file=sys.stderr)


def load_grid_from_cdo(gridfile):
    """Load CDO grid file and return grid coordinates."""
    grid_info = {}
    with open(gridfile, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                continue
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()
            if key == 'xfirst':
                grid_info['xfirst'] = float(value)
            elif key == 'xinc':
                grid_info['xinc'] = float(value)
            elif key == 'xsize':
                grid_info['xsize'] = int(value)
            elif key == 'yfirst':
                grid_info['yfirst'] = float(value)
            elif key == 'yinc':
                grid_info['yinc'] = float(value)
            elif key == 'ysize':
                grid_info['ysize'] = int(value)
            elif key == 'yvals':
                grid_info['yvals'] = [float(v) for v in value.split() if v]
    return grid_info


def apply_grid(ds, gridfile):
    """Apply grid information from CDO grid file to dataset."""
    grid_info = load_grid_from_cdo(gridfile)
    
    # Create new longitude coordinates
    lon = np.arange(
        grid_info['xfirst'],
        grid_info['xfirst'] + grid_info['xsize'] * grid_info['xinc'],
        grid_info['xinc']
    )
    
    # Create latitude coordinates from yvals if present (apparently yes) otherwise use yfirst/yinc
    if 'yvals' in grid_info:
        lat = np.array(grid_info['yvals'], dtype=float)
    else:
        lat = np.arange(
            grid_info['yfirst'],
            grid_info['yfirst'] + grid_info['ysize'] * grid_info['yinc'],
            grid_info['yinc']
        )
    
    # Reassign coordinates
    ds = ds.assign_coords({
        'lon': ('x', lon) if 'x' in ds.dims else ('lon', lon),
        'lat': ('y', lat) if 'y' in ds.dims else ('lat', lat)
    })
    
    return ds


def make_regular_time_axis(start_time, count, hours=3):
    """Create a regular cftime time axis with a fixed hourly step."""
    return np.array([start_time + timedelta(hours=hours * i) for i in range(count)])


def align_bias_to_ds(ds, ds_bias):
    """Interpolate ds_bias to match ds.time and return an aligned dataset.

    Source datasets have different calendars so their times need to be converted first to be compared in .interp()
    """
    if 'time' not in ds_bias.coords or 'time' not in ds.coords:
        return ds_bias

    # Function to convert a sequence of time objects (cftime or numpy) to numpy datetime64
    def to_datetime64_array(times):
        arr = times
        # If already numpy datetime64 return it
        if np.issubdtype(np.array(arr).dtype, np.datetime64):
            return np.array(arr)
        # Otherwise convert to datetime64
        return np.array([np.datetime64(str(t)) for t in arr], dtype='datetime64[ns]')

    ds_time_np = to_datetime64_array(ds['time'].values)
    ds_bias_time_np = to_datetime64_array(ds_bias['time'].values)

    # Copy and interpolate with datetime64 times
    ds_bias_copy = ds_bias.copy(deep=True)
    ds_bias_copy = ds_bias_copy.assign_coords(time=ds_bias_time_np)
    first_var_bias = list(ds_bias_copy.data_vars)[0]

    interp_da = ds_bias_copy[first_var_bias].interp(time=ds_time_np, method='linear')

    # The first bias is in the middle of the first months so before that date, we copy the first bias
    bias_start = ds_bias_time_np.min()
    mask_before = ds_time_np < bias_start
    if mask_before.any():
        first_val = ds_bias_copy[first_var_bias].isel(time=0).values
        interp_da = interp_da.copy()
        vals = interp_da.values
        vals[mask_before, ...] = first_val
        interp_da.values = vals

    # Assign the original ds.time to the interpolated array
    interp_da = interp_da.assign_coords(time=ds['time'])

    # The date has different names for variables etc so it needs to be changed to the same to work
    ds_primary = ds[list(ds.data_vars)[0]]
    spatial_dims_ds = [d for d in ds_primary.dims if d != 'time']
    spatial_dims_bias = [d for d in interp_da.dims if d != 'time']
    rename_map = {}
    for bias_dim in spatial_dims_bias:
        if bias_dim in spatial_dims_ds:
            continue
        matches = [
            target_dim for target_dim in spatial_dims_ds
            if target_dim not in rename_map.values()
            and len(interp_da[bias_dim]) == len(ds_primary[target_dim])
        ]
        if len(matches) == 1:
            rename_map[bias_dim] = matches[0]
        elif len(matches) > 1:
            exact = [
                target_dim for target_dim in matches
                if np.array_equal(interp_da[bias_dim].values, ds_primary[target_dim].values)
            ]
            if len(exact) == 1:
                rename_map[bias_dim] = exact[0]
    if rename_map:
        interp_da = interp_da.rename(rename_map)

    # Build aligned bias dataset with now the right time lenght and with the interpolated data
    ds_bias_aligned = xr.Dataset({first_var_bias: interp_da}, attrs=ds_bias.attrs)
    for coord in ds_primary.coords:
        if coord in ds_bias_aligned.coords:
            ds_bias_aligned = ds_bias_aligned.assign_coords({coord: ds_primary.coords[coord]})

    return ds_bias_aligned


def bias_correct(ds, atmvar, biasdir):
    """Apply bias correction to dataset."""
    if atmvar in ["FSDS", "TREFHT"]:
        return ds
    elif atmvar == "PRECT":
        time_coder = xr.coders.CFDatetimeCoder(use_cftime=True)
        ds_bias = xr.open_dataset(f"{biasdir}RATIO_PRECT_nobc_vs_bc_cal.nc", decode_times=time_coder)

        # Aligning bias dates to the years we are working with
        ds_bias["time"] = [t.replace(year=t.year + ds.time.dt.year.values[0] - 2003) for t in ds_bias.time.values]

        ds[list(ds.data_vars)[0]] = ds[list(ds.data_vars)[0]] * ds_bias[list(ds_bias.data_vars)[0]][0]
        ds_bias.close()
    elif atmvar == "QREFHT":
        time_coder = xr.coders.CFDatetimeCoder(use_cftime=True)
        ds_bias = xr.open_dataset(f"{biasdir}bias_NorCPM_ERA5_64M_{atmvar}_20n_cal.nc", decode_times=time_coder)
        
        # Aligning bias dates to the years we are working with
        ds_bias["time"] = [t.replace(year=t.year + ds.time.dt.year.values[0] - 2003) for t in ds_bias.time.values]

        ds_bias = align_bias_to_ds(ds, ds_bias)
        ds[list(ds.data_vars)[0]] = (ds[list(ds.data_vars)[0]] - ds_bias[list(ds_bias.data_vars)[0]]).clip(min=6.0e-5)
        ds_bias.close()
    else:
        time_coder = xr.coders.CFDatetimeCoder(use_cftime=True)
        ds_bias = xr.open_dataset(f"{biasdir}bias_NorCPM_ERA5_64M_{atmvar}_20n_cal.nc", decode_times=time_coder)
        
        # Aligning bias dates to the years we are working with
        ds_bias["time"] = [t.replace(year=t.year + ds.time.dt.year.values[0] - 2003) for t in ds_bias.time.values]

        ds_bias = align_bias_to_ds(ds, ds_bias)
        ds[list(ds.data_vars)[0]] = ds[list(ds.data_vars)[0]] - ds_bias[list(ds_bias.data_vars)[0]]
        ds_bias.close()
    return ds


def process_var_batch(atmvar, syear, eyear, memdir, memstr, biasdir, griddir):
    """
    Merge source files, bias-correct, apply grid, split years, and handle calendar
    No creation of intermediate files.
    """
    print(f"  Processing {atmvar}...")
    
    # Load source files and merge
    source_files = [
        f"{memdir}noresm2-mm-seaclim_hindcast_{syear}1101_mem{memstr}.cam.h2.{year}-11-01-10800.nc"
        for year in range(syear, eyear)
    ]
    existing_files = [f for f in source_files if os.path.exists(f)]
    varname = f"{atmvar}_0e_to_360e_20n_to_90n"

    if not existing_files:
        print(f"    WARNING: No data files found for {atmvar}")
        return

    dsets = []
    for src_file in existing_files:
        try:
            time_coder = xr.coders.CFDatetimeCoder(use_cftime=True)
            ds = xr.open_dataset(src_file, decode_times=time_coder)
            if varname in ds.data_vars:
                dsets.append(ds[[varname]])
            ds.close()
        except Exception:
            continue

    if not dsets:
        print(f"    WARNING: No data found for {atmvar}")
        return

    ds_merged = xr.concat(dsets, dim='time')

    # Remove spurious timestep (indexed 15559)
    ds_merged = ds_merged.isel(time=[i for i in range(len(ds_merged.time)) if i != 15559])
    
    # Bias correction
    ds_merged = bias_correct(ds_merged, atmvar, biasdir)
    
    # Remove bounds and old lat/lon
    vars_to_drop = [v for v in ['bnds', 'time_bnds'] if v in ds_merged.data_vars]
    if vars_to_drop:
        ds_merged = ds_merged.drop_vars(vars_to_drop)
    
    # Apply grid
    if os.path.exists(f"{griddir}cdogrid_norcpm_atm_20n"):
        ds_merged = apply_grid(ds_merged, f"{griddir}cdogrid_norcpm_atm_20n")

    ds_merged = ds_merged.drop_vars(['lon','lat'])
    
    # Split by year and process calendar/leap days
    for year in range(syear, eyear + 1):
        # Select times for the given year
        times_all = ds_merged.time.values
        years_all = np.array([t.year for t in times_all])
        idx_year = np.where(years_all == year)[0]
        if idx_year.size == 0:
            continue
        ds_year = ds_merged.isel(time=idx_year)
        
        # Convert time to Gregorian and build regular axis
        is_leap = (year % 4 == 0) and (year % 100 != 0 or year % 400 == 0)
        
        # Handle leap day if needed (inserting it into the raw noleap data first)
        if is_leap and year != syear:
            times_noleap = ds_year.time.values
            mask_part1 = np.array([t.month < 3 for t in times_noleap])
            ds_part1 = ds_year.isel(time=mask_part1)
            ds_part2 = ds_year.isel(time=~mask_part1)
            
            mask_feb28 = np.array([t.month == 2 and t.day == 28 for t in ds_part1.time.values])
            ds_feb28 = ds_part1.isel(time=mask_feb28)
            
            ds_year = xr.concat([ds_part1, ds_feb28, ds_part2], dim='time')
        
        # Add synthetic first timestep for start year
        if year == syear:
            ds_first = ds_year.isel(time=0)
            ds_year = xr.concat([ds_first, ds_first, ds_year], dim='time')
            start_time = cftime.DatetimeGregorian(year, 10, 31, 21, 0, 0)
        else:
            start_time = cftime.DatetimeGregorian(year, 1, 1, 0, 0, 0)
            
        # Build and assign regular time axis
        ds_year['time'] = make_regular_time_axis(start_time, len(ds_year.time), hours=3)
        
        # Ensure dimension order is (time, ...) before writing
        desired_order = ['time'] + [d for d in ds_year.dims if d != 'time']
        ds_year = ds_year.transpose(*desired_order)
        
        # Write output
        print(f"Writing {atmvar} file for {year}...")
        outfile = f"{memdir}noresm2-mm-seaclim_hindcast_{syear}1101_mem{memstr}.cam.h2.{atmvar}_{year}.nc"
        ds_year.to_netcdf(outfile, encoding={v: {'zlib': True, 'complevel': 6} for v in ds_year.data_vars})


def main():
    # Parse arguments
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <start_year> <member> [atmdir]")
        sys.exit(1)
    
    syear = int(sys.argv[1])
    eyear = syear + 6
    print(f"End year: {eyear}")
    
    member = int(sys.argv[2])
    atmdir = sys.argv[3] if len(sys.argv) > 3 else os.getcwd()
    downloaddir = atmdir
    atmdir = f"{atmdir}/noresm2-mm-seaclim_hindcast/"
    
    # Configuration paths
    biasdir = "/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/"
    griddir = "/cluster/projects/nn9481k/Climate_downscaling/ESM_grids/"
    
    # Atmospheric variables
    atmvars = ["UAS", "VAS", "TREFHT", "QREFHT", "PSL", "PRECT", "FSDS", "FLDS"]
    #atmvars = ["PRECT"]
    
    # Format member string
    memstr = f"{member:03d}"
    memdir = f"{atmdir}noresm2-mm-seaclim_hindcast_{syear}1101_mem{memstr}/"
    
    # Ensure directory exists
    if not os.path.isdir(memdir):
        print(f"Directory not found: {memdir}. Attempting to run downloader script...")
        script_dir = os.path.dirname(__file__) or os.getcwd()
        download_script = os.path.join(script_dir, 'Download_norcpm_atm.sh')
        if not os.path.exists(download_script):
            download_script = os.path.join(os.getcwd(), 'Download_norcpm_atm.sh')

        if os.path.exists(download_script):
            ret = subprocess.run(['bash', download_script, str(syear), str(member), str(downloaddir)])
            if ret.returncode != 0:
                print(f"ERROR: downloader script failed (rc={ret.returncode})", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"ERROR: downloader script not found: {download_script}", file=sys.stderr)
            sys.exit(1)

        if not os.path.isdir(memdir):
            print(f"ERROR: Directory still not found after download: {memdir}")
            sys.exit(1)
    
    print(f"Directory found: {memdir}")
    
    # Process each variable
    print("Processing variables...")
    max_workers = min(len(atmvars), (os.cpu_count() or 1))
    # Use parallelism to allow all variables to be processed at the same time
    with concurrent.futures.ProcessPoolExecutor(max_workers=1) as ex:
        futures = [
            ex.submit(process_var_batch, atmvar, syear, eyear, memdir, memstr, biasdir, griddir)
            for atmvar in atmvars
        ]
        for f in concurrent.futures.as_completed(futures):
            try:
                f.result()
            except Exception as e:
                print(f"Error processing variable: {e}", file=sys.stderr)
    
    print("Preprocessing complete!")


if __name__ == "__main__":
    main()
