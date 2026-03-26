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

  Character. Path to the Julia `bin/` directory. If `NULL` (default),
  the system PATH and common locations are searched.

- threads:

  Integer. Number of Julia threads to start. Default `1L`. Must be set
  before Julia initializes — once Julia is running, the thread count
  cannot be changed without restarting R. This setting controls
  parallelism for
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  only; Circuitscape functions (`cs_*`) run single-threaded regardless
  of this value.

- quiet:

  Logical. Suppress Julia startup messages. Default `TRUE`.

- ...:

  Additional arguments passed to
  [`JuliaCall::julia_setup()`](https://rdrr.io/pkg/JuliaCall/man/julia_setup.html).

## Value

Invisibly returns `TRUE` on success.

## Details

`cs_setup()` does **not** install Julia or Julia packages. If Julia is
not found or the required packages are missing, it throws an informative
error directing you to
[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md).

`cs_setup()` will:

- Verify that Julia is installed and accessible.

- Verify that the Circuitscape and Omniscape Julia packages are
  installed.

- Load both packages and warm up the JIT compiler.

Once Julia is initialized, it stays warm for the R session. Subsequent
calls to `cs_setup()` return immediately.

### Threading

Julia's thread count is fixed at startup and cannot be changed
mid-session. Multi-threading is used by
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
when `parallelize = TRUE`. Circuitscape functions (`cs_pairwise`,
`cs_one_to_all`, etc.) do not benefit from multiple threads.

    cs_setup(threads = 4)
    os_run(resistance, radius = 50, parallelize = TRUE)

## References

McRae, B.H. (2006). Isolation by resistance. *Evolution*, 60(8),
1551–1561.
[doi:10.1111/j.0014-3820.2006.tb00500.x](https://doi.org/10.1111/j.0014-3820.2006.tb00500.x)

Landau, V.A., Shah, V.B., Anantharaman, R. & Hall, K.R. (2021).
Omniscape.jl: Software to compute omnidirectional landscape
connectivity. *Journal of Open Source Software*, 6(57), 2829.
[doi:10.21105/joss.02829](https://doi.org/10.21105/joss.02829)

Circuitscape.jl: <https://docs.circuitscape.org/Circuitscape.jl/latest/>

Omniscape.jl: <https://docs.circuitscape.org/Omniscape.jl/latest/>

## See also

[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md),
[`cs_pairwise()`](https://matthewkling.github.io/circuitscaper/reference/cs_pairwise.md),
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)

## Examples

``` r
if (FALSE) { # circuitscaper:::julia_check()
cs_setup()
cs_setup(threads = 4)
cs_setup(julia_home = "/usr/local/julia/bin")
}
```
