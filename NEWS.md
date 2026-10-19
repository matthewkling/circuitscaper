# circuitscaper (development version)

## Bug fixes

* `cs_setup()` now finds Julia wherever `JuliaCall::julia_setup()` would,
  instead of only on the PATH. Previously, a Julia installed by
  `cs_install_julia()` (which `JuliaCall::install_julia()` places outside the
  PATH) was not found in later sessions, so `cs_setup()` failed with "Julia
  not found" until `julia_home` was given explicitly. The same applied to
  Julia installed via juliaup or Homebrew when R was started from the macOS
  GUI, whose PATH lacks the shell's. `cs_install_julia()`,
  `cs_julia_available()`, and the startup message use the same search.

# circuitscaper 0.1.1

## New features

* New `os_condition()` constructor gives `os_run()` full access to
  Omniscape's conditional connectivity (#2):
  * `"within"` comparisons with user-specified bounds (`lower`, `upper`).
  * Present-vs-future comparisons (`future`), in which sources' present-day
    values are compared against targets' future values, as in
    climate-tracking connectivity analyses.
  * Two simultaneous conditions, by passing a list of two `os_condition()`
    objects.
* `os_run()` now warns when a condition layer has missing values at source
  cells, which Omniscape does not filter.
* All `cs_*()` functions and `os_run()` now warn if the installed
  Circuitscape.jl or Omniscape.jl does not recognize a configuration option
  written by circuitscaper, rather than letting the option silently have no
  effect.

## Bug fixes

* In 0.1.0, `os_run()`'s `condition_type` argument was written to the
  Omniscape configuration under a key Omniscape does not recognize, so it was
  silently ignored. All conditional analyses instead used Omniscape's
  defaults, `"within"` with bounds of 0 and 0: a source was connected to a
  target only if its condition value exactly equaled the median value of the
  target block. This was neither the documented behavior (an unbounded range)
  nor the requested `"equal"` comparison. **Results from 0.1.0 that used
  `condition` should be rerun.**
* In 0.1.0, `four_neighbors = TRUE` was written to the Circuitscape
  configuration under an unrecognized key and silently ignored in
  `cs_pairwise()`, `cs_one_to_all()`, `cs_all_to_one()`, and `cs_advanced()`;
  all analyses used 8-neighbor connectivity. **Results from 0.1.0 that used
  `four_neighbors = TRUE` should be rerun.**

## Breaking changes and deprecations

* Passing a raster directly as `os_run(condition = )` is now shorthand for
  `os_condition(x, type = "equal")`. Use `os_condition()` for `"within"`
  comparisons, which now require explicit bounds.
* `os_run()`'s `condition_type` argument is deprecated. `condition_type =
  "equal"` still works with a warning; `condition_type = "within"` now errors,
  since it has no way to specify bounds.


# circuitscaper 0.1.0

* Initial release
