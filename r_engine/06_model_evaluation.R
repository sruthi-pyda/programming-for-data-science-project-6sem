# =============================================================================
# MODULE 6: MODEL EVALUATION — Confusion Matrix, Train/Test Accuracy & Outputs
# LA Road Safety Intelligence System
#
# Purpose : Reload all three saved models and produce a complete evaluation
#           report with confusion matrices, per-class metrics, train accuracy,
#           test accuracy, and comparison outputs — all saved to disk.
#
# Run from the r_engine/ directory:
#   Rscript 06_model_evaluation.R
# =============================================================================

# ── 1. Libraries ──────────────────────────────────────────────────────────────
required_packages <- c("data.table", "dplyr", "caret", "randomForest",
                        "rpart", "ggplot2", "scales", "nnet", "e1071")
new_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]
if (length(new_packages)) install.packages(new_packages, repos = "https://cloud.r-project.org")

library(data.table)
library(dplyr)
library(caret)
library(randomForest)
library(rpart)
library(ggplot2)
library(scales)

set.seed(42)

# ── 2. Paths ──────────────────────────────────────────────────────────────────
base_dir    <- dirname(getwd())
data_dir    <- file.path(base_dir, "data")
models_dir  <- file.path(data_dir, "models")
plots_dir   <- file.path(data_dir, "eda_plots")
eval_dir    <- file.path(data_dir, "evaluation")
dir.create(eval_dir,  showWarnings = FALSE)
dir.create(plots_dir, showWarnings = FALSE)

# ── 3. Recreate Modeling Dataset (same logic as 04_modeling.R) ────────────────
cat("Loading cleaned data...\n")
dt <- fread(file.path(data_dir, "traffic_collisions_clean.csv"))

agg <- dt[!is.na(area) & !is.na(hour) & !is.na(month_num),
          .(accident_count = .N,
            avg_victim_age = mean(vict_age, na.rm = TRUE),
            avg_severity   = mean(mo_code_count, na.rm = TRUE)),
          by = .(area, hour, month_num, premis_cd)]

q33 <- quantile(agg$accident_count, 0.33)
q66 <- quantile(agg$accident_count, 0.66)

agg[, risk_level := fcase(
  accident_count <= q33, "Low",
  accident_count <= q66, "Medium",
  default = "High"
)]
agg[, risk_level := factor(risk_level, levels = c("Low", "Medium", "High"))]

mode_premis <- agg[!is.na(premis_cd), .N, by = premis_cd][which.max(N)]$premis_cd
agg[is.na(premis_cd), premis_cd := mode_premis]
agg[is.na(avg_victim_age), avg_victim_age := median(agg$avg_victim_age, na.rm = TRUE)]

cat(sprintf("Dataset: %d rows | Risk distribution:\n", nrow(agg)))
print(table(agg$risk_level))

# ── 4. Train / Test Split (identical seed + partition as Module 4) ─────────────
train_idx <- createDataPartition(agg$risk_level, p = 0.8, list = FALSE)
train_df  <- agg[ train_idx]
test_df   <- agg[-train_idx]

features <- c("area", "hour", "month_num", "premis_cd", "avg_victim_age", "avg_severity")

X_train <- train_df[, ..features]
y_train <- train_df$risk_level
X_test  <- test_df[, ..features]
y_test  <- test_df$risk_level

cat(sprintf("\nTrain rows: %d  |  Test rows: %d\n", nrow(train_df), nrow(test_df)))

# ── 5. Load Saved Models ──────────────────────────────────────────────────────
cat("\nLoading saved models...\n")
lr_model <- readRDS(file.path(models_dir, "logistic_regression.rds"))
dt_model <- readRDS(file.path(models_dir, "decision_tree.rds"))
rf_model <- readRDS(file.path(models_dir, "random_forest.rds"))
cat("All models loaded.\n")

# ── 6. Helper: Full Evaluation Report ────────────────────────────────────────
# Returns a list with train_acc, test_acc, and the full confusionMatrix object.
evaluate_model <- function(model, X_train, y_train, X_test, y_test,
                            model_name, model_type = "caret") {

  cat(sprintf("\n%s\n", strrep("=", 60)))
  cat(sprintf("  MODEL: %s\n", model_name))
  cat(sprintf("%s\n", strrep("=", 60)))

  # ---- Predictions ----
  if (model_type == "caret") {
    train_preds <- predict(model, X_train)
    test_preds  <- predict(model, X_test)
  } else if (model_type == "rpart") {
    train_preds <- predict(model, X_train, type = "class")
    test_preds  <- predict(model, X_test,  type = "class")
  } else {   # randomForest
    train_preds <- predict(model, X_train)
    test_preds  <- predict(model, X_test)
  }

  # ---- Accuracy ----
  train_acc <- mean(train_preds == y_train)
  test_acc  <- mean(test_preds  == y_test)

  cat(sprintf("\n  Training Accuracy : %.4f  (%.2f%%)\n", train_acc, train_acc * 100))
  cat(sprintf("  Test Accuracy     : %.4f  (%.2f%%)\n", test_acc,  test_acc  * 100))

  # ---- Confusion Matrix (test set) ----
  cm <- confusionMatrix(test_preds, y_test)

  cat("\n  Confusion Matrix (Test Set):\n")
  cat("  Rows = Predicted | Columns = Actual\n\n")
  cm_table <- cm$table
  print(cm_table)

  cat("\n  Per-Class Metrics (Test Set):\n")
  per_class <- data.frame(
    Class     = rownames(cm$byClass),
    Precision = round(cm$byClass[, "Pos Pred Value"], 4),
    Recall    = round(cm$byClass[, "Sensitivity"],    4),
    F1        = round(cm$byClass[, "F1"],              4),
    Specificity = round(cm$byClass[, "Specificity"],   4)
  )
  print(per_class)

  cat("\n  Overall Test Metrics:\n")
  cat(sprintf("    Accuracy          : %.4f\n", cm$overall["Accuracy"]))
  cat(sprintf("    95%% CI            : [%.4f, %.4f]\n",
              cm$overall["AccuracyLower"], cm$overall["AccuracyUpper"]))
  cat(sprintf("    Kappa             : %.4f\n", cm$overall["Kappa"]))
  cat(sprintf("    P-value (Acc > NIR): %.4e\n", cm$overall["AccuracyPValue"]))

  # ---- Confusion Matrix Plot ----
  cm_df <- as.data.frame(cm_table)
  p_cm <- ggplot(cm_df, aes(x = Reference, y = Prediction, fill = Freq)) +
    geom_tile(color = "white", linewidth = 0.8) +
    geom_text(aes(label = Freq), size = 5, fontface = "bold") +
    scale_fill_gradient(low = "#F7F7F7", high = "#E63946", name = "Count") +
    labs(
      title    = sprintf("%s — Confusion Matrix (Test Set)", model_name),
      subtitle = sprintf("Test Accuracy: %.2f%%  |  Kappa: %.4f",
                         test_acc * 100, cm$overall["Kappa"]),
      x = "Actual Class",
      y = "Predicted Class"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title    = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(color = "gray40"),
      axis.text     = element_text(size = 12),
      legend.position = "right"
    )

  plot_file <- file.path(eval_dir,
                          sprintf("cm_%s.png", tolower(gsub(" ", "_", model_name))))
  ggsave(plot_file, p_cm, width = 7, height = 5.5, dpi = 150)
  cat(sprintf("\n  Confusion matrix plot saved: %s\n", plot_file))

  invisible(list(
    model_name = model_name,
    train_acc  = train_acc,
    test_acc   = test_acc,
    cm         = cm,
    per_class  = per_class
  ))
}

# ── 7. Evaluate All Three Models ──────────────────────────────────────────────
lr_eval <- evaluate_model(lr_model, X_train, y_train, X_test, y_test,
                           "Logistic Regression", model_type = "caret")

dt_eval <- evaluate_model(dt_model, X_train, y_train, X_test, y_test,
                           "Decision Tree", model_type = "rpart")

rf_eval <- evaluate_model(rf_model, X_train, y_train, X_test, y_test,
                           "Random Forest", model_type = "randomForest")

# ── 8. Side-by-Side Accuracy Comparison ──────────────────────────────────────
cat(sprintf("\n%s\n", strrep("=", 60)))
cat("  TRAIN vs TEST ACCURACY COMPARISON\n")
cat(sprintf("%s\n", strrep("=", 60)))

comparison <- data.frame(
  Model      = c("Logistic Regression", "Decision Tree", "Random Forest"),
  Train_Acc  = round(c(lr_eval$train_acc, dt_eval$train_acc, rf_eval$train_acc), 4),
  Test_Acc   = round(c(lr_eval$test_acc,  dt_eval$test_acc,  rf_eval$test_acc),  4),
  Kappa      = round(c(
    lr_eval$cm$overall["Kappa"],
    dt_eval$cm$overall["Kappa"],
    rf_eval$cm$overall["Kappa"]
  ), 4)
)
comparison$Overfit_Gap <- round(comparison$Train_Acc - comparison$Test_Acc, 4)

print(comparison)

# Save to CSV
write.csv(comparison, file.path(eval_dir, "train_test_accuracy_comparison.csv"),
          row.names = FALSE)
cat(sprintf("\nAccuracy comparison saved: %s\n",
            file.path(eval_dir, "train_test_accuracy_comparison.csv")))

# ── 9. Train vs Test Accuracy Bar Chart ──────────────────────────────────────
comp_long <- tidyr::pivot_longer(
  comparison[, c("Model", "Train_Acc", "Test_Acc")],
  cols      = c("Train_Acc", "Test_Acc"),
  names_to  = "Split",
  values_to = "Accuracy"
)
comp_long$Split <- ifelse(comp_long$Split == "Train_Acc", "Train", "Test")

p_acc <- ggplot(comp_long, aes(x = Model, y = Accuracy, fill = Split)) +
  geom_col(position = "dodge", alpha = 0.88, width = 0.6) +
  geom_text(aes(label = scales::percent(Accuracy, accuracy = 0.1)),
            position = position_dodge(width = 0.6),
            vjust = -0.4, size = 3.8) +
  scale_fill_manual(values = c("Train" = "#457B9D", "Test" = "#E63946")) +
  scale_y_continuous(labels = percent, limits = c(0, 1.1)) +
  labs(
    title    = "Train vs Test Accuracy — All Models",
    subtitle = "Higher test accuracy = better generalisation; large gap = overfitting",
    x        = NULL,
    y        = "Accuracy",
    fill     = "Data Split"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "top"
  )

ggsave(file.path(eval_dir, "train_test_accuracy_comparison.png"),
       p_acc, width = 9, height = 5.5, dpi = 150)
cat("Train vs test accuracy chart saved.\n")

# ── 10. Overfitting Gap Chart ─────────────────────────────────────────────────
p_gap <- ggplot(comparison, aes(x = reorder(Model, -Overfit_Gap),
                                 y = Overfit_Gap, fill = Overfit_Gap > 0.05)) +
  geom_col(alpha = 0.88) +
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "gray50") +
  scale_fill_manual(values = c("FALSE" = "#2A9D8F", "TRUE" = "#E63946"),
                    labels = c("Acceptable", "Potential Overfit"),
                    name   = "") +
  scale_y_continuous(labels = percent) +
  labs(
    title    = "Overfitting Gap (Train Acc − Test Acc)",
    subtitle = "Dashed line = 5% threshold",
    x        = NULL,
    y        = "Train − Test Gap"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "top")

ggsave(file.path(eval_dir, "overfitting_gap.png"),
       p_gap, width = 8, height = 5, dpi = 150)
cat("Overfitting gap chart saved.\n")

# ── 11. Per-Class F1 Score Comparison ────────────────────────────────────────
add_model <- function(df, name) { df$Model <- name; df }

f1_all <- rbind(
  add_model(lr_eval$per_class, "Logistic Regression"),
  add_model(dt_eval$per_class, "Decision Tree"),
  add_model(rf_eval$per_class, "Random Forest")
)
f1_all$Class <- gsub("Class: ", "", f1_all$Class)

p_f1 <- ggplot(f1_all, aes(x = Class, y = F1, fill = Model)) +
  geom_col(position = "dodge", alpha = 0.88, width = 0.65) +
  geom_text(aes(label = round(F1, 2)),
            position = position_dodge(width = 0.65),
            vjust = -0.4, size = 3.5) +
  scale_fill_manual(values = c(
    "Logistic Regression" = "#2A9D8F",
    "Decision Tree"       = "#E9C46A",
    "Random Forest"       = "#E63946"
  )) +
  scale_y_continuous(limits = c(0, 1.05)) +
  labs(
    title = "Per-Class F1 Score — All Models",
    x     = "Risk Level",
    y     = "F1 Score",
    fill  = "Model"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "top")

ggsave(file.path(eval_dir, "per_class_f1_comparison.png"),
       p_f1, width = 9, height = 5, dpi = 150)
cat("Per-class F1 comparison chart saved.\n")

# ── 12. Final Summary to Console ─────────────────────────────────────────────
cat(sprintf("\n%s\n", strrep("=", 60)))
cat("  FINAL EVALUATION SUMMARY\n")
cat(sprintf("%s\n", strrep("=", 60)))
cat(sprintf("  %-22s  %8s  %8s  %8s  %10s\n",
            "Model", "Train %", "Test %", "Kappa", "Gap"))
cat(sprintf("  %s\n", strrep("-", 60)))
for (i in seq_len(nrow(comparison))) {
  cat(sprintf("  %-22s  %7.2f%%  %7.2f%%  %8.4f  %+9.2f%%\n",
              comparison$Model[i],
              comparison$Train_Acc[i]   * 100,
              comparison$Test_Acc[i]    * 100,
              comparison$Kappa[i],
              comparison$Overfit_Gap[i] * 100))
}
cat(sprintf("\n  Best Model (Test Accuracy): %s — %.2f%%\n",
            comparison$Model[which.max(comparison$Test_Acc)],
            max(comparison$Test_Acc) * 100))

cat(sprintf("\n  Outputs saved to: %s\n", eval_dir))
cat("\n  Files produced:\n")
cat("    cm_logistic_regression.png         — Logistic Regression confusion matrix\n")
cat("    cm_decision_tree.png               — Decision Tree confusion matrix\n")
cat("    cm_random_forest.png               — Random Forest confusion matrix\n")
cat("    train_test_accuracy_comparison.csv — Accuracy table (all models)\n")
cat("    train_test_accuracy_comparison.png — Grouped bar chart\n")
cat("    overfitting_gap.png                — Train–Test gap chart\n")
cat("    per_class_f1_comparison.png        — F1 by class and model\n")

cat("\n✓ Module 6 (Model Evaluation) complete.\n")
