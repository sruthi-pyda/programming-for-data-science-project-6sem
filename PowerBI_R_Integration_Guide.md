# Power BI + R Integration Guide
## US Road Safety Project — BCSE207L

---

## Prerequisites

1. Install **Power BI Desktop** (Windows only — use a Windows PC or VM)
2. Install **R** on that same machine
3. In Power BI Desktop → `File > Options > R scripting` → set your R home directory
4. Install required R packages on that machine:
   ```r
   install.packages(c("ggplot2", "scales", "dplyr", "data.table"))
   ```

---

## Step 1: Load Data into Power BI

`Home > Get Data > Text/CSV` — load the following files:

| File | Purpose |
|---|---|
| `data/area_risk_ranking.csv` | Area-level risk scores |
| `data/hotspot_clusters.csv` | DBSCAN cluster results |
| `data/models/model_comparison.csv` | Model accuracy comparison |

> The two large raw CSVs are excluded from git — load them directly from your local machine path when building the `.pbix` file.

---

## Step 2: R Custom Visuals (ggplot2-based)

In the Visualizations pane, click the **R script visual** icon (`R`).
Drag the required columns into the Values field, then paste the script into the R editor.

### Visual 1 — Collision Heatmap (Area × Time of Day)

**Columns needed:** `area_name`, `hour_bucket`, `N` (collision count)

```r
library(ggplot2)
library(scales)

# Power BI passes selected columns as 'dataset'
ggplot(dataset, aes(x = hour_bucket, y = area_name, fill = N)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "#FFF3CD", high = "#E63946", labels = comma) +
  labs(
    title = "Collision Heatmap: Area × Time of Day",
    x     = "Time of Day",
    y     = "LAPD Area",
    fill  = "Collisions"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title   = element_text(face = "bold"),
    axis.text.x  = element_text(angle = 20, hjust = 1)
  )
```

---

### Visual 2 — Random Forest Feature Importance

**Columns needed:** `Feature`, `MeanDecreaseAccuracy`

```r
library(ggplot2)

ggplot(dataset, aes(x = MeanDecreaseAccuracy,
                    y = reorder(Feature, MeanDecreaseAccuracy))) +
  geom_col(fill = "#E63946", alpha = 0.85) +
  geom_text(aes(label = round(MeanDecreaseAccuracy, 1)),
            hjust = -0.2, size = 3.5) +
  labs(
    title = "Random Forest – Feature Importance",
    x     = "Mean Decrease in Accuracy",
    y     = "Feature"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))
```

---

## Step 3: Native Power BI Visuals (Key Stats + Trend Lines)

| What to show | Visual type |
|---|---|
| Collisions per year | Line chart → Analytics pane → `+ Trend line` |
| Top 10 areas by collisions | Horizontal bar chart |
| Risk level distribution (Low / Medium / High) | Donut chart |
| Model accuracy comparison | Clustered bar chart from `model_comparison.csv` |
| Total collisions, unique areas, year range | Card visuals |

---

## Step 4: Model Predictions Display

Load `data/models/model_comparison.csv` and create a **Table visual**:

| Model | Accuracy |
|---|---|
| Random Forest | 87.x% |
| Decision Tree | 79.x% |
| Logistic Regression | 74.x% |

Add a **Card visual** with the text: `Best Model: Random Forest`

---

## Step 5: Insights & Storytelling

Add a **Text Box** on each page with a short narrative. Example:

> Traffic collisions peak between **3–6 PM on Fridays**. The **77th Street** area has the highest collision count. The Random Forest model achieves **87% accuracy** and identifies **hour of day** and **area** as the strongest risk predictors.

---

## Dashboard Layout (3 pages)

### Page 1 — Overview
- KPI cards: Total Collisions · Unique Areas · Year Range
- Line chart: Collisions per Year + trend line
- Bar chart: Top 10 Areas by Collision Count
- Slicer: Year

### Page 2 — Deep Dive
- **R Visual**: Heatmap — Area × Time of Day
- Bar chart: Collisions by Hour of Day
- Bar chart: Collisions by Day of Week
- Slicer: Area Name

### Page 3 — Model Results
- **R Visual**: Random Forest Feature Importance
- Table: Model Accuracy Comparison
- Donut chart: Risk Level Distribution
- Card: Best Model name + accuracy

---

## Interactivity

Add **Slicers** to each page:
- `Year` — filters trend and count visuals
- `Area Name` — filters heatmap and bar charts
- `Risk Level` — filters model results page

---

## Checklist

- [ ] R home path configured in Power BI options
- [ ] Data loaded from CSV files
- [ ] R Visual 1: Heatmap (Area × Time of Day)
- [ ] R Visual 2: Feature Importance chart
- [ ] Line chart with trend line (yearly collisions)
- [ ] Model accuracy table + best model card
- [ ] Slicers added for interactivity
- [ ] Insights text boxes on each page
- [ ] `.pbix` file screenshot added to GitHub README
