# Check if Julia and Required Packages Are Available

Tests whether Julia is installed and the Circuitscape and Omniscape
Julia packages can be loaded. This is a lightweight check that does not
initialize a full Julia session. It is used internally by example code
and can be called by users to verify their setup before running
analyses.

## Usage

``` r
cs_julia_available(circuitscape = TRUE)
```

## Arguments

- circuitscape:

  Logical. Also check that the Circuitscape and Omniscape Julia packages
  load, as the `cs_*()` and `os_*()` functions need. Default `TRUE`. Use
  `FALSE` to check for what the dipole methods (`dp_*()`) need: a Julia
  that runs and is recent enough.

## Value

`TRUE` if Julia is found (in the places
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
searches) and runs, is at least the minimum version, and (with
`circuitscape = TRUE`) loads the 'Circuitscape' and 'Omniscape' Julia
packages; `FALSE` otherwise.

## Examples

``` r
cs_julia_available()
#> [1] FALSE
cs_julia_available(circuitscape = FALSE)
#> [1] FALSE
```
