# =============================================================================
# MODULE 5: PLUMBER REST API
# Serves predictions from the trained Random Forest model to the Flutter app
# Run: plumber::plumb("05_api.R")$run(port = 8000, host = "0.0.0.0")
# =============================================================================

library(plumber)
library(randomForest)
library(data.table)

# ── Load artefacts at startup ─────────────────────────────────────────────────
# Supports both local dev (r_engine/ subfolder) and Docker (/app root)
app_root     <- Sys.getenv("APP_ROOT", unset = dirname(getwd()))
models_dir   <- file.path(app_root, "data", "models")
best_model   <- readRDS(file.path(models_dir, "random_forest.rds"))
area_ranking <- fread(file.path(app_root, "data", "area_risk_ranking.csv"))
cluster_data <- fread(file.path(app_root, "data", "hotspot_clusters.csv"))

# ── Helper: build input data.frame with all required features ─────────────────
make_input <- function(area, hour, month_num, day_num, premis_cd,
                       avg_victim_age, avg_severity, avg_hist_freq, prop_female,
                       area_mean = 10000, hour_mean = 25000,
                       area_hour_mean = 1000, area_month_mean = 1200,
                       area_day_mean = 800, hour_day_mean = 900,
                       premis_mean = 500) {
  h <- as.integer(hour)
  m <- as.integer(month_num)
  d <- as.integer(day_num)
  data.frame(
    area             = as.integer(area),
    hour             = h,
    month_num        = m,
    day_num          = d,
    premis_cd        = as.integer(premis_cd),
    avg_victim_age   = as.numeric(avg_victim_age),
    avg_severity     = as.numeric(avg_severity),
    avg_hist_freq    = as.numeric(avg_hist_freq),
    prop_female      = as.numeric(prop_female),
    area_hour_mean   = as.numeric(area_hour_mean),
    area_month_mean  = as.numeric(area_month_mean),
    area_day_mean    = as.numeric(area_day_mean),
    hour_day_mean    = as.numeric(hour_day_mean),
    area_mean        = as.numeric(area_mean),
    premis_mean      = as.numeric(premis_mean),
    hour_mean        = as.numeric(hour_mean),
    is_weekend       = as.integer(d %in% c(1L, 7L)),
    hour_sin         = sin(2 * pi * h / 24),
    hour_cos         = cos(2 * pi * h / 24),
    month_sin        = sin(2 * pi * m / 12),
    month_cos        = cos(2 * pi * m / 12)
  )
}

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
  list(status = "ok", model = "Random Forest", version = "2.0")
}

# ── Predict Risk Level ────────────────────────────────────────────────────────
#* Predict accident risk for a given area/time/premise combination
#*
#* @param area:int      LAPD area code (1–21)
#* @param hour:int      Hour of day (0–23)
#* @param month_num:int Month number (1–12)
#* @param day_num:int   Day of week (1=Sun … 7=Sat, default 4=Wed)
#* @param premis_cd:int Premise code
#* @param avg_victim_age:double  Average victim age (default 35)
#* @param avg_severity:double    Average MO code count (default 2)
#* @param avg_hist_freq:double   Historical frequency (default 100)
#* @param prop_female:double     Proportion female victims (default 0.5)
#*
#* @get /predict
#* @serializer json
function(area = 1, hour = 12, month_num = 6, day_num = 4,
         premis_cd = 101, avg_victim_age = 35, avg_severity = 2,
         avg_hist_freq = 100, prop_female = 0.5) {

  input <- make_input(area, hour, month_num, day_num, premis_cd,
                      avg_victim_age, avg_severity, avg_hist_freq, prop_female)

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

  if (!"day_num"          %in% names(df)) df$day_num          <- 4L
  if (!"avg_victim_age"   %in% names(df)) df$avg_victim_age   <- 35
  if (!"avg_severity"     %in% names(df)) df$avg_severity     <- 2
  if (!"avg_hist_freq"    %in% names(df)) df$avg_hist_freq    <- 100
  if (!"prop_female"      %in% names(df)) df$prop_female      <- 0.5
  if (!"area_total"       %in% names(df)) df$area_total       <- 10000
  if (!"hour_total"       %in% names(df)) df$hour_total       <- 25000
  if (!"area_hour_total"  %in% names(df)) df$area_hour_total  <- 1000
  if (!"area_day_total"   %in% names(df)) df$area_day_total   <- 5000

  df$is_weekend <- as.integer(df$day_num %in% c(1L, 7L))
  df$hour_sin   <- sin(2 * pi * df$hour / 24)
  df$hour_cos   <- cos(2 * pi * df$hour / 24)
  df$month_sin  <- sin(2 * pi * df$month_num / 12)
  df$month_cos  <- cos(2 * pi * df$month_num / 12)

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
