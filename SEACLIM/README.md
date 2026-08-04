# SEACLIM NorCPM Hindcast Post-Processing

A set of scripts for downloading, bias-correcting, and calendar-adjusting atmospheric and ocean output from NorESM2-MM seasonal climate hindcast runs.

---

## Scripts

| Script | Description |
|---|---|
| `wget_seaclim_hindcasts.sh` | Downloads raw NorCPM hindcast files from the Sigma2 server |
| `Download_norcpm_atm.sh` | Wraps `wget_seaclim_hindcasts.sh` for atmospheric output (cam.h2, >20N, 3-hourly) |
| `Download_norcpm_ocn.sh` | Wraps `wget_seaclim_hindcasts.sh` for ocean output (global and >20N monthly) |
| `Preproc_norcpm_atm.sh` | Main atmospheric pipeline — extract, bias-correct, calendar-fix, insert leap days |
| `Preproc_norcpm_atm.py` | Main atmospheric pipeline updated in Python — extract, bias-correct, calendar-fix, insert leap days |
| `Preproc_norcpm_ocn.sh` | Main ocean pipeline — extract, bias-correct, calendar-fix ocean variables |
| `Update_cal_biasfiles_fix.sh` | Fixes calendar metadata on atmospheric bias correction reference files |
| `Transport_1year.sh` | Computes ocean section transports for a single year using `m2transport` |
| `Transfer_to_edito.sh` | Transfers processed TOPAZ2 hindcast output from NIRD to the EDITO platform |
| `run_preproc.sh` | Downloads and runs preprocessing scripts for both ocean and atmosphere |
| `run_nesting.sh` | Nesting files generation and experiment creation pipeline after ocean preprocessing |
| `run_atmforcing.sh` | Generates hycom input files for atmosphere forcing from preprocessed files |
| `Make_ref_clim.py` | Computes climatology from a run output on selected variables |
| `Make_bias_from_refrun.py` | Computes the biases between reference run and Norcpm, used in `Preproc_norcpm_ocn.sh` |
| `Make_uvbias_from_refrun.ipynb` | Computes the velocity and barotropic biases between reference run and Norcpm, used in `Preproc_norcpm_ocn.sh` |

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
python Preproc_norcpm_atm.py <start_year> <member> [atmdir]
```

| Argument | Description | Example |
|---|---|---|
| `start_year` | Hindcast initialisation year | `1993` |
| `member` | Ensemble member number | `3` |
| `atmdir` | Root data directory (optional, defaults to current directory) | `/data/seaclim` |

### Example

```bash
python Preproc_norcpm_atm.py 1993 3
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
| `salnlvl` | Salinity on depth levels | Yes |
| `templvl` | Temperature on depth levels | Yes |
| `ubaro` | Barotropic eastward velocity | Yes |
| `vbaro` | Barotropic northward velocity | Yes |
| `sealv` | Sea surface height | Yes |
| `uvellvl` | Eastward velocity on depth levels | Yes |
| `vvellvl` | Northward velocity on depth levels | Yes |

Bias correction files are expected in `./NorCPM_bias/`.

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

## Complete input files generation

The preparation of hycom input files from NorCPM data has been wrapped in 3 scripts to automate the workflow. 


To use these, the file setup and model installation described in the NERSC-HYCOM-CICE documentation is expected : https://nersc-hycom-cice.readthedocs.io/en/latest/.


The scripts cover downloading, preprocessing and converting the data to hycom input files.
At the same time, experiments are created with the naming convention : year.member (example : 93.1 for year 1993 and member 1).
And other inputs required by hycom are copied over from experiment 01.0 taken as a reference.
To then run the model in these experiments, `EXPT.src` and `srjob.sh` should be updated and the model compiled.

### Usage

```bash
./run_preproc.sh <start_year>
./run_nesting.sh <start_year>
./run_atmforcing.sh <start_year>
```

| Argument | Description | Example |
|---|---|---|
| `start_year` | Initialisation years (can be multiple) | `1993 1994` |

`./run_preproc.sh` should always be ran first as it downloads and preprocesses the files needed by the following scripts.
By default the scripts will go over members 1 to 4 but the loops can be adjusted.

---

## Notes

- The hindcast window covers `syear` to `syear + 6` (7 years).
- The atmospheric pipeline handles **leap years** by duplicating February 28th data and relabelling it as February 29th.
- Reference time for all output is anchored to `1950-01-01` with a 3-hourly timestep (atmospheric) or monthly timestep (ocean).
