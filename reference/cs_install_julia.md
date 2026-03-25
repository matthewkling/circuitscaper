# Install Julia and Required Packages

Downloads and installs Julia, Circuitscape.jl, and Omniscape.jl. This is
the recommended first step after installing the circuitscaper R package.

## Usage

``` r
cs_install_julia(force = FALSE, version = "latest")
```

## Arguments

- force:

  Logical. If `TRUE`, reinstall Julia and packages even if they appear
  to be already present. Default `FALSE`.

- version:

  Character. Julia version to install. Default `"latest"`.

## Value

Invisibly returns `TRUE` on success, `FALSE` if cancelled.

## Details

In interactive sessions, prompts for confirmation before downloading. In
non-interactive sessions (e.g., CI), proceeds without prompting.

## Examples

``` r
if (FALSE) { # circuitscaper:::julia_check()
cs_install_julia()
cs_install_julia(force = TRUE)
}
```
