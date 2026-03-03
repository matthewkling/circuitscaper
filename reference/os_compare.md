# Compare Two Omniscape Runs

Convenience function for comparing two Omniscape results, e.g., current
vs. future climate scenarios. Computes the difference and ratio between
a specified layer from each run.

## Usage

``` r
os_compare(baseline, future, metric = "normalized_current")
```

## Arguments

- baseline:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  result from
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md).

- future:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  result from
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md).

- metric:

  Character. Layer name to compare. Default `"normalized_current"`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with two layers:

- difference:

  `future - baseline`

- ratio:

  `future / baseline`

## See also

[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)

## Examples

``` r
if (FALSE) { # \dontrun{
baseline <- os_run(resistance_current, radius = 50)
future <- os_run(resistance_future, radius = 50)
comparison <- os_compare(baseline, future)
plot(comparison[["difference"]])
plot(comparison[["ratio"]])
} # }
```
