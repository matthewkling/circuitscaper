## R CMD check results

0 errors | 0 warnings | 0 notes

<!-- Confirm the results and environments below after the local and
win-builder checks. -->

## Test environments

* macOS (local), R release
* win-builder: R devel
* GitHub Actions: macOS-latest (R release), windows-latest (R release),
  ubuntu-latest (R devel, release, oldrel-1)
* GitHub Actions with Julia installed (macOS, Windows, Ubuntu; Julia 1.10
  and the current release), running the full test suite including
  installation from scratch

## Changes in this version

The package now connects to Julia through 'JuliaConnectoR' instead of
'JuliaCall', which fixes setup failures that users reported on all three
platforms. See NEWS.md.

## System requirement note

This package requires Julia (>= 1.10) and the Julia packages
Circuitscape.jl and Omniscape.jl. The `cs_install_julia()` function
installs them when the user calls it (it asks for confirmation in
interactive sessions). It downloads Julia from julialang.org into
`tools::R_user_dir("circuitscaper", "data")`, and installs the Julia
packages into Julia's own package depot. Nothing is downloaded or
installed otherwise.

All examples use `@examplesIf` to check for a working Julia +
Circuitscape installation before running. Tests that require Julia are
skipped on CRAN via `skip_on_cran()`. The package installs and operates
correctly without Julia present - users receive an informative startup
message directing them to `cs_install_julia()`.
