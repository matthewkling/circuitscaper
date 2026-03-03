# Advanced Circuitscape Analysis

Advanced mode with user-specified source and ground layers. Unlike the
other modes, there is no focal node concept — the user provides explicit
source current strengths and ground conductances.

## Usage

``` r
cs_advanced(
  resistance,
  source,
  ground,
  resistance_is = "resistances",
  four_neighbors = FALSE,
  solver = "cg+amg",
  write_voltage = FALSE,
  output_dir = NULL,
  verbose = FALSE
)
```

## Arguments

- resistance:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. The resistance (or conductance) surface.

- source:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Source current strengths.

- ground:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Ground conductances.

- resistance_is:

  Character. Whether the resistance surface represents `"resistances"`
  (default) or `"conductances"`.

- four_neighbors:

  Logical. Use 4-neighbor (rook) connectivity instead of 8-neighbor
  (queen). Default `FALSE`.

- solver:

  Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.

- write_voltage:

  Logical. Also compute voltage maps. Default `FALSE`.

- output_dir:

  Optional character path. If provided, output files persist there.
  Default `NULL` uses a temporary directory.

- verbose:

  Logical. Print Circuitscape solver output. Default `FALSE`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with named layers. Always includes `"cumulative_current"`. If
`write_voltage = TRUE`, also includes `"voltage"`.

## References

Circuitscape user guide:
<https://docs.circuitscape.org/Circuitscape.jl/latest/usage/>

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
src <- rast(nrows = 10, ncols = 10, vals = 0)
src[1, 1] <- 1
gnd <- rast(nrows = 10, ncols = 10, vals = 0)
gnd[10, 10] <- 1
result <- cs_advanced(res, src, gnd)
plot(result)

# With voltage maps
result_v <- cs_advanced(res, src, gnd, write_voltage = TRUE)
plot(result_v[["voltage"]])
} # }
```
