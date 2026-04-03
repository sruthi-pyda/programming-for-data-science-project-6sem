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
# Aggregate: count accidents per area × hour × month × day_of_week
cat("Building aggregated modeling dataset...\n")

agg <- dt[!is.na(area) & !is.na(hour) & !is.na(month_num),
          .(accident_count = .N,
            avg_victim_age = mean(vict_age, na.rm = TRUE),
            avg_severity   = mean(mo_code_count, na.rm = TRUE)),
          by = .(area, hour, month_num, premis_cd)]

# Label risk level based on accident_count quantiles
q33 <- quantile(agg$accident_count, 0.33)
q66 <- quantile(agg$accident_count, 0.66)

agg[, risk_level := fcase(
  accident_count <= q33, "Low",
  accident_count <= q66, "Medium",
  default = "High"
)]
agg[, risk_level := factor(risk_level, levels = c("Low", "Medium", "High"))]

# Fill missing premis_cd with mode
mode_premis <- agg[!is.na(premis_cd), .N, by = premis_cd][which.max(N)]$premis_cd
agg[is.na(premis_cd), premis_cd := mode_premis]
agg[is.na(avg_victim_age), avg_victim_age := median(agg$avg_victim_age, na.rm = TRUE)]

cat(sprintf("Modeling dataset: %d rows\n", nrow(agg)))
cat("Risk level distribution:\n")
print(table(agg$risk_level))

# ── Train/Test Split ──────────────────────────────────────────────────────────
train_idx <- createDataPartition(agg$risk_level, p = 0.8, list = FALSE)
train_df  <- agg[ train_idx]
test_df   <- agg[-train_idx]

features <- c("area", "hour", "month_num", "premis_cd", "avg_victim_age", "avg_severity")

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
  control = rpart.control(cp = 0.005, maxdepth = 8)
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

# ── Model C: Random Forest ────────────────────────────────────────────────────
cat("\nTraining Random Forest (this may take a few minutes)...\n")
rf_model <- randomForest(
  x         = X_train,
  y         = y_train,
  ntree     = 300,
  mtry      = 3,
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
