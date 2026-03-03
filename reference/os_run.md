# Run Omniscape Moving-Window Connectivity Analysis

Performs an Omniscape analysis, computing omnidirectional landscape
connectivity using a moving window approach based on circuit theory.

## Usage

``` r
os_run(
  resistance,
  radius,
  source_strength = NULL,
  block_size = 1L,
  source_threshold = 0,
  resistance_is = "resistances",
  calc_normalized_current = TRUE,
  calc_flow_potential = TRUE,
  condition = NULL,
  condition_type = NULL,
  parallelize = FALSE,
  julia_threads = 2L,
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

- radius:

  Numeric. Moving window radius in pixels.

- source_strength:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Source strength weights. If `NULL` (default), all
  non-nodata pixels are treated as sources with equal weight.

- block_size:

  Integer. Aggregation block size for source points. Default `1` (no
  aggregation). Increasing this significantly speeds computation.

- source_threshold:

  Numeric. Minimum source strength to include a pixel. Default `0`.

- resistance_is:

  Character. Whether the resistance surface represents `"resistances"`
  (default) or `"conductances"`.

- calc_normalized_current:

  Logical. Compute normalized current flow. Default `TRUE`.

- calc_flow_potential:

  Logical. Compute flow potential. Default `TRUE`.

- condition:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Conditional layer for targeted connectivity analysis.

- condition_type:

  Character. Determines how the condition layer is used. Only relevant
  if `condition` is provided. See the Omniscape documentation for
  options.

- parallelize:

  Logical. Use Julia multithreading. Default `FALSE`. Julia's thread
  count is fixed at startup. If Julia was already initialized without
  enough threads, a warning is issued. To avoid this, call
  [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  with the `threads` argument at the start of your session.

- julia_threads:

  Integer. Number of Julia threads if `parallelize = TRUE`. Default `2`.
  Ignored if Julia is already running with fewer threads.

- solver:

  Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.

- output_dir:

  Optional character path. If provided, output files persist there.
  Default `NULL` uses a temporary directory.

- verbose:

  Logical. Print Omniscape output. Default `FALSE`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with named layers. Possible layers depending on options:

- cumulative_current:

  Cumulative current flow.

- flow_potential:

  Flow potential (if `calc_flow_potential = TRUE`).

- normalized_current:

  Normalized current flow (if `calc_normalized_current = TRUE`).

## References

Omniscape documentation:
<https://docs.circuitscape.org/Omniscape.jl/latest/>

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
res <- rast(nrows = 50, ncols = 50, vals = runif(2500, 1, 10))
result <- os_run(res, radius = 10)
plot(result)
plot(result[["normalized_current"]])
} # }
```
