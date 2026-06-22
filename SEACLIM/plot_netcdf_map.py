"""
plot_netcdf_map.py
==================
Open a NetCDF file and plot a variable across time on a geographic map.
Dependencies
------------
    pip install xarray netcdf4 matplotlib cartopy numpy
Usage
-----
    # Animate the first detected variable and save as GIF
    python plot_netcdf_map.py data.nc
    # Plot a specific variable
    python plot_netcdf_map.py data.nc --var temperature
    # Save individual PNG frames instead of a GIF
    python plot_netcdf_map.py data.nc --frames
    # Limit to the first 20 timesteps
    python plot_netcdf_map.py data.nc --max-steps 20
    # Choose a different colormap
    python plot_netcdf_map.py data.nc --cmap viridis
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import matplotlib.animation as animation
import matplotlib.pyplot as plt
import numpy as np
import xarray as xr
# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
# Common dimension name aliases used across NetCDF conventions
_TIME_ALIASES = {"time", "t", "times", "date", "dates", "datetime", "Time", "TIME"}
_LAT_ALIASES  = {"lat", "latitude", "y", "nav_lat", "Latitude", "LAT", "LATITUDE", "XLAT"}
_LON_ALIASES  = {"lon", "longitude", "x", "nav_lon", "Longitude", "LON", "LONGITUDE", "XLONG"}
def _find_dim(ds: xr.Dataset, aliases: set[str]) -> str | None:
    """Return the first dimension/coordinate name that matches any alias."""
    for name in ds.dims:
        if name in aliases:
            return name
    for name in ds.coords:
        if name in aliases:
            return name
    return None
def _find_plottable_var(ds: xr.Dataset, time_dim: str) -> str | None:
    """Return the first data variable that has at least 3 dims (time + 2D space)."""
    for var_name in ds.data_vars:
        var = ds[var_name]
        if var.ndim >= 3 and time_dim in var.dims:
            return var_name
    return None
def _nice_title(var_name: str, ds: xr.Dataset) -> str:
    """Build a human-readable title from variable metadata."""
    var = ds[var_name]
    long_name = var.attrs.get("long_name", var_name)
    units = var.attrs.get("units", "")
    if units:
        return f"{long_name} [{units}]"
    return long_name
# ---------------------------------------------------------------------------
# Core plotting
# ---------------------------------------------------------------------------
def plot_frames(
    ds: xr.Dataset,
    var_name: str,
    time_dim: str,
    lat_dim: str,
    lon_dim: str,
    *,
    output_dir: Path,
    cmap: str = "coolwarm",
    max_steps: int | None = None,
) -> list[Path]:
    """Save one PNG per timestep and return the list of file paths."""
    output_dir.mkdir(parents=True, exist_ok=True)
    data = ds[var_name]
    n_steps = data.sizes[time_dim]
    if max_steps is not None:
        n_steps = min(n_steps, max_steps)
    # Compute a shared colour range across all timesteps for consistency
    vmin = float(data.isel({time_dim: slice(0, n_steps)}).min())
    vmax = float(data.isel({time_dim: slice(0, n_steps)}).max())
    title_base = _nice_title(var_name, ds)
    paths: list[Path] = []
    for i in range(n_steps):
        field = data.isel({time_dim: i})
        time_label = str(field.coords[time_dim].values)[:19]  # trim nanoseconds
        fig, ax = plt.subplots(
            figsize=(12, 6),
            subplot_kw={"projection": ccrs.PlateCarree()},
        )
        # Plot the data
        im = ax.pcolormesh(
            ds[lon_dim].values,
            ds[lat_dim].values,
            field.values,
            cmap=cmap,
            vmin=vmin,
            vmax=vmax,
            transform=ccrs.PlateCarree(),
            shading="auto",
        )
        # Map features
        ax.add_feature(cfeature.COASTLINE, linewidth=0.8)
        ax.add_feature(cfeature.BORDERS, linewidth=0.4, linestyle="--")
        ax.add_feature(cfeature.LAND, facecolor="lightgray", alpha=0.3)
        ax.gridlines(draw_labels=True, linewidth=0.3, alpha=0.5)
        # Colour bar & title
        cbar = fig.colorbar(im, ax=ax, orientation="vertical", pad=0.02, shrink=0.75)
        cbar.set_label(title_base, fontsize=10)
        ax.set_title(f"{title_base}\n{time_label}", fontsize=13, fontweight="bold")
        out_path = output_dir / f"frame_{i:04d}.png"
        fig.savefig(out_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
        paths.append(out_path)
        print(f"  [{i + 1}/{n_steps}] saved {out_path.name}")
    return paths
def plot_animation(
    ds: xr.Dataset,
    var_name: str,
    time_dim: str,
    lat_dim: str,
    lon_dim: str,
    *,
    output_path: Path,
    cmap: str = "coolwarm",
    max_steps: int | None = None,
    fps: int = 4,
) -> Path:
    """Create an animated GIF of the variable over time."""
    data = ds[var_name]
    n_steps = data.sizes[time_dim]
    if max_steps is not None:
        n_steps = min(n_steps, max_steps)
    vmin = float(data.isel({time_dim: slice(0, n_steps)}).min())
    vmax = float(data.isel({time_dim: slice(0, n_steps)}).max())
    title_base = _nice_title(var_name, ds)
    fig, ax = plt.subplots(
        figsize=(12, 6),
        subplot_kw={"projection": ccrs.PlateCarree()},
    )
    # Initial frame
    field_0 = data.isel({time_dim: 0})
    im = ax.pcolormesh(
        ds[lon_dim].values,
        ds[lat_dim].values,
        field_0.values,
        cmap=cmap,
        vmin=vmin,
        vmax=vmax,
        transform=ccrs.PlateCarree(),
        shading="auto",
    )
    ax.add_feature(cfeature.COASTLINE, linewidth=0.8)
    ax.add_feature(cfeature.BORDERS, linewidth=0.4, linestyle="--")
    ax.add_feature(cfeature.LAND, facecolor="lightgray", alpha=0.3)
    ax.gridlines(draw_labels=True, linewidth=0.3, alpha=0.5)
    cbar = fig.colorbar(im, ax=ax, orientation="vertical", pad=0.02, shrink=0.75)
    cbar.set_label(title_base, fontsize=10)
    title_obj = ax.set_title("", fontsize=13, fontweight="bold")
    def _update(frame_idx: int):
        field = data.isel({time_dim: frame_idx})
        time_label = str(field.coords[time_dim].values)[:19]
        # pcolormesh returns a QuadMesh; update its array
        im.set_array(field.values.ravel())
        title_obj.set_text(f"{title_base}\n{time_label}")
        print(f"  [{frame_idx + 1}/{n_steps}] rendering frame …")
        return (im, title_obj)
    anim = animation.FuncAnimation(
        fig, _update, frames=n_steps, blit=False, interval=1000 // fps,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    anim.save(str(output_path), writer="pillow", fps=fps, dpi=120)
    plt.close(fig)
    print(f"\n✓ Animation saved → {output_path}")
    return output_path
# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Plot a NetCDF variable across time on a geographic map.",
    )
    parser.add_argument("file", type=Path, help="Path to the NetCDF file (.nc)")
    parser.add_argument("--var", type=str, default=None,
                        help="Variable name to plot (auto-detected if omitted)")
    parser.add_argument("--cmap", type=str, default="coolwarm",
                        help="Matplotlib colormap (default: coolwarm)")
    parser.add_argument("--frames", action="store_true",
                        help="Save individual PNG frames instead of an animated GIF")
    parser.add_argument("--max-steps", type=int, default=None,
                        help="Maximum number of timesteps to plot")
    parser.add_argument("--fps", type=int, default=4,
                        help="Frames per second for the GIF (default: 4)")
    parser.add_argument("--output", type=str, default=None,
                        help="Output path (directory for --frames, file for GIF)")
    args = parser.parse_args(argv)
    # ── Open dataset ──────────────────────────────────────────────────────
    if not args.file.exists():
        sys.exit(f"Error: file not found → {args.file}")
    print(f"Opening {args.file} …")
    ds = xr.open_dataset(args.file)
    # ── Resolve dimensions ────────────────────────────────────────────────
    time_dim = _find_dim(ds, _TIME_ALIASES)
    lat_dim  = _find_dim(ds, _LAT_ALIASES)
    lon_dim  = _find_dim(ds, _LON_ALIASES)
    if time_dim is None:
        sys.exit("Error: could not detect a time dimension. "
                 f"Available dims: {list(ds.dims)}")
    if lat_dim is None or lon_dim is None:
        sys.exit("Error: could not detect lat/lon dimensions. "
                 f"Available dims: {list(ds.dims)}")
    print(f"  Detected dims → time={time_dim}, lat={lat_dim}, lon={lon_dim}")
    # ── Resolve variable ──────────────────────────────────────────────────
    if args.var:
        if args.var not in ds.data_vars:
            sys.exit(f"Error: variable '{args.var}' not found. "
                     f"Available: {list(ds.data_vars)}")
        var_name = args.var
    else:
        var_name = _find_plottable_var(ds, time_dim)
        if var_name is None:
            sys.exit("Error: no plottable 3-D+ variable found. "
                     f"Available vars: {list(ds.data_vars)}")
    print(f"  Plotting variable → {var_name}  "
          f"(shape: {dict(ds[var_name].sizes)})")
    # ── Plot ──────────────────────────────────────────────────────────────
    stem = args.file.stem
    if args.frames:
        out_dir = Path(args.output) if args.output else Path(f"{stem}_frames")
        plot_frames(
            ds, var_name, time_dim, lat_dim, lon_dim,
            output_dir=out_dir,
            cmap=args.cmap,
            max_steps=args.max_steps,
        )
        print(f"\n✓ Frames saved → {out_dir}/")
    else:
        out_path = Path(args.output) if args.output else Path(f"{stem}_animation.gif")
        plot_animation(
            ds, var_name, time_dim, lat_dim, lon_dim,
            output_path=out_path,
            cmap=args.cmap,
            max_steps=args.max_steps,
            fps=args.fps,
        )
if __name__ == "__main__":
    main()
