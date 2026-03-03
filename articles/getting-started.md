# Getting Started with circuitscaper

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

## Choosing a Mode

circuitscaper provides four Circuitscape modes and one Omniscape mode.
Here’s how to choose:

**Pairwise** is the most common starting point. Use it when you have
discrete sites (habitat patches, populations) and want to know how
well-connected they are to each other. The resistance matrix is useful
as a distance metric for analyses such as isolation by resistance in
population genetics.

**One-to-all / All-to-one** are variants that produce different current
maps. One-to-all emphasizes how current disperses outward from each
site; all-to-one emphasizes how current converges on each site. Use
these when you care about the spatial pattern of connectivity for
individual nodes, not just the pairwise resistances.

**Advanced** is for when you want full control over source and ground
placement rather than using focal nodes. This is useful for modeling
directional movement between a defined source area and a destination.

**Omniscape** is fundamentally different — it doesn’t require focal
nodes at all. It uses a moving window to compute omnidirectional
connectivity everywhere in the landscape. Use it for wall-to-wall
connectivity mapping.

## Circuitscape: Pairwise Mode

The most common Circuitscape analysis computes effective resistance and
cumulative current flow between all pairs of focal nodes.

``` r
library(terra)
library(circuitscaper)

# Resistance surface (higher values = harder to traverse)
resistance <- rast("path/to/resistance.tif")

# Focal nodes (integer IDs; cells with 0 or NA are not nodes)
locations <- rast("path/to/focal_nodes.tif")

# Run pairwise analysis
result <- cs_pairwise(resistance, locations)

# Current flow map
plot(result$current_map)

# Pairwise resistance matrix
result$resistance_matrix
```

## Circuitscape: One-to-All Mode

In one-to-all mode, each focal node takes a turn as the source while all
others are grounded simultaneously. The result includes a per-node
current map for each focal node plus a cumulative map summing across all
iterations.

``` r
result <- cs_one_to_all(resistance, locations)
plot(result[["cumulative_current"]])
```

## Circuitscape: All-to-One Mode

All-to-one is the reverse: all other focal nodes inject current and each
node takes a turn as the ground.

``` r
result <- cs_all_to_one(resistance, locations)
plot(result[["cumulative_current"]])
```

## Circuitscape: Advanced Mode

Advanced mode gives full control over source and ground placement. It
returns both a current map and a voltage map.

``` r
source_layer <- rast("path/to/sources.tif")
ground_layer <- rast("path/to/grounds.tif")

result <- cs_advanced(resistance, source_layer, ground_layer)

# Access individual layers
plot(result[["cumulative_current"]])
plot(result[["voltage"]])
```

## Omniscape: Moving-Window Connectivity

Omniscape computes omnidirectional connectivity using a moving window
approach. It does not require focal nodes — every cell can serve as a
source.

``` r
result <- os_run(resistance, radius = 100, block_size = 5)

plot(result[["normalized_current"]])
plot(result[["flow_potential"]])
```

### With Source Strength Weights

``` r
source_strength <- rast("path/to/habitat_quality.tif")

result <- os_run(resistance, radius = 100,
                 source_strength = source_strength,
                 block_size = 5)

plot(result[["normalized_current"]])
```

### Parallel Processing

For large landscapes, enable Julia multithreading. Julia’s thread count
is fixed at startup, so set it via
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
before any other circuitscaper calls:

``` r
# Set thread count at the start of your session
cs_setup(threads = 4)

result <- os_run(resistance, radius = 100,
                 block_size = 5,
                 parallelize = TRUE)
```

## Saving Outputs

By default, intermediate files are written to a temporary directory and
cleaned up. To persist output files, use `output_dir`:

``` r
result <- cs_pairwise(resistance, locations,
                      output_dir = "my_output_directory")
```

## Tips

- **CRS preservation**: circuitscaper captures the CRS from your input
  raster and reattaches it to outputs, even though Circuitscape’s ASCII
  grid format doesn’t carry CRS information.

- **Solver choice**: The default `"cg+amg"` solver works well for most
  cases. For small problems, `"cholmod"` (direct solver) may be faster.

- **Verbose output**: Set `verbose = TRUE` to see Circuitscape’s solver
  progress, useful for debugging or monitoring long runs.
