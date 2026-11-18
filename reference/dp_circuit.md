# Prepare a Circuit for the Dipole Methods

**\[experimental\]**

## Usage

``` r
dp_circuit(resistance, resistance_is = "resistances", flow_potential = TRUE)
```

## Arguments

- resistance:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path: the resistance (or conductance) surface.

- resistance_is:

  Character. Whether `resistance` holds `"resistances"` (default) or
  `"conductances"`.

- flow_potential:

  Logical. Also factor the uniform circuit (the same cells with
  conductance 1) that flow potential and normalized current use. Default
  `TRUE`. If `FALSE`, it is built when first needed.

## Value

A `dp_circuit` object.

## Details

Builds and factors the circuit for a resistance surface once, so that
several dipole-method runs on the same surface (different radii, source
strengths, seeds or methods) can reuse it. Pass the result as the
`resistance` argument of
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
[`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md),
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
or
[`dp_pathways()`](https://matthewkling.github.io/circuitscaper/reference/dp_pathways.md).

The circuit is Circuitscape's default raster graph: every non-NA cell is
a node, joined to its 8 neighbours by links of conductance \\(c_u +
c_v)/2\\, divided by \\\sqrt{2}\\ on diagonals. Cells with zero
conductance (infinite resistance) are left out. A tiny conductance to
ground (\\10^{-12}\\ per cell) keeps the circuit solvable; the dipole
methods inject balanced currents, so it carries essentially no current.
Groups of cells with no links between them (separated by NA cells) are
separate circuits, and no current passes between them.

The factorization lives in the Julia session. If Julia is restarted
(e.g., by
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
with more threads, or after a crash), the circuit is rebuilt
automatically the next time it is used.

## See also

[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
circuit <- dp_circuit(resistance)
circuit
a <- dp_omni(circuit, radius = 10)
b <- dp_omni(circuit, radius = 20)
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
