# Isolation of Each Cell From Its Targets

**\[experimental\]**

## Usage

``` r
dp_isolation(
  resistance,
  radius,
  source_strength = NULL,
  destination = NULL,
  site_radius = NULL,
  source_threshold = 0.01,
  radius_units = c("pixels", "km"),
  resistance_is = "resistances",
  normalize = TRUE,
  n_draws = 64,
  seed = NULL,
  se = FALSE,
  accessibility = FALSE,
  reference_resistance = 1,
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

  Numeric or `NULL`. The radius of the site each cell stands for (see
  "Sites"), in `radius_units`. `0` is the cell alone. Default `NULL`: 2
  pixels, whatever `radius_units`.

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

  Integer. Number of draws (solves). Default `64`.

- seed:

  Integer or `NULL`. Seed for the random draws. If `NULL` (default), one
  is drawn from R's random number generator, so
  [`set.seed()`](https://rdrr.io/r/base/Random.html) also makes runs
  reproducible. The seed used is returned as the `"seed"` attribute.

- se:

  Logical. Also return each layer's per-cell standard error, as layers
  with an `_se` suffix. Default `FALSE`.

- accessibility:

  Logical. Also return the `target_area` and `accessible_area` layers
  (see "Accessibility"). Default `FALSE`.

- reference_resistance:

  Positive number. The resistance of the continuous habitat that
  `accessible_area` compares with, in the units of the input's
  resistance (also when `resistance_is = "conductances"`). Default `1`.

- contact:

  Logical. Also return each cell's contact resistance, the resistance of
  its own links in parallel, as the `contact` layer (see "Sites").
  Default `FALSE`.

- progress:

  Logical. Report progress through the 'progressr' package (see
  "Progress" in
  [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)).
  Default `TRUE`; it shows only when a 'progressr' handler is active.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with layers `resistance` and `mean_resistance`; with `normalize`,
`normalized_resistance` and `normalized_mean_resistance`; with
`accessibility`, `target_area` and `accessible_area`; and with `se`, an
`_se` layer for each but `target_area`, which is exact. With a
`destination`, this set of layers twice, prefixed `origin_` and
`destination_`. With `contact`, a last layer `contact`. Attributes:
`"relative_se"`, each layer's median relative standard error over the
cells with values; with `accessibility`, `"area_units"` (`"km2"` or
`"cells"`); and `"seed"`.

## Details

Maps how well connected each cell is to its targets, as effective
resistance: to the habitat within `radius` (`source_strength`), or, with
a `destination`, between the two distributions in both directions. Where
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
and
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
map where movement passes, this maps how isolated each place is. Every
cell with targets in reach gets a value, not only habitat, so it also
shows how connected a site would be there.

A cell's targets are the cells of its connected component within
`radius` and beyond its own site (see "Sites"; for single cells, the
other cells), each weighted by its share \\q_j\\ of the cell's target
strength in reach, \\A_i = \sum\_{j \notin S_i} t_j k(d\_{ij})\\, where
\\t\\ is the target strength, \\S_i\\ is the cell's site, and \\k\\ is 1
within `radius` and 0 otherwise. With \\R\_{ij}\\ the effective
resistance between the sites around cells \\i\\ and \\j\\ (see "Sites")
on the whole circuit, two layers summarise the targets:

- `resistance`:

  Resistance to the target distribution: the effective resistance when
  one unit of current leaves the site and is withdrawn across its
  targets in proportion to \\q\\. Many targets in reach act like
  parallel paths and lower it, so it measures how well the site is
  connected to its targets as a set. It is the injection of
  [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
  with the one site as the origin.

- `mean_resistance`:

  Mean effective resistance to the targets, \\\sum_j q_j R\_{ij}\\: the
  difficulty of reaching a typical target. It is at least `resistance`,
  by the spread of the targets among themselves, and the targets that
  are hardest to reach weigh most in it. With `site_radius = 0`, summed
  over cells with weights \\w_i A_i\\, it gives the total effective
  resistance over the pairs of
  [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).

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

Cells without targets in reach (none within `radius` and beyond their
site, in the same component) are NA. These include cells of pieces of
the circuit not much wider than a site, such as small islands, whose
site holds the whole piece.

### Sites

Each cell stands for a site: the cells within `site_radius` of it (2
pixels by default), across which the current is spread evenly. Targets
are sites too, so \\R\_{ij}\\ above is the effective resistance between
the sites around \\i\\ and \\j\\. A site is never its own target: a
cell's targets are the habitat beyond its site, as a single cell's are
the other cells, so `radius` must reach beyond `site_radius`. This
matters because on a grid, the effective resistance from a single cell
grows only with the log of distance, so most of it is in the first few
rings of links around the cell. A single cell's value is then dominated
by its own contact resistance, the resistance of its own links in
parallel, and maps the cell's own resistance more than its place in the
landscape. Spreading the current over a site keeps that local term from
dominating, as Circuitscape's focal regions do. Choose `site_radius` for
the area a population or site occupies; values depend on it, so compare
runs at the same site radius.

With `site_radius = 0`, each site is its single cell, and its own
resistance is part of its isolation: the reading for a single point of
interest. With `contact = TRUE`, the result includes the `contact`
layer, each cell's contact resistance (exact, not estimated), which is a
lower bound on the single-cell `resistance`. Subtracting it leaves the
resistance beyond the cell's own links, but the subtraction doesn't
remove any noise, so where contact is most of the value (high-resistance
cells), the remainder is very noisy.

### Accessibility

`resistance` responds to where the targets are, not to how much of them
there is: \\q\\ is a share, so thinning every target to a tenth of its
strength leaves it unchanged. With `accessibility = TRUE`, two layers
measure how much of the targets each cell can access, as area:

- `target_area`:

  The targets in reach as area, each cell's area weighted by its target
  strength: \\\sum\_{j \notin S_i} t_j a_j k(d\_{ij})\\, with \\a_j\\
  the cell's area. For a 0-1 suitability it is the area of suitable
  habitat in reach; for strengths above 1 it is an area-equivalent, and
  can exceed the area in reach. It is exact, and ignores resistance.

- `accessible_area`:

  `target_area` counted by how easily the targets are reached,
  \\\mathrm{target\\area}\_i \\ R^\* / R_i\\, where \\R_i\\ is
  `resistance` and \\R^\*\\ is the resistance a site would have in
  continuous habitat (every cell a target, of resistance
  `reference_resistance`) at the same `radius` and `site_radius`.
  Targets as easy to reach as in continuous habitat count in full, and
  harder ones proportionally less; targets close to the site, or through
  resistance below the reference, can count for more. It responds to the
  amount of targets, their arrangement and the resistance surface
  together. Its relative noise is that of `resistance`, and it is
  corrected for the bias of inverting a noisy estimate.

Both are in square kilometres where the grid's coordinate reference
system gives cell areas, and in cells otherwise; the `"area_units"`
attribute says which. Both are computed from per-row running sums, at a
cost linear in the radius.

\\R^\*\\ is solved exactly, once per kernel, on a uniform grid wide
enough that its edges don't matter, and is proportional to
`reference_resistance`: set it to the resistance of good habitat. On
lon/lat grids with `radius_units = "km"`, the kernel varies by row, and
so does \\R^\*\\; rows within reach of the top or bottom of the grid use
the nearest row whose kernel fits, so that there, as at other edges, the
grid's edge lowers accessible area rather than the reference.
Accessibility needs a finite `radius`.

A larger `radius` raises `target_area` everywhere and `accessible_area`
almost everywhere, but not at every cell: `resistance` withdraws current
from the targets in fixed proportions, so where widening the radius adds
mostly hard-to-reach targets, it raises the resistance to all of them,
and accessible area can fall. To compare runs at different resolutions,
give `site_radius` in km too: the default of 2 pixels is a different
site on each grid.

### Method

Each draw injects a random-sign dipole across every link of the circuit,
scaled by the square root of the link's conductance, and solves the
circuit once. For the solution \\y\\, \\(y_i - y_j)^2\\ is then an
unbiased estimate of \\R\_{ij}\\ for every pair at once, and both layers
come from sums of \\y\\ and \\y^2\\ over each cell's targets, after
averaging \\y\\ over each site. Their mean over draws estimates each
layer without bias.

Flow potential has no direct analogue here. With `normalize`, the same
draws on the uniform circuit (conductance 1 on the same cells) give the
same quantities for geometry alone, and the normalized layers divide by
them: the resistance of a unit-resistance landscape of the same shape
that would give the same isolation, so in the units of the input's
resistance. A normalized value of 2 means the cell is as isolated as it
would be if every cell had resistance 2. Above the landscape's typical
resistance, the cell is isolated by its resistances; below, by geometry
(distance, edges, few targets) more than by resistance.

### Accuracy

Each draw's estimate of `resistance` is a squared Gaussian-like
quantity, so its relative standard error is about \\\sqrt{2 /
\mathrm{n\\draws}}\\ at any grid size: about 18% at the default 64
draws, and 10% at 200. `mean_resistance` averages over targets and is
usually less noisy. Both circuits see the same draws, so on landscapes
of modest contrast the noise of the normalized layers largely cancels,
but where resistance varies by orders of magnitude it doesn't. With
`se = TRUE`, the result includes each layer's per-cell standard error,
from the spread of the draws; the `"relative_se"` attribute gives each
layer's median relative standard error either way.

Reproducibility, performance and progress are as for
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md):
one factorization (two with `normalize`), then about `n_draws` solves.
Accessibility adds a small factorization and one solve per kernel.

## See also

[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available(circuitscape = FALSE)
resistance <- terra::rast(system.file("extdata/resistance.tif",
                                      package = "circuitscaper"))
result <- dp_isolation(resistance, radius = 15, seed = 1)
terra::plot(result)
attr(result, "relative_se")

# How much of the targets each cell can access, as area
access <- dp_isolation(resistance, radius = 15, normalize = FALSE,
                       accessibility = TRUE, seed = 1)
terra::plot(access[[c("target_area", "accessible_area")]])
attr(access, "area_units")

# Isolation between two distributions, in both directions
origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
between <- dp_isolation(resistance, radius = 45, source_strength = origin,
                        destination = destination, normalize = FALSE, seed = 1)
terra::plot(between)
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
