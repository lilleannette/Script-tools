# Remapping AR7 regions to other grids

Used for the Topaz2 grid for now, ´remap_AR7_regions.ipynb´ outputs the regions on the specified target grid in a netcdf file.

In the netcdf file, each region gets an integer index and a list mapping the IDs to regions names is provided.

The script handles dupplicate regions and the dateline in the input.

