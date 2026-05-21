# NorCPM Atmospheric Hindcast Post-Processing

A set of Bash scripts for downloading, bias-correcting, and calendar-adjusting atmospheric output from NorESM2-MM seasonal climate hindcast runs.

---

## Overview

This pipeline processes raw NorCPM atmospheric forecast data for a given start year and ensemble member. It performs the following steps:

1. **Downloads** NorCPM atmospheric output for the specified hindcast
2. **Extracts** individual atmospheric variables from model output files
3. **Merges** yearly files into a single time series
4. **Applies bias correction** (variable-dependent method)
5. **Fixes the time axis and calendar** to standard Gregorian
6. **Inserts leap days** for leap years
7. **Prepends an additional timestep** to the first year of output

---

## Scripts

| Script | Description |
|---|---|
| `Process_norcpm_atm.sh` | Main script — orchestrates the full pipeline |
| `Download_norcpm_atm.sh` | Downloads raw NorCPM hindcast atmospheric files |
| `Update_cal_biasfiles.sh` | Fixes calendar metadata on bias correction reference files |

---

## Dependencies

| Tool | Version | Purpose |
|---|---|---|
| [CDO](https://code.mpimet.mpg.de/projects/cdo) | 2.0.6-gompi-2022a | NetCDF file manipulation and calendar operations |
| [NCO](https://nco.sourceforge.net/) | 5.1.3-foss-2022a | Variable subsetting and attribute editing |

> **HPC users:** Uncomment the `module load` lines at the top of the script to load these tools via the module system.

---

## Usage

```bash
./Process_norcpm_atm.sh <start_year> <member>
```

### Arguments

| Argument | Description | Example |
|---|---|---|
| `start_year` | Hindcast initialisation year | `1993` |
| `member` | Ensemble member number | `3` |

### Example

```bash
./Process_norcpm_atm.sh 1993 3
```

This processes ensemble member 3 of the hindcast initialised in November 1993, covering the period 1993–1999.

---

## Atmospheric Variables

| Variable | Long Name |
|---|---|
| `UAS` | Eastward near-surface wind |
| `VAS` | Northward near-surface wind |
| `TREFHT` | Reference height temperature |
| `QREFHT` | Reference height specific humidity |
| `PSL` | Sea level pressure |
| `PRECT` | Total precipitation rate |
| `FSDS` | Downwelling shortwave flux at surface |
| `FLDS` | Downwelling longwave flux at surface |

---

## Bias Correction Methods

Different variables use different correction strategies:

| Variable(s) | Method |
|---|---|
| `FSDS`, `TREFHT` | No bias correction applied |
| `PRECT` | Multiplicative correction using a pre-computed ratio file |
| `QREFHT` | Additive monthly correction with a floor cap at `6.0e-5` |
| `UAS`, `VAS`, `PSL`, `FLDS` | Standard additive monthly bias correction |

Bias correction reference files are located in the parent of the member directory (`../`).

---

## Configuration

The following paths are hardcoded and should be updated to match your environment:

```bash
# In Process_norcpm_atm.sh and Update_cal_biasfiles.sh
atmdir=/Users/annettes/Downloads/Tools/SEACLIM/noresm2-mm-seaclim_hindcast/
```

Also ensure the CDO grid description file is available:
```
cdogrid_norcpm_atm_20n
```

---

## Output

Processed files are written into the ensemble member directory:

```
<atmdir>/noresm2-mm-seaclim_hindcast_<syear>1101_mem<memstr>/
```

Final output files follow the naming convention:

```
noresm2-mm-seaclim_hindcast_<syear>1101_mem<memstr>.cam.h2.<VARIABLE>_<year>.nc
```

Backup copies of files modified during leap year insertion are saved to:

```
<memdir>/bckup/
```

---

## Notes

- The hindcast window covers `syear` to `syear + 6` (7 years).
- The pipeline handles **leap years** by duplicating February 28th data and relabelling it as February 29th.
- The first year's output is prepended with an additional timestep at `<syear>-10-31 21:00:00` to satisfy downstream model requirements.
- Reference time for all output is anchored to `1950-01-01` with a 3-hourly time step.
