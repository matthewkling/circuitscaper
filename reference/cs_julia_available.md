# Check if Julia and Required Packages Are Available

Tests whether Julia is installed and the Circuitscape Julia package can
be loaded. This is a lightweight check that does not initialize a full
Julia session. It is used internally by example code and can be called
by users to verify their setup before running analyses.

## Usage

``` r
cs_julia_available()
```

## Value

`TRUE` if Julia is found on the system PATH and the 'Circuitscape' Julia
package loads successfully, `FALSE` otherwise.

## Examples

``` r
cs_julia_available()
#> Warning: running command ''julia' --startup-file=no -e "using Circuitscape; println(true)" 2>/dev/null' had status 1
#> [1] FALSE
```
