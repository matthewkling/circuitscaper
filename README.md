# circuitscaper <a href="https://matthewkling.github.io/circuitscaper/"><img src="man/figures/logo.png" align="right" height="139" alt="circuitscaper website" /></a>

<!-- badges: start -->
[![R-CMD-check](https://github.com/matthewkling/circuitscaper/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/matthewkling/circuitscaper/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R interface to [Circuitscape.jl](https://github.com/Circuitscape/Circuitscape.jl) and [Omniscape.jl](https://github.com/Circuitscape/Omniscape.jl) via JuliaCall.

## Overview

How easily can organisms, genes, or ecological processes move across a
landscape? **circuitscaper** answers this using circuit theory, where the
landscape is modeled as an electrical circuit and current flow reveals
connectivity patterns.

The package wraps [Circuitscape](https://circuitscape.org) and
[Omniscape](https://docs.circuitscape.org/Omniscape.jl/latest/), open-source
Julia tools developed by Brad McRae, Viral Shah, Ranjan Anantharaman, and
collaborators. The key input is a **resistance surface** — a raster where
each cell's value represents how difficult it is for an organism to cross
(typically derived from land cover, with higher values for hostile habitat).
Circuitscape treats each cell as a node in a circuit and computes current
flow between focal sites. Unlike least-cost path methods, this captures all
possible pathways simultaneously, making it especially useful for identifying
corridors and pinch points. Omniscape extends this by applying Circuitscape
in a moving window across the entire landscape, producing wall-to-wall
connectivity maps without predefined focal sites.

**circuitscaper** is an independent R package (not affiliated with the
Circuitscape development team) that provides an R-native interface to
both tools. Users work entirely in R with `terra::SpatRaster` objects
while Julia handles computation behind the scenes.

## Installation

```r
# Install from GitHub
remotes::install_github("matthewkling/circuitscaper")

# First time: install Julia and required packages
library(circuitscaper)
cs_install_julia()
```

## Quick Example

```r
library(circuitscaper)
library(terra)

# Create a simple resistance surface (or load your own with rast("file.tif"))
resistance <- rast(nrows = 50, ncols = 50, vals = runif(2500, 1, 10))

# Focal nodes as coordinates (x, y)
coords <- matrix(c(-140, 50,
                     -60, 50,
                    -100, 10), ncol = 2, byrow = TRUE)

# Pairwise Circuitscape — resistance matrix + cumulative current map
result <- cs_pairwise(resistance, coords)
plot(result$current_map)
result$resistance_matrix

# Omniscape — wall-to-wall moving-window connectivity
result <- os_run(resistance, radius = 10)
plot(result[["normalized_current"]])
```

## Functions

| Function | Description |
|---|---|
| `cs_pairwise()` | Pairwise effective resistance and current flow |
| `cs_one_to_all()` | One-to-all connectivity analysis |
| `cs_all_to_one()` | All-to-one connectivity analysis |
| `cs_advanced()` | Advanced mode with custom sources and grounds |
| `os_run()` | Omniscape moving-window connectivity |
| `cs_locations()` | Create focal node raster from coordinates |
| `cs_setup()` | Initialize Julia (called automatically) |
| `cs_install_julia()` | Install Julia and required packages |

## Requirements

- R >= 4.0
- Julia >= 1.9 (installed automatically via `cs_install_julia()`)
- R packages: terra, JuliaCall

## Learn More

- [Getting started vignette](https://matthewkling.github.io/circuitscaper/articles/getting-started.html)
- [Circuitscape user guide](https://docs.circuitscape.org/Circuitscape.jl/latest/)
- [Omniscape documentation](https://docs.circuitscape.org/Omniscape.jl/latest/)
- McRae, B.H. (2006). Isolation by resistance. *Evolution*, 60(8), 1551-1561.
- McRae, B.H. & Beier, P. (2007). Circuit theory predicts gene flow in plant and animal populations. *PNAS*, 104(50), 19885-19890.
- McRae, B.H., Dickson, B.G., Keitt, T.H. & Shah, V.B. (2008). Using circuit theory to model connectivity in ecology, evolution, and conservation. *Ecology*, 89(10), 2712-2724.
