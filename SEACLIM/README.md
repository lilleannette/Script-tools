# SEACLIM NorCPM Hindcast Post-Processing

A set of Bash scripts for downloading, bias-correcting, and calendar-adjusting atmospheric and ocean output from NorESM2-MM seasonal climate hindcast runs.

---

## Scripts

| Script | Description |
|---|---|
| `wget_seaclim_hindcasts.sh` | Downloads raw NorCPM hindcast files from the Sigma2 server |
| `Download_norcpm_atm.sh` | Wraps `wget_seaclim_hindcasts.sh` for atmospheric output (cam.h2, >20N, 3-hourly) |
| `Download_norcpm_ocn.sh` | Wraps `wget_seaclim_hindcasts.sh` for ocean output (global and >20N monthly) |
| `Preproc_norcpm_atm.sh` | Main atmospheric pipeline — extract, bias-correct, calendar-fix, insert leap days |
| `Preproc_norcpm_ocn.sh` | Main ocean pipeline — extract, bias-correct, calendar-fix ocean variables |
| `Update_cal_biasfiles_fix.sh` | Fixes calendar metadata on atmospheric bias correction reference files |
| `Transport_1year.sh` | Computes ocean section transports for a single year using `m2transport` |
| `Transfer_to_edito.sh` | Transfers processed TOPAZ2 hindcast output from NIRD to the EDITO platform |

---

## Dependencies

| Tool | Version | Purpose |
|---|---|---|
| [CDO](https://code.mpimet.mpg.de/projects/cdo) | 2.0.6-gompi-2022a | NetCDF file manipulation and calendar operations |
| [NCO](https://nco.sourceforge.net/) | 5.1.3-foss-2022a | Variable subsetting and attribute editing |

> **HPC users:** Uncomment the `module load` lines at the top of the scripts to load these tools via the module system.

---

## Atmospheric Pipeline

### Usage

```bash
./Preproc_norcpm_atm.sh <start_year> <member> [atmdir]
```

| Argument | Description | Example |
|---|---|---|
| `start_year` | Hindcast initialisation year | `1993` |
| `member` | Ensemble member number | `3` |
| `atmdir` | Root data directory (optional, defaults to current directory) | `/data/seaclim` |

### Example

```bash
./Preproc_norcpm_atm.sh 1993 3
```

This processes ensemble member 3 of the hindcast initialised in November 1993, covering the period 1993–1999.

### Pipeline stages

1. **Download** raw NorCPM atmospheric output via `Download_norcpm_atm.sh`
2. **Extract** individual variables from model output files per year
3. **Merge** yearly files into a single time series and remove spurious timesteps
4. **Apply bias correction** (variable-dependent method, see below)
5. **Set grid** and split back into yearly files
6. **Prepend** a synthetic timestep at `<syear>-10-31 21:00:00` to the first year
7. **Fix the calendar** to standard Gregorian and insert leap days for leap years

### Atmospheric variables

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

### Bias correction methods

| Variable(s) | Method |
|---|---|
| `FSDS`, `TREFHT` | No bias correction applied |
| `PRECT` | Multiplicative correction using a pre-computed ratio file |
| `QREFHT` | Additive monthly correction with a floor cap at `6.0e-5` |
| `UAS`, `VAS`, `PSL`, `FLDS` | Standard additive monthly bias correction |

Bias correction reference files are located in the parent of the member directory (`../`).

---

## Ocean Pipeline

### Usage

```bash
./Preproc_norcpm_ocn.sh <start_year> <member> [download]
```

| Argument | Description | Example |
|---|---|---|
| `start_year` | Hindcast initialisation year | `1993` |
| `member` | Ensemble member number | `3` |
| `download` | Whether to download raw data first (`true`/`false`, default `true`) | `false` |

### Ocean variables

| Variable | Description | Bias corrected |
|---|---|---|
| `salnlvl` | Salinity on depth levels | Yes (WOA2018) |
| `templvl` | Temperature on depth levels | Yes (WOA2018) |
| `ubaro` | Barotropic eastward velocity | No |
| `vbaro` | Barotropic northward velocity | No |
| `sealv` | Sea surface height | No |
| `uvellvl` | Eastward velocity on depth levels | No |
| `vvellvl` | Northward velocity on depth levels | No |

Bias correction files are expected in `./NorCPM_ocn_biascorr/`.

---

## Output

### Atmospheric

Processed files are written into the ensemble member directory:

```
<atmdir>/noresm2-mm-seaclim_hindcast_<syear>1101_mem<memstr>/
```

Final output files follow the naming convention:

```
noresm2-mm-seaclim_hindcast_<syear>1101_mem<memstr>.cam.h2.<VARIABLE>_<year>.nc
```

Backup copies of files modified during leap year insertion are saved to `<memdir>/bckup/`.

### Ocean

```
noresm2-mm-seaclim_hindcast_<syear>1101_mem<memstr>/
  noresm2-mm-seaclim_hindcast_<syear>1101_mem<memstr>.blom.hmphyglb.<VARIABLE>_<year>_<month>.nc
```

---

## Notes

- The hindcast window covers `syear` to `syear + 6` (7 years).
- The atmospheric pipeline handles **leap years** by duplicating February 28th data and relabelling it as February 29th.
- Reference time for all output is anchored to `1950-01-01` with a 3-hourly timestep (atmospheric) or monthly timestep (ocean).
