# Methodology & Future Scope
## LA Road Safety Intelligence System

---

## PART 1 — METHODOLOGY

### Project Pipeline Overview

An 8-step end-to-end data science pipeline was built to analyse, model, and visualise traffic collision data from the City of Los Angeles.

---

### Step 01 — Data Collection

Downloaded the LAPD Traffic Collision dataset from **data.lacity.org** (~600,000 records). Data spans 2010 to present, transcribed from original paper police reports.

**Source:** data.lacity.org | **Format:** CSV

---

### Step 02 — Preprocessing (R)

- Loaded with `data.table::fread` for memory efficiency
- Standardised column names to snake_case
- Parsed date/time with `lubridate`; extracted Year, Month, Day, Hour
- Created hour buckets (Night / Morning / Afternoon / Evening)
- Cleaned victim age (removed negatives/outliers), sex, descent codes
- Validated lat/lon within LA bounding box; replaced (0,0) nulls
- Computed historical frequency per area × hour × month as a feature

**Tech Stack:** R — `data.table`, `dplyr`, `lubridate`, `stringr`

---

### Step 03 — Exploratory Analysis (R)

- Yearly / monthly / hourly / day-of-week collision trends
- Top areas by collision count
- Victim age group, sex, and descent distributions
- Premise type breakdown
- Area × Time-of-Day heatmap

**Tech Stack:** R — `ggplot2`, `dplyr`, `scales`

---

### Step 04 — Spatial Analysis (R)

- Scatter and density maps of all collision points
- 50×50 grid-based hotspot counting with risk tier labels
- DBSCAN clustering (eps = 0.005° ≈ 500 m, minPts = 30) to find accident clusters
- Composite area risk score = normalised(count) + normalised(severity)

**Tech Stack:** R — `sf`, `dbscan`, `ggplot2`

---

### Step 05 — Predictive Modelling (R)

- Aggregated data to area × hour × month level
- Risk labels: **Low / Medium / High** based on 33rd / 66th percentile splits
- Features: Area, Hour, Month, Premise Code, Avg Age, Avg Severity
- 80/20 train-test split with 5-fold cross-validation
- Models: Logistic Regression (baseline), Decision Tree, Random Forest
- Evaluated with Accuracy, Confusion Matrix, Feature Importance

**Tech Stack:** R — `caret`, `randomForest`, `rpart`, `e1071`

---

### Step 06 — REST API (R Plumber)

- Plumber exposes `/predict`, `/predict/batch`, `/areas/ranking`, `/hotspots`
- Trained Random Forest model loaded at startup
- CORS headers enabled for Flutter app requests
- Returns JSON with risk level, colour, and probabilities

**Tech Stack:** R — `plumber`, `randomForest`, `jsonlite`

---

### Step 07 — Visualisation (Power BI)

- 5 dashboard pages: Overview, Time Analysis, Location, Demographics, Predictions
- Published via "Publish to Web" (free embed)
- Dynamic slicers for year, area, time period
- Embedded in Flutter app via WebView

**Tech Stack:** Power BI Desktop → Publish to Web

---

### Step 08 — Flutter App

- 4 screens: Home, Dashboard, Insights, Prediction
- Bottom navigation with IndexedStack for performance
- Prediction screen posts to Plumber API, displays result with pie chart
- Dashboard screen embeds Power BI via WebView
- Provider for state management; `fl_chart` for local charts

**Tech Stack:** Flutter/Dart — `webview_flutter`, `http`, `fl_chart`, `provider`

---
---

## PART 2 — FUTURE SCOPE

### Beyond the Project

This system lays the foundation for a real-time, AI-powered urban safety platform. Below are the planned enhancements grouped by implementation timeline.

---

### Short-Term Enhancements

#### Real-Time Data Ingestion
Connect to live LAPD incident feeds and 911 dispatch APIs to update hotspot maps and risk predictions in near real-time, enabling truly proactive responses.

#### Weather-Based Risk Prediction
Integrate NOAA weather APIs to factor rain, fog, and ice conditions into the predictive model. Wet roads increase collision probability by 4×.

---

### Medium-Term Enhancements

#### Google Maps Integration
Overlay accident hotspots and real-time risk scores onto navigation routes. Warn drivers when entering high-risk corridors and suggest safer alternatives.

#### Mobile Safety Alerts
Push notifications when a user's GPS location approaches a known hotspot or when risk conditions are elevated (e.g., Friday evening in 77th Street division).

---

### Long-Term Enhancements

#### Deep Learning Models
Replace Random Forest with LSTM or Transformer-based time-series models for improved sequence modelling of accident trends and hour-ahead risk forecasting.

#### Smart City Integration
Feed risk scores into city traffic management systems to dynamically adjust signal timing, speed limits, and lane configurations during high-risk windows.

---

### Real-World Applications

| Stakeholder | Application |
|---|---|
| **Traffic Police** | Optimised patrol allocation to hotspots |
| **Urban Planners** | Data-driven road design & infrastructure |
| **Emergency Services** | Pre-position ambulances near clusters |
| **Insurance** | Risk-based premium calculation |

---

*Document prepared from the LA Road Safety Intelligence Flutter application — Methods and Future Scope screens.*
