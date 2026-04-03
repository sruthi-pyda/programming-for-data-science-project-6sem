# Run this file to start the Plumber API server
# In R console: source("run_api.R")
# Or in terminal: Rscript run_api.R

if (!requireNamespace("plumber", quietly = TRUE)) {
  install.packages("plumber", repos = "https://cloud.r-project.org")
}

library(plumber)

api <- plumber::plumb(file.path(getwd(), "05_api.R"))
api$run(port = 8000, host = "0.0.0.0", swagger = TRUE)
# Swagger UI will be available at http://localhost:8000/__docs__/
