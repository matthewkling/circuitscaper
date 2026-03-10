library(terra)

set.seed(123)
r <- focal(rast(matrix(runif(2500)^.25, 50)), w = 5, fun = mean, na.rm = TRUE)
r <- focal(r, w = 3, fun = mean, na.rm = TRUE)
r <- app(r, function(x) scales::rescale(x, to = c(1, 100)))

res <- r
res[r[] < 45] <- 1
res[r[] >= 45 & r[] < 55] <- 10
res[r[] >= 55 & r[] < 65] <- 100
res[r[] >= 65] <- 1000
names(res) <- "resistance"
writeRaster(res, "inst/extdata/resistance.tif", overwrite = TRUE)

source <- res
source[] <- 0
source[45:50, 14:19] <- 1
source <- focal(source, w = 7, fun = mean, na.rm = TRUE)
names(source) <- "source"
writeRaster(source, "inst/extdata/source.tif", overwrite = TRUE)

ground <- res
ground[] <- 0
ground[1:5, 25:30] <- 1
ground <- focal(ground, w = 7, fun = mean, na.rm = TRUE)
names(ground) <- "ground"
writeRaster(ground, "inst/extdata/ground.tif", overwrite = TRUE)
