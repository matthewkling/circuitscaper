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
  r_cutoff = Inf,
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
  or file path. The resistance (or conductance) surface. Higher values
  represent greater resistance to movement.

- radius:

  Numeric. Moving window radius in pixels. This determines the maximum
  distance over which connectivity is evaluated from each source pixel.

- source_strength:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Source strength weights, often derived from habitat
  quality or suitability, where higher values indicate stronger sources
  of movement. If `NULL` (default), source strength is set to the
  inverse of resistance (i.e., all non-nodata pixels become sources,
  weighted by conductance). Use `r_cutoff` to exclude high-resistance
  cells from acting as sources in that case.

- block_size:

  Integer. Aggregation block size for source points. Default `1` (no
  aggregation). A `block_size` of e.g. 3 coarsens the source grid into
  3x3 blocks, reducing the number of solves (and thus computation time)
  substantially with typically negligible effects on results.

- source_threshold:

  Numeric. Minimum source strength to include a pixel. Default `0`.

- r_cutoff:

  Numeric. Maximum resistance value for a cell to be included as a
  source when `source_strength = NULL`. Cells with resistance above this
  value are excluded as sources. Default `Inf` (no cutoff). Only
  relevant when `source_strength` is not provided.

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

  Character. How the condition layer filters connectivity: `"within"`
  (connectivity only between source and target cells whose condition
  values fall within a specified range) or `"equal"` (connectivity only
  between cells with equal condition values, evaluated pairwise). Only
  relevant if `condition` is provided. Note: `"within"` currently uses
  Omniscape's default unbounded range (`-Inf` to `Inf`), which
  effectively includes all cells. Finer control over range bounds is
  planned for a future version.

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
with the following layers (depending on options):

- cumulative_current:

  Raw cumulative current flow. Always present. Higher values indicate
  cells that carry more current across all moving-window iterations.

- flow_potential:

  Expected current under homogeneous resistance (if
  `calc_flow_potential = TRUE`). Reflects the spatial configuration of
  sources independently of landscape resistance.

- normalized_current:

  Cumulative current divided by flow potential (if
  `calc_normalized_current = TRUE`). Values greater than 1 indicate
  cells where connectivity is higher than expected given the source
  geometry; values less than 1 indicate relative barriers. This is
  typically the most informative layer for identifying corridors and
  pinch points.

## References

Landau, V.A., Shah, V.B., Anantharaman, R. & Hall, K.R. (2021).
Omniscape.jl: Software to compute omnidirectional landscape
connectivity. *Journal of Open Source Software*, 6(57), 2829.
[doi:10.21105/joss.02829](https://doi.org/10.21105/joss.02829)

Omniscape.jl: <https://docs.circuitscape.org/Omniscape.jl/latest/>

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available()
library(terra)
res <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
result <- os_run(res, radius = 20)
plot(result)
}
```
