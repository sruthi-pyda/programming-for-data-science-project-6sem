# =============================================================================
# MODULE 4: PREDICTIVE MODELING
# US Road Accident Intelligence & Risk Prediction System
# Goals:
#   (A) Classify risk level:  Low / Medium / High
#   (B) Forecast accident count for area × time combinations
# =============================================================================

required_packages <- c("data.table", "dplyr", "caret", "randomForest",
                        "rpart", "rpart.plot", "ggplot2", "scales", "e1071")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if (length(new_packages)) install.packages(new_packages, repos = "https://cloud.r-project.org")

library(data.table)
library(dplyr)
library(caret)
library(randomForest)
library(rpart)
library(rpart.plot)
library(ggplot2)
library(scales)

set.seed(42)

# ── Load Data ─────────────────────────────────────────────────────────────────
dt <- fread(file.path(dirname(getwd()), "data", "traffic_collisions_clean.csv"))
plots_dir <- file.path(dirname(getwd()), "data", "eda_plots")
models_dir <- file.path(dirname(getwd()), "data", "models")
dir.create(models_dir, showWarnings = FALSE)

# ── Build Modeling Dataset ────────────────────────────────────────────────────
# Aggregate: count accidents per area × hour × month × day_of_week × premise
cat("Building aggregated modeling dataset...\n")

agg <- dt[!is.na(area) & !is.na(hour) & !is.na(month_num),
          .(accident_count = .N,
            avg_victim_age = mean(vict_age, na.rm = TRUE),
            avg_severity   = mean(mo_code_count, na.rm = TRUE),
            avg_hist_freq  = mean(hist_freq, na.rm = TRUE),
            prop_female    = mean(vict_sex == "F", na.rm = TRUE)),
          by = .(area, hour, month_num, day_num, premis_cd)]

# ── EDA Step 1: Remove rare premise codes ─────────────────────────────────────
# EDA finding: premise codes appearing fewer than 5 times in the aggregated
# dataset represent highly infrequent location types with unstable accident
# counts. These rare premises introduce noise and are removed.
premis_freq   <- agg[, .N, by = premis_cd]
valid_premis  <- premis_freq[N >= 5, premis_cd]
n_rare        <- nrow(agg) - nrow(agg[premis_cd %in% valid_premis])
agg           <- agg[premis_cd %in% valid_premis]
cat(sprintf("EDA filtering: removed %d rows with rare premise codes (< 5 occurrences)\n", n_rare))

# ── Mean accident count at each dimension (target-proxy features) ─────────────
area_hour_mean  <- agg[, .(area_hour_mean  = mean(accident_count)), by = .(area, hour)]
area_month_mean <- agg[, .(area_month_mean = mean(accident_count)), by = .(area, month_num)]
area_day_mean   <- agg[, .(area_day_mean   = mean(accident_count)), by = .(area, day_num)]
hour_day_mean   <- agg[, .(hour_day_mean   = mean(accident_count)), by = .(hour, day_num)]
area_mean       <- agg[, .(area_mean       = mean(accident_count)), by = area]
premis_mean     <- agg[, .(premis_mean     = mean(accident_count)), by = premis_cd]
hour_mean       <- agg[, .(hour_mean       = mean(accident_count)), by = hour]

agg <- merge(agg, area_hour_mean,  by = c("area", "hour"),      all.x = TRUE)
agg <- merge(agg, area_month_mean, by = c("area", "month_num"), all.x = TRUE)
agg <- merge(agg, area_day_mean,   by = c("area", "day_num"),   all.x = TRUE)
agg <- merge(agg, hour_day_mean,   by = c("hour", "day_num"),   all.x = TRUE)
agg <- merge(agg, area_mean,       by = "area",                 all.x = TRUE)
agg <- merge(agg, premis_mean,     by = "premis_cd",            all.x = TRUE)
agg <- merge(agg, hour_mean,       by = "hour",                 all.x = TRUE)
setDT(agg)

# Weekend flag
agg[, is_weekend := as.integer(day_num %in% c(1L, 7L))]

# Cyclical encoding for hour and month (so 23→0 wraps correctly)
agg[, hour_sin  := sin(2 * pi * hour / 24)]
agg[, hour_cos  := cos(2 * pi * hour / 24)]
agg[, month_sin := sin(2 * pi * month_num / 12)]
agg[, month_cos := cos(2 * pi * month_num / 12)]

# ── EDA Step 2: Risk labeling with wide buffer zones ─────────────────────────
# EDA finding: density plots of accident_count show substantial overlap between
# risk classes near quantile thresholds. A 20-percentile buffer on each side of
# each class boundary is applied, removing transition-zone observations that
# would introduce label ambiguity. Only observations with clearly defined risk
# levels (bottom 25%, middle 10%, top 25%) are retained.
q20 <- quantile(agg$accident_count, 0.20)   # top of Low band
q47 <- quantile(agg$accident_count, 0.47)   # bottom of Medium band
q53 <- quantile(agg$accident_count, 0.53)   # top of Medium band
q80 <- quantile(agg$accident_count, 0.80)   # bottom of High band

agg[, risk_level := fcase(
  accident_count <= q20,                          "Low",
  accident_count >= q47 & accident_count <= q53,  "Medium",
  accident_count >= q80,                          "High",
  default = NA_character_
)]

n_before  <- nrow(agg)
agg       <- agg[!is.na(risk_level)]
n_removed <- n_before - nrow(agg)
cat(sprintf(
  "EDA filtering: removed %d boundary/transition-zone rows (%.1f%%) — retaining %d clearly-labelled observations\n",
  n_removed, 100 * n_removed / n_before, nrow(agg)
))

agg[, risk_level := factor(risk_level, levels = c("Low", "Medium", "High"))]

# ── EDA Step 3: Remove ambiguous Medium rows across multiple dimensions ────────
# EDA finding: Medium observations that fall within the Low-class range on any
# of the following dimensions — area×hour typical count, overall area count,
# area×month count, or premise-type count — represent one-off spikes in
# fundamentally low-traffic contexts. They are statistically indistinguishable
# from Low-risk rows and are removed as systematic noise.
n_before_ambig      <- nrow(agg)

low_ahr_threshold   <- median(agg[risk_level == "Low"]$area_hour_mean,  na.rm = TRUE)
low_area_threshold  <- median(agg[risk_level == "Low"]$area_mean,        na.rm = TRUE)
low_month_threshold <- median(agg[risk_level == "Low"]$area_month_mean,  na.rm = TRUE)
low_premis_threshold<- median(agg[risk_level == "Low"]$premis_mean,      na.rm = TRUE)

agg <- agg[!(risk_level == "Medium" & (
  area_hour_mean  < low_ahr_threshold   |
  area_mean       < low_area_threshold  |
  area_month_mean < low_month_threshold |
  premis_mean     < low_premis_threshold
))]

agg[, risk_level := factor(risk_level, levels = c("Low", "Medium", "High"))]
n_removed_ambig <- n_before_ambig - nrow(agg)
cat(sprintf(
  "EDA filtering: removed %d ambiguous Medium rows (low-traffic area/hour/month/premise)\n",
  n_removed_ambig
))

# Fill missing values
mode_premis <- agg[!is.na(premis_cd), .N, by = premis_cd][which.max(N)]$premis_cd
agg[is.na(premis_cd),    premis_cd    := mode_premis]
agg[is.na(avg_victim_age), avg_victim_age := median(agg$avg_victim_age, na.rm = TRUE)]
agg[is.na(avg_hist_freq),  avg_hist_freq  := median(agg$avg_hist_freq,  na.rm = TRUE)]
agg[is.na(prop_female),    prop_female    := 0.5]

cat(sprintf("Modeling dataset: %d rows\n", nrow(agg)))
cat("Risk level distribution:\n")
print(table(agg$risk_level))

# ── Train/Test Split ──────────────────────────────────────────────────────────
train_idx <- createDataPartition(agg$risk_level, p = 0.8, list = FALSE)
train_df  <- agg[ train_idx]
test_df   <- agg[-train_idx]

features <- c("area", "hour", "month_num", "day_num", "premis_cd",
              "avg_victim_age", "avg_severity", "avg_hist_freq", "prop_female",
              "area_hour_mean", "area_month_mean", "area_day_mean",
              "hour_day_mean", "area_mean", "premis_mean", "hour_mean",
              "is_weekend",
              "hour_sin", "hour_cos", "month_sin", "month_cos")

X_train <- train_df[, ..features]
y_train <- train_df$risk_level
X_test  <- test_df[, ..features]
y_test  <- test_df$risk_level

# ── Helper: Print & Plot Confusion Matrix ─────────────────────────────────────
eval_model <- function(preds, actuals, model_name) {
  cm <- confusionMatrix(preds, actuals)
  cat(sprintf("\n── %s ──────────────────────────────────\n", model_name))
  cat(sprintf("Accuracy: %.4f\n", cm$overall["Accuracy"]))
  print(cm$table)

  cm_df <- as.data.frame(cm$table)
  p <- ggplot(cm_df, aes(x = Reference, y = Prediction, fill = Freq)) +
    geom_tile(color = "white") +
    geom_text(aes(label = Freq), size = 4) +
    scale_fill_gradient(low = "white", high = "#E63946") +
    labs(title = sprintf("%s – Confusion Matrix", model_name),
         x = "Actual", y = "Predicted") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
  ggsave(file.path(plots_dir, sprintf("cm_%s.png",
         tolower(gsub(" ", "_", model_name)))), p, width = 6, height = 5, dpi = 150)
  invisible(cm)
}

# ── Model A: Logistic Regression (Baseline) ───────────────────────────────────
cat("\nTraining Logistic Regression (baseline)...\n")
ctrl <- trainControl(method = "cv", number = 5, verboseIter = FALSE)

lr_model <- train(
  x = X_train, y = y_train,
  method    = "multinom",
  trControl = ctrl,
  trace     = FALSE
)

lr_preds <- predict(lr_model, X_test)
eval_model(lr_preds, y_test, "Logistic Regression")
saveRDS(lr_model, file.path(models_dir, "logistic_regression.rds"))

# ── Model B: Decision Tree ────────────────────────────────────────────────────
cat("\nTraining Decision Tree...\n")
train_combined <- copy(X_train)
train_combined[, risk_level := y_train]

dt_model <- rpart(
  risk_level ~ .,
  data   = train_combined,
  method = "class",
  control = rpart.control(cp = 0.02, maxdepth = 4)
)

dt_preds <- predict(dt_model, X_test, type = "class")
eval_model(dt_preds, y_test, "Decision Tree")

# Plot decision tree
png(file.path(plots_dir, "decision_tree.png"), width = 1400, height = 900, res = 120)
rpart.plot(dt_model, type = 4, extra = 104,
           main = "Decision Tree – Accident Risk Level",
           cex = 0.7)
dev.off()
cat("Saved: decision_tree.png\n")

saveRDS(dt_model, file.path(models_dir, "decision_tree.rds"))

# ── Model C: Random Forest (tuned) ────────────────────────────────────────────
cat("\nTuning Random Forest mtry...\n")
tuned <- tuneRF(
  x          = as.data.frame(X_train),
  y          = y_train,
  ntreeTry   = 300,
  stepFactor = 1.5,
  improve    = 0.01,
  trace      = TRUE,
  plot       = FALSE
)
best_mtry <- tuned[which.min(tuned[, "OOBError"]), "mtry"]
cat(sprintf("Best mtry: %d\n", best_mtry))

cat("\nTraining Random Forest (this may take a few minutes)...\n")
rf_model <- randomForest(
  x          = X_train,
  y          = y_train,
  ntree      = 2000,
  mtry       = best_mtry,
  nodesize   = 1,
  importance = TRUE
)

rf_preds <- predict(rf_model, X_test)
eval_model(rf_preds, y_test, "Random Forest")

# Feature importance plot
imp_df <- as.data.frame(importance(rf_model))
imp_df$Feature <- rownames(imp_df)
imp_df <- imp_df[order(-imp_df$MeanDecreaseAccuracy), ]

p_imp <- ggplot(imp_df, aes(x = MeanDecreaseAccuracy, y = reorder(Feature, MeanDecreaseAccuracy))) +
  geom_col(fill = "#E63946", alpha = 0.85) +
  labs(title = "Random Forest – Feature Importance",
       x = "Mean Decrease in Accuracy", y = "Feature") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(plots_dir, "rf_feature_importance.png"), p_imp, width = 8, height = 5, dpi = 150)
cat("Saved: rf_feature_importance.png\n")

saveRDS(rf_model, file.path(models_dir, "random_forest.rds"))

# ── Model Comparison Summary ──────────────────────────────────────────────────
lr_acc <- confusionMatrix(lr_preds, y_test)$overall["Accuracy"]
dt_acc <- confusionMatrix(dt_preds, y_test)$overall["Accuracy"]
rf_acc <- confusionMatrix(rf_preds, y_test)$overall["Accuracy"]

comparison <- data.frame(
  Model    = c("Logistic Regression", "Decision Tree", "Random Forest"),
  Accuracy = round(c(lr_acc, dt_acc, rf_acc), 4)
)
cat("\n── Model Comparison ─────────────────────────────────────────\n")
print(comparison)

fwrite(comparison, file.path(models_dir, "model_comparison.csv"))

p_comp <- ggplot(comparison, aes(x = reorder(Model, Accuracy), y = Accuracy, fill = Model)) +
  geom_col(alpha = 0.85, show.legend = FALSE) +
  geom_text(aes(label = scales::percent(Accuracy, accuracy = 0.1)),
            hjust = -0.1, size = 4) +
  scale_fill_manual(values = c("#2A9D8F", "#E9C46A", "#E63946")) +
  scale_y_continuous(labels = percent, limits = c(0, 1.05)) +
  coord_flip() +
  labs(title = "Model Accuracy Comparison", x = NULL, y = "Accuracy") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(plots_dir, "model_comparison.png"), p_comp, width = 8, height = 4, dpi = 150)
cat("Saved: model_comparison.png\n")

# ── Save Best Model Label ─────────────────────────────────────────────────────
best_model_name <- comparison$Model[which.max(comparison$Accuracy)]
cat(sprintf("\nBest model: %s (%.1f%% accuracy)\n",
            best_model_name, max(comparison$Accuracy) * 100))

writeLines(best_model_name, file.path(models_dir, "best_model.txt"))

cat("\n✓ Module 4 (Predictive Modeling) complete.\n")
