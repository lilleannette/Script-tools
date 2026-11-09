# SEACLIM NorCPM Hindcast Bias Creation

A set of scripts to create biases used on NorESM2-MM seasonal climate hindcast runs.

---

## Scripts

| Script | Description |
|---|---|
| `Update_cal_biasfiles_fix.sh` | Fixes calendar metadata on atmospheric bias correction reference files |
| `Make_ref_clim.py` | Computes climatology from a run output on selected variables |
| `Make_bias_from_refrun.py` | Computes the biases between reference run and Norcpm, used in `Preproc_norcpm_ocn.sh` |
| `Make_uvbias_from_refrun.ipynb` | Computes the velocity and barotropic biases between reference run and Norcpm, used in `Preproc_norcpm_ocn.sh` |
| `correct_TREFHT_bias.ipynb` | Corrects the TREFHT bias by taking 50% of the full bias |

---

## Dependencies

| Tool | Version | Purpose |
|---|---|---|
| [CDO](https://code.mpimet.mpg.de/projects/cdo) | 2.0.6-gompi-2022a | NetCDF file manipulation and calendar operations |
| [NCO](https://nco.sourceforge.net/) | 5.1.3-foss-2022a | Variable subsetting and attribute editing |

> **HPC users:** Uncomment the `module load` lines at the top of the scripts to load these tools via the module system.

The hycom-cice Python environment, the exact setup is described in the NERSC-HYCOM-CICE documentation 
(https://nersc-hycom-cice.readthedocs.io/en/latest/installation.html#python-environment)

---

## Notes

Bias correction files created with these scripts are saved on Nird at 
`/nird/datalake/NS9481K/arnaud/atm_bias/` and `/nird/datalake/NS9481K/arnaud/NorCPM_bias/` for the atmosphere and the ocean respectively.
