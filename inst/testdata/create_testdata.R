# Script to generate small test rasters for unit/integration testing
# Run this once to create the test data files

library(terra)

set.seed(42)

# Small 10x10 resistance surface
resistance <- rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                   ymin = 0, ymax = 10, vals = runif(100, 1, 10))
writeRaster(resistance, "inst/testdata/resistance.asc",
            overwrite = TRUE, NAflag = -9999)

# Focal node locations (3 nodes)
locations <- rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                  ymin = 0, ymax = 10, vals = 0)
locations[2, 2] <- 1
locations[2, 9] <- 2
locations[9, 5] <- 3
writeRaster(locations, "inst/testdata/locations.asc",
            overwrite = TRUE, NAflag = -9999)
