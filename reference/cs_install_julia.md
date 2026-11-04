# Install Julia and Required Packages

Downloads and installs Julia, Circuitscape.jl, and Omniscape.jl. This is
the recommended first step after installing the circuitscaper R package.

## Usage

``` r
cs_install_julia(force = FALSE, version = "latest")
```

## Arguments

- force:

  Logical. If `TRUE`, reinstall Julia and packages even if they appear
  to be already present. Use this to replace a Julia installation that
  is too old. Default `FALSE`.

- version:

  Character. Julia version to install, e.g. `"1.12.1"`. Default
  `"latest"`, the latest stable release. Must be at least 1.10.

## Value

Invisibly returns `TRUE` on success, `FALSE` if cancelled.

## Details

In interactive sessions, prompts for confirmation before downloading. In
non-interactive sessions (e.g., CI), proceeds without prompting.

Julia is installed with
[`JuliaCall::install_julia()`](https://rdrr.io/pkg/JuliaCall/man/install_julia.html).
The CRAN release of 'JuliaCall' (0.17.6) cannot install current Julia
versions, so if it is installed, `cs_install_julia()` stops before
downloading and explains how to install the development version of
'JuliaCall' instead. Julia installed by other means (e.g., juliaup or
the official installers) also works.

## Examples

``` r
if (FALSE) { # \dontrun{
cs_install_julia()
} # }
```
