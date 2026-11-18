# Directional and Undirected Flow Between Two Distributions

**\[experimental\]**

## Usage

``` r
dp_directionality(
  resistance,
  origin,
  destination,
  radius = Inf,
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

- origin, destination:

  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)s
  or file paths on the same grid as `resistance`: origin and destination
  strength, e.g. habitat suitability in two periods or seasons. NA
  counts as 0.

- radius:

  Numeric. The dispersal radius: origin and destination cells are paired
  if their centres are at most this far apart. In pixels by default (see
  `radius_units`). Default `Inf`, no distance limit.

- source_threshold:

  Numeric. Cells with origin or destination strength below this are not
  origins or destinations. Default `0.01`.

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

  Logical. Also compute flow potential and normalized current for both
  maps (on the uniform circuit, conductance 1 on the same cells).
  Default `TRUE`.

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

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with layers:

- directionality:

  The ratio \\R\\ above, between 0 and 1.

- flux_current:

  The directional map's RMS current, as `dp_flux(cell_value = "rms")`'s
  `current`.

- flux_flow_potential, flux_normalized_current:

  (with `normalize`) As
  [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)'s
  `flow_potential` and `normalized_current`.

- flow_x, flow_y:

  Net flow through the cell towards the east and the north, as from
  [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md).

- omni_current:

  The undirected map's current, as `dp_omni(destination = )`'s
  `current`.

- omni_flow_potential, omni_normalized_current:

  (with `normalize`) As
  [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)'s
  `flow_potential` and `normalized_current`.

Attributes: `"halves"`, comparing the estimates from odd and even draws
on origin and destination cells, as in
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
for the undirected layers and `directionality`; `"seed"`; and
`"in_reach"`, as in
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md).

## Details

Maps movement between an origin and a destination distribution both ways
at once, from the same pairs of cells: the directional map of
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
where flows in opposite directions cancel, and the undirected map of
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
with a `destination`, where they don't. Their ratio, `directionality`,
shows where movement between the two distributions is one-way and where
it runs both ways.

Current flows along the circuit's links: the resistors joining each cell
to its 8 neighbours (see
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)).
Both maps sum over pairs of an origin cell \\i\\ and a destination cell
\\j\\, with weights \\o_i d_j k(d\_{ij})\\: \\o\\ and \\d\\ are origin
and destination strength, and \\k\\ is 1 for cells within `radius` of
each other (in the same component) and 0 otherwise. With \\W\\ the total
weight and \\I_e(i,j)\\ the current through link \\e\\ when one unit
flows from \\i\\ to \\j\\, the directional map is the pairs' weighted
mean current, \\F_e = \sum\_{i,j} o_i d_j k(d\_{ij}) I_e(i,j) / W\\, and
the undirected map their summed squared current, \\U_e = \sum\_{i,j} o_i
d_j k(d\_{ij}) I_e(i,j)^2\\.

Since \\U_e / W\\ is the pairs' weighted mean square current, the ratio
\$\$R_e = \frac{W F_e^2}{U_e} = 1 -
\frac{\mathrm{Var}(I_e)}{\mathrm{E}\[I_e^2\]}\$\$ is between 0 and 1.
Like an \\R^2\\, it is the share of the pairs' squared current that
their mean flow accounts for, and so the share of the power they
dissipate in the link: 1 where all pairs cross the link in the same
direction, and near 0 where their flows cancel. A cell's
`directionality` is the same ratio over the links that meet at it, \\W
\sum_e F_e^2 / \sum_e U_e\\: the links' \\R_e\\ averaged with weights
\\U_e\\.

The directional map is exact; the undirected map is estimated from
random dipoles centered on the pairs' mean, as in
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
with a `destination`: the draws estimate only the variance of the pairs'
currents, and the mean's exact squared current is added back. So
`directionality` never exceeds 1, and its noise, about \\R (1 - R)
\times 1.4 / \sqrt{\mathrm{n\\draws}}\\, vanishes where movement is
one-way. (Without centering, it would be about \\R \times 1.4 /
\sqrt{\mathrm{n\\draws}}\\, and largest there.) It is NA where the
undirected current is zero.

The layers are as from `dp_flux(cell_value = "rms")` and
`dp_omni(destination = )`, with the same arguments, but computed
together: one circuit, one set of pair weights, and one kernel.

## See also

[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
result <- dp_directionality(resistance, origin, destination, radius = 45,
                            normalize = FALSE, seed = 1)
terra::plot(result[[c("flux_current", "omni_current", "directionality")]])
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
