# US Road Safety Intelligence & Risk Prediction System
### BCSE207L — Programming for Data Science | VIT Vellore | Winter 2025-26

A full end-to-end data science project analyzing **LA traffic collision data** to predict accident risk levels using machine learning, served via a REST API and visualized in Flutter and Power BI.

---

## Project Structure

```
.
├── r_engine/                   # All R scripts (pipeline)
│   ├── 01_preprocessing.R      # Data cleaning & feature engineering
│   ├── 02_eda.R                # Exploratory data analysis (ggplot2)
│   ├── 03_spatial.R            # Spatial hotspot analysis (DBSCAN)
│   ├── 04_modeling.R           # ML models (LR, Decision Tree, Random Forest)
│   ├── 05_api.R                # Plumber REST API definition
│   ├── 06_model_evaluation.R   # Model metrics and evaluation
│   ├── run_api.R               # Local API launcher
│   └── entrypoint.R            # Docker container entrypoint
├── flutter_app/                # Flutter mobile/web frontend
├── data/
│   ├── eda_plots/              # All generated ggplot2 visualizations
│   ├── models/                 # Trained model .rds files
│   ├── area_risk_ranking.csv   # Area-level risk scores
│   └── hotspot_clusters.csv    # DBSCAN cluster output
├── Dockerfile                  # Docker image for R Plumber API
├── docker-compose.yml          # Container orchestration
├── .env.example                # Environment variable template
├── PowerBI_R_Integration_Guide.md
└── R_ML_Documentation.md
```

---

## Dataset

- **Source:** [LAPD Traffic Collision Data](https://data.lacity.org/) — LA City Open Data Portal (Socrata API)
- **Size:** 800,000+ rows, 20+ attributes
- **Types:** Numeric + Categorical (date, location, victim demographics, premise)
- **Not from Kaggle** — fetched directly via Socrata REST API with authentication

---

## API Integration

Socrata Open Data API used for data ingestion:
- Authentication via app token (`X-App-Token` header)
- Pagination via `$limit` and `$offset` query params
- JSON response converted to R data frame via `jsonlite`

---

## Installation & Execution

### Prerequisites
- R >= 4.2
- Required packages (auto-installed by scripts):
  `data.table`, `dplyr`, `ggplot2`, `lubridate`, `caret`,
  `randomForest`, `rpart`, `plumber`, `httr`, `jsonlite`, `dbscan`

### Run the pipeline locally

```bash
# From r_engine/ directory, run scripts in order:
Rscript 01_preprocessing.R
Rscript 02_eda.R
Rscript 03_spatial.R
Rscript 04_modeling.R
Rscript 06_model_evaluation.R

# Start the API
Rscript run_api.R
# API available at http://localhost:8000
# Swagger docs at http://localhost:8000/__docs__/
```

### Run with Docker

```bash
# Build image
docker build -t sruthipyda/road-safety-api:1.0 .

# Run container
docker-compose up

# API available at http://localhost:8000
```

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/predict` | Predict risk level for area/time/premise |
| POST | `/predict/batch` | Batch predict for multiple inputs |
| GET | `/areas/ranking` | Get top N areas by risk score |
| GET | `/hotspots` | Get top N accident hotspot clusters |

**Example:**
```
GET http://localhost:8000/predict?area=1&hour=17&month_num=6&premis_cd=101
```

---

## Models & Results

| Model | Accuracy |
|---|---|
| Random Forest | ~87% |
| Decision Tree | ~79% |
| Logistic Regression | ~74% |

**Best model:** Random Forest
**Top features:** Hour of day, LAPD area, month, premise type

---

## Power BI Dashboard

See `PowerBI_R_Integration_Guide.md` for full setup.

**3-page dashboard:**
1. **Overview** — KPI cards, yearly trend line, top areas
2. **Deep Dive** — R visual heatmap (Area × Time), hour/day patterns
3. **Model Results** — R visual feature importance, model accuracy comparison

---

## Docker Hub

```bash
docker pull sruthipyda/road-safety-api:1.0
```

> Note: Power BI module is excluded from containerization as per project requirements.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in:

```
SOCRATA_APP_TOKEN=your_token_here
API_PORT=8000
```

**Never commit `.env` to GitHub.**

---

## Git Branches

- `main` — stable, production-ready code
- `development` — active development, feature branches merged here before main
