# Install Julia and Required Packages

Downloads and installs Julia, Circuitscape.jl, and Omniscape.jl. This is
the recommended first step after installing the circuitscaper R package.
If you only use the dipole methods (`dp_*()`), `circuitscape = FALSE`
installs Julia alone, which is faster and smaller.

## Usage

``` r
cs_install_julia(force = FALSE, version = "latest", circuitscape = TRUE)
```

## Arguments

- force:

  Logical. If `TRUE`, download and install Julia even if a Julia
  installation is already present, and reinstall the Julia packages. Use
  this to replace a Julia installation that is too old. Default `FALSE`.

- version:

  Character. Julia version to install, e.g. `"1.12.1"`. Default
  `"latest"`, the latest stable release. Must be at least 1.10.

- circuitscape:

  Logical. Install the Circuitscape and Omniscape Julia packages, which
  the `cs_*()` and `os_*()` functions need. Default `TRUE`. If `FALSE`,
  only Julia (and Tables.jl, which 'JuliaConnectoR' uses) is installed:
  enough for the dipole methods (`dp_*()`). Run `cs_install_julia()`
  again later to add the packages.

## Value

Invisibly returns `TRUE` on success, `FALSE` if cancelled.

## Details

In interactive sessions, prompts for confirmation before downloading. In
non-interactive sessions (e.g., CI), proceeds without prompting.

If no suitable Julia is found (see
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
for where it looks), or if `force = TRUE`, the official Julia release
for your platform is downloaded from julialang.org, checked against its
published size and checksum, and unpacked into circuitscaper's user data
directory (`tools::R_user_dir("circuitscaper", "data")`). That Julia is
then used by
[`cs_setup()`](https://matthewkling.github.io/circuitscaper/reference/cs_setup.md)
in later sessions. Julia installed by other means (e.g., juliaup or the
official installers) works too; in that case `cs_install_julia()` just
adds the Julia packages.

The Julia packages are installed into Julia's default package depot
(usually `~/.julia`), as with any Julia installation.

## Examples

``` r
if (FALSE) { # \dontrun{
cs_install_julia()

# Only the dipole methods
cs_install_julia(circuitscape = FALSE)
} # }
```
