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
cs_install_julia()
#> Julia already installed at: /usr/local/julia1.12.5/bin
#> Initializing Julia...
#> Warning: running command ''/usr/local/julia1.12.5/bin/julia' '--startup-file=no' '/home/runner/work/_temp/Library/JuliaCall/julia/install_dependency.jl' '/opt/R/4.5.3/lib/R' 2>&1' had status 139
#> Error in .julia$cmd(paste0(Rhomeset, "Base.include(Main,\"", system.file("julia/setup.jl",     package = "JuliaCall"), "\")")): Error happens when you try to execute command ENV["R_HOME"] = "/opt/R/4.5.3/lib/R";Base.include(Main,"/home/runner/work/_temp/Library/JuliaCall/julia/setup.jl") in Julia.
#>                         To have more helpful error messages,
#>                         you could considering running the command in Julia directly
cs_install_julia(force = TRUE)
#> Installing Julia...
#> [1] "Installed Julia to /home/runner/.local/share/R/JuliaCall/julia/1.9.4/julia-1.9.4"
#> Initializing Julia...
#> Warning: running command ''/usr/local/julia1.12.5/bin/julia' '--startup-file=no' '/home/runner/work/_temp/Library/JuliaCall/julia/install_dependency.jl' '/opt/R/4.5.3/lib/R' 2>&1' had status 139
#> Error in .julia$cmd(paste0(Rhomeset, "Base.include(Main,\"", system.file("julia/setup.jl",     package = "JuliaCall"), "\")")): Error happens when you try to execute command ENV["R_HOME"] = "/opt/R/4.5.3/lib/R";Base.include(Main,"/home/runner/work/_temp/Library/JuliaCall/julia/setup.jl") in Julia.
#>                         To have more helpful error messages,
#>                         you could considering running the command in Julia directly
```
