# Getting Started with circuitscaper

## What is circuit-theory connectivity?

Landscape connectivity — how easily organisms, genes, or ecological
processes can move across a landscape — is central to spatial ecology
and conservation biology. Circuit theory offers a powerful way to model
it. The idea is to treat a landscape as an electrical circuit: each
raster cell is a node, adjacent cells are connected by resistors, and
current flowing through the network reveals movement patterns. Unlike
least-cost path methods, which find only the single cheapest route,
circuit theory considers all possible pathways simultaneously. This
makes it especially effective at identifying movement corridors and
pinch points — places where connectivity is funneled through narrow
gaps.

circuitscaper brings circuit-theory connectivity to R, with two families
of methods that take the same inputs (terra rasters) and run in the same
Julia session:

- **Circuitscape and Omniscape** (`cs_*()` and `os_*()` functions). The
  established tools, run through the
  [Circuitscape.jl](https://github.com/Circuitscape/Circuitscape.jl) and
  [Omniscape.jl](https://github.com/Circuitscape/Omniscape.jl) Julia
  packages. Results are the same as running those tools directly.
- **Dipole methods** (`dp_*()` functions). circuitscaper’s own methods,
  which factor one circuit and solve many superposed source–sink pairs
  (“dipoles”) against it. They cover similar questions — pairwise and
  omnidirectional connectivity, and connectivity between two
  distributions — much faster and with a built-in error estimate, but
  they compute a related, different quantity (squared rather than
  absolute current) and are stochastic. They are **experimental**: new,
  not yet published, and their interface may change.

This vignette covers installation, inputs and how to choose a method.
Two articles on the package website go further:

- [Circuitscape and
  Omniscape](https://matthewkling.github.io/circuitscaper/articles/circuitscape-omniscape.html):
  each mode and its options.
- [Dipole
  methods](https://matthewkling.github.io/circuitscaper/articles/dipole-methods.html):
  how to use them, how they work, and how they compare.

## Installation

circuitscaper requires Julia (\>= 1.10). The `cs_*()` and `os_*()`
functions also need the Circuitscape and Omniscape Julia packages; the
dipole methods need only Julia. You can install everything from R:

``` r

install.packages("circuitscaper")

library(circuitscaper)

# First time only: install Julia and required packages
cs_install_julia()

# Or, if you'll only use the dipole methods: Julia alone, which is
# quicker to install and to start
cs_install_julia(circuitscape = FALSE)
```

[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md)
downloads the official Julia release for your platform from
julialang.org into circuitscaper’s own data directory, so it doesn’t
touch any other Julia you have installed. You can add the Circuitscape
and Omniscape packages later by running
[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md)
again.

If you already have Julia installed,
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
will find it automatically, searching the `JULIA_HOME` and
`JULIA_BINDIR` environment variables, a Julia installed by
[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md),
and your PATH. If Julia is somewhere else, you can point to it:

``` r

cs_setup(julia_home = "/path/to/julia/bin")
```

Julia starts the first time you call a circuitscaper function, or when
you call
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md),
and takes a few seconds. The first `cs_*()` or `os_*()` call of a
session then also loads Circuitscape and Omniscape and warms them up,
which takes longer (often 15 seconds or more); the dipole methods skip
that step. To use several threads, which speeds up Omniscape and the
dipole methods, call `cs_setup(threads = )` at the start of your
session:

``` r

cs_setup(threads = 4)
```

## Key inputs

### The resistance surface

Every analysis starts with a **resistance surface** — a raster where
each cell’s value represents how difficult it is for the organism or
process of interest to move through that location. These are typically
derived from land cover or habitat suitability models. For example, a
resistance surface for a forest-dwelling mammal might assign low values
to forest (easy to traverse), moderate values to grassland, and high
values to urban areas or water. (Note that while the Circuitscape.jl
Julia library allows resistance datasets to be specified as adjacency
graph networks, circuitscaper currently only supports rasters.)

Resistance values must be positive. If your data represents conductance
(ease of movement) rather than resistance, set
`resistance_is = "conductances"`. Circuitscape and the dipole methods
treat a conductance of zero as no connection, but Omniscape requires all
values to be positive in either case. To make cells impassable, set them
to `NA`.

### Focal nodes

The focal-node methods
([`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
[`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md)
and
[`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md))
require **focal nodes** — the sites between which you want to measure
connectivity. These are typically habitat patches, populations,
protected areas, or sampling locations. You can provide them as:

- A matrix or data.frame of x/y coordinates (simplest)
- A raster with positive integer IDs at each site (0 and NA are ignored)

### Source strength

The omnidirectional methods
([`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
and
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md))
need no focal nodes: every cell can be a source, weighted by its
**source strength**, such as habitat quality or suitability. By default
both use the conductance surface (the inverse of resistance). For
connectivity between two distributions,
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md),
`dp_omni(destination = )` and
[`dp_directionality()`](https://matthewkling.github.io/circuitscaper/reference/dp_directionality.md)
take two surfaces: an origin and a destination.

## Choosing a method

Start from the question you’re asking:

| Question | Circuitscape and Omniscape | Dipole methods |
|----|----|----|
| How well connected are these sites to each other, and through where? | [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md) | [`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md) |
| How does current spread out from, or converge on, each site? | [`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md), [`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md) |  |
| How does movement flow between a defined source area and a destination? | [`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md) |  |
| Where are the corridors and barriers across the whole landscape? | [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md) | [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md) |
| How does movement link two distributions (such as seasonal ranges, or present and future habitat), and which way does it flow? | [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md) with `os_condition(future = )`, for climate | [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md), `dp_omni(destination = )`, [`dp_directionality()`](https://matthewkling.github.io/circuitscaper/reference/dp_directionality.md) |
| How isolated is each place from its habitat, or from another distribution? | [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md) resistances, for focal nodes only | [`dp_isolation()`](https://matthewkling.github.io/circuitscaper/reference/dp_isolation.md) |

**Pairwise** analyses treat discrete sites (habitat patches,
populations) and ask how well they’re connected to each other.
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)
also returns the matrix of effective resistances between sites, a
distance measure for analyses such as isolation by resistance in
population genetics.

**One-to-all** and **all-to-one** modes inject current at each site in
turn (or ground each in turn), emphasizing how current disperses from,
or converges on, each site — useful for recolonization potential, or
finding the most reachable sites.

**Advanced** mode gives full control over where current enters and
leaves: explicit source and ground rasters, and one circuit solved.

**Omnidirectional** analyses need no focal nodes. They map connectivity
continuously across the landscape among all habitat within a dispersal
radius, to identify corridors and barriers across the full extent.

**Two-distribution** analyses ask how movement links one distribution to
another: present and future habitat under climate change, breeding and
wintering ranges, foraging and roosting habitat, or source populations
and restoration sites.
[`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
maps the net flow from origin to destination, with its direction;
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
with a `destination` maps the routes between them without direction; and
[`dp_directionality()`](https://matthewkling.github.io/circuitscaper/reference/dp_directionality.md)
maps both, with their ratio, showing where movement is one-way and where
it runs both ways. For climate change,
[`os_condition()`](https://matthewkling.github.io/circuitscaper/reference/os_condition.md)
offers a related Omniscape analysis, restricting connections to sources
and targets with compatible present and future conditions.

**Isolation** asks how well connected each *place* is, rather than where
movement passes.
[`dp_isolation()`](https://matthewkling.github.io/circuitscaper/reference/dp_isolation.md)
scores every cell by its effective resistance to the habitat within
reach, or to and from another distribution, so it also shows how
connected a site would be at each place. With `coverage = TRUE`, it also
compares each cell with ideal continuous habitat, so the amount of
habitat in reach counts as well as the resistance to it. For discrete
sites,
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)’s
resistance matrix answers the same question exactly.

### Circuitscape and Omniscape, or dipole methods?

Where both families answer a question, choose by what you need:

- **Circuitscape and Omniscape** are established and published, so
  results compare directly with the many studies that use them. They
  also offer outputs the dipole methods don’t: pairwise resistance
  matrices, voltage and per-pair maps, short-circuit regions and
  conditional connectivity.
- **Dipole methods** are much faster on large grids, with many focal
  nodes, or when you want many runs (several radii, species or
  scenarios). They treat every habitat cell as a source without block
  sizes or windows, and each map comes with an estimate of its own
  noise. But their maps are of squared current over the whole circuit,
  which ranks cells similarly to Circuitscape and Omniscape but isn’t
  the same quantity, and they carry some sampling noise. See the [Dipole
  methods](https://matthewkling.github.io/circuitscaper/articles/dipole-methods.html)
  article before relying on them.

## A first look

``` r

library(terra)
library(circuitscaper)

resistance <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))

# Pairwise Circuitscape among four sites
sites <- matrix(c(10, 40, 40, 40, 10, 10, 40, 10), ncol = 2, byrow = TRUE)
pw <- cs_pairwise(resistance, sites)
plot(pw$current_map)
pw$resistance_matrix

# Omnidirectional connectivity: Omniscape and the dipole method
os <- os_run(resistance, radius = 10)
dp <- dp_omni(resistance, radius = 10, seed = 1)
plot(c(os$normalized_current, dp$normalized_current))
```

## Saving outputs and other tips

- **CRS preservation**: circuitscaper reattaches your input raster’s CRS
  to outputs.
- **Conductance input**: If your surface represents ease of movement
  rather than difficulty, set `resistance_is = "conductances"` to avoid
  inverting values manually.
- **Output files**: The `cs_*()` and `os_*()` functions write
  intermediate files to a temporary directory and clean up. To keep them
  (ASC rasters, INI configuration and resistance matrices), use
  `output_dir`.
- **Verbose output**: Set `verbose = TRUE` in the `cs_*()` and `os_*()`
  functions to see the solver’s progress, useful for debugging or
  monitoring long runs.
