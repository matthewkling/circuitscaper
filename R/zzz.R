# Package-level environment for storing Julia state
.cs_env <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  .cs_env$julia_ready <- FALSE
  .cs_env$loaded_packages <- character(0)
  .cs_env$julia_threads <- 1L
}

.onAttach <- function(libname, pkgname) {
  if (interactive() && nchar(Sys.which("julia")) == 0) {
    packageStartupMessage(
      "Welcome to circuitscaper! Julia was not detected on your system.\n",
      "Run cs_install_julia() to install Julia and required packages."
    )
  }
}
