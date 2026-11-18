# Set Up Julia

Start the Julia session that circuitscaper's functions run in. This is
called automatically on first use of any `cs_*()`, `os_*()` or `dp_*()`
function. Call it explicitly to control the Julia path or the number of
threads, ideally at the start of your session.

## Usage

``` r
cs_setup(julia_home = NULL, threads = 1L, quiet = TRUE)
```

## Arguments

- julia_home:

  Character. Path to the Julia `bin/` directory. If `NULL` (default),
  Julia is looked for in: the `JULIA_HOME` option or environment
  variable, the `JULIA_BINDIR` environment variable, a Julia installed
  by
  [`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md)
  (or by `JuliaCall::install_julia()`), the system PATH (including a
  login shell's PATH on macOS and Linux), and common Windows install
  locations.

- threads:

  Integer. Number of Julia threads. Default `1L`. If Julia is already
  running with fewer threads, it is restarted with `threads` threads
  (see Threading, below). This setting controls parallelism for
  [`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
  and the dipole methods (`dp_*`); Circuitscape functions (`cs_*`) run
  single-threaded regardless of this value.

- quiet:

  Logical. Suppress Julia startup messages. Default `TRUE`.

## Value

Invisibly returns `TRUE` on success.

## Details

`cs_setup()` does **not** install Julia or Julia packages. If Julia is
not found, it throws an informative error directing you to
[`cs_install_julia()`](https://matthewkling.github.io/circuitscaper/reference/cs_install_julia.md).

`cs_setup()` verifies that Julia is installed and accessible, and starts
it with the requested threads. Julia runs in its own process, connected
to R by 'JuliaConnectoR'.

The Circuitscape and Omniscape Julia packages are loaded later, the
first time a `cs_*()` or `os_*()` function runs: that call checks they
are installed, loads them and warms up Julia's compiler, which takes a
few seconds to a minute once per session. The dipole methods (`dp_*()`)
need neither package, so a session that only uses them skips that step.

Once Julia is initialized, it stays warm for the R session. Subsequent
calls to `cs_setup()` return immediately. If the Julia process has
stopped in the meantime (for example, it crashed or ran out of memory,
or was stopped with
[`JuliaConnectoR::stopJulia()`](https://rdrr.io/pkg/JuliaConnectoR/man/stopJulia.html)),
the next `cs_setup()` call, or the next `cs_*()`, `os_*()` or `dp_*()`
call, starts and sets up Julia again.

### Threading

Multi-threading is used by
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
when `parallelize = TRUE`, and always by the dipole methods (e.g.,
[`dp_omni()`](https://matthewkling.github.io/circuitscaper/reference/dp_omni.md)).
Circuitscape functions (`cs_pairwise`, `cs_one_to_all`, etc.) do not
benefit from multiple threads.

    cs_setup(threads = 4)
    os_run(resistance, radius = 50, parallelize = TRUE)

Julia's thread count is fixed when Julia starts, so if Julia is already
running with fewer threads, `cs_setup(threads = )` restarts it. After a
restart, Circuitscape and Omniscape are loaded and warmed up again on
the next `cs_*()` or `os_*()` call, and circuits from
[`dp_circuit()`](https://matthewkling.github.io/circuitscaper/reference/dp_circuit.md)
are rebuilt when next used. A restart also discards anything else in
this R session's Julia (e.g., objects created through 'JuliaConnectoR'
by other code). Asking for fewer threads than Julia has doesn't restart
it.

Julia is started with `JULIA_NUM_THREADS` set to `"N,0"`: N threads and
no interactive threads. Omniscape releases before 0.6.3 fail in parallel
when Julia has an interactive thread, so `cs_setup(threads = )` also
restarts a Julia that has one, and
[`os_run()`](https://matthewkling.github.io/circuitscaper/reference/os_run.md)
falls back to a serial run with a warning if it finds one.

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
if (FALSE) { # circuitscaper::cs_julia_available()
cs_setup()
cs_setup(threads = 4)
cs_setup(julia_home = "/usr/local/julia/bin")
DONTSHOW({JuliaConnectoR::stopJulia()})
}
```
