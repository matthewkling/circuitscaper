# Accessibility of Targets From Each Cell

**\[experimental\]**

## Usage

``` r
dp_accessibility(
  resistance,
  radius,
  source_strength = NULL,
  destination = NULL,
  site_radius = 2,
  source_threshold = 0.01,
  radius_units = c("pixels", "km"),
  resistance_is = "resistances",
  reference_resistance = 1,
  normalize = TRUE,
  n_draws = 64,
  seed = NULL,
  se = FALSE,
  contact = FALSE,
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
  or file path on the same grid: target strength, e.g. habitat
  suitability. If `NULL` (default), the conductance surface is used, as
  in
  [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
  With a `destination`, this is the origin strength: the targets of the
  `destination_` layers.

- destination:

  Optional
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path on the same grid: destination strength, the targets of
  the `origin_` layers. Default `NULL`: one set of targets.

- site_radius:

  Number. The radius of the site each cell stands for (see "Sites"), in
  pixels, whatever `radius_units`. `0` is the cell alone. Default `2`.

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

- reference_resistance:

  Positive number. The resistance of the continuous habitat that
  `accessible_area` compares with, in the units of the input's
  resistance (also when `resistance_is = "conductances"`). Default `1`.

- normalize:

  Logical. Also return `normalized_conductance` (see "Method"). Default
  `TRUE`.

- n_draws:

  Integer. Number of draws (solves). Default `64`.

- seed:

  Integer or `NULL`. Seed for the random draws. If `NULL` (default), one
  is drawn from R's random number generator, so
  [`set.seed()`](https://rdrr.io/r/base/Random.html) also makes runs
  reproducible. The seed used is returned as the `"seed"` attribute.

- se:

  Logical. Also return each estimated layer's per-cell standard error,
  as layers with an `_se` suffix. Default `FALSE`.

- contact:

  Logical. Also return each cell's contact conductance, the conductance
  of its own links in parallel, as the `contact` layer (see "Sites").
  Default `FALSE`.

- progress:

  Logical. Report progress through the 'progressr' package (see
  "Progress" in
  [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)).
  Default `TRUE`; it shows only when a 'progressr' handler is active.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with layers `accessible_area` (unless `radius` is `Inf`), `target_area`
and `conductance`; with `normalize`, `normalized_conductance`; and with
`se`, an `_se` layer for each but `target_area`, which is exact. With a
`destination`, this set of layers twice, prefixed `origin_` and
`destination_`. With `contact`, a last layer `contact`. Cells off the
circuit are NA, as is `normalized_conductance` where a cell has no
targets. Attributes: `"area_units"` (`"km2"` or `"cells"`),
`"relative_se"` (each estimated layer's median relative standard error
over the cells with targets) and `"seed"`.

## Details

Maps how much of its targets each cell can reach, as area: the habitat
within `radius` (`source_strength`), counted by how easily it is reached
across the resistance surface; or, with a `destination`, the same
between two distributions in both directions. Where
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
and
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
map where movement passes, this maps how connected each place is. Every
cell gets a value, not only habitat, so it also shows how connected a
site would be there.

A cell's targets are the cells of its connected component within
`radius` and beyond its own site (see "Sites"), weighted by target
strength \\t\\. Three layers describe them:

- `accessible_area`:

  The targets in reach, counted by how easily they are reached:
  \\\mathrm{target\\area}\_i \\ C_i / C^\*\\, where \\C_i\\ is
  `conductance` and \\C^\*\\ is the conductance a site would have in
  continuous habitat (every cell a target, of resistance
  `reference_resistance`) at the same `radius` and `site_radius`.
  Targets as easy to reach as in continuous habitat count in full, and
  harder ones proportionally less; targets close to the site, or through
  resistance below the reference, can count for more. It responds to the
  amount of targets, their arrangement and the resistance surface
  together.

- `target_area`:

  The targets in reach as area, each cell's area weighted by its target
  strength: \\\sum\_{j \notin S_i} t_j a_j k(d\_{ij})\\, with \\S_i\\
  the cell's site, \\a_j\\ the cell's area and \\k\\ 1 within `radius`
  and 0 otherwise. For a 0-1 suitability it is the area of suitable
  habitat in reach; for strengths above 1 it is an area-equivalent, and
  can exceed the area in reach. It is exact, and ignores resistance.

- `conductance`:

  The effective conductance from the site to its targets as a set: one
  over the effective resistance when one unit of current leaves the site
  and is withdrawn across its targets in proportion to their strength.
  Many targets in reach act like parallel paths and raise it. Its
  inverse is the injection of
  [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
  with the one site as the origin. It doesn't respond to how much target
  there is: thinning every target to a tenth of its strength leaves it
  unchanged, which is what `accessible_area` adds.

Areas are in square kilometres where the grid's coordinate reference
system gives cell areas (on lon/lat grids, per row, on a sphere), and in
cells otherwise; the `"area_units"` attribute says which. Cells without
targets in reach (none within `radius` and beyond their site, in the
same component) score 0 on all three layers. These include cells of
pieces of the circuit not much wider than a site, such as small islands,
whose site holds the whole piece.

With a `destination`, each cell is scored in both directions, with
`origin_` and `destination_` prefixes on the layers. The `origin_`
layers take the cell as an origin, with the destination (`destination`)
as its targets: how well could movement from here reach the destination?
The `destination_` layers take the cell as a destination, with the
origin (`source_strength`) as its targets: how reachable is this place
from the origin? For present and future habitat, the first asks which
populations can track their habitat, the second which future habitat can
be colonised. Effective resistance is symmetric, so the two differ only
in their targets.

### Sites

Each cell stands for a site: the cells within `site_radius` pixels of it
(2 by default), across which the current is spread evenly. Targets are
sites too, so conductances are between the sites around cells. A site is
never its own target: a cell's targets are the habitat beyond its site,
so `radius` must reach beyond the site.

Sites correct for the grid. On a grid, the effective resistance from a
single cell grows only with the log of distance, so most of it is in the
first few rings of links around the cell. A single cell's value is then
dominated by its own contact resistance, the resistance of its own links
in parallel, and maps the cell's own resistance more than its place in
the landscape. A site a couple of cells in radius keeps that local term
from dominating, as Circuitscape's focal regions do. Because the problem
is the grid's, `site_radius` is in pixels whatever `radius_units`, and
is not the dispersal scale: that is `radius`.

Values depend on the site, so compare runs at the same site. On grids of
different resolution, the same number of pixels is a different site
(between 2 km and 0.5 km grids, median accessible area shifted by about
10%, and more in core habitat); to compare resolutions, scale
`site_radius` to keep the same ground distance.

With `site_radius = 0`, each site is its single cell, and its own
resistance is part of its value: the reading for a single point of
interest. With `contact = TRUE`, the result includes the `contact`
layer, each cell's contact conductance (its own links in parallel,
exact), an upper bound on the single-cell `conductance`.

### The continuous-habitat reference

\\C^\*\\ is solved exactly, once per kernel, on a uniform grid wide
enough that its edges don't matter, and is inversely proportional to
`reference_resistance`: set that to the resistance of good habitat. On
lon/lat grids with `radius_units = "km"`, the kernel varies by row, and
so does \\C^\*\\; rows within reach of the top or bottom of the grid use
the nearest row whose kernel fits, so that there, as at other edges, the
grid's edge lowers accessible area rather than the reference. With
`radius = Inf`, continuous habitat has no finite reference, and the
result has no `accessible_area` layer.

A larger `radius` raises `target_area` everywhere and `accessible_area`
almost everywhere, but not at every cell: the current is withdrawn from
the targets in fixed proportions, so where widening the radius adds
mostly hard-to-reach targets, it lowers the conductance to all of them,
and accessible area can fall.

### Method

Each draw injects a random-sign dipole across every link of the circuit,
scaled by the square root of the link's conductance, and solves the
circuit once. For the solution \\y\\, \\(y_i - y_j)^2\\ is then an
unbiased estimate of the effective resistance between \\i\\ and \\j\\
for every pair at once, and the resistance to the targets comes from
sums of \\y\\ over each cell's targets, after averaging \\y\\ over each
site. Its mean over draws estimates the resistance without bias;
`conductance` and `accessible_area` invert it, corrected for the bias of
inverting a noisy estimate. `target_area` and all window sums use
per-row running sums, at a cost linear in the radius.

Flow potential has no direct analogue here. With `normalize`, the same
draws on the uniform circuit (conductance 1 on the same cells, with the
same targets) give the conductance for geometry alone, and
`normalized_conductance` divides by it: the conductance of a uniform
landscape of the same shape that would give the same value, in the units
of the input's conductance. A value of 0.5 means the cell is as
connected as it would be if every cell had resistance 2. Below the
landscape's typical conductance, the cell is isolated by its
resistances; above, by geometry (distance, edges, few targets) more than
by resistance. Unlike `accessible_area`, it compares each cell with its
own geometry, so it doesn't respond to the amount of targets either.

### Accuracy

Each draw's resistance estimate is a squared Gaussian-like quantity, so
the relative standard error of `conductance` and `accessible_area` is
about \\\sqrt{2 / \mathrm{n\\draws}}\\ at any grid size: about 18% at
the default 64 draws, and 10% at 200. Both circuits see the same draws,
so on landscapes of modest contrast the noise of
`normalized_conductance` largely cancels, but where resistance varies by
orders of magnitude it doesn't. With `se = TRUE`, the result includes
each estimated layer's per-cell standard error; the `"relative_se"`
attribute gives each estimated layer's median relative standard error
either way.

Reproducibility, performance and progress are as for
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md):
one factorization (two with `normalize`), then about `n_draws` solves,
plus a small factorization and one solve per kernel for the reference.

## See also

[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
result <- dp_accessibility(resistance, radius = 15, seed = 1)
terra::plot(result)
attr(result, "area_units")
attr(result, "relative_se")

# Between two distributions, in both directions
origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
between <- dp_accessibility(resistance, radius = 45, source_strength = origin,
                            destination = destination, normalize = FALSE, seed = 1)
terra::plot(between)
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
