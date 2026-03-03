# circuitscaper

R interface to
[Circuitscape.jl](https://github.com/Circuitscape/Circuitscape.jl) and
[Omniscape.jl](https://github.com/Circuitscape/Omniscape.jl) via
JuliaCall.

## Overview

[Circuitscape](https://circuitscape.org) and
[Omniscape](https://docs.circuitscape.org/Omniscape.jl/latest/) are
open-source Julia packages for modeling landscape connectivity using
circuit theory, developed by Brad McRae, Viral Shah, Ranjan
Anantharaman, and collaborators. Circuitscape treats the landscape as an
electrical circuit, where each raster cell is a node and cells with
lower resistance allow more “current” (representing movement probability
or gene flow) to pass through. This captures not just the single best
path between sites, but all possible pathways simultaneously, making it
especially useful for identifying corridors and pinch points. Omniscape
extends this by applying Circuitscape in a moving window across the
landscape, producing wall-to-wall connectivity maps without requiring
predefined focal sites.

**circuitscaper** is an independent R package (not affiliated with the
Circuitscape development team) that provides a clean, R-native interface
to both tools. Users work entirely in R with familiar
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects while Julia handles computation invisibly.

## Installation

``` r
# Install from GitHub
remotes::install_github("matthewkling/circuitscaper")

# First time: install Julia and required packages
library(circuitscaper)
cs_install_julia()
```

## Quick Example

``` r
library(circuitscaper)
library(terra)

# Load resistance and focal node rasters
resistance <- rast("path/to/resistance.tif")
locations <- rast("path/to/focal_nodes.tif")

# Pairwise Circuitscape
result <- cs_pairwise(resistance, locations)
plot(result$current_map)
result$resistance_matrix

# Omniscape moving-window connectivity
result <- os_run(resistance, radius = 100, block_size = 5)
plot(result[["normalized_current"]])
```

## Functions

| Function                                                                                           | Description                                    |
|----------------------------------------------------------------------------------------------------|------------------------------------------------|
| [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)           | Pairwise effective resistance and current flow |
| [`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md)       | One-to-all connectivity analysis               |
| [`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md)       | All-to-one connectivity analysis               |
| [`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md)           | Advanced mode with custom sources and grounds  |
| [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)                     | Omniscape moving-window connectivity           |
| [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)                 | Initialize Julia (called automatically)        |
| [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md) | Install Julia and required packages            |

## Requirements

- R \>= 4.0
- Julia \>= 1.9 (installed automatically via
  [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md))
- R packages: terra, JuliaCall

## Learn More

- [Circuitscape user
  guide](https://docs.circuitscape.org/Circuitscape.jl/latest/)
- [Omniscape
  documentation](https://docs.circuitscape.org/Omniscape.jl/latest/)
- McRae, B.H. (2006). Isolation by resistance. *Evolution*, 60(8),
  1551-1561.
- McRae, B.H. & Beier, P. (2007). Circuit theory predicts gene flow in
  plant and animal populations. *PNAS*, 104(50), 19885-19890.
- McRae, B.H., Dickson, B.G., Keitt, T.H. & Shah, V.B. (2008). Using
  circuit theory to model connectivity in ecology, evolution, and
  conservation. *Ecology*, 89(10), 2712-2724.
