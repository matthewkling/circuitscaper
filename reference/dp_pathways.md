# Cross-Era Gross Pathways From Random Dipoles

**\[experimental\]**

## Usage

``` r
dp_pathways(
  resistance,
  present,
  future,
  radius,
  source_threshold = 0.01,
  radius_units = c("pixels", "km"),
  resistance_is = "resistances",
  normalize = TRUE,
  n_draws = 32,
  n_dipoles = 1e+05,
  seed = NULL
)
```

## Arguments

- resistance:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path: the resistance (or conductance) surface. Or a circuit
  from
  [`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md),
  to reuse its factorization.

- present, future:

  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)s
  or file paths on the same grid as `resistance`: present and future
  source strength, e.g. habitat suitability. NA counts as 0.

- radius:

  Numeric. The dispersal radius: pairs of cells are counted if their
  centres are at most this far apart. In pixels by default (see
  `radius_units`). `Inf` counts all pairs.

- source_threshold:

  Numeric. Cells with source strength below this are not sources.
  Default `0.01`.

- radius_units:

  Character. `"pixels"` (default): the radius counts cells, so the
  kernel is the cells with \\dr^2 + dc^2 \le\\ `radius`\\^2\\, as in
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md).
  `"km"`: great-circle distance between cell centres on lon/lat grids
  (the kernel narrows in degrees of longitude towards the poles), or
  distance in the coordinate reference system's units, converted to km,
  on projected grids.

- resistance_is:

  Character. Whether `resistance` holds `"resistances"` (default) or
  `"conductances"`. Ignored for a circuit.

- normalize:

  Logical. Also compute flow potential (the same dipoles on the uniform
  circuit) and normalized current. Default `TRUE`.

- n_draws:

  Integer. Number of draws (solves). Default `32`.

- n_dipoles:

  Integer. Number of dipoles per draw. Default `1e5`.

- seed:

  Integer or `NULL`. Seed for the random draws. If `NULL` (default), one
  is drawn from R's random number generator, so
  [`set.seed()`](https://rdrr.io/r/base/Random.html) also makes runs
  reproducible. The seed used is returned as the `"seed"` attribute.

## Value

As for
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
The `"halves"` diagnostic is over cells that are present or future
sources.

## Details

Maps the pathways that connect present habitat to future habitat within
dispersal reach: random-sign dipoles with one end in present habitat and
the other in future habitat. Magnitude only, without direction.

As
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
with pairs \\(i, j)\\ weighted by \\p_i f_j k(d\_{ij})\\: \\i\\ in
present habitat, \\j\\ in future habitat, within `radius` of each other.
The pairing is one-way, but the squared current of a pair is the same in
both directions, so random signs are valid. Stable habitat (suitable in
both eras) takes part at both ends, unlike in
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md).
See
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
for the estimator, accuracy, reproducibility and performance.

## See also

[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available()
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
present <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
future <- terra::flip(present, "horizontal")
result <- dp_pathways(resistance, present, future, radius = 20, seed = 1)
terra::plot(result)
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
