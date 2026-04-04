# Entrypoint for Docker container
# Resolves paths relative to /app (container working directory)

library(plumber)

# Override path resolution for container environment
Sys.setenv(APP_ROOT = "/app")

api <- plumber::plumb("/app/r_engine/05_api.R")
api$run(host = "0.0.0.0", port = 8000, swagger = TRUE)
