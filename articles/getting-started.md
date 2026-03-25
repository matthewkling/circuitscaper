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

circuitscaper brings this approach to R by wrapping two Julia tools:
**Circuitscape** (which computes connectivity between specific sites)
and **Omniscape** (which maps connectivity continuously across an entire
landscape).

This vignette provides a basic overview of the circuitscaper R package.
For more details on circuit theory and the underlying Julia algorithms,
see the [Circuitscape](https://circuitscape.org) and
[Omniscape](https://docs.circuitscape.org/Omniscape.jl/latest/)
documentation.

## Installation

circuitscaper requires Julia (\>= 1.9) with the Circuitscape and
Omniscape packages. You can install everything from R:

``` r
# Install circuitscaper (from GitHub during development)
# remotes::install_github("matthewkling/circuitscaper")

library(circuitscaper)

# First time only: install Julia and required packages
cs_install_julia()
```

If you already have Julia installed,
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
will find it automatically or you can point to it:

``` r
cs_setup(julia_home = "/path/to/julia/bin")
```

## Key Inputs

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
`resistance_is = "conductances"`.

### Focal nodes

Circuitscape’s focal-node modes (pairwise, one-to-all, all-to-one)
require **focal nodes** — the sites between which you want to measure
connectivity. These are typically habitat patches, populations,
protected areas, or sampling locations. You can provide them as:

- A matrix or data.frame of x/y coordinates (simplest)
- A raster with positive integer IDs at each site (0 and NA are ignored)

## Choosing a Mode

circuitscaper provides four Circuitscape modes and one Omniscape mode.
Here’s how to choose:

**Pairwise** is a common starting point. Use it when you have discrete
sites (habitat patches, populations) and want to know how well-connected
they are to each other. The resistance matrix is useful as a distance
metric for analyses such as isolation by resistance in population
genetics.

**One-to-all** iterates over each focal node, injecting current at that
node and grounding all others. This emphasizes how current disperses
outward from each source, making it useful for modeling recolonization
potential or identifying which sites have the best overall connectivity
to the network.

**All-to-one** is the reverse: all other nodes inject current while each
node takes a turn as the ground. This emphasizes convergence and is
useful for identifying the most accessible or reachable sites — for
example, which protected areas are easiest to reach via migration.

**Advanced** is for when you want full control over source and ground
placement rather than using focal nodes. You provide explicit source
current and ground conductance rasters, and a single circuit is solved.
This is useful for modeling directional movement between a defined
source area and a destination (e.g., current flow between a migratory
species’ winter and summer ranges).

**Omniscape** is fundamentally different — it doesn’t require focal
nodes at all. It uses a moving window to compute omnidirectional
connectivity everywhere in the landscape. Use it for wall-to-wall
connectivity mapping when you want to identify corridors and barriers
across the full extent.

## Circuitscape: Pairwise Mode

``` r
library(terra)
library(circuitscaper)

# Resistance surface (higher values = harder to traverse)
resistance <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))

# Option 1: Focal nodes as coordinates (simplest)
coords <- matrix(c(10, 40, 40, 40, 10, 10, 40, 10), ncol = 2, byrow = TRUE)
result <- cs_pairwise(resistance, coords)

# Option 2: Focal nodes as a raster (integer IDs; 0 and NA are not nodes)
# locations <- rast("path/to/focal_nodes.tif")
# result <- cs_pairwise(resistance, locations)

# Cumulative current map -- high values indicate important movement corridors
plot(result$current_map)

# Pairwise resistance matrix -- can be used as a connectivity distance metric
result$resistance_matrix
```

## Circuitscape: One-to-All and All-to-One Modes

``` r
result <- cs_one_to_all(resistance, coords)
plot(result)
```

``` r
result <- cs_all_to_one(resistance, coords)
plot(result$cumulative_current)
```

## Circuitscape: Advanced Mode

``` r
source_layer <- rast(system.file("extdata/source.tif", package = "circuitscaper"))
ground_layer <- rast(system.file("extdata/ground.tif", package = "circuitscaper"))

result <- cs_advanced(resistance, source_layer, ground_layer,
                      ground_is = "conductances")

# Current density -- corridors and pinch points where flow is concentrated
# i.e. possible preservation priorities
plot(result[["current"]])

# Voltage -- analogous to movement probability, decreasing with distance
# and resistance from sources
plot(result[["voltage"]])

# Power dissipation -- areas of current flow through high-resistance areas,
# i.e. possible restoration priorities
plot(result[["current"]]^2 * resistance)
```

## Additional Circuitscape Options

The `cs_*` functions expose several additional Circuitscape features.

### Per-pair current and voltage maps

By default, pairwise, one-to-all, and all-to-one modes return only the
cumulative current map. Set `cumulative_only = FALSE` to include
per-pair (or per-node) current layers, and `write_voltage = TRUE` to
include voltage layers:

``` r
result <- cs_pairwise(resistance, coords,
                      cumulative_only = FALSE,
                      write_voltage = TRUE)
names(result$current_map)
```

### Variable source strengths

By default, each focal node injects 1 amp of current. Use
`source_strengths` to assign different injection strengths per node —
useful when sites differ in population size or habitat area:

``` r
# Strengths in the same order as the locations
strengths <- c(2.5, 1.0, 0.5)
result <- cs_one_to_all(resistance, coords, source_strengths = strengths)
```

### Short-circuit regions

Short-circuit regions represent areas of zero resistance (e.g., lakes
that can be crossed freely, or developed areas that funnel movement).
Pass a raster where cells sharing the same positive integer value are
short-circuited:

``` r
polygons <- rast("path/to/short_circuit_regions.tif")
result <- cs_pairwise(resistance, locations, short_circuit = polygons)
```

### Include/exclude pairs

For large numbers of focal nodes, you may want to restrict analysis to a
subset of pairs:

``` r
result <- cs_pairwise(resistance, locations,
                      included_pairs = "path/to/pairs.txt")
```

## Omniscape: Moving-Window Connectivity

Omniscape computes omnidirectional connectivity using a moving window.
It does not require focal nodes — every cell can serve as a source.

The two key parameters are:

- **`radius`**: The moving window radius in pixels. This defines the
  neighborhood over which connectivity is evaluated — conceptually, how
  far the organism can disperse. Larger radii capture longer-distance
  connectivity but increase computation time substantially.
- **`block_size`**: Aggregation factor for source points (default 1, no
  aggregation). Setting `block_size = 3` groups sources into 3x3 blocks,
  reducing the number of circuit solves with typically negligible
  effects on results. This is the primary knob for trading off speed
  vs. precision.

``` r
result <- os_run(resistance, radius = 20, block_size = 3)
```

Omniscape returns up to three layers:

- **`cumulative_current`**: Raw current flow summed across all
  moving-window iterations. Higher values indicate cells that carry more
  current overall.
- **`flow_potential`**: What current flow would look like if resistance
  were uniform everywhere. This isolates the effect of source geometry
  from landscape resistance.
- **`normalized_current`**: Cumulative current divided by flow
  potential. Values greater than 1 indicate corridors where connectivity
  is higher than expected given the arrangement of sources; values less
  than 1 indicate relative barriers. This is usually the most
  informative layer.

``` r
plot(result)
```

### With source strength weights

By default, source strength is derived from the inverse of resistance.
You can provide an explicit source strength raster (e.g., habitat
quality) to weight sources independently of resistance:

``` r
source_strength <- rast("path/to/habitat_quality.tif")

result <- os_run(resistance, radius = 20,
                 source_strength = source_strength)
```

### Parallel processing

For large landscapes, enable Julia multithreading to reduce compute
times. Julia’s thread count is fixed at startup, so set it via
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
before any other circuitscaper calls:

``` r
# Set thread count at the start of your session
cs_setup(threads = 4)

result <- os_run(resistance, radius = 20,
                 block_size = 5,
                 parallelize = TRUE)
```

## Performance

Circuitscape computation time scales with the number of non-NA cells in
the resistance raster and, for focal-node modes, with the number of
pairs or iterations. A few practical guidelines:

- **Raster size**: Problems up to ~1 million cells run comfortably. For
  larger landscapes, consider aggregating the resistance surface before
  analysis.
- **Number of focal nodes**: Pairwise mode solves n\*(n-1)/2 circuits,
  so computation grows quadratically with the number of nodes. Use
  `included_pairs` to limit the set if needed.
- **Omniscape**: Computation is dominated by the number of source pixels
  and the `radius`. Use `block_size` to reduce the source count and keep
  `radius` as small as ecologically justified. Enable
  `parallelize = TRUE` for large runs.
- **Solver choice**: The default `"cg+amg"` (iterative) solver works
  well for large problems. For small rasters (under ~10,000 cells),
  `"cholmod"` (direct solver) may be faster.

## Saving Outputs

By default, intermediate files are written to a temporary directory and
cleaned up. To persist output files (ASC rasters, INI configuration, and
resistance matrices), use `output_dir`:

``` r
result <- cs_pairwise(resistance, locations,
                      output_dir = "my_output_directory")
```

## Tips

- **CRS preservation**: circuitscaper captures the CRS from your input
  raster and reattaches it to outputs, even though Circuitscape’s ASCII
  grid format doesn’t carry CRS information.

- **Conductance input**: If your surface represents ease of movement
  rather than difficulty, set `resistance_is = "conductances"` to avoid
  inverting values manually. There’s a similar option for grounds in
  advanced mode.

- **Normalized current for Circuitscape**: Omniscape returns normalized
  current (actual current / flow potential) automatically. You can
  compute the equivalent for Circuitscape by running the analysis twice
  — once with your resistance surface and once with a uniform surface —
  and dividing:

  ``` r
  result      <- cs_pairwise(resistance, sites)
  result_null <- cs_pairwise(resistance * 0 + 1, sites)
  normalized  <- result$current_map / result_null$current_map
  ```

  Values greater than 1 indicate areas where landscape resistance is
  concentrating current flow; values less than 1 indicate areas where
  current is lower than expected from geometry alone.

- **Verbose output**: Set `verbose = TRUE` to see Circuitscape’s solver
  progress, useful for debugging or monitoring long runs.
