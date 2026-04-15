# ── Stage 1: Base R image with required packages ──────────────────────────────
FROM rocker/r-ver:4.3.2

LABEL maintainer="sruthi-pyda"
LABEL description="US Road Safety – R Plumber API"
LABEL version="1.0"

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c( \
    'plumber', \
    'randomForest', \
    'data.table', \
    'jsonlite', \
    'dplyr' \
  ), repos = 'https://cloud.r-project.org', Ncpus = 2)"

# ── Stage 2: Copy project files ───────────────────────────────────────────────
WORKDIR /app

# Copy R engine scripts
COPY r_engine/ ./r_engine/

# Copy pre-trained model artifacts and supporting data
COPY data/models/           ./data/models/
COPY data/area_risk_ranking.csv ./data/
COPY data/hotspot_clusters.csv  ./data/

# ── Expose API port ───────────────────────────────────────────────────────────
EXPOSE 8000

# ── Entrypoint: start the Plumber API ────────────────────────────────────────
CMD ["Rscript", "/app/r_engine/entrypoint.R"]
