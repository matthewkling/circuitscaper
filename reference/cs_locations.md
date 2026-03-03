# Create a Focal Node Raster from Coordinates

Convert a set of point coordinates into a focal node raster suitable for
use with
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
and
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md).
Each point is snapped to the nearest cell of the resistance raster and
assigned a sequential integer ID.

## Usage

``` r
cs_locations(coords, resistance)
```

## Arguments

- coords:

  A two-column matrix or data.frame of x and y coordinates. Each row
  represents one focal node. IDs are assigned sequentially (1, 2, 3,
  ...) based on row order.

- resistance:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  used as a template for extent, resolution, and CRS. The output raster
  will match this exactly.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with 0 background and positive integer IDs at the cells nearest each
coordinate. This can be passed directly to the `locations` argument of
any `cs_*` function.

## Details

Coordinates are snapped to the nearest raster cell center using
[`terra::cellFromXY()`](https://rspatial.github.io/terra/reference/xyCellFrom.html).
If two points snap to the same cell, an error is raised. Points that
fall outside the raster extent also produce an error.

This function is called internally when you pass coordinates directly to
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
or
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md).
Use it explicitly if you want to inspect or modify the focal node raster
before running an analysis.

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))

coords <- matrix(c(-140, 70,
                    -100, 30,
                     -60, 50), ncol = 2, byrow = TRUE)
locs <- cs_locations(coords, res)
plot(locs)

# Equivalent to passing coords directly:
result <- cs_pairwise(res, coords)
} # }
```
