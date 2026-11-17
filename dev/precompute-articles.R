# Knit the website articles from their .Rmd.orig sources.
#
# The articles run Julia, which the pkgdown CI doesn't have, so they are
# knitted here and the generated .Rmd files and figures committed; pkgdown
# then renders them without running any code. Rerun after changing an
# article's .orig file or anything that changes its output.
#
# From the package root: Rscript dev/precompute-articles.R

devtools::load_all(quiet = TRUE)
cs_setup(threads = 4)

dir <- "vignettes/articles"
unlink(file.path(dir, "figures"), recursive = TRUE)
for (f in list.files(dir, "\\.Rmd\\.orig$")) {
  withr::with_dir(dir, knitr::knit(f, sub("\\.orig$", "", f), envir = new.env(), quiet = TRUE))
}
JuliaConnectoR::stopJulia()
