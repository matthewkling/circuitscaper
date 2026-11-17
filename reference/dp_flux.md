# Cross-Era Net Flux

**\[experimental\]**

## Usage

``` r
dp_flux(
  resistance,
  present,
  future,
  source_threshold = 0.01,
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

- present, future:

  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)s
  or file paths on the same grid as `resistance`: present and future
  source strength, e.g. habitat suitability. NA counts as 0.

- source_threshold:

  Numeric. Cells with source strength below this are not sources (or
  sinks). Default `0.01`.

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

Attribute `"imbalance"` (see Details).

## Details

Maps the net flow of a range shift: present habitat injects current and
future habitat withdraws it, in fixed amounts, in one solve. The result
is signed, so it has direction.

The injection is \\b = p / \sum p - f / \sum f\\, with \\p\\ and \\f\\
the present and future source strengths: one unit enters at present
habitat and leaves at future habitat, wherever it has to travel. This is
the minimum-energy flow that turns the present distribution into the
future one. Only the cell totals matter, not which present cell pairs
with which future cell, so there is no dispersal limit; show results
beside a dispersal-limited map such as
[`dp_pathways()`](https://matthewkling.github.io/circuitscaper/reference/dp_pathways.md).
Where present and future habitat coincide, injection and withdrawal
cancel, so net flux mostly measures movement from lost to gained
habitat.

Withdrawals are fixed, not grounds: each future cell takes its share
however far away it is. (With grounds, as in
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md),
current drains into the nearest future habitat instead.)

Current can't cross NA cells, so the flow must balance within each group
of connected cells (component). Within a component holding present share
\\P_c\\ and future share \\F_c\\ of the totals, both are scaled to
\\(P_c + F_c)/2\\; components with no present or no future habitat carry
no flow. The share that would have had to move between components,
\\\sum_c \|P_c - F_c\| / 2\\, is returned as the `"imbalance"`
attribute, with a warning if it exceeds 1%.

## See also

[`dp_pathways()`](https://matthewkling.github.io/circuitscaper/reference/dp_pathways.md),
[`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available()
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
present <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
future <- terra::flip(present, "horizontal")
result <- dp_flux(resistance, present, future)
terra::plot(result)
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
