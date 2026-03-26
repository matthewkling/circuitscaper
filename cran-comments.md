## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* macOS (local), R 4.3.x
* GitHub Actions: macOS-latest (R release), windows-latest (R release),
  ubuntu-latest (R devel, release, oldrel-1)

## System requirement note

This package requires Julia (>= 1.9) and the Julia packages
Circuitscape.jl and Omniscape.jl. The `cs_install_julia()` function
handles installation of all Julia dependencies.

All examples use `@examplesIf` to check for a working Julia +
Circuitscape installation before running. Tests that require Julia are
skipped on CRAN via `skip_on_cran()`. The package installs and operates
correctly without Julia present - users receive an informative startup
message directing them to `cs_install_julia()`.
