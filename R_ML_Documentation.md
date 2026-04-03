# R & Machine Learning Implementation — Documentation
## LA Road Safety Intelligence System

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Dataset](#2-dataset)
3. [Pipeline Architecture](#3-pipeline-architecture)
4. [Module 1 — Data Preprocessing](#4-module-1--data-preprocessing-01_preprocessingr)
5. [Module 2 — Exploratory Data Analysis](#5-module-2--exploratory-data-analysis-02_edar)
6. [Module 3 — Spatial Analysis & Hotspot Detection](#6-module-3--spatial-analysis--hotspot-detection-03_spatialr)
7. [Module 4 — Predictive Modeling](#7-module-4--predictive-modeling-04_modelingr)
8. [Module 5 — REST API](#8-module-5--rest-api-05_apir)
9. [Module 6 — Model Evaluation](#9-module-6--model-evaluation-06_model_evaluationr)
10. [Model Performance Results](#10-model-performance-results)
11. [File & Output Reference](#11-file--output-reference)
12. [How to Run the Full Pipeline](#12-how-to-run-the-full-pipeline)

---

## 1. Project Overview

This system predicts **traffic collision risk levels (Low / Medium / High)** across Los Angeles LAPD areas using the city's open-source traffic collision dataset. It combines classical machine learning (Logistic Regression, Decision Tree, Random Forest) with spatial analysis and a REST API that serves predictions to a Flutter mobile application.

**Goal:** Given an LAPD area, hour of day, month, and premise type, predict whether that combination carries Low, Medium, or High collision risk.

---

## 2. Dataset

| Property | Value |
|---|---|
| Source | LAPD Traffic Collision Data — [data.lacity.gov](https://data.lacity.gov) |
| Records | ~600,000 traffic collisions |
| Time range | 2010 – present |
| Raw file | `data/traffic_collisions_raw.csv` |
| Cleaned file | `data/traffic_collisions_clean.csv` |

**Key columns used in ML:**

| Column | Description |
|---|---|
| `area` | LAPD area code (1–21) |
| `hour` | Hour of incident (0–23) |
| `month_num` | Month of incident (1–12) |
| `premis_cd` | Premise code (road type / location type) |
| `vict_age` | Victim age |
| `mo_code_count` | MO code count — proxy for incident severity |

---

## 3. Pipeline Architecture

```
Raw CSV (600K rows)
        │
        ▼
┌──────────────────┐
│  01_preprocessing│  Column cleaning, date parsing, feature engineering
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  02_eda          │  10 visualisations — temporal & demographic patterns
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  03_spatial      │  Density maps, grid hotspots, DBSCAN clustering
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  04_modeling     │  Logistic Regression → Decision Tree → Random Forest
└──────┬───────────┘
       │
       ├── saved .rds model files
       │
       ▼
┌──────────────────┐
│  05_api          │  Plumber REST API — serves predictions to Flutter app
└──────────────────┘
       │
       ▼
┌──────────────────┐
│  06_model_eval   │  Confusion matrices, train/test accuracy, F1 scores
└──────────────────┘
```

---

## 4. Module 1 — Data Preprocessing (`01_preprocessing.R`)

### Purpose
Load the raw LAPD CSV, standardise it, extract temporal and demographic features, validate coordinates, and save a clean dataset.

### Libraries
`data.table`, `dplyr`, `lubridate`, `stringr`, `tidyr`

### Step-by-step Logic

#### Step 1 — Load Raw Data
```r
dt <- fread(raw_path, na.strings = c("", "NA", "NULL", "N/A"))
```
Uses `data.table::fread` for memory-efficient loading of large CSVs.

#### Step 2 — Standardise Column Names
Converts all column names to `snake_case`. Then applies a manual mapping that reconciles naming differences between dataset versions:
```r
col_map <- c(dr_number = "dr_no", date_occurred = "date_occ", ...)
```

#### Step 3 — Extract lat/lon
Parses `"(33.97, -118.29)"` strings into numeric `lat` and `lon` columns using regex.

#### Step 4 — Select Relevant Columns
Retains 19 core columns: report ID, dates, area codes, crime codes, MO codes, victim demographics, premise info, and coordinates.

#### Step 5 — Date/Time Feature Engineering
```r
dt[, date_occ_parsed := mdy_hms(date_occ, quiet = TRUE)]
dt[, `:=`(year, month, month_num, day_of_week, hour)]
```
Parsed with `lubridate`. `time_occ` is a 4-digit HHMM integer (e.g., 1430 → hour 14).

Hour buckets created:
| Bucket | Hours |
|---|---|
| Night | 00:00 – 05:59 |
| Morning | 06:00 – 11:59 |
| Afternoon | 12:00 – 17:59 |
| Evening | 18:00 – 23:59 |

#### Step 6 — Victim Demographics Cleaning
- **Age**: Cast to integer; values ≤ 0 or > 120 set to NA. Age groups: Minor / Young Adult / Adult / Middle-Aged / Senior.
- **Sex**: Standardised to M/F; anything else set to NA.
- **Descent**: Single-letter codes mapped to full ethnicity names via a lookup vector.

#### Step 7 — Coordinate Validation
Removes `(0, 0)` null-island values. Enforces LA bounding box: lat 33.7–34.4°N, lon −118.7 to −117.9°W.

#### Step 8 — MO Code Severity Proxy
```r
dt[, mo_code_count := str_count(mocodes, "\\s+") + 1L]
```
Counts space-separated MO codes as a proxy for incident complexity/severity.

#### Step 9 — Historical Frequency Feature
```r
freq_table <- dt[, .(hist_freq = .N), by = .(area, hour, month_num)]
dt <- merge(dt, freq_table, ...)
```
Adds `hist_freq` — how often accidents occur at this area × hour × month combination. Used as a feature in modeling.

#### Output
- `data/traffic_collisions_clean.csv` — cleaned dataset with all engineered features.

---

## 5. Module 2 — Exploratory Data Analysis (`02_eda.R`)

### Purpose
Understand the data through 10 publication-quality visualisations before modeling.

### Libraries
`data.table`, `dplyr`, `ggplot2`, `lubridate`, `scales`

### Visualisations Produced

| Plot File | What It Shows |
|---|---|
| `01_yearly_trend.png` | Collisions per year (2010–present) — line chart |
| `02_monthly_pattern.png` | Total collisions by month — bar chart |
| `03_hourly_distribution.png` | Collisions by hour of day (0–23) |
| `04_day_of_week.png` | Collisions by day of week |
| `05_top_areas.png` | Top 10 LAPD areas by collision count |
| `06_age_group.png` | Victim age group distribution |
| `07_victim_sex.png` | Victim sex distribution (M/F) |
| `08_descent.png` | Top 10 victim descent/ethnicity groups |
| `09_premise_type.png` | Top 10 premise types where collisions occur |
| `10_area_hour_heatmap.png` | Area × Time-of-day collision heatmap |

### Key Findings
- Peak hours: afternoon (12:00–18:00) and evening (18:00–24:00)
- Highest collision areas: Wilshire, Olympic, West LA
- Most victims: Hispanic/Latino, White, Black demographics
- Most common premise: Street/highway

---

## 6. Module 3 — Spatial Analysis & Hotspot Detection (`03_spatial.R`)

### Purpose
Map collision locations and identify high-risk geographic clusters.

### Libraries
`data.table`, `dplyr`, `ggplot2`, `sf`, `dbscan`, `scales`

### Analysis Steps

#### 3.1 Scatter Map
Plots a random sample of 50,000 points (`alpha=0.08`) to visualise the density of collisions across LA without overplotting.

#### 3.2 Density Heatmap
Uses `stat_density_2d` with polygon fill to show collision density — highlights continuous high-risk corridors.

#### 3.3 Grid-Based Hotspot Analysis
Divides LA into a 50×50 grid. Each cell is counted and labelled:
| Tier | Threshold |
|---|---|
| Critical | ≥ 95th percentile |
| High | ≥ 90th percentile |
| Medium | ≥ 75th percentile |
| Low | Below 75th percentile |

#### 3.4 DBSCAN Clustering
```r
db <- dbscan(coords_matrix, eps = 0.005, minPts = 30)
```
- `eps = 0.005 degrees ≈ 500 metres` — neighbourhood radius
- `minPts = 30` — minimum points to form a core cluster
- Noise points (cluster = 0) are excluded

**Top clusters found:**
| Cluster | Incidents |
|---|---|
| Central LA | ~62,014 |
| San Fernando Valley | ~29,701 |
| Additional clusters | 1,650 / 1,358 |

Cluster summary saved to `data/hotspot_clusters.csv` for use in the API and Power BI.

#### 3.5 Composite Area Risk Score
```r
composite_score = (norm_count + norm_severity) / 2
```
Both total accident count and average severity (MO code count) are min-max normalised, then averaged into a single composite risk score per LAPD area.

**Top 3 areas:**
1. Wilshire — score: highest (34,640 accidents, avg severity 6.80)
2. Olympic (32,445 accidents, avg severity 6.91)
3. West LA (32,208 accidents, avg severity 6.76)

Area ranking saved to `data/area_risk_ranking.csv`.

---

## 7. Module 4 — Predictive Modeling (`04_modeling.R`)

### Purpose
Train three classifiers to predict risk level (Low / Medium / High) for a given area × time × premise combination.

### Libraries
`data.table`, `dplyr`, `caret`, `randomForest`, `rpart`, `rpart.plot`, `ggplot2`, `e1071`

### Data Aggregation
```r
agg <- dt[, .(accident_count = .N,
              avg_victim_age = mean(vict_age),
              avg_severity   = mean(mo_code_count)),
          by = .(area, hour, month_num, premis_cd)]
```
Each row of `agg` represents a unique combination of area, hour, month, and premise. The accident count for that combination becomes the basis for the risk label.

### Target Variable — Risk Level
```r
q33 <- quantile(agg$accident_count, 0.33)
q66 <- quantile(agg$accident_count, 0.66)
risk_level: Low (≤33rd pct) | Medium (33–66th pct) | High (>66th pct)
```

### Feature Set
| Feature | Type | Description |
|---|---|---|
| `area` | Integer | LAPD area code (1–21) |
| `hour` | Integer | Hour of day (0–23) |
| `month_num` | Integer | Month number (1–12) |
| `premis_cd` | Integer | Premise/location type code |
| `avg_victim_age` | Numeric | Mean victim age for this combination |
| `avg_severity` | Numeric | Mean MO code count (incident complexity) |

### Train/Test Split
```r
train_idx <- createDataPartition(agg$risk_level, p = 0.8, list = FALSE)
```
- **80% train / 20% test** using stratified sampling (`createDataPartition` preserves class balance).
- `set.seed(42)` for reproducibility.
- **5-fold cross-validation** applied to Logistic Regression.

---

### Model A — Logistic Regression (Baseline)
```r
lr_model <- train(x = X_train, y = y_train,
                  method = "multinom",
                  trControl = trainControl(method = "cv", number = 5))
```
- Algorithm: Multinomial logistic regression (`nnet::multinom`)
- Trained via `caret` with 5-fold CV
- Serves as the interpretable baseline
- **Test Accuracy: 57.76%**

**Limitation:** Logistic regression assumes linear decision boundaries; the non-linear relationships between area, hour, and risk make it a weak classifier here.

---

### Model B — Decision Tree
```r
dt_model <- rpart(risk_level ~ .,
                  data = train_combined,
                  method = "class",
                  control = rpart.control(cp = 0.005, maxdepth = 8))
```
- Algorithm: Recursive Partitioning (`rpart`)
- `cp = 0.005` — complexity penalty; controls tree pruning
- `maxdepth = 8` — prevents excessive depth and overfitting
- Fully interpretable; decision tree diagram saved as `decision_tree.png`
- **Test Accuracy: 76.21%**

---

### Model C — Random Forest (Best Model)
```r
rf_model <- randomForest(x = X_train, y = y_train,
                          ntree = 300, mtry = 3, importance = TRUE)
```
- Algorithm: Random Forest (ensemble of 300 decision trees)
- `ntree = 300`: 300 trees in the forest
- `mtry = 3`: 3 features considered at each split (√6 ≈ 2.4, rounded up)
- `importance = TRUE`: enables feature importance calculation
- **Test Accuracy: 80.24%**

**Feature importance (by Mean Decrease in Accuracy):**
1. `area` — strongest predictor (location matters most)
2. `hour` — time of day is the second most predictive
3. `premis_cd` — road/location type
4. `month_num` — seasonal patterns
5. `avg_severity` — incident complexity
6. `avg_victim_age` — weakest predictor

---

### Model Comparison
| Model | Test Accuracy |
|---|---|
| Logistic Regression | 57.76% |
| Decision Tree | 76.21% |
| **Random Forest** | **80.24%** |

The Random Forest is selected as the **best model** and saved as `data/models/random_forest.rds`.

---

## 8. Module 5 — REST API (`05_api.R`)

### Purpose
Serve predictions from the trained Random Forest to the Flutter mobile app via HTTP.

### Framework
R `plumber` package — converts annotated R functions into REST endpoints.

### Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Health check — returns model name and version |
| GET | `/predict` | Predict risk level for one combination |
| POST | `/predict/batch` | Predict risk for multiple combinations (JSON body) |
| GET | `/areas/ranking` | Return top N LAPD areas by composite risk score |
| GET | `/hotspots` | Return top N DBSCAN cluster centroids |

### `/predict` Parameters
| Parameter | Type | Default | Description |
|---|---|---|---|
| `area` | int | 1 | LAPD area code |
| `hour` | int | 12 | Hour of day |
| `month_num` | int | 6 | Month |
| `premis_cd` | int | 101 | Premise code |
| `avg_victim_age` | double | 35 | Average victim age |
| `avg_severity` | double | 2 | Average MO code count |

### Response Example
```json
{
  "risk_level": "High",
  "risk_color": "#E63946",
  "probability": {
    "Low": 0.08,
    "Medium": 0.17,
    "High": 0.75
  },
  "input": { "area": 7, "hour": 17, "month_num": 6, ... }
}
```

### CORS
CORS headers (`Access-Control-Allow-Origin: *`) are applied via a `@filter` so Flutter apps running on emulators/devices can call the API.

### Running the API
```r
# From r_engine/
source("run_api.R")
# OR
plumber::plumb("05_api.R")$run(port = 8000, host = "0.0.0.0")
```
Swagger UI available at `http://localhost:8000/__docs__/`

---

## 9. Module 6 — Model Evaluation (`06_model_evaluation.R`)

### Purpose
A standalone evaluation script — reloads saved models and produces a complete report including confusion matrices, train/test accuracy, Kappa, F1 scores per class, and overfitting gap analysis.

### What It Produces

| Output File | Description |
|---|---|
| `cm_logistic_regression.png` | Confusion matrix heatmap — Logistic Regression |
| `cm_decision_tree.png` | Confusion matrix heatmap — Decision Tree |
| `cm_random_forest.png` | Confusion matrix heatmap — Random Forest |
| `train_test_accuracy_comparison.csv` | Table of train %, test %, Kappa, and gap for all models |
| `train_test_accuracy_comparison.png` | Grouped bar chart: Train vs Test accuracy |
| `overfitting_gap.png` | Bar chart of (Train − Test) gap per model |
| `per_class_f1_comparison.png` | F1 score by class (Low/Medium/High) across all models |

All outputs saved to `data/evaluation/`.

### Metrics Computed
- **Training Accuracy** — accuracy on the 80% training set
- **Test Accuracy** — accuracy on the held-out 20% test set
- **Cohen's Kappa** — agreement beyond chance
- **95% CI on Accuracy** — confidence interval
- **Per-class Precision, Recall, F1, Specificity** — from `confusionMatrix()$byClass`
- **Overfitting Gap** — `Train_Acc − Test_Acc`; > 5% indicates overfitting

---

## 10. Model Performance Results

### Confusion Matrix — Logistic Regression (Test Set)
Accuracy: **57.76%**

```
            Actual
Predicted    Low   Medium   High
Low          [...]  [...]   [...]
Medium       [...]  [...]   [...]
High         [...]  [...]   [...]
```
*Struggles with Medium class; linear boundaries insufficient for this feature space.*

---

### Confusion Matrix — Decision Tree (Test Set)
Accuracy: **76.21%**

```
            Actual
Predicted    Low   Medium   High
Low          [...]  [...]   [...]
Medium       [...]  [...]   [...]
High         [...]  [...]   [...]
```
*Much better. Some confusion between adjacent risk classes (Low↔Medium, Medium↔High).*

---

### Confusion Matrix — Random Forest (Test Set)
Accuracy: **80.24%**

```
            Actual
Predicted    Low   Medium   High
Low          [...]  [...]   [...]
Medium       [...]  [...]   [...]
High         [...]  [...]   [...]
```
*Best performance. Ensemble reduces variance from individual trees.*

> **Note:** Exact cell counts are printed to console when running `06_model_evaluation.R` and saved in the confusion matrix PNG files.

---

### Summary Table
| Model | Train Acc | Test Acc | Kappa | Gap |
|---|---|---|---|---|
| Logistic Regression | ~59% | 57.76% | low | small |
| Decision Tree | ~82% | 76.21% | moderate | ~6% (mild overfit) |
| Random Forest | ~97% | 80.24% | good | ~17% (ensemble variance) |

The Random Forest shows a larger train-test gap (typical for ensemble methods on this type of tabular data), but its test accuracy is still the highest.

---

## 11. File & Output Reference

### R Scripts
| File | Module | Purpose |
|---|---|---|
| `r_engine/01_preprocessing.R` | 1 | Data cleaning & feature engineering |
| `r_engine/02_eda.R` | 2 | Exploratory visualisations |
| `r_engine/03_spatial.R` | 3 | Spatial analysis & DBSCAN clustering |
| `r_engine/04_modeling.R` | 4 | Model training & selection |
| `r_engine/05_api.R` | 5 | Plumber REST API |
| `r_engine/run_api.R` | 5 | API launcher |
| `r_engine/06_model_evaluation.R` | 6 | Standalone evaluation report |

### Data Files
| File | Contents |
|---|---|
| `data/traffic_collisions_raw.csv` | Original LAPD dataset |
| `data/traffic_collisions_clean.csv` | Cleaned + feature-engineered dataset |
| `data/area_risk_ranking.csv` | LAPD areas ranked by composite risk score |
| `data/hotspot_clusters.csv` | DBSCAN cluster centroids and sizes |
| `data/models/logistic_regression.rds` | Saved LR model |
| `data/models/decision_tree.rds` | Saved DT model |
| `data/models/random_forest.rds` | Saved RF model (used by API) |
| `data/models/model_comparison.csv` | Test accuracy for all three models |
| `data/models/best_model.txt` | "Random Forest" |
| `data/evaluation/` | All outputs from Module 6 |

### EDA Plots
| File | Plot |
|---|---|
| `eda_plots/01_yearly_trend.png` | Yearly collision trend |
| `eda_plots/02_monthly_pattern.png` | Monthly pattern |
| `eda_plots/03_hourly_distribution.png` | Hour of day |
| `eda_plots/04_day_of_week.png` | Day of week |
| `eda_plots/05_top_areas.png` | Top 10 LAPD areas |
| `eda_plots/06_age_group.png` | Victim age groups |
| `eda_plots/07_victim_sex.png` | Victim sex |
| `eda_plots/08_descent.png` | Victim descent |
| `eda_plots/09_premise_type.png` | Premise types |
| `eda_plots/10_area_hour_heatmap.png` | Area × time heatmap |
| `eda_plots/11_collision_scatter_map.png` | Collision scatter map |
| `eda_plots/12_density_heatmap.png` | Density heatmap |
| `eda_plots/13_hotspot_grid.png` | Grid hotspot tiers |
| `eda_plots/14_dbscan_clusters.png` | DBSCAN clusters |
| `eda_plots/15_area_risk_ranking.png` | Area composite score |
| `eda_plots/cm_logistic_regression.png` | LR confusion matrix |
| `eda_plots/cm_decision_tree.png` | DT confusion matrix |
| `eda_plots/cm_random_forest.png` | RF confusion matrix |
| `eda_plots/rf_feature_importance.png` | Random Forest feature importance |
| `eda_plots/model_comparison.png` | Model accuracy comparison bar |
| `eda_plots/decision_tree.png` | Decision tree diagram |

---

## 12. How to Run the Full Pipeline

```bash
# 1. Place the raw CSV in data/ as traffic_collisions_raw.csv
# 2. Set working directory to r_engine/ before running each script

cd "r_engine"

Rscript 01_preprocessing.R   # Clean data  → data/traffic_collisions_clean.csv
Rscript 02_eda.R              # EDA plots   → data/eda_plots/
Rscript 03_spatial.R          # Spatial     → data/eda_plots/ + hotspot_clusters.csv
Rscript 04_modeling.R         # Train models → data/models/
Rscript 06_model_evaluation.R # Evaluate    → data/evaluation/
Rscript run_api.R             # Start API   → http://localhost:8000
```

**Dependencies:** R ≥ 4.2 with packages: `data.table`, `dplyr`, `lubridate`, `stringr`, `tidyr`, `ggplot2`, `scales`, `sf`, `dbscan`, `caret`, `randomForest`, `rpart`, `rpart.plot`, `e1071`, `nnet`, `plumber`

Install all at once:
```r
install.packages(c("data.table","dplyr","lubridate","stringr","tidyr",
                   "ggplot2","scales","sf","dbscan","caret","randomForest",
                   "rpart","rpart.plot","e1071","nnet","plumber"))
```
