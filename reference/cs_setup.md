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
[doi:10.1111/j.1558-5646.2006.tb00500.x](https://doi.org/10.1111/j.1558-5646.2006.tb00500.x)

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
# \donttest{
cs_setup()
#> Initializing Julia (one-time per session)...
#> Warning: running command ''/usr/local/julia1.12.5/bin/julia' '--startup-file=no' '/home/runner/work/_temp/Library/JuliaCall/julia/install_dependency.jl' '/opt/R/4.5.3/lib/R' 2>&1' had status 139
#> Error in .julia$cmd(paste0(Rhomeset, "Base.include(Main,\"", system.file("julia/setup.jl",     package = "JuliaCall"), "\")")): Error happens when you try to execute command ENV["R_HOME"] = "/opt/R/4.5.3/lib/R";Base.include(Main,"/home/runner/work/_temp/Library/JuliaCall/julia/setup.jl") in Julia.
#>                         To have more helpful error messages,
#>                         you could considering running the command in Julia directly
cs_setup(threads = 4)
#> Initializing Julia (one-time per session)...
#> Warning: running command ''/usr/local/julia1.12.5/bin/julia' '--startup-file=no' '/home/runner/work/_temp/Library/JuliaCall/julia/install_dependency.jl' '/opt/R/4.5.3/lib/R' 2>&1' had status 139
#> Error in .julia$cmd(paste0(Rhomeset, "Base.include(Main,\"", system.file("julia/setup.jl",     package = "JuliaCall"), "\")")): Error happens when you try to execute command ENV["R_HOME"] = "/opt/R/4.5.3/lib/R";Base.include(Main,"/home/runner/work/_temp/Library/JuliaCall/julia/setup.jl") in Julia.
#>                         To have more helpful error messages,
#>                         you could considering running the command in Julia directly
cs_setup(julia_home = "/usr/local/julia/bin")
#> Initializing Julia (one-time per session)...
#> Error in (function (JULIA_HOME = NULL, verbose = TRUE, installJulia = FALSE,     install = TRUE, force = FALSE, useRCall = TRUE, rebuild = FALSE,     sysimage_path = NULL, version = "latest") {    if (!force && .julia$initialized) {        return(invisible(julia))    }    notebook <- check_notebook()    verbose <- verbose && (!notebook)    JULIA_HOME <- julia_locate(JULIA_HOME)    if (is.null(JULIA_HOME)) {        if (isTRUE(installJulia)) {            install_julia(version)            JULIA_HOME <- julia_locate(JULIA_HOME)            if (is.null(JULIA_HOME))                 stop("Julia is not found and automatic installation failed.")        }        else {            stop("Julia is not found.")        }    }    if (is.null(sysimage_path)) {        img_abs_path <- ""    }    else {        img_abs_path <- normalizePath(sysimage_path, mustWork = F)        if (!file.exists(img_abs_path))             stop("sysimage at path: ", img_abs_path, " is not found. ",                 "You have to specify the path relative to the current ",                 "directory or as an absolute path.")    }    .julia$bin_dir <- JULIA_HOME    .julia$VERSION <- julia_line(c("-e", "print(VERSION)"), stdout = TRUE)    if (newer("0.5.3", .julia$VERSION)) {        stop(paste0("Julia version ", .julia$VERSION, " at location ",             JULIA_HOME, " is found.", " But the version is too old and is not supported. Please install current release julia from https://julialang.org/downloads/ to use JuliaCall"))    }    if (verbose)         message(paste0("Julia version ", .julia$VERSION, " at location ",             JULIA_HOME, " will be used."))    dll_command <- system.file("julia/libjulia.jl", package = "JuliaCall")    .julia$dll_file <- julia_line(dll_command, stdout = TRUE)    if (!is.character(.julia$dll_file)) {        stop("libjulia cannot be located.")    }    if (!isTRUE(file.exists(.julia$dll_file))) {        stop("libjulia located at ", .julia$dll_file, " is not a valid file.")    }    if (.Platform$OS.type == "windows") {        if (newer("0.6.5", .julia$VERSION)) {            libm <- julia_line(c("-e", "print(Libdl.dlpath(Base.libm_name))"),                 stdout = TRUE)            dyn.load(libm, DLLpath = .julia$bin_dir)        }        cur_dir <- getwd()        setwd(.julia$bin_dir)        on.exit(setwd(cur_dir))    }    if (identical(get_os(), "osx")) {        cur_dir <- getwd()        setwd(dirname(.julia$dll_file))        on.exit(setwd(cur_dir))    }    if (!identical(get_os(), "osx")) {        try(dyn.load(.julia$dll_file))    }    juliacall_initialize(.julia$dll_file, .julia$bin_dir, img_abs_path)    .julia$cmd <- function(cmd) {        if (!(length(cmd) == 1 && is.character(cmd))) {            stop("cmd should be a character scalar.")        }        if (!juliacall_cmd(cmd)) {            stop(paste0("Error happens when you try to execute command ",                 cmd, " in Julia.\n                        To have more helpful error messages,\n                        you could considering running the command in Julia directly"))        }    }    reg.finalizer(.julia, function(e) {        message("Julia exit.")        juliacall_atexit_hook(0)    }, onexit = TRUE)    Rhomeset <- paste0("ENV[\"R_HOME\"] = \"", R.home(), "\";")    if (verbose)         message("Loading setup script for JuliaCall...")    if (isTRUE(install)) {        install_dependency()    }    if (isTRUE(rebuild)) {        rebuild()    }    if (!newer(.julia$VERSION, "0.7.0")) {        .julia$cmd(paste0(Rhomeset, "include(\"", system.file("julia/setup.jl",             package = "JuliaCall"), "\")"))    }    else {        .julia$cmd(paste0(Rhomeset, "Base.include(Main,\"", system.file("julia/setup.jl",             package = "JuliaCall"), "\")"))    }    if (verbose)         message("Finish loading setup script for JuliaCall.")    .julia$do.call_ <- juliacall_docall    julia$VERSION <- .julia$VERSION    .julia$rmd <- check_rmd() || notebook    .julia$notebook <- notebook    julia$useRCall <- useRCall    .julia$initialized <- TRUE    if (useRCall) {        julia$command("using RCall")        julia$command("Base.atreplinit(JuliaCall.setup_repl);")    }    if (interactive()) {        julia_command("Core.eval(Base, :(is_interactive = true));")    }    if (isTRUE(getOption("jupyter.in_kernel"))) {        julia_command("Base.pushdisplay(JuliaCall.irjulia_display);")    }    if (.julia$rmd) {        julia_command("Base.pushdisplay(JuliaCall.rmd_display);")    }    julia_command("ENV[\"GKSwstype\"]=\"pdf\";")    julia_command("ENV[\"GKS_FILEPATH\"] = tempdir();")    julia_command("ENV[\"MPLBACKEND\"] = \"Agg\";")    .julia$simple_call_ <- julia_eval("JuliaCall.simple_call")    if (.Platform$OS.type == "windows") {        Sys.setenv(PATH = paste0(Sys.getenv("PATH"), ";", .julia$bin_dir))    }    invisible(julia)})(installJulia = FALSE, JULIA_HOME = "/usr/local/julia/bin"): Julia is not found.
# }
```
