# =============================================================================
# MODULE 3: SPATIAL ANALYSIS & HOTSPOT DETECTION
# US Road Accident Intelligence & Risk Prediction System
# =============================================================================

required_packages <- c("data.table", "dplyr", "ggplot2", "sf", "dbscan", "scales")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if (length(new_packages)) install.packages(new_packages, repos = "https://cloud.r-project.org")

library(data.table)
library(dplyr)
library(ggplot2)
library(sf)
library(dbscan)
library(scales)

# ── Load Cleaned Data ─────────────────────────────────────────────────────────
dt <- fread(file.path(dirname(getwd()), "data", "traffic_collisions_clean.csv"))

# Filter to rows with valid coordinates
spatial_dt <- dt[!is.na(lat) & !is.na(lon)]
cat(sprintf("Rows with valid coordinates: %d\n", nrow(spatial_dt)))

plots_dir <- file.path(dirname(getwd()), "data", "eda_plots")
dir.create(plots_dir, showWarnings = FALSE)

save_plot <- function(p, filename, w = 10, h = 8) {
  ggsave(file.path(plots_dir, filename), plot = p, width = w, height = h, dpi = 150)
  cat(sprintf("Saved: %s\n", filename))
}

theme_set(theme_minimal(base_size = 12))

# ── 1. Basic Scatter Map of All Collisions ────────────────────────────────────
cat("\nGenerating scatter map...\n")

# Sample for plotting performance (use all rows for actual analysis)
sample_n <- min(50000L, nrow(spatial_dt))
map_sample <- spatial_dt[sample(.N, sample_n)]

p_scatter <- ggplot(map_sample, aes(x = lon, y = lat)) +
  geom_point(alpha = 0.08, size = 0.3, color = "#E63946") +
  coord_fixed(ratio = 1.2) +
  labs(title = sprintf("LA Traffic Collisions – Sample of %s Points",
                       scales::comma(sample_n)),
       x = "Longitude", y = "Latitude") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p_scatter, "11_collision_scatter_map.png")

# ── 2. Density Heatmap ────────────────────────────────────────────────────────
cat("Generating density heatmap...\n")

p_density <- ggplot(map_sample, aes(x = lon, y = lat)) +
  stat_density_2d(
    aes(fill = after_stat(level)),
    geom = "polygon",
    alpha = 0.7,
    bins = 30
  ) +
  scale_fill_gradient(low = "#FFF3CD", high = "#E63946", name = "Density") +
  coord_fixed(ratio = 1.2) +
  labs(title = "Collision Density Heatmap – Los Angeles",
       x = "Longitude", y = "Latitude") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p_density, "12_density_heatmap.png")

# ── 3. Grid-Based Hotspot Analysis ────────────────────────────────────────────
cat("Running grid-based hotspot analysis...\n")

# Divide LA into a 50×50 grid and count collisions per cell
grid_res <- 50

spatial_dt[, `:=`(
  lat_bin = cut(lat, breaks = grid_res, labels = FALSE),
  lon_bin = cut(lon, breaks = grid_res, labels = FALSE)
)]

grid_counts <- spatial_dt[!is.na(lat_bin) & !is.na(lon_bin),
                           .(count = .N,
                             lat_mid = mean(lat),
                             lon_mid = mean(lon)),
                           by = .(lat_bin, lon_bin)]

# Label hotspot tiers
quantiles <- quantile(grid_counts$count, probs = c(0.75, 0.90, 0.95))
grid_counts[, risk_tier := fcase(
  count >= quantiles["95%"], "Critical",
  count >= quantiles["90%"], "High",
  count >= quantiles["75%"], "Medium",
  default = "Low"
)]

p_grid <- ggplot(grid_counts, aes(x = lon_mid, y = lat_mid, color = risk_tier, size = count)) +
  geom_point(alpha = 0.7) +
  scale_color_manual(values = c(
    "Critical" = "#E63946",
    "High"     = "#FF6B35",
    "Medium"   = "#FFB703",
    "Low"      = "#2A9D8F"
  )) +
  scale_size_continuous(range = c(0.5, 6), labels = comma) +
  coord_fixed(ratio = 1.2) +
  labs(title = "Collision Hotspot Grid – Los Angeles",
       x = "Longitude", y = "Latitude",
       color = "Risk Tier", size = "Count") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p_grid, "13_hotspot_grid.png")

# ── 4. DBSCAN Clustering ──────────────────────────────────────────────────────
cat("Running DBSCAN clustering...\n")

# Use a sample for clustering (full dataset can be slow)
cluster_n  <- min(100000L, nrow(spatial_dt))
cluster_dt <- spatial_dt[sample(.N, cluster_n), .(lon, lat)]

coords_matrix <- as.matrix(cluster_dt)

# eps ≈ 0.005 degrees ≈ ~500m; minPts = 30 points to form a cluster
db <- dbscan(coords_matrix, eps = 0.005, minPts = 30)

cluster_dt[, cluster := db$cluster]

# Remove noise points (cluster == 0)
cluster_dt <- cluster_dt[cluster > 0]

# Summarise each cluster
cluster_summary <- cluster_dt[, .(
  size      = .N,
  lat_center = mean(lat),
  lon_center = mean(lon)
), by = cluster][order(-size)]

cat(sprintf("Found %d clusters (excl. noise)\n", nrow(cluster_summary)))
cat("Top 10 clusters:\n")
print(head(cluster_summary, 10))

# Save cluster summary for Power BI / API
fwrite(cluster_summary, file.path(dirname(getwd()), "data", "hotspot_clusters.csv"))

p_clusters <- ggplot(cluster_dt[cluster > 0], aes(x = lon, y = lat, color = factor(cluster))) +
  geom_point(alpha = 0.2, size = 0.4, show.legend = FALSE) +
  geom_point(data = cluster_summary[1:20],
             aes(x = lon_center, y = lat_center),
             color = "black", shape = 4, size = 3, inherit.aes = FALSE) +
  coord_fixed(ratio = 1.2) +
  labs(title = "DBSCAN Accident Clusters (Top 20 Marked)",
       x = "Longitude", y = "Latitude") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p_clusters, "14_dbscan_clusters.png")

# ── 5. Area Ranking by Severity (MO Code Count) ───────────────────────────────
cat("Ranking areas by severity...\n")

area_severity <- dt[!is.na(area_name),
                    .(total_accidents = .N,
                      avg_severity    = mean(mo_code_count, na.rm = TRUE)),
                    by = area_name][order(-avg_severity)]

# Composite score: normalise both metrics (0–1) then average
area_severity[, `:=`(
  norm_count    = (total_accidents - min(total_accidents)) /
                  (max(total_accidents) - min(total_accidents)),
  norm_severity = (avg_severity - min(avg_severity)) /
                  (max(avg_severity) - min(avg_severity))
)]
area_severity[, composite_score := (norm_count + norm_severity) / 2]
setorder(area_severity, -composite_score)

cat("\nArea Risk Ranking (Top 10):\n")
print(area_severity[1:10, .(area_name, total_accidents, avg_severity, composite_score)])

# Save for API and Power BI
fwrite(area_severity, file.path(dirname(getwd()), "data", "area_risk_ranking.csv"))

p_rank <- ggplot(area_severity[1:10], aes(x = composite_score, y = reorder(area_name, composite_score))) +
  geom_col(fill = "#E63946", alpha = 0.85) +
  labs(title = "Top 10 Areas by Composite Risk Score",
       x = "Composite Risk Score (0–1)", y = "Area") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p_rank, "15_area_risk_ranking.png", w = 10, h = 6)

cat("\n✓ Module 3 (Spatial Analysis) complete.\n")
