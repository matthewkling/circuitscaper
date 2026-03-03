# All-to-One Circuitscape Analysis

For each focal node in turn, inject current at all other focal nodes and
ground that single node.

## Usage

``` r
cs_all_to_one(
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

  Focal node locations, provided as any of:

  - A
    [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
    with positive integer IDs identifying each node. Cells with value 0
    or `NA` are not treated as focal nodes.

  - A file path to a raster file (e.g., `.tif`, `.asc`).

  - A two-column matrix or data.frame of x/y coordinates. Each row
    becomes a focal node, auto-assigned IDs 1, 2, 3, ... in row order.
    Coordinates are snapped to the nearest cell of the `resistance`
    raster (which must be a SpatRaster in this case). See
    [`cs_locations()`](https://matthewkling.github.io/circuitscaper/reference/cs_locations.md).

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

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with the following layers:

- cumulative_current:

  Current flow summed across all iterations.

- curmap\_*N*:

  Per-node current map for focal node *N*, where *N* is the integer node
  ID from the `locations` raster. One layer per focal node.

## Details

All-to-one mode iterates over each focal node. In each iteration, all
other focal nodes are injected with 1 amp of current each, and the focal
node is connected to ground. This produces a current map showing how
current converges on that node from across the landscape.

This mode is useful for identifying the most accessible or reachable
sites in the network, emphasizing current flow toward each ground node.
The cumulative map sums across all iterations and highlights cells that
are important for connectivity across the full set of nodes.

## References

Circuitscape user guide:
<https://docs.circuitscape.org/Circuitscape.jl/latest/usage/>

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
locs <- rast(nrows = 10, ncols = 10, vals = 0)
locs[1, 1] <- 1; locs[1, 10] <- 2; locs[10, 5] <- 3
result <- cs_all_to_one(res, locs)
plot(result)
} # }
```
