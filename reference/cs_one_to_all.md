# One-to-All Circuitscape Analysis

For each focal node in turn, inject current at that node and ground all
other focal nodes simultaneously.

## Usage

``` r
cs_one_to_all(
  resistance,
  locations,
  resistance_is = "resistances",
  four_neighbors = FALSE,
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

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with the following layers:

- cumulative_current:

  Current flow summed across all iterations.

- current\_*N*:

  Per-node current map for focal node *N*, where *N* is the integer node
  ID from the `locations` raster. One layer per focal node.

## Details

One-to-all mode iterates over each focal node. In each iteration, the
focal node is injected with 1 amp of current and all remaining focal
nodes are simultaneously connected to ground. This produces a current
map showing how current spreads from that node through the landscape to
reach the others.

This mode is useful for mapping how well each site is connected to the
rest of the focal node network, emphasizing current dispersal from each
source. The cumulative map sums across all iterations and highlights
cells that are important for connectivity across the full set of nodes.

## References

Circuitscape user guide:
<https://docs.circuitscape.org/Circuitscape.jl/latest/usage/>

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md),
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
coords <- matrix(c(-140, 70, -60, 70, -100, 30), ncol = 2, byrow = TRUE)
result <- cs_one_to_all(res, coords)
plot(result)
} # }
```
