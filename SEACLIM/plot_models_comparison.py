#!/usr/bin/env python3
"""
============================================================================
Multi-Model Atmospheric Forcing Comparison at North Atlantic / Arctic Points
============================================================================
Compare 4 models (NorCPM, ERA5, original, original_corrected) across
8 atmospheric variables (UAS, VAS, TREFHT, QREFHT, PSL, PRECT, FSDS, FLDS)
at 3 ocean points (Iceland Basin, Norwegian Sea, Fram Strait).
Handles two NetCDF layouts:
  - One file per variable  (e.g., UAS.nc containing only UAS)
  - One file with all variables (e.g., forcing.nc containing UAS, VAS, …)
Usage:
  1. Fill in the FILE_CONFIG dictionary below with your actual file paths.
  2. Run:  python plot_models_comparison.py
"""
import sys
import warnings
import numpy as np
import xarray as xr
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
# Suppress common NetCDF / xarray warnings
warnings.filterwarnings("ignore", category=xr.SerializationWarning)
warnings.filterwarnings("ignore", message=".*does not have a character.*")
# ============================================================================
#  USER CONFIGURATION — edit this section
# ============================================================================
# --- Variables to compare ---------------------------------------------------
VARIABLES = ["UAS", "VAS", "TREFHT", "QREFHT", "PSL", "PRECT", "FSDS", "FLDS"]
# Human-readable labels and units for each variable (for plot titles / y-axes)
"""VAR_META = {
    "UAS":    {"long_name": "Eastward Near-Surface Wind",   "units": "m/s"},
    "VAS":    {"long_name": "Northward Near-Surface Wind",  "units": "m/s"},
    "TREFHT": {"long_name": "2-m Air Temperature",          "units": "K"},
    "QREFHT": {"long_name": "2-m Specific Humidity",        "units": "kg/kg"},
    "PSL":    {"long_name": "Sea Level Pressure",            "units": "Pa"},
    "PRECT":  {"long_name": "Total Precipitation Rate",     "units": "m/s"},
    "FSDS":   {"long_name": "Downwelling Shortwave Flux",   "units": "W/m²"},
    "FLDS":   {"long_name": "Downwelling Longwave Flux",    "units": "W/m²"},
}"""
VAR_META = {
    "UAS":    {"long_name": "UAS",   "units": "m/s"},
    "VAS":    {"long_name": "VAS",  "units": "m/s"},
    "TREFHT": {"long_name": "TREFHT",          "units": "K"},
    "QREFHT": {"long_name": "QREFHT",        "units": "kg/kg"},
    "PSL":    {"long_name": "PSL",            "units": "Pa"},
    "PRECT":  {"long_name": "PRECT",     "units": "m/s"},
    "FSDS":   {"long_name": "FSDS",   "units": "W/m²"},
    "FLDS":   {"long_name": "FLDS",    "units": "W/m²"},
}
# --- Models to compare ------------------------------------------------------
MODELS = ["NorCPM", "ERA5", "original", "original_corrected"]
# Colors and line styles for each model (consistent across all panels)
MODEL_STYLE = {
    "NorCPM":             {"color": "#E63946", "ls": "-",  "lw": 1.4},
    "ERA5":               {"color": "#457B9D", "ls": "-",  "lw": 1.4},
    "original":           {"color": "#2A9D8F", "ls": "--", "lw": 1.4},
    "original_corrected": {"color": "#E9C46A", "ls": "-.", "lw": 1.4},
}
# --- Ocean points to extract -------------------------------------------------
POINTS = {
    "Iceland Basin":  {"lat": 62.0, "lon": -20.0},
    "Norwegian Sea":  {"lat": 68.0, "lon":   5.0},
    "Fram Strait":    {"lat": 79.0, "lon":   0.0},
}
# --- File paths for each model -----------------------------------------------
# Two formats are supported (can be mixed within a model):
#
# FORMAT A — One multi-variable file:
#   Provide the key "__all__" pointing to the file path.
#   The script will look for each variable name inside that single file.
#
# FORMAT B — One file per variable:
#   Provide one key per variable name pointing to its file path.
#
# You can combine both: variables found in per-variable files take priority
# over the multi-variable file.
#
# IMPORTANT: Replace the placeholder paths below with your actual file paths.
# Use raw strings (r"...") or forward slashes to avoid backslash issues.
file_year = 1993
FILE_CONFIG = {
    "NorCPM": {
        # Example FORMAT A — single file containing all variables:
        # "__all__": r"C:\data\NorCPM\NorCPM_forcing.nc",
        # Example FORMAT B — one file per variable:
        "UAS":    r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_UAS.nc",
        "VAS":    r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_VAS.nc",
        "TREFHT": r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_TREFHT.nc",
        "QREFHT": r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_QREFHT.nc",
        "PSL":    r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_PSL.nc",
        "PRECT":  r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_PRECT.nc",
        "FSDS":   r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_FSDS.nc",
        "FLDS":   r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/NorCPM_climatology/noresm2-mm-seaclim_hindcast.cam.h0.clim.1993-2024.startmonth11.leadmonth1-64.mem1-10_FLDS.nc",
    },
    "ERA5": {
        # Example: ERA5 might have everything in one file
        # "__all__": r"C:\data\ERA5\ERA5_forcing.nc",
        "UAS":    r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.10U_clim_64M.nc",
        "VAS":    r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.10V_clim_64M.nc",
        "TREFHT": r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.2T_clim_64M.nc",
        "QREFHT": r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.QREFHT_clim_64M.nc",
        "PSL":    r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.MSL_clim_64M.nc",
        "PRECT":  r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.TP_clim_64M_unit.nc",
        "FSDS":   r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.SSRD_clim_64M_unit.nc",
        "FLDS":   r"/cluster/projects/nn9481k/Climate_downscaling/NORCPM2_bias/ERA5_climatology/mon.STRD_clim_64M_unit.nc",
    },
    "original": {
        "UAS":    f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "VAS":    f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "TREFHT": f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "QREFHT": f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "PSL":    f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "PRECT":  f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "FSDS":   f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
        "FLDS":   f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.{file_year+1}-11-01-10800.nc",
    },
    "original_corrected": {
        "UAS":    f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.UAS_{file_year+2}.nc",
        "VAS":    f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.VAS_{file_year+2}.nc",
        "TREFHT": f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.TREFHT_{file_year+2}.nc",
        "QREFHT": f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.QREFHT_{file_year+2}.nc",
        "PSL":    f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.PSL_{file_year+2}.nc",
        "PRECT":  f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.PRECT_{file_year+2}.nc",
        "FSDS":   f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.FSDS_{file_year+2}.nc",
        "FLDS":   f"noresm2-mm-seaclim_hindcast/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001/noresm2-mm-seaclim_hindcast_{file_year}1101_mem001.cam.h2.FLDS_{file_year+2}.nc",
    },
}
# --- Coordinate names in the NetCDF files ------------------------------------
LAT_NAME = "lat"
LON_NAME = "lon"
TIME_NAME = "time"
# --- Optional: time slicing (set to None to use the full time range) ---------
TIME_START = f"{file_year+2}-01-01"   # e.g., "1980-01-01"
TIME_END   = f"{file_year+2}-10-31"   # e.g., "2020-12-31"
# --- Plot settings -----------------------------------------------------------
# Monthly rolling mean to smooth noisy sub-daily / daily data (set 0 to skip)
ROLLING_WINDOW = 0          # e.g., 30 for a 30-step rolling mean
FIGSIZE_PER_PANEL = (5, 2.8)  # (width, height) of each subplot panel
# ============================================================================
#  INTERNAL — no need to edit below unless you want to customize further
# ============================================================================
def _normalise_lon(lon):
    """Convert longitude to the -180..180 range."""
    return ((lon + 180) % 360) - 180
def _open_dataset(path):
    """Open a NetCDF file with sensible defaults."""
    return xr.open_dataset(path, decode_times=True, use_cftime=True)
def _cached_datasets():
    """
    Cache opened datasets so we don't re-open the same file many times.
    Returns a dict  {path: xr.Dataset}.
    """
    return {}
_DS_CACHE = _cached_datasets()
def get_dataset(path):
    """Return (possibly cached) xr.Dataset for *path*."""
    if path not in _DS_CACHE:
        print(f"  Opening {path} …")
        ds = _open_dataset(path)
        
        # Check if it is a climatology file (needs alignment to initialization date)
        # We check for 'climatology', '_clim', or '.clim.' to avoid matching 'seaclim' in standard runs
        if "climatology" in path.lower() or "_clim" in path.lower() or ".clim." in path.lower():
            import re
            # Extract initialization year and month from the FILE_CONFIG paths
            init_year, init_month = 2003, 11  # defaults
            found = False
            for m_key, m_cfg in FILE_CONFIG.items():
                for v_path in m_cfg.values():
                    match = re.search(r'_(\d{4})(\d{2})\d{2}_', v_path)
                    if match:
                        init_year = int(match.group(1))
                        init_month = int(match.group(2))
                        found = True
                        break
                if found:
                    break
            
            # Find the actual time coordinate name in the dataset
            time_coord_name = None
            for c in list(ds.coords) + list(ds.dims):
                if c.lower() == 'time' or 'time' in c.lower():
                    time_coord_name = c
                    break
            
            # Align the time axis by applying a constant shift (offsets the start date)
            # This preserves the exact resolution (3-hourly, daily, monthly) and avoids any smoothing/downsampling
            if time_coord_name is not None:
                time_vals = ds[time_coord_name].values
                first_val = time_vals[0]
                
                # Determine target start datetime with same class and calendar as first_val
                import cftime
                if hasattr(first_val, 'calendar'):
                    cal = getattr(first_val, 'calendar', 'standard')
                    if 'noleap' in cal.lower():
                        T_run_init = cftime.DatetimeNoLeap(init_year, init_month, first_val.day, first_val.hour, first_val.minute, first_val.second)
                    elif 'gregorian' in cal.lower():
                        T_run_init = cftime.DatetimeGregorian(init_year, init_month, first_val.day, first_val.hour, first_val.minute, first_val.second)
                    else:
                        try:
                            T_run_init = type(first_val)(init_year, init_month, first_val.day, first_val.hour, first_val.minute, first_val.second)
                        except Exception:
                            T_run_init = cftime.datetime(init_year, init_month, first_val.day, hour=first_val.hour, calendar=cal)
                else:
                    import datetime
                    T_run_init = datetime.datetime(init_year, init_month, first_val.day, first_val.hour, first_val.minute, first_val.second)
                
                # Compute offset and shift the time coordinate
                offset = T_run_init - first_val
                import numpy as np
                if isinstance(first_val, np.datetime64):
                    dt_offset = np.timedelta64(int(offset.total_seconds()), 's')
                    new_times = ds[time_coord_name].values + dt_offset
                else:
                    new_times = ds[time_coord_name].values + offset
                    
                ds = ds.assign_coords({time_coord_name: new_times})
                print(f"    ℹ Shifted climatology time axis by {offset} to start on {init_year}-{init_month:02d}")
                
        _DS_CACHE[path] = ds
    return _DS_CACHE[path]
# Known suffixes that may be appended to variable or coordinate names inside
# NetCDF files.  The script tries the bare name first, then each suffix.
KNOWN_SUFFIXES = [
    "_0e_to_360e_20n_to_90n",
    "_0e_to_360e",
    "_20n_to_90n",
]
def _resolve_name(name, candidates):
    """
    Resolve *name* against a list of *candidates* (variable or coord names).
    Lookup order:
      1. Exact match  (e.g. "lat")
      2. name + known suffix  (e.g. "lat_0e_to_360e_20n_to_90n")
      3. Case-insensitive match of the above
    Returns the resolved name, or None if not found.
    """
    # 1. Exact match
    if name in candidates:
        return name
    # 2. Try each known suffix
    for suffix in KNOWN_SUFFIXES:
        candidate = name + suffix
        if candidate in candidates:
            return candidate
    # 3. Case-insensitive fallback
    lower_map = {c.lower(): c for c in candidates}
    if name.lower() in lower_map:
        return lower_map[name.lower()]
    for suffix in KNOWN_SUFFIXES:
        candidate_lower = (name + suffix).lower()
        if candidate_lower in lower_map:
            return lower_map[candidate_lower]
    return None

COORD_ALIASES = {
    "lat": ["lat", "latitude", "LAT", "LATITUDE"],
    "lon": ["lon", "longitude", "LON", "LONGITUDE"],
    "time": ["time", "TIME"],
}

MODEL_VAR_ALIASES = {
    "ERA5": {
        "UAS":    ["10U", "10u", "u10", "var165"],
        "VAS":    ["10V", "10v", "v10", "var166"],
        "TREFHT": ["2T", "2t", "t2m", "var167"],
        "QREFHT": ["QREFHT", "q", "shum", "var235"],
        "PSL":    ["MSL", "msl", "var151"],
        "PRECT":  ["TP", "tp", "var228"],
        "FSDS":   ["SSRD", "ssrd", "var169"],
        "FLDS":   ["STRD", "strd", "var175"],
    }
}

def _resolve_coord(obj, coord_name):
    """
    Resolve a coordinate / dimension name in *obj*, prioritizing checking
    obj.dims, then checking obj.coords for possible suffixed variants.
    Supports coordinate aliases (e.g. lat -> latitude).
    """
    aliases = COORD_ALIASES.get(coord_name, [coord_name])
    for alias in aliases:
        # Check dims first since selection is done on dimensions
        all_names = list(obj.dims)
        resolved = _resolve_name(alias, all_names)
        if resolved is None:
            # Fallback to coords if not found in dims
            all_names = list(obj.coords) + list(obj.dims)
            resolved = _resolve_name(alias, all_names)
        if resolved is not None:
            return resolved
            
    raise KeyError(
        f"Coordinate '{coord_name}' (and aliases/suffixed variants) not found.\n"
        f"  Available coords/dims: {sorted(set(list(obj.coords) + list(obj.dims)))}"
    )
def extract_timeseries(model, varname, lat, lon):
    """
    Extract a 1-D time series for *varname* from *model* at the nearest
    grid point to (*lat*, *lon*).
    Returns
    -------
    xr.DataArray  (dims: time)
    """
    cfg = FILE_CONFIG[model]
    # --- Determine which file contains this variable -------------------------
    if varname in cfg:
        path = cfg[varname]
    elif "__all__" in cfg:
        path = cfg["__all__"]
    else:
        raise FileNotFoundError(
            f"No file configured for variable '{varname}' in model '{model}'. "
            f"Provide either a per-variable path or an '__all__' path."
        )
    ds = get_dataset(path)
    # --- Resolve the actual variable name (handles suffixes & aliases) --------
    resolved_var = _resolve_name(varname, list(ds.data_vars))
    if resolved_var is None and model in MODEL_VAR_ALIASES:
        for alias in MODEL_VAR_ALIASES[model].get(varname, []):
            resolved_var = _resolve_name(alias, list(ds.data_vars))
            if resolved_var is not None:
                break
                
    if resolved_var is None:
        available = list(ds.data_vars)
        raise KeyError(
            f"Variable '{varname}' (and aliases/suffixed variants) not found in {path}.\n"
            f"  Available variables: {available}"
        )
    if resolved_var != varname:
        print(f"    ℹ {model}/{varname}: using var '{resolved_var}'")
    da = ds[resolved_var]
    # --- Resolve coordinate names (handles suffixes on lat/lon/time) ---------
    resolved_lat  = _resolve_coord(da, LAT_NAME)
    resolved_lon  = _resolve_coord(da, LON_NAME)
    resolved_time = _resolve_coord(da, TIME_NAME)
    # --- Normalise longitudes if needed --------------------------------------
    file_lon = ds[resolved_lon].values
    target_lon = lon
    if file_lon.min() >= 0 and file_lon.max() > 180:
        # File uses 0..360 convention
        target_lon = lon % 360
    # --- Select nearest grid point -------------------------------------------
    da_point = da.sel(
        **{resolved_lat: lat, resolved_lon: target_lon},
        method="nearest",
    )
    # --- Optional time slicing -----------------------------------------------
    if TIME_START or TIME_END:
        da_point = da_point.sel(
            **{resolved_time: slice(TIME_START, TIME_END)}
        )
    # --- Optional smoothing --------------------------------------------------
    if ROLLING_WINDOW and ROLLING_WINDOW > 1:
        da_point = da_point.rolling(
            **{resolved_time: ROLLING_WINDOW}, center=True, min_periods=1
        ).mean()
    return da_point, resolved_time
def plot_all():
    """
    Create the full comparison figure.
    Layout:  rows = variables (8),  columns = points (3)
    Each panel shows 4 model lines.
    """
    n_vars = len(VARIABLES)
    n_pts  = len(POINTS)
    point_names = list(POINTS.keys())
    fig_w = FIGSIZE_PER_PANEL[0] * n_pts
    fig_h = FIGSIZE_PER_PANEL[1] * n_vars
    fig, axes = plt.subplots(
        n_vars, n_pts,
        figsize=(fig_w, fig_h),
        sharex="col",
        constrained_layout=True,
    )
    # Ensure axes is always 2-D
    if n_vars == 1:
        axes = axes[np.newaxis, :]
    if n_pts == 1:
        axes = axes[:, np.newaxis]
    for j, pt_name in enumerate(point_names):
        lat = POINTS[pt_name]["lat"]
        lon = POINTS[pt_name]["lon"]
        for i, varname in enumerate(VARIABLES):
            ax = axes[i, j]
            for model in MODELS:
                style = MODEL_STYLE[model]
                try:
                    ts, resolved_time = extract_timeseries(model, varname, lat, lon)
                    # Convert cftime to matplotlib-friendly dates if needed
                    time_vals = ts[resolved_time].values
                    if len(time_vals) > 0 and hasattr(time_vals[0], 'calendar'):
                        import datetime
                        time_vals = [
                            datetime.datetime(t.year, t.month, t.day, t.hour, t.minute, t.second)
                            for t in time_vals
                        ]
                    # Dynamic marker: use circular markers for low-frequency data (like monthly climatologies)
                    marker = "o" if len(time_vals) < 100 else None
                    ax.plot(
                        time_vals, ts.values,
                        label=model,
                        color=style["color"],
                        ls=style["ls"],
                        lw=style["lw"],
                        marker=marker,
                        markersize=4,
                        alpha=0.85,
                    )
                except Exception as exc:
                    print(f"  ⚠ {model}/{varname} @ {pt_name}: {exc}")
            # --- Axis decoration ---------------------------------------------
            meta = VAR_META.get(varname, {})
            ylabel = meta.get("units", "")
            if i == 0:
                ax.set_title(pt_name, fontsize=11, fontweight="bold")
            if j == 0:
                long = meta.get("long_name", varname)
                ax.set_ylabel(f"{long}\n[{ylabel}]", fontsize=8)
            else:
                ax.set_ylabel(ylabel, fontsize=8)
            ax.tick_params(labelsize=7)
            ax.grid(True, alpha=0.3)
            # Show legend only on the first panel
            if i == 0 and j == 0:
                ax.legend(fontsize=7, loc="best", framealpha=0.7)
    # --- Format x-axes (bottom row) ------------------------------------------
    for j in range(n_pts):
        ax_bottom = axes[-1, j]
        ax_bottom.set_xlabel("Time", fontsize=9)
        # Auto-format dates
        ax_bottom.xaxis.set_major_locator(mdates.AutoDateLocator())
        ax_bottom.xaxis.set_major_formatter(mdates.ConciseDateFormatter(
            mdates.AutoDateLocator()
        ))
        for label in ax_bottom.get_xticklabels():
            label.set_rotation(30)
            label.set_ha("right")
    fig.suptitle(
        "Multi-Model Atmospheric Forcing Comparison\n"
        "North Atlantic & Arctic Ocean Points",
        fontsize=14, fontweight="bold", y=1.01,
    )
    plt.show()
# ============================================================================
#  ENTRY POINT
# ============================================================================
def main():
    # --- Sanity check: warn if placeholder paths are still present -----------
    placeholder_found = False
    for model, var_paths in FILE_CONFIG.items():
        for key, path in var_paths.items():
            if "<PATH_TO_FILE>" in path:
                placeholder_found = True
                break
        if placeholder_found:
            break
    if placeholder_found:
        print("=" * 70)
        print("WARNING: Placeholder paths detected in FILE_CONFIG!")
        print("Please open this script and replace all '<PATH_TO_FILE>'")
        print("entries with your actual NetCDF file paths.")
        print("=" * 70)
        print()
        print("Example configuration:")
        print()
        print('  FILE_CONFIG = {')
        print('      "NorCPM": {')
        print('          # Option A: one file with all variables')
        print('          "__all__": r"C:\\data\\NorCPM\\forcing.nc",')
        print('      },')
        print('      "ERA5": {')
        print('          # Option B: one file per variable')
        print('          "UAS":    r"C:\\data\\ERA5\\UAS.nc",')
        print('          "VAS":    r"C:\\data\\ERA5\\VAS.nc",')
        print('          "TREFHT": r"C:\\data\\ERA5\\TREFHT.nc",')
        print('          ...')
        print('      },')
        print('  }')
        print()
        sys.exit(1)
    print("Starting multi-model comparison plot…")
    print(f"  Variables : {VARIABLES}")
    print(f"  Models    : {MODELS}")
    print(f"  Points    : {list(POINTS.keys())}")
    if ROLLING_WINDOW:
        print(f"  Smoothing : {ROLLING_WINDOW}-step rolling mean")
    print()
    plot_all()
if __name__ == "__main__":
    main()
