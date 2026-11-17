# circuitscaper

An R package wrapping Circuitscape.jl and Omniscape.jl for landscape connectivity. Users work with terra SpatRasters; Julia runs in its own process through JuliaConnectoR (`R/julia-backend.R`), and circuitscaper writes INI files and calls Circuitscape and Omniscape under the hood. The package is on CRAN (0.2.0); `main` is the development version.

## Layout

- `R/cs-*.R`: the Circuitscape modes (`cs_pairwise()`, `cs_one_to_all()`, `cs_all_to_one()`, `cs_advanced()`).
- `R/os-run.R`, `R/os-condition.R`: Omniscape.
- `R/config.R`, `R/io.R`, `R/utils.R`: INI writing and output parsing.
- `R/setup.R`, `R/julia-*.R`, `R/install-julia.R`, `R/threads.R`: Julia discovery, installation, startup and threads.
- `inst/julia/`: Julia code loaded into the session.
- `tests/testthat/`: unit tests, plus Julia integration tests (`test-integration.R`) that skip without Julia unless `CIRCUITSCAPER_REQUIRE_JULIA=true`, as in the `julia-integration` CI workflow.
- `notes`: Matt's informal design notes.
- `dev/`: development material, not built into the package (see below).

## Working conventions

- Run `devtools::document()` after changing roxygen comments, and `devtools::test()` before finishing. Integration tests need a working Julia (`cs_setup()`).
- Add a NEWS.md entry for user-visible changes.
- Keep CRAN in mind: no network access or Julia in examples or tests on CRAN; keep `R CMD check` clean.
- Anything under `dev/` must stay out of the package build (it is in `.Rbuildignore`).

## Current project: dipole methods

New `dp_*()` functions implementing the "dipole methods": fast omnidirectional, focal-node and cross-era connectivity from superposed random dipoles on a single factored circuit. Start with **`dev/dipole/SPEC.md`**. It is the implementation contract: scope, definitions, architecture, test oracles and pitfalls.

- `dev/dipole/background.md` has the full design history and evidence; `SPEC.md` wins where they differ.
- `dev/dipole/prototype/` holds the reference R prototype. The Julia implementation must reproduce it (SPEC §5); don't edit the prototype files.
- `dev/dipole/reference/` holds reference outputs for tests.
- Ask Matt before settling the open questions in SPEC §7, or before changing anything the spec marks as decided.
