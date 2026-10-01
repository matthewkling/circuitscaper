# Define a Condition for Conditional Omniscape Connectivity

Creates a condition specification for use with the `condition` argument
of
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md).
Conditional connectivity restricts which source cells are connected to
each target, based on how their values on a condition layer (e.g.,
climate, land cover class) compare. Conditions can compare present-day
values at both sources and targets, or present-day values at sources
against future values at targets (e.g., for climate-tracking
connectivity).

## Usage

``` r
os_condition(
  present,
  future = NULL,
  type = c("equal", "within"),
  lower = NULL,
  upper = NULL
)
```

## Arguments

- present:

  A single-layer
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path giving present-day condition values. Must align with the
  resistance surface.

- future:

  Optional single-layer
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or file path giving future condition values. If supplied, each
  source's *present* value is compared against the target's *future*
  value. If `NULL` (default), present values are used for both sources
  and targets.

- type:

  Character. How source and target values are compared: `"equal"`
  (connect only sources whose value equals the target's value; intended
  for categorical data) or `"within"` (connect only sources whose value
  falls within a range relative to the target's value; see `lower` and
  `upper`). If not specified, defaults to `"within"` when `lower` and
  `upper` are supplied and `"equal"` otherwise.

- lower, upper:

  Numeric. Required when `type = "within"`, and not used otherwise. A
  source is connected to a target only if
  `target + lower <= source <= target + upper`, or equivalently if
  `source - target` falls in `[lower, upper]`. For example, `lower = -1`
  and `upper = 0.5` connect sources whose values are up to 1 unit below
  or 0.5 units above the target's value. Either bound may be infinite
  (e.g., `upper = Inf` for a one-sided comparison).

## Value

An object of class `"os_condition"`: a list with elements `present`,
`future`, `type`, `lower`, and `upper`.

## Details

Omniscape evaluates each moving-window target against every source cell
in the window, and sets the strength of any source that fails the
comparison to zero for that target. The target's value is summarized
over its block (see `block_size` in
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)):
the median for `"within"`, and the mode for `"equal"`. When
`block_size = 1` this is simply the target cell's value.

Omniscape requires a condition value at every source cell. Source cells
with a missing (`NA`) present-day condition value are *not* filtered
out; they remain sources for every target.
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
warns if it detects this.

`"equal"` compares values exactly, so it is only meaningful for
categorical (integer-valued) layers; a warning is issued if a
`SpatRaster` supplied with `type = "equal"` contains non-integer values.

Up to two conditions can be combined by passing a list of two
`os_condition()` objects to
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md);
a source must satisfy both to be connected.

## References

Omniscape.jl conditional connectivity options:
<https://docs.circuitscape.org/Omniscape.jl/latest/usage/>

## See also

[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)

## Examples

``` r
if (FALSE) { # circuitscaper::cs_julia_available()
library(terra)
temp_now <- rast(nrows = 20, ncols = 20, vals = rep(1:20, each = 20))
temp_future <- temp_now + 2

# Climate-tracking: connect sources to targets whose future temperature is
# between 1 unit cooler and 3 units warmer than the source's present value
# (i.e., source - target_future within [-3, 1])
os_condition(temp_now, future = temp_future, lower = -3, upper = 1)

# Categorical: connect only cells of the same land cover class
landcover <- rast(nrows = 20, ncols = 20, vals = sample(1:3, 400, TRUE))
os_condition(landcover, type = "equal")
}
```
