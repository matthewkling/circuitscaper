# Pairwise Circuitscape Analysis

Compute pairwise effective resistances and cumulative current flow
between all pairs of focal nodes.

## Usage

``` r
cs_pairwise(
  resistance,
  locations,
  resistance_is = "resistances",
  four_neighbors = FALSE,
  solver = "cg+amg",
  output_dir = NULL,
  verbose = FALSE
)
```

## Arguments

- resistance:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. The resistance (or conductance) surface. Higher values
  represent greater resistance to movement. Use the `resistance_is`
  argument if your surface represents conductances instead.

- locations:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Focal nodes raster with positive integer IDs identifying
  each node. Cells with value 0 or `NA` are not treated as focal nodes.

- resistance_is:

  Character. Whether the resistance surface represents `"resistances"`
  (default) or `"conductances"`.

- four_neighbors:

  Logical. Use 4-neighbor (rook) connectivity instead of 8-neighbor
  (queen). Default `FALSE`.

- solver:

  Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.

- output_dir:

  Optional character path. If provided, output files persist there.
  Default `NULL` uses a temporary directory that is cleaned up
  automatically.

- verbose:

  Logical. Print Circuitscape solver output. Default `FALSE`.

## Value

A named list with:

- current_map:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  with a single layer:

  cumulative_current

  :   Current flow summed across all pairs, indicating the relative
      importance of each cell as a movement corridor.

- resistance_matrix:

  A symmetric numeric matrix of pairwise effective resistances between
  focal nodes, with node IDs as row and column names.

## Details

Pairwise mode iterates over every unique pair of focal nodes. For each
pair, one node is injected with 1 amp of current and the other is
connected to ground. The effective resistance between the pair is
recorded, and the resulting current flow is accumulated across all pairs
into a cumulative current map that highlights important movement
corridors.

This is the most common Circuitscape mode and is typically used to
quantify connectivity between discrete habitat patches or populations.
The resistance matrix can be used as a distance metric in analyses such
as isolation by resistance.

## References

Circuitscape user guide:
<https://docs.circuitscape.org/Circuitscape.jl/latest/usage/>

## See also

[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md),
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
locs <- rast(nrows = 10, ncols = 10, vals = 0)
locs[1, 1] <- 1; locs[1, 10] <- 2; locs[10, 5] <- 3
result <- cs_pairwise(res, locs)
plot(result$current_map)
result$resistance_matrix
} # }
```
