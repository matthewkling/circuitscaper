# Package-level environment for storing Julia state
.cs_env <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  .cs_env$julia_ready <- FALSE
  .cs_env$loaded_packages <- character(0)
  .cs_env$julia_threads <- 1L
}
