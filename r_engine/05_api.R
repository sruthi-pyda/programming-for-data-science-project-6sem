# =============================================================================
# MODULE 5: PLUMBER REST API
# Serves predictions from the trained Random Forest model to the Flutter app
# Run: plumber::plumb("05_api.R")$run(port = 8000, host = "0.0.0.0")
# =============================================================================

library(plumber)
library(randomForest)
library(data.table)

# ── Load artefacts at startup ─────────────────────────────────────────────────
models_dir   <- file.path(dirname(getwd()), "data", "models")
best_model   <- readRDS(file.path(models_dir, "random_forest.rds"))
area_ranking <- fread(file.path(dirname(getwd()), "data", "area_risk_ranking.csv"))
cluster_data <- fread(file.path(dirname(getwd()), "data", "hotspot_clusters.csv"))

# ── CORS helper (Flutter on emulator/device needs this) ──────────────────────
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

# ── Health Check ──────────────────────────────────────────────────────────────
#* @get /health
#* @serializer json
function() {
  list(status = "ok", model = "Random Forest", version = "1.0")
}

# ── Predict Risk Level ────────────────────────────────────────────────────────
#* Predict accident risk for a given area/time/premise combination
#*
#* @param area:int      LAPD area code (1–21)
#* @param hour:int      Hour of day (0–23)
#* @param month_num:int Month number (1–12)
#* @param premis_cd:int Premise code
#* @param avg_victim_age:double  Average victim age (default 35)
#* @param avg_severity:double    Average MO code count (default 2)
#*
#* @get /predict
#* @serializer json
function(area = 1, hour = 12, month_num = 6,
         premis_cd = 101, avg_victim_age = 35, avg_severity = 2) {

  input <- data.frame(
    area           = as.integer(area),
    hour           = as.integer(hour),
    month_num      = as.integer(month_num),
    premis_cd      = as.integer(premis_cd),
    avg_victim_age = as.numeric(avg_victim_age),
    avg_severity   = as.numeric(avg_severity)
  )

  predicted_class <- as.character(predict(best_model, input))
  probabilities   <- as.data.frame(predict(best_model, input, type = "prob"))

  risk_color <- switch(predicted_class,
    "Low"    = "#2A9D8F",
    "Medium" = "#E9C46A",
    "High"   = "#E63946",
    "#999999"
  )

  list(
    risk_level  = predicted_class,
    risk_color  = risk_color,
    probability = list(
      Low    = round(probabilities$Low,    4),
      Medium = round(probabilities$Medium, 4),
      High   = round(probabilities$High,   4)
    ),
    input = input
  )
}

# ── Batch Predict (POST) ─────────────────────────────────────────────────────
#* Predict risk for multiple combinations at once
#*
#* @post /predict/batch
#* @serializer json
function(req) {
  body <- jsonlite::fromJSON(req$postBody)
  df   <- as.data.frame(body)

  required_cols <- c("area", "hour", "month_num", "premis_cd")
  if (!all(required_cols %in% names(df))) {
    return(list(error = paste("Missing columns:", paste(setdiff(required_cols, names(df)), collapse = ", "))))
  }

  if (!"avg_victim_age" %in% names(df)) df$avg_victim_age <- 35
  if (!"avg_severity"   %in% names(df)) df$avg_severity   <- 2

  predictions   <- as.character(predict(best_model, df))
  probabilities <- as.data.frame(predict(best_model, df, type = "prob"))

  result <- df
  result$risk_level  <- predictions
  result$prob_low    <- round(probabilities$Low,    4)
  result$prob_medium <- round(probabilities$Medium, 4)
  result$prob_high   <- round(probabilities$High,   4)

  result
}

# ── Area Risk Rankings ────────────────────────────────────────────────────────
#* Get ranked list of all LAPD areas by composite risk score
#*
#* @param top:int  Number of top areas to return (default 10, max 21)
#*
#* @get /areas/ranking
#* @serializer json
function(top = 10) {
  n <- min(as.integer(top), nrow(area_ranking))
  as.list(area_ranking[1:n])
}

# ── Hotspot Clusters ──────────────────────────────────────────────────────────
#* Get top N accident hotspot clusters
#*
#* @param top:int  Number of clusters to return (default 20)
#*
#* @get /hotspots
#* @serializer json
function(top = 20) {
  n <- min(as.integer(top), nrow(cluster_data))
  as.list(cluster_data[1:n])
}
