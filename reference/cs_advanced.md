# Advanced Circuitscape Analysis

Solve a single circuit with user-specified source and ground layers.

## Usage

``` r
cs_advanced(
  resistance,
  source,
  ground,
  resistance_is = "resistances",
  ground_is = "resistances",
  use_unit_currents = FALSE,
  use_direct_grounds = FALSE,
  short_circuit = NULL,
  source_ground_conflict = "keepall",
  four_neighbors = FALSE,
  avg_resistances = FALSE,
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

- source:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Source current strengths (amps per cell). Cells with
  value 0 or NA are not sources.

- ground:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Ground node values. Interpretation depends on
  `ground_is`: resistances to ground (default) or conductances to
  ground. Cells with value 0 or NA are not grounds.

- resistance_is:

  Character. Whether the resistance surface represents `"resistances"`
  (default) or `"conductances"`.

- ground_is:

  Character. Whether the ground raster values represent `"resistances"`
  (default) or `"conductances"` to ground.

- use_unit_currents:

  Logical. If `TRUE`, all current sources are set to 1 amp regardless of
  the values in the source raster. Default `FALSE`.

- use_direct_grounds:

  Logical. If `TRUE`, all ground nodes are tied directly to ground (zero
  resistance), regardless of the values in the ground raster. Default
  `FALSE`.

- short_circuit:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path. Raster identifying short-circuit regions (aka polygons).
  Cells sharing the same positive integer value are treated as
  short-circuit regions with zero resistance between them. Default
  `NULL` (no short-circuit regions).

- source_ground_conflict:

  Character. How to resolve cells that appear in both the source and
  ground rasters: `"keepall"` (default, keep both), `"rmvsrc"` (remove
  source), `"rmvgnd"` (remove ground), or `"rmvall"` (remove both).

- four_neighbors:

  Logical. Use 4-neighbor (rook) connectivity instead of 8-neighbor
  (queen). Default `FALSE`.

- avg_resistances:

  Logical. When using 8-neighbor connectivity, compute the resistance of
  diagonal connections as the average of the two cells rather than their
  sum. Default `FALSE` (Circuitscape default). Ignored when
  `four_neighbors = TRUE`.

- solver:

  Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.

- output_dir:

  Optional character path. If provided, output files persist there.
  Default `NULL` uses a temporary directory.

- verbose:

  Logical. Print Circuitscape solver output. Default `FALSE`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with the following layers:

- current:

  Current density at each cell.

- voltage:

  Voltage at each cell. Voltage is analogous to movement probability and
  decreases with distance from sources.

## Details

Unlike the other Circuitscape modes, advanced mode does not iterate over
focal nodes. Instead, the user provides explicit source current and
ground conductance rasters, and a single circuit is solved. This gives
full control over the current injection pattern and is useful for
modeling specific scenarios such as directional movement between a
defined source area and destination.

## References

McRae, B.H. (2006). Isolation by resistance. *Evolution*, 60(8),
1551–1561.
[doi:10.1111/j.1558-5646.2006.tb00500.x](https://doi.org/10.1111/j.1558-5646.2006.tb00500.x)

Circuitscape.jl: <https://docs.circuitscape.org/Circuitscape.jl/latest/>

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md),
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)

## Examples

``` r
if (FALSE) { # circuitscaper:::julia_check()
library(terra)
res <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
origin <- rast(system.file("extdata/source.tif", package = "circuitscaper"))
dest <- rast(system.file("extdata/ground.tif", package = "circuitscaper"))
result <- cs_advanced(res, origin, dest, ground_is = "conductances")
plot(result)
}
```
