# Omnidirectional Connectivity From Random Dipoles

Maps omnidirectional connectivity among habitat, in the role of
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md),
with the random-dipole method: many random source-sink pairs superposed
on one factored circuit, which takes about `n_draws` solves whatever the
number of pairs.

## Usage

``` r
dp_omni(
  resistance,
  radius,
  source_strength = NULL,
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

- radius:

  Numeric. The dispersal radius: pairs of cells are counted if their
  centres are at most this far apart. In pixels by default (see
  `radius_units`). `Inf` counts all pairs.

- source_strength:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path on the same grid: source strength, e.g. habitat
  suitability. If `NULL` (default), the conductance surface is used, as
  in
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md).

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

  Logical. Also compute flow potential and normalized current. Default
  `TRUE`.

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
with layers `current`, and with `normalize`, `flow_potential` and
`normalized_current`. Attributes: `"halves"`, a data frame comparing the
estimates from odd and even draws on source cells (Spearman's \\\rho\\
and the median relative difference), and `"seed"`.

## Details

For each link \\e\\ of the circuit (see
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)),
the method estimates \$\$T_e = \sum\_{i \ne j} w_i w_j k(d\_{ij})
I_e(i,j)^2\$\$ over ordered pairs of cells, where \\w\\ is source
strength, \\k\\ is 1 for cells within `radius` of each other and 0
otherwise, and \\I_e(i,j)\\ is the current through \\e\\ when one unit
flows from \\i\\ to \\j\\ on the whole circuit. A cell's current is
\\\sqrt{\frac{1}{2}\sum\_{e \ni \mathrm{cell}} T_e}\\. For a unit flow,
a link's squared current is the derivative of the pair's effective
resistance with respect to that link's resistance, so the map is the
sensitivity of habitat-weighted pairwise resistance to degrading each
cell.

Each draw injects `n_dipoles` unit dipoles, pairs drawn in proportion to
\\w_i w_j k(d\_{ij})\\, each with a random sign, and solves the circuit
once. The random signs make the cross terms between dipoles average out,
so the mean squared current over draws, scaled by \\S / M\\ (\\S\\ the
sum of pair weights, \\M\\ = `n_dipoles`), estimates \\T_e\\ without
bias. Values don't depend on `n_dipoles`, and runs with different
settings are comparable.

Pairs never span groups of cells that are separated by NA cells, since
no current can pass between them. Cells with source strength below
`source_threshold`, or NA, are not sources.

Flow potential is the same estimate on the uniform circuit (conductance
1 on the same cells) with the same dipoles, and normalized current is
current divided by flow potential: above 1 where current is channelled,
below 1 where it is impeded. Unlike
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md),
flow potential uses the same circuit shape as current, not a square box
per target.

The result differs from
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)'s
by design: squared rather than absolute current, and the whole circuit
rather than a window around each target. Current maps typically agree
closely (Spearman's \\\rho \approx\\ 0.95–0.99), normalized current less
so (\\\rho \approx\\ 0.85). No current is added at endpoints for the
injected current itself, unlike Circuitscape's cell maps.

### Accuracy

Each draw contributes noise with a relative standard deviation of about
1.4, so per-cell noise falls as \\1/\sqrt{\mathrm{n\\draws}}\\: in tests
at the default 32 draws, about 6–12% in current and 3–10% in normalized
current. More dipoles per draw help only until pairs are well covered
(about \\10^5\\). The `"halves"` attribute compares estimates from the
odd and even draws, an estimate of the noise of a run.

### Reproducibility

Results are determined by `seed`, the settings and the circuit: each
draw has its own random stream, so they don't depend on the number of
Julia threads (beyond the last bits of rounding, which can depend on the
linear algebra library's threading). Random streams can change between
Julia versions.

### Performance

The time is mostly the factorization (one, or two with `normalize`) and
the solves; it barely depends on `radius`. Draws are sampled and link
currents summed in parallel over Julia's threads; set the number with
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md).
To reuse factorizations across runs, pass a circuit from
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md).

## See also

[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md),
[`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md),
[`dp_pathways()`](https://matthewkling.github.io/circuitscaper/reference/dp_pathways.md),
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available()
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
result <- dp_omni(resistance, radius = 15, seed = 1)
terra::plot(result)
attr(result, "halves")
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
