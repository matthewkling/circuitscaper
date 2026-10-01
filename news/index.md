# Changelog

## circuitscaper 0.1.1

### New features

- New
  [`os_condition()`](https://matthewkling.github.io/circuitscaper/reference/os_condition.md)
  constructor gives
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  full access to Omniscape’s conditional connectivity
  ([\#2](https://github.com/matthewkling/circuitscaper/issues/2)):
  - `"within"` comparisons with user-specified bounds (`lower`,
    `upper`).
  - Present-vs-future comparisons (`future`), in which sources’
    present-day values are compared against targets’ future values, as
    in climate-tracking connectivity analyses.
  - Two simultaneous conditions, by passing a list of two
    [`os_condition()`](https://matthewkling.github.io/circuitscaper/reference/os_condition.md)
    objects.
- [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  now warns when a condition layer has missing values at source cells,
  which Omniscape does not filter.
- All `cs_*()` functions and
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  now warn if the installed Circuitscape.jl or Omniscape.jl does not
  recognize a configuration option written by circuitscaper, rather than
  letting the option silently have no effect.

### Bug fixes

- In 0.1.0,
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)’s
  `condition_type` argument was written to the Omniscape configuration
  under a key Omniscape does not recognize, so it was silently ignored.
  All conditional analyses instead used Omniscape’s defaults, `"within"`
  with bounds of 0 and 0: a source was connected to a target only if its
  condition value exactly equaled the median value of the target block.
  This was neither the documented behavior (an unbounded range) nor the
  requested `"equal"` comparison. **Results from 0.1.0 that used
  `condition` should be rerun.**
- In 0.1.0, `four_neighbors = TRUE` was written to the Circuitscape
  configuration under an unrecognized key and silently ignored in
  [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
  [`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md),
  [`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md),
  and
  [`cs_advanced()`](https://matthewkling.github.io/circuitscaper/reference/cs_advanced.md);
  all analyses used 8-neighbor connectivity. **Results from 0.1.0 that
  used `four_neighbors = TRUE` should be rerun.**

### Breaking changes and deprecations

- Passing a raster directly as `os_run(condition = )` is now shorthand
  for `os_condition(x, type = "equal")`. Use
  [`os_condition()`](https://matthewkling.github.io/circuitscaper/reference/os_condition.md)
  for `"within"` comparisons, which now require explicit bounds.
- [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)’s
  `condition_type` argument is deprecated. `condition_type = "equal"`
  still works with a warning; `condition_type = "within"` now errors,
  since it has no way to specify bounds.

## circuitscaper 0.1.0

CRAN release: 2026-04-09

- Initial release
