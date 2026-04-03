# =============================================================================
# MODULE 2: EXPLORATORY DATA ANALYSIS (EDA)
# US Road Accident Intelligence & Risk Prediction System
# =============================================================================

library(data.table)
library(dplyr)
library(ggplot2)
library(lubridate)
library(stringr)
library(scales)

# ── Load Cleaned Data ─────────────────────────────────────────────────────────
dt <- fread(file.path(dirname(getwd()), "data", "traffic_collisions_clean.csv"))
cat(sprintf("Loaded %d rows\n", nrow(dt)))

# Output folder for plots
plots_dir <- file.path(dirname(getwd()), "data", "eda_plots")
dir.create(plots_dir, showWarnings = FALSE)

save_plot <- function(p, filename, w = 10, h = 6) {
  ggsave(file.path(plots_dir, filename), plot = p, width = w, height = h, dpi = 150)
  cat(sprintf("Saved: %s\n", filename))
}

theme_set(theme_minimal(base_size = 13))
accent <- "#E63946"

# ── 1. Temporal Trend: Accidents per Year ─────────────────────────────────────
yearly <- dt[!is.na(year), .N, by = year][order(year)]

p1 <- ggplot(yearly, aes(x = year, y = N)) +
  geom_line(color = accent, linewidth = 1.2) +
  geom_point(color = accent, size = 2.5) +
  scale_y_continuous(labels = comma) +
  labs(title = "Traffic Collisions per Year (2010–Present)",
       x = "Year", y = "Number of Collisions") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p1, "01_yearly_trend.png")

# ── 2. Monthly Pattern (averaged across years) ────────────────────────────────
monthly <- dt[!is.na(month_num), .N, by = month_num][order(month_num)]
month_labels <- month.abb[monthly$month_num]

p2 <- ggplot(monthly, aes(x = factor(month_num, labels = month_labels), y = N)) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_y_continuous(labels = comma) +
  labs(title = "Total Collisions by Month", x = "Month", y = "Count") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p2, "02_monthly_pattern.png")

# ── 3. Hour-of-Day Distribution ───────────────────────────────────────────────
hourly <- dt[!is.na(hour), .N, by = hour][order(hour)]

p3 <- ggplot(hourly, aes(x = hour, y = N)) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_x_continuous(breaks = 0:23) +
  scale_y_continuous(labels = comma) +
  labs(title = "Collisions by Hour of Day",
       x = "Hour (24h)", y = "Count") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p3, "03_hourly_distribution.png")

# ── 4. Day-of-Week Pattern ────────────────────────────────────────────────────
dow_levels <- c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
dow <- dt[!is.na(day_of_week), .N, by = day_of_week]
dow[, day_of_week := factor(day_of_week, levels = dow_levels)]
setorder(dow, day_of_week)

p4 <- ggplot(dow, aes(x = day_of_week, y = N)) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_y_continuous(labels = comma) +
  labs(title = "Collisions by Day of Week", x = "Day", y = "Count") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p4, "04_day_of_week.png")

# ── 5. Top 10 Areas by Collision Count ───────────────────────────────────────
top_areas <- dt[!is.na(area_name), .N, by = area_name][order(-N)][1:10]

p5 <- ggplot(top_areas, aes(x = N, y = reorder(area_name, N))) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_x_continuous(labels = comma) +
  labs(title = "Top 10 LAPD Areas by Collision Count",
       x = "Number of Collisions", y = "Area") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p5, "05_top_areas.png")

# ── 6. Victim Age Group Distribution ─────────────────────────────────────────
age_dist <- dt[!is.na(age_group), .N, by = age_group][order(-N)]

p6 <- ggplot(age_dist, aes(x = reorder(age_group, -N), y = N)) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_y_continuous(labels = comma) +
  labs(title = "Collision Victims by Age Group",
       x = "Age Group", y = "Count") +
  theme(plot.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 25, hjust = 1))

save_plot(p6, "06_age_group.png")

# ── 7. Victim Sex Distribution ────────────────────────────────────────────────
sex_dist <- dt[!is.na(vict_sex_label), .N, by = vict_sex_label]

p7 <- ggplot(sex_dist, aes(x = vict_sex_label, y = N, fill = vict_sex_label)) +
  geom_col(alpha = 0.85, show.legend = FALSE) +
  scale_fill_manual(values = c("Male" = "#457B9D", "Female" = "#E63946")) +
  scale_y_continuous(labels = comma) +
  labs(title = "Collision Victims by Sex", x = "Sex", y = "Count") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p7, "07_victim_sex.png")

# ── 8. Top 10 Victim Descents ─────────────────────────────────────────────────
descent_dist <- dt[!is.na(descent_label), .N, by = descent_label][order(-N)][1:10]

p8 <- ggplot(descent_dist, aes(x = N, y = reorder(descent_label, N))) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_x_continuous(labels = comma) +
  labs(title = "Top 10 Victim Descents", x = "Count", y = "Descent") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p8, "08_descent.png")

# ── 9. Premise Type Analysis ──────────────────────────────────────────────────
premise_dist <- dt[!is.na(premis_desc) & premis_desc != "", .N, by = premis_desc][order(-N)][1:10]

p9 <- ggplot(premise_dist, aes(x = N, y = reorder(premis_desc, N))) +
  geom_col(fill = accent, alpha = 0.85) +
  scale_x_continuous(labels = comma) +
  labs(title = "Top 10 Premise Types for Collisions", x = "Count", y = "Premise") +
  theme(plot.title = element_text(face = "bold"))

save_plot(p9, "09_premise_type.png")

# ── 10. Hour Bucket Heatmap: Area × Hour Bucket ───────────────────────────────
if ("hour_bucket" %in% names(dt)) {
  heatmap_data <- dt[!is.na(area_name) & !is.na(hour_bucket),
                     .N, by = .(area_name, hour_bucket)]
  top10_areas <- top_areas$area_name

  p10 <- heatmap_data[area_name %in% top10_areas] |>
    ggplot(aes(x = hour_bucket, y = area_name, fill = N)) +
    geom_tile(color = "white") +
    scale_fill_gradient(low = "#FFF3CD", high = accent, labels = comma) +
    labs(title = "Collision Heatmap: Area × Time of Day",
         x = "Time of Day", y = "Area", fill = "Count") +
    theme(plot.title = element_text(face = "bold"),
          axis.text.x = element_text(angle = 20, hjust = 1))

  save_plot(p10, "10_area_hour_heatmap.png", w = 11, h = 7)
}

# ── Summary Statistics ────────────────────────────────────────────────────────
cat("\n── Summary ──────────────────────────────────────────────────\n")
cat(sprintf("Total records:       %d\n", nrow(dt)))
cat(sprintf("Year range:          %d – %d\n", min(dt$year, na.rm = TRUE), max(dt$year, na.rm = TRUE)))
cat(sprintf("Unique areas:        %d\n", dt[, uniqueN(area_name)]))
cat(sprintf("Records with coords: %d\n", nrow(dt[!is.na(lat) & !is.na(lon)])))
cat(sprintf("EDA plots saved to:  %s\n", plots_dir))
cat("\n✓ Module 2 (EDA) complete.\n")
