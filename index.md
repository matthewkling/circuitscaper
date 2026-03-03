# circuitscaper

R interface to
[Circuitscape.jl](https://github.com/Circuitscape/Circuitscape.jl) and
[Omniscape.jl](https://github.com/Circuitscape/Omniscape.jl) via
JuliaCall.

## Overview

circuitscaper provides a clean, R-native interface to Circuitscape and
Omniscape for landscape connectivity modeling using circuit theory.
Users work entirely in R with familiar
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

# Pairwise Circuitscape
result <- cs_pairwise(resistance_raster, focal_nodes)
plot(result$current_map)
result$resistance_matrix

# Omniscape
result <- os_run(resistance_raster, radius = 100, block_size = 5)
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
| [`os_compare()`](https://matthewkling.github.io/circuitscaper/reference/os_compare.md)             | Compare two Omniscape runs                     |
| [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)                 | Initialize Julia (called automatically)        |
| [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md) | Install Julia and required packages            |

## Requirements

- R \>= 4.0
- Julia \>= 1.9 (installed automatically via
  [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md))
- R packages: terra, JuliaCall
