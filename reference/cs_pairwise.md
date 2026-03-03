# Pairwise Circuitscape Analysis

Compute effective resistance and cumulative current flow between all
pairs of focal nodes using Circuitscape's pairwise mode.

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
  or file path. The resistance (or conductance) surface.

- locations:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Focal nodes/regions raster with integer IDs.

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
  with named layers for each output map (e.g., `"cumulative_current"`).

- resistance_matrix:

  A numeric matrix of pairwise effective resistances.

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
