# Install Julia and Required Packages

One-time helper that installs Julia and the Circuitscape and Omniscape
Julia packages. Intended for first-time users.

## Usage

``` r
cs_install_julia(version = "latest")
```

## Arguments

- version:

  Character. Julia version to install. Default `"latest"`.

## Value

Invisibly returns `TRUE` on success.

## Examples

``` r
if (FALSE) { # \dontrun{
cs_install_julia()
} # }
```
