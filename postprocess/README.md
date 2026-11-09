# Post-Processing tools

A set of scripts for post-processing runs.

---

## Scripts

| Script | Description |
|---|---|
| `remap_AR7_regions.ipynb` | Notebook to see and remap AR7 regions to other grids |
| `Scp_norcpm_atm.sh` | scp utility |
| `Transport_1year.sh` | Computes ocean section transports for a single year using `m2transport` |
| `Transfer_to_edito.sh` | Transfers processed TOPAZ2 hindcast output from NIRD to the EDITO platform |

# Remapping AR7 regions to other grids

Used for the Topaz2 grid for now, `remap_AR7_regions.ipynb` outputs the regions on the specified target grid in a netcdf file.

In the netcdf file, each region gets an integer index and a list mapping the IDs to regions names is provided.

The script handles dupplicate regions and the dateline in the input.

