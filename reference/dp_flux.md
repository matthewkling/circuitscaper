# Directional Flow Between Two Distributions

**\[experimental\]**

## Usage

``` r
dp_flux(
  resistance,
  origin,
  destination,
  radius = Inf,
  source_threshold = 0.01,
  radius_units = c("pixels", "km"),
  resistance_is = "resistances",
  direction = TRUE
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

- direction:

  Logical. Also return the components of net flow. Default `TRUE`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with layers:

- current:

  Half the sum of absolute current over a cell's links, as in
  Circuitscape's current maps (without the injection term).

- flow_x, flow_y:

  (with `direction`) Net flow through the cell towards the east and the
  north, in grid directions: half the sum over the cell's links of the
  current along the link times its unit direction.

Attribute `"in_reach"`: the share of all origin–destination pair weight,
\\W / (\sum o \sum d)\\, that is within `radius` and in the same
component, and so carried by the map. A small share means most of the
origin has no destination within reach.

## Details

Maps the net flow from an origin distribution to a destination
distribution, with its direction, in one solve: for example from present
to future habitat, from breeding to wintering grounds, or from source
populations to restoration sites. Flows in opposite directions cancel,
so the map shows net movement. For movement between the two
distributions without direction, where every pair counts whichever way
it flows, see
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
with a `destination`.

The map is the signed sum over origin–destination pairs of cells within
`radius` of each other, \$\$F_e = \frac{1}{W} \sum\_{i,j} o_i\\ d_j\\
k(d\_{ij})\\ I_e(i,j),\$\$ where \\o\\ and \\d\\ are origin and
destination strength, \\k\\ is 1 for cells within `radius` of each other
and 0 otherwise, \\I_e(i,j)\\ is the current through link \\e\\ when one
unit flows from \\i\\ to \\j\\, and \\W = \sum\_{i,j} o_i d_j
k(d\_{ij})\\ makes the pair weights sum to one unit of flow. Pairs never
span groups of cells that NA cells separate (components), since no
current passes between them.

The sum is linear in the pairs' currents, so it takes a single solve, of
the injection \\b_i = (o_i\\ (Kd)\_i - d_i\\ (Ko)\_i) / W\\, where
\\(Kd)\_i\\ is the destination strength within reach of cell \\i\\ and
\\(Ko)\_i\\ the origin strength within reach of it. Each origin cell
sends flow in proportion to its strength and the destination strength
within its reach; each destination cell receives in proportion to its
strength and the origin strength within its reach. A cell's pair with
itself counts in \\W\\ but moves nothing, so where origin and
destination overlap, flow cancels.

With `radius = Inf` and one component, this is the injection \\b = o /
\sum o - d / \sum d\\: one unit enters at the origin and leaves at the
destination, wherever it has to travel. That is the minimum-energy flow
that turns the origin distribution into the destination one.

Withdrawals are fixed, not grounds: each destination cell takes its
share however electrically far away it is. (With grounds, as in
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md),
current drains into the nearest destination instead.)

Swapping `origin` and `destination` reverses the flow: the same
`current`, with `flow_x` and `flow_y` negated.

## See also

[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
result <- dp_flux(resistance, origin, destination)
terra::plot(result)

# Only pairs within 45 cells of each other
near <- dp_flux(resistance, origin, destination, radius = 45)
attr(near, "in_reach")
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
