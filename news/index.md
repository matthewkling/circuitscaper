# Changelog

## circuitscaper (development version)

### New features

- New dipole methods: connectivity from many balanced source-sink pairs
  (“dipoles”) superposed on one factored circuit, at a cost of one
  factorization and a few dozen solves whatever the number of pairs.

  - [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)
    maps omnidirectional connectivity among habitat, in the role of
    [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md),
    from random-sign dipoles within a radius (in pixels or km): current,
    flow potential and normalized current, with a built-in estimate of
    its sampling noise. With a `destination`, it maps the routes linking
    two distributions, such as present and future habitat, seasonal
    ranges, or two habitat types, without direction.
  - [`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md)
    maps connectivity among every pair of focal nodes, the
    squared-current analogue of
    [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)’s
    cumulative map, at a cost independent of the number of nodes, or
    exactly from one solve per node, with flow potential and normalized
    current.
  - [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
    maps the net flow from an origin to a destination distribution, with
    direction, in one solve, among pairs within an optional radius, with
    flow potential and normalized current as in
    [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
    Its current is the sum of absolute current over a cell’s links, as
    in Circuitscape, or with `cell_value = "rms"`, the RMS current, as
    in
    [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
    Attributes `"origin_in_reach"` and `"destination_in_reach"` give the
    shares of origin and destination strength with any counterpart
    within the radius, and `"pair_weight_in_reach"` the share of all
    origin–destination pair weight within it, which is small whenever
    the domain is large relative to the radius.
  - [`dp_directionality()`](https://matthewkling.github.io/circuitscaper/reference/dp_directionality.md)
    maps both at once from the same pairs, the directional map of
    [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
    and the undirected map of `dp_omni(destination = )`, with their
    ratio: where movement between the two distributions is one-way and
    where it runs both ways. Both it and `dp_omni(destination = )`
    center their random dipoles on the pairs’ mean dipole, which is
    solved exactly, so their noise is much smaller where movement is
    one-way.
  - With `power = TRUE` (off by default),
    [`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md),
    [`dp_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/dp_pairwise.md),
    [`dp_flux()`](https://matthewkling.github.io/circuitscaper/reference/dp_flux.md)
    and
    [`dp_directionality()`](https://matthewkling.github.io/circuitscaper/reference/dp_directionality.md)
    also map the power dissipated, which picks out choke points, and
    with `normalize = TRUE`, normalized power. Each link’s squared
    current is weighted by that link’s resistance, which squaring a
    current map and multiplying by cell resistance can’t do; it costs no
    extra solves.
  - [`dp_isolation()`](https://matthewkling.github.io/circuitscaper/reference/dp_isolation.md)
    maps how isolated each cell is from its targets, as effective
    resistance: to the habitat within a radius, or with a `destination`,
    between two distributions in both directions (each cell’s resistance
    to the destination as an origin, and from the origin as a
    destination). Two layers summarise a cell’s targets: the resistance
    to them as a set, and the mean resistance to them, each with a
    normalized version that removes the effect of geometry. Every cell
    with targets in reach gets a value, habitat or not. Each cell stands
    for a site of the cells within `site_radius` (2 pixels by default),
    since a single cell’s effective resistance is dominated by its own
    links; `site_radius = 0` gives the single-cell reading, and
    `contact = TRUE` adds each cell’s exact contact resistance. Random
    dipoles across every link give these for all cells at once, with
    per-cell standard errors (`se = TRUE`).
  - [`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)
    prepares a circuit whose factorizations several runs can reuse.
  - The `dp_*()` functions report progress through the ‘progressr’
    package: a step per factorization and, per batch of draws, for
    sampling the dipoles and for each solve. Wrap a call in
    [`progressr::with_progress()`](https://progressr.futureverse.org/reference/with_progress.html),
    or in a ‘shiny’ app
    [`progressr::withProgressShiny()`](https://progressr.futureverse.org/reference/withProgressShiny.html),
    to see it; with no handler active, nothing is shown.
    `progress = FALSE` turns it off. ‘progressr’ is a new dependency.

  These methods map squared current on the whole circuit, so their
  results differ from Circuitscape’s and Omniscape’s by design; see
  [`?dp_omni`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md).
  They are experimental.

- The dipole methods need only Julia, not the Circuitscape and Omniscape
  Julia packages. `cs_install_julia(circuitscape = FALSE)` installs
  Julia alone, and `cs_julia_available(circuitscape = FALSE)` checks
  that a recent enough Julia is found and starts.

### Changes

- [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)
  gains `normalize`, which runs Circuitscape a second time on a uniform
  surface and adds `flow_potential` and `normalized_current` layers to
  `current_map`, as in
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md).
  It is `TRUE` by default, for the same default across the package, so
  [`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md)
  now takes about twice as long and its `current_map` has these two
  extra layers after `cumulative_current`; set `normalize = FALSE` for
  the previous behaviour.

- [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  now only starts Julia. Circuitscape and Omniscape are loaded and
  warmed up on the first `cs_*()` or `os_*()` call of a session instead,
  so a session that only uses the dipole methods starts in a few seconds
  rather than 15 or more. Circuitscape and Omniscape sessions take the
  same total time as before.

### Documentation

- The getting-started vignette now covers both families of methods, with
  a guide to choosing one by question. Mode-by-mode material for
  Circuitscape and Omniscape moved to a website article, beside a new
  article on the dipole methods: usage, how they work, and how they
  compare.

### Bug fixes

- [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  now starts Julia when the Julia it finds is a shim or launcher in
  another directory, such as Chocolatey’s on Windows. It pointed
  ‘JuliaConnectoR’ at the shim’s directory, which Julia also uses to
  find its system image, so Julia failed to start (“could not load
  library …sys.dll”). It now asks Julia for its own directory first.

- `cs_install_julia(force = TRUE)` now updates Circuitscape.jl and
  Omniscape.jl even when a new release needs newer versions of their own
  dependencies. It previously held those dependencies fixed, so, for
  example, it stayed on Circuitscape.jl 6.1 instead of installing 6.2,
  which needs a newer GZip.jl.

- [`cs_one_to_all()`](https://matthewkling.github.io/circuitscaper/reference/cs_one_to_all.md)
  and
  [`cs_all_to_one()`](https://matthewkling.github.io/circuitscaper/reference/cs_all_to_one.md)
  return per-node current layers only with `cumulative_only = FALSE`, as
  documented. Circuitscape.jl before 6.2 wrote these maps regardless, so
  with older versions both functions also returned them by default.

## circuitscaper 0.2.0

CRAN release: 2026-11-06

### New features

- `cs_setup(threads = )` now restarts Julia when it is already running
  with fewer threads (or with an interactive thread, which breaks
  parallel runs of Omniscape \< 0.6.3), instead of warning that R must
  be restarted.
- If the Julia process stops during a session (for example, it crashes
  or runs out of memory, or is stopped with
  [`JuliaConnectoR::stopJulia()`](https://rdrr.io/pkg/JuliaConnectoR/man/stopJulia.html)),
  the next circuitscaper call starts and sets up Julia again, instead of
  failing with connection errors until R is restarted.

### Bug fixes

- circuitscaper now runs Julia in its own process, connected to R by
  ‘JuliaConnectoR’, instead of inside R’s process via ‘JuliaCall’. With
  Julia inside R, the libraries R had loaded clashed with the ones Julia
  bundles, and setup failed on Linux: on Ubuntu 24.04, Julia’s GDAL
  could not load because terra had already loaded the system libtiff
  (“version
  `LIBTIFF_4.6.1' not found"), and Julia could also crash on the system libunwind. 'JuliaConnectoR' also starts Julia without R's`LD_LIBRARY_PATH`, which crashed Julia's package manager. Julia packages are likewise installed in a separate Julia process with a clean library path. RCall.jl is no longer needed, and the`…`argument of`cs_setup()`(passed to`JuliaCall::julia_setup()\`)
  is gone.

- The shell and Julia commands circuitscaper runs to find and check
  Julia (including at package attach) now time out instead of
  potentially hanging, e.g. on a slow login shell profile.

- [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  and
  [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md)
  now refuse Julia versions older than 1.10 with an explanation of how
  to upgrade. On older Julia, the package manager falls back to old
  releases of Circuitscape.jl and Omniscape.jl that fail in obscure
  ways. The minimum in `SystemRequirements` is now Julia 1.10.

- [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md)
  now downloads and installs Julia itself, from the official release
  index at julialang.org, verifying each download against its published
  size and (on R \>= 4.5) SHA-256 checksum. Julia goes into
  circuitscaper’s user data directory
  (`tools::R_user_dir("circuitscaper")`) and is found automatically by
  [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md).
  Previously it used `JuliaCall::install_julia()`, which in the current
  CRAN release of ‘JuliaCall’ (0.17.6) installs Julia 1.9 when asked for
  the latest version and can’t install Julia 1.10 or later, so a fresh
  install failed with errors such as “undefined symbol: SET_SYMVALUE”.

- [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  now starts the Julia it finds explicitly, so the Julia whose version
  it checks is always the one that starts, and stops with a clear
  message if an older Julia is already running in the session.

- [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  now finds Julia wherever `JuliaCall::julia_setup()` would, instead of
  only on the PATH. Previously, a Julia installed by
  [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md)
  (which `JuliaCall::install_julia()` places outside the PATH) was not
  found in later sessions, so
  [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  failed with “Julia not found” until `julia_home` was given explicitly.
  The same applied to Julia installed via juliaup or Homebrew when R was
  started from the macOS GUI, whose PATH lacks the shell’s.
  [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md),
  [`cs_julia_available()`](https://matthewkling.github.io/circuitscaper/reference/cs_julia_available.md),
  and the startup message use the same search.

- `os_run(parallelize = TRUE)` now checks the running Julia session
  before calling Omniscape, and warns and runs serially if it cannot run
  in parallel: if Julia has only one thread, or if it was started with
  an interactive thread (e.g. `JULIA_NUM_THREADS = "4"` rather than
  `"4,0"`), which makes Omniscape releases before 0.6.3 fail with a
  BoundsError. This can happen when Julia is started outside
  [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md),
  for example by another package.

- [`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
  now records the number of threads Julia actually has, and warns when
  `threads` cannot take effect because Julia was already running
  (including when started outside circuitscaper). Previously it recorded
  the requested count, and `os_run(parallelize = TRUE)` could reset the
  record to 1 when it started Julia.

- [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  now has Omniscape write its outputs as ASCII grids rather than
  GeoTIFFs. Writing GeoTIFFs from Julia could crash R (seen on Ubuntu,
  in `TIFFClose`), most likely because Julia’s GDAL loads its own
  libtiff into a process where R’s terra has already loaded the system
  one. Inputs were already passed as ASCII grids, so Julia now never
  touches libtiff. Files kept via `output_dir` are therefore `.asc`
  rather than `.tif`.

- [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  now stops with a clear error if the resistance or conductance surface
  contains zero or negative values, which Omniscape rejects without
  writing outputs. Previously this surfaced as an obscure failure to
  read Omniscape’s output.

## circuitscaper 0.1.1

CRAN release: 2026-10-01

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
