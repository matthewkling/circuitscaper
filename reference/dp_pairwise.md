# Pairwise Connectivity Among Focal Nodes From Random Dipoles

**\[experimental\]**

## Usage

``` r
dp_pairwise(
  resistance,
  locations,
  method = c("random", "exact"),
  resistance_is = "resistances",
  normalize = TRUE,
  n_draws = 32,
  seed = NULL,
  power = FALSE
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

- locations:

  The focal nodes: a two-column matrix or data frame of x and y
  coordinates (each snapped to the cell it falls in), or a
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path on the same grid as `resistance` with a positive integer
  ID at each focal node's cell and 0 or NA elsewhere. Each node is one
  cell; focal regions of several cells aren't supported.

- method:

  Character. `"random"` (default) for random dipoles, or `"exact"` for
  the exact sum from one solve per node.

- resistance_is:

  Character. Whether `resistance` holds `"resistances"` (default) or
  `"conductances"`. Ignored for a circuit.

- normalize:

  Logical. Also compute flow potential (the same pairs on the uniform
  circuit, conductance 1 on the same cells) and normalized current.
  Default `TRUE`.

- n_draws:

  Integer. Number of draws (solves) for `method = "random"`. Default
  `32`.

- seed:

  Integer or `NULL`. Seed for the random draws. If `NULL` (default), one
  is drawn from R's random number generator, so
  [`set.seed()`](https://rdrr.io/r/base/Random.html) also makes runs
  reproducible. The seed used is returned as the `"seed"` attribute.

- power:

  Logical. Also map the power dissipated (see "Power" in
  [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)),
  and with `normalize`, normalized power. Default `FALSE`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with layers `current`; with `normalize`, `flow_potential` and
`normalized_current`; with `power`, `power`; and with both,
`normalized_power`, as in
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
With `method = "exact"`, `power` sums to the pairs' total effective
resistance, the power each pair's unit current dissipates. Attributes:
`"n_pairs"`, the number of pairs counted; for `method = "random"`, also
`"halves"` (see
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md))
and `"seed"`.

## Details

Maps connectivity among every pair of a set of focal nodes, the
squared-current analogue of
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)'s
cumulative current map, at a cost that doesn't grow with the number of
nodes.

Current flows along the circuit's links: the resistors joining each cell
to its 8 neighbours (see
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)).
For each link \\e\\, the target is \\\sum\_{i\<j} I_e(i,j)^2\\, over
unordered pairs of focal nodes, where \\I_e(i,j)\\ is the current
through \\e\\ when one unit flows from node \\i\\ to node \\j\\. A
cell's value is \\\sqrt{\frac{1}{2}\sum\_{e \ni \mathrm{cell}}
(\cdot)}\\ over its links, as in
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
Pairs are counted only within groups of cells connected to each other
(no current passes across NA cells).

With `method = "random"`, each draw injects \\\sum\_{i\<j}
\xi\_{ij}(e_i - e_j)\\, every pair weighted by an independent standard
normal \\\xi\_{ij}\\, and solves the circuit once; the mean squared
current over draws estimates the target without bias. Its time hardly
depends on the number of nodes (building each injection takes
\\O(N^2)\\, which is small next to a solve until \\N\\ is in the
thousands). With `method = "exact"`, one solve per node gives the exact
target, using \\\sum\_{i\<j}(y_i - y_j)^2 = N\sum_i y_i^2 - (\sum_i
y_i)^2\\ for each link, with \\y_i\\ its current when node \\i\\ is the
source.

Current enters and leaves the circuit at the focal nodes, as in
Circuitscape, but cell values count only the current on links.
Circuitscape's cell maps also add the current injected or withdrawn at a
cell before halving, so that a focal node's value includes the full unit
it sends or receives; here, the current arriving from outside the
circuit isn't counted, so focal nodes' cells read lower than in
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md).
Other cells, where current both enters and leaves along links, are
unaffected.

Flow potential is the same quantity on the uniform circuit (with the
same draws, for `method = "random"`), and normalized current is current
divided by it, as in
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
Normalizing takes a second factorization and, for `method = "exact"`, a
second set of solves.

Reproducibility is as for
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).

## See also

[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
set.seed(1)
nodes <- terra::spatSample(resistance, 30, xy = TRUE)[, 1:2]
result <- dp_pairwise(resistance, nodes, seed = 1)
exact <- dp_pairwise(resistance, nodes, method = "exact")
terra::plot(c(result$normalized_current, exact$normalized_current))
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
