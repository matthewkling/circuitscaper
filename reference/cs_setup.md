# Set Up Julia and Load Circuitscape/Omniscape

Initialize the Julia session and load the Circuitscape and Omniscape
Julia packages. This is called automatically on first use of any `cs_*`
or `os_*` function. Call explicitly to control the Julia path, number of
threads, or pre-warm the session.

## Usage

``` r
cs_setup(julia_home = NULL, threads = 1L, quiet = TRUE, ...)
```

## Arguments

- julia_home:

  Character. Path to the Julia installation directory. If `NULL`
  (default), JuliaCall searches standard locations.

- threads:

  Integer. Number of Julia threads to start. Default `1L`. Must be set
  before Julia initializes — once Julia is running, the thread count
  cannot be changed without restarting R. Set this to a value greater
  than 1 if you plan to use
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  with `parallelize = TRUE`.

- quiet:

  Logical. Suppress Julia startup messages. Default `TRUE`.

- ...:

  Additional arguments passed to
  [`JuliaCall::julia_setup()`](https://rdrr.io/pkg/JuliaCall/man/julia_setup.html).

## Value

Invisibly returns `TRUE` on success.

## Details

Following the pattern established by diffeqr, `cs_setup()` will:

- Install Julia automatically if missing (via `installJulia = TRUE`).

- Install the Circuitscape and Omniscape Julia packages if missing.

- Pass `...` through to
  [`JuliaCall::julia_setup()`](https://rdrr.io/pkg/JuliaCall/man/julia_setup.html)
  so users can set `JULIA_HOME`, `rebuild`, etc.

Once Julia is initialized, it stays warm for the R session. Subsequent
calls to `cs_setup()` return immediately.

### Threading

Julia's thread count is fixed at startup and cannot be changed
mid-session. If you need parallelization for Omniscape, set `threads`
here before calling any other circuitscaper function:

    cs_setup(threads = 4)
    os_run(resistance, radius = 50, parallelize = TRUE)

## References

Circuitscape: <https://docs.circuitscape.org/Circuitscape.jl/latest/>

Omniscape: <https://docs.circuitscape.org/Omniscape.jl/latest/>

## See also

[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md),
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)

## Examples

``` r
if (FALSE) { # \dontrun{
cs_setup()
cs_setup(threads = 4)
cs_setup(julia_home = "/usr/local/julia/bin")
} # }
```
