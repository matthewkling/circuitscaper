# Omnidirectional Connectivity From Random Dipoles

**\[experimental\]**

## Usage

``` r
dp_omni(
  resistance,
  radius,
  source_strength = NULL,
  destination = NULL,
  source_threshold = 0.01,
  radius_units = c("pixels", "km"),
  resistance_is = "resistances",
  normalize = TRUE,
  n_draws = 32,
  n_dipoles = 1e+05,
  seed = NULL,
  power = FALSE,
  progress = TRUE
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
  With a `destination`, this is the origin strength.

- destination:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path on the same grid: destination strength, e.g. habitat
  suitability in another period or season. If given, only pairs of an
  origin and a destination cell count. Default `NULL`: pairs of cells of
  one surface.

- source_threshold:

  Numeric. Cells with source (or destination) strength below this are
  not sources (or destinations). Default `0.01`.

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

- power:

  Logical. Also map the power dissipated (see "Power" in `dp_omni()`),
  and with `normalize`, normalized power. Default `FALSE`.

- progress:

  Logical. Report progress through the 'progressr' package (see
  "Progress" in `dp_omni()`). Default `TRUE`; it shows only when a
  'progressr' handler is active.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with layers `current`; with `normalize`, `flow_potential` and
`normalized_current`; with `power`, `power`; and with both,
`normalized_power`. Attributes: `"halves"`, a data frame comparing the
estimates from odd and even draws on source (and destination) cells
(Spearman's \\\rho\\ and the median relative difference), for `current`
and the normalized and power layers; and `"seed"`.

## Details

Maps omnidirectional connectivity among habitat, in the role of
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md),
with the random-dipole method: many random source-sink pairs superposed
on one factored circuit, which takes about `n_draws` solves whatever the
number of pairs.

With a `destination`, it maps connectivity between two distributions
instead: the routes linking origin cells (`source_strength`) to
destination cells within `radius`, for example present to future
habitat, breeding to wintering grounds, or foraging to roosting habitat.
The map is undirected: every pair counts whichever way it flows, so
swapping the two surfaces gives the same map. For the net flow from one
to the other, with its direction, see
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md).

Current flows along the circuit's links: the resistors joining each cell
to its 8 neighbours (see
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)).
For each link \\e\\, the method estimates \$\$T_e = \sum\_{i \ne j} w_i
w_j k(d\_{ij}) I_e(i,j)^2\$\$ over ordered pairs of cells, where \\w\\
is source strength, \\k\\ is 1 for cells within `radius` of each other
and 0 otherwise, and \\I_e(i,j)\\ is the current through \\e\\ when one
unit flows from \\i\\ to \\j\\ on the whole circuit. A cell's current
combines the links that meet at it, up to 8: \\\sqrt{\frac{1}{2}\sum\_{e
\ni \mathrm{cell}} T_e}\\, where the half is because each link is shared
by the two cells it joins. For a unit flow, a link's squared current is
the derivative of the pair's effective resistance with respect to that
link's resistance, so the map is the sensitivity of habitat-weighted
pairwise resistance to degrading each cell.

With a `destination`, the pair weights are \\o_i d_j k(d\_{ij})\\, with
\\o\\ the origin (`source_strength`) and \\d\\ the destination strength.
Since \\I_e(i,j)^2 = I_e(j,i)^2\\, only the unordered pairs matter, and
the map is the same whichever surface is the origin. A cell's pair with
itself carries no current. Cells in both distributions take part at both
ends, unlike in
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
where their flow cancels. With one surface, \\o = d = w\\.

With two surfaces, the pairs have a mean dipole, whose current (the
directional map of
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md))
is solved exactly. Each draw's dipoles are centered on it, so the draws
estimate only the variance of the pairs' currents, and the mean's exact
squared current is added back. The estimate is still unbiased, but where
the pairs' currents mostly agree in direction its noise is much smaller:
by a factor of about \\1 - R\\, with \\R\\ as in
[`dp_directionality()`](https://matthewkling.github.io/circuitscaper/reference/dp_directionality.md).
With one surface, the mean dipole is zero.

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

### Power

With `power = TRUE`, the result also maps the power dissipated, which
picks out choke points: places where current is forced through
resistance. A link's power is its squared current (summed over pairs, as
for `current`) times its resistance, \\1 / g_e\\. A cell's `power` is
half the sum over its links, so each link's power is shared between the
two cells it joins, and the cells sum to the circuit's total. It comes
from the same per-link sums as `current`, so it costs no extra solves,
and its estimate is unbiased with about twice the relative noise of
`current`.

This is not `current` squared times the cell's resistance. A link's
resistance depends on both cells it joins (with Circuitscape's averaged
conductances, it approaches twice the lower of the two resistances where
they differ widely), and diagonal links' resistance is \\\sqrt{2}\\
times larger. Squaring a current map and multiplying by resistance
overstates power on high-resistance cells next to low-resistance ones,
where choke points often are.

With `normalize`, `normalized_power` is power divided by the power of
the same pairs on the uniform circuit. Unlike normalized current, it has
the units of resistance (the uniform circuit's links have resistance 1),
so compare it within a surface rather than across surfaces in different
units.

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

### Progress

The dipole functions report progress through the 'progressr' package:
one step per factorization and, for each batch of draws, one for
sampling its dipoles and one per circuit solved (current, and with
`normalize`, flow potential), plus one per solve of the mean flow with a
`destination`. Draws are solved in batches of 8 to 32 (fewer on larger
grids), so at the default 32 draws most runs are one batch. Nothing is
shown unless a handler is active, e.g.
`progressr::with_progress(dp_omni(...))` or, in a 'shiny' app,
`progressr::withProgressShiny(dp_omni(...))`; see
[`progressr::handlers()`](https://progressr.futureverse.org/reference/handlers.html).
Reporting doesn't change the results. Set `progress = FALSE` to signal
nothing at all.

## See also

[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md),
[`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md),
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
result <- dp_omni(resistance, radius = 15, seed = 1)
terra::plot(result)
attr(result, "halves")

# Connectivity between two distributions
origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
between <- dp_omni(resistance, radius = 45, source_strength = origin,
                   destination = destination, seed = 1)
terra::plot(between)
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
