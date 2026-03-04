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
  avg_resistances = FALSE,
  short_circuit = NULL,
  included_pairs = NULL,
  write_voltage = FALSE,
  cumulative_only = TRUE,
  source_strengths = NULL,
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

  Focal node locations, provided as any of:

  - A
    [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
    with positive integer IDs identifying each node. Cells with value 0
    or `NA` are not treated as focal nodes.

  - A file path to a raster file (e.g., `.tif`, `.asc`).

  - A two-column matrix or data.frame of x/y coordinates. Each row
    becomes a focal node, auto-assigned IDs 1, 2, 3, ... in row order.
    Coordinates are snapped to the nearest cell of the `resistance`
    raster. See
    [`cs_locations()`](https://matthewkling.github.io/circuitscaper/reference/cs_locations.md).

- resistance_is:

  Character. Whether the resistance surface represents `"resistances"`
  (default) or `"conductances"`.

- four_neighbors:

  Logical. Use 4-neighbor (rook) connectivity instead of 8-neighbor
  (queen). Default `FALSE`.

- avg_resistances:

  Logical. When using 8-neighbor connectivity, compute the resistance of
  diagonal connections as the average of the two cells rather than their
  sum. Default `FALSE` (Circuitscape default). Ignored when
  `four_neighbors = TRUE`.

- short_circuit:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Raster identifying short-circuit regions (aka polygons).
  Cells sharing the same positive integer value are treated as
  short-circuit regions with zero resistance between them. Default
  `NULL` (no short-circuit regions).

- included_pairs:

  Optional character file path. A text file specifying which pairs of
  focal nodes to include or exclude from analysis. See the Circuitscape
  documentation for the file format. Default `NULL` (all pairs).

- write_voltage:

  Logical. Write voltage maps. Default `FALSE`. When `TRUE`,
  per-iteration voltage layers (named `voltage_1`, `voltage_2`, ...) are
  included in the output raster.

- cumulative_only:

  Logical. If `TRUE` (default), only the cumulative current map is
  returned. If `FALSE`, per-iteration current layers (named `current_1`,
  `current_2`, ...) are also included. Use with caution for large
  numbers of focal nodes, as this can produce many layers.

- source_strengths:

  Optional. Variable current injection strengths for each focal node.
  Can be:

  - A numeric vector with one value per focal node (in the same order as
    the locations input). Node IDs are assigned 1, 2, 3, ... matching
    the order.

  - A character file path to a tab-delimited text file with two columns:
    node ID and strength in amps. Nodes not listed default to 1 amp.
    Default `NULL` (all nodes inject 1 amp).

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
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html).
  By default contains a single `cumulative_current` layer (current flow
  summed across all pairs). When `cumulative_only = FALSE`, additional
  per-pair layers are included (e.g., `current_1_2`, `current_1_3`).
  When `write_voltage = TRUE`, per-pair voltage layers are included
  (e.g., `voltage_1_2`, `voltage_1_3`).

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
coords <- matrix(c(-140, 70, -60, 70, -100, 30), ncol = 2, byrow = TRUE)
result <- cs_pairwise(res, coords)
plot(result$current_map)
result$resistance_matrix
} # }
```
