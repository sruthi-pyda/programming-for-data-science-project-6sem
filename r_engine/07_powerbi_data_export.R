# =============================================================================
# MODULE 7: POWER BI DATA EXPORT
# Prepares aggregated, clean CSVs for direct import into Power BI
# Run after 04_modeling.R
# =============================================================================

library(data.table)
library(dplyr)

app_root  <- Sys.getenv("APP_ROOT", unset = dirname(getwd()))
data_dir  <- file.path(app_root, "data")
powerbi_dir <- file.path(data_dir, "powerbi_export")
dir.create(powerbi_dir, showWarnings = FALSE)

# ── 1. Yearly trend data ──────────────────────────────────────────────────────
dt <- fread(file.path(data_dir, "traffic_collisions_clean.csv"))

yearly <- dt[!is.na(year), .N, by = year][order(year)]
setnames(yearly, "N", "collision_count")
fwrite(yearly, file.path(powerbi_dir, "yearly_trend.csv"))
cat("Saved: yearly_trend.csv\n")

# ── 2. Hourly distribution ────────────────────────────────────────────────────
hourly <- dt[!is.na(hour), .N, by = hour][order(hour)]
setnames(hourly, "N", "collision_count")
fwrite(hourly, file.path(powerbi_dir, "hourly_distribution.csv"))
cat("Saved: hourly_distribution.csv\n")

# ── 3. Area × hour bucket heatmap data ───────────────────────────────────────
if ("hour_bucket" %in% names(dt)) {
  top10 <- dt[!is.na(area_name), .N, by = area_name][order(-N)][1:10]$area_name
  heatmap_data <- dt[area_name %in% top10 & !is.na(hour_bucket),
                     .N, by = .(area_name, hour_bucket)]
  setnames(heatmap_data, "N", "collision_count")
  fwrite(heatmap_data, file.path(powerbi_dir, "heatmap_area_hour.csv"))
  cat("Saved: heatmap_area_hour.csv\n")
}

# ── 4. Feature importance (from saved model) ─────────────────────────────────
if (requireNamespace("randomForest", quietly = TRUE)) {
  library(randomForest)
  rf_model <- readRDS(file.path(data_dir, "models", "random_forest.rds"))
  imp_df <- as.data.frame(importance(rf_model))
  imp_df$Feature <- rownames(imp_df)
  imp_df <- imp_df[order(-imp_df$MeanDecreaseAccuracy), c("Feature", "MeanDecreaseAccuracy")]
  fwrite(imp_df, file.path(powerbi_dir, "feature_importance.csv"))
  cat("Saved: feature_importance.csv\n")
}

# ── 5. Model comparison ───────────────────────────────────────────────────────
file.copy(
  file.path(data_dir, "models", "model_comparison.csv"),
  file.path(powerbi_dir, "model_comparison.csv"),
  overwrite = TRUE
)
cat("Saved: model_comparison.csv\n")

cat("\n✓ Power BI export complete. Files in:", powerbi_dir, "\n")
