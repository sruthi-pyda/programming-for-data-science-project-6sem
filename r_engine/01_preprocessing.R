# =============================================================================
# MODULE 1: DATA PREPROCESSING
# US Road Accident Intelligence & Risk Prediction System
# Dataset: LA Traffic Collision Data (2010–Present)
# =============================================================================

# ── 1. Install & Load Libraries ──────────────────────────────────────────────
required_packages <- c("data.table", "dplyr", "lubridate", "stringr", "tidyr")
new_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]
if (length(new_packages)) install.packages(new_packages, repos = "https://cloud.r-project.org")

library(data.table)
library(dplyr)
library(lubridate)
library(stringr)
library(tidyr)

# ── 2. Load Raw Data ──────────────────────────────────────────────────────────
cat("Loading raw data...\n")

# Place the downloaded CSV in the ../data/ folder
raw_path <- file.path(dirname(getwd()), "data", "traffic_collisions_raw.csv")

# data.table::fread is memory-efficient for large CSVs
dt <- fread(raw_path, na.strings = c("", "NA", "NULL", "N/A"))

cat(sprintf("Loaded %d rows x %d columns\n", nrow(dt), ncol(dt)))
cat("Column names:\n")
print(names(dt))

# ── 3. Standardise Column Names ───────────────────────────────────────────────
# Rename to snake_case for consistency
setnames(dt, old = names(dt), new = str_to_lower(str_replace_all(names(dt), " ", "_")))

cat("\nStandardised column names:\n")
print(names(dt))

# ── 3b. Map actual downloaded column names → expected names ──────────────────
col_map <- c(
  dr_number                = "dr_no",
  date_reported            = "date_rptd",
  date_occurred            = "date_occ",
  time_occurred            = "time_occ",
  area_id                  = "area",
  reporting_district       = "rpt_dist_no",
  crime_code               = "crm_cd",
  crime_code_description   = "crm_cd_desc",
  mo_codes                 = "mocodes",
  victim_age               = "vict_age",
  victim_sex               = "vict_sex",
  victim_descent           = "vict_descent",
  premise_code             = "premis_cd",
  premise_description      = "premis_desc",
  address                  = "location"
)
for (from in names(col_map)) {
  to <- col_map[[from]]
  if (from %in% names(dt) && !to %in% names(dt)) setnames(dt, from, to)
}

# ── 3c. Extract lat/lon from Location column "(lat, lon)" ────────────────────
if ("location" %in% names(dt) && !all(c("lat", "lon") %in% names(dt))) {
  dt[, lat := as.numeric(str_match(location, "\\(([^,]+),")[, 2])]
  dt[, lon := as.numeric(str_match(location, ",\\s*([^)]+)\\)")[, 2])]
  cat("Extracted lat/lon from Location column.\n")
}

cat("\nFinal column names after remapping:\n")
print(names(dt))

# ── 4. Select Relevant Columns ────────────────────────────────────────────────
# Core columns present in the LAPD dataset
cols_keep <- c(
  "dr_no",             # report number (unique ID)
  "date_rptd",         # date reported
  "date_occ",          # date occurred
  "time_occ",          # time occurred (HHMM format)
  "area",              # area code
  "area_name",         # area name
  "rpt_dist_no",       # reporting district number
  "crm_cd",            # crime/collision code
  "crm_cd_desc",       # description
  "mocodes",           # MO codes (severity proxy)
  "vict_age",          # victim age
  "vict_sex",          # victim sex
  "vict_descent",      # victim descent/ethnicity
  "premis_cd",         # premise code
  "premis_desc",       # premise description
  "location",          # street address
  "cross_street",      # cross street
  "lat",               # latitude
  "lon"                # longitude
)

# Keep only columns that actually exist in the dataset
cols_keep <- intersect(cols_keep, names(dt))
dt <- dt[, ..cols_keep]

cat(sprintf("\nRetained %d columns\n", length(cols_keep)))

# ── 5. Parse & Extract Date/Time Features ────────────────────────────────────
cat("\nParsing date and time fields...\n")

# date_occ is typically "MM/DD/YYYY hh:mm:ss AM/PM"
dt[, date_occ_parsed := mdy_hms(date_occ, quiet = TRUE)]

# Fallback: try mdy if datetime parse fails
dt[is.na(date_occ_parsed), date_occ_parsed := mdy(date_occ, quiet = TRUE)]

# Extract components
dt[, `:=`(
  year       = year(date_occ_parsed),
  month      = month(date_occ_parsed, label = TRUE, abbr = TRUE),
  month_num  = month(date_occ_parsed),
  day_of_week = wday(date_occ_parsed, label = TRUE, abbr = TRUE),
  day_num    = day(date_occ_parsed)
)]

# time_occ is HHMM integer (e.g. 1430 = 14:30)
dt[, time_occ := str_pad(as.character(time_occ), width = 4, pad = "0")]
dt[, hour := as.integer(str_sub(time_occ, 1, 2))]
dt[hour > 23, hour := NA_integer_]   # sanitise bad values

# Hour buckets
dt[, hour_bucket := fcase(
  hour >= 0  & hour < 6,  "Night (00–06)",
  hour >= 6  & hour < 12, "Morning (06–12)",
  hour >= 12 & hour < 18, "Afternoon (12–18)",
  hour >= 18 & hour < 24, "Evening (18–24)",
  default = NA_character_
)]

cat("Date/time parsing complete.\n")

# ── 6. Clean Victim Demographics ─────────────────────────────────────────────
cat("\nCleaning victim demographics...\n")

# --- Age ---
dt[, vict_age := as.integer(vict_age)]
dt[vict_age <= 0 | vict_age > 120, vict_age := NA_integer_]

dt[, age_group := fcase(
  vict_age >= 0  & vict_age <= 17, "Minor (0–17)",
  vict_age >= 18 & vict_age <= 25, "Young Adult (18–25)",
  vict_age >= 26 & vict_age <= 40, "Adult (26–40)",
  vict_age >= 41 & vict_age <= 60, "Middle-Aged (41–60)",
  vict_age >= 61,                   "Senior (61+)",
  default = NA_character_
)]

# --- Sex ---
dt[, vict_sex := str_to_upper(str_trim(vict_sex))]
dt[!(vict_sex %in% c("M", "F")), vict_sex := NA_character_]
dt[, vict_sex_label := fcase(
  vict_sex == "M", "Male",
  vict_sex == "F", "Female",
  default = NA_character_
)]

# --- Descent (ethnicity codes) ---
descent_map <- c(
  A = "Asian", B = "Black", C = "Chinese", D = "Cambodian",
  F = "Filipino", G = "Guamanian", H = "Hispanic/Latino",
  I = "Native American", J = "Japanese", K = "Korean",
  L = "Laotian", O = "Other", P = "Pacific Islander",
  S = "Samoan", U = "Hawaiian", V = "Vietnamese",
  W = "White", X = "Unknown", Z = "Asian Indian"
)
dt[, vict_descent := str_to_upper(str_trim(vict_descent))]
dt[, descent_label := descent_map[vict_descent]]

cat("Demographics cleaned.\n")

# ── 7. Clean Location / Coordinates ───────────────────────────────────────────
cat("\nCleaning location data...\n")

dt[, lat := as.numeric(lat)]
dt[, lon := as.numeric(lon)]

# Remove rows where lat/lon are (0,0) — null island placeholder
dt[lat == 0 & lon == 0, `:=`(lat = NA_real_, lon = NA_real_)]

# Bounding box for Los Angeles (rough)
dt[lat < 33.7 | lat > 34.4, lat := NA_real_]
dt[lon < -118.7 | lon > -117.9, lon := NA_real_]

cat(sprintf("Valid coordinates: %d / %d rows\n",
            nrow(dt[!is.na(lat) & !is.na(lon)]), nrow(dt)))

# ── 8. Clean Premise & MO Codes ──────────────────────────────────────────────
dt[, premis_cd := as.integer(premis_cd)]
dt[, premis_desc := str_to_title(str_trim(premis_desc))]

# Count MO codes as a rough severity proxy (more codes = more complex incident)
dt[, mo_code_count := fifelse(
  is.na(mocodes) | mocodes == "",
  0L,
  str_count(str_trim(mocodes), "\\s+") + 1L
)]

# ── 9. Handle Missing Values Summary ─────────────────────────────────────────
cat("\n── Missing Value Summary ──\n")
missing_pct <- dt[, lapply(.SD, function(x) round(mean(is.na(x)) * 100, 2))]
missing_df <- data.frame(
  column = names(missing_pct),
  missing_pct = as.numeric(missing_pct)
) |> arrange(desc(missing_pct))
print(missing_df)

# Drop rows missing both lat/lon AND date (unusable for any analysis)
rows_before <- nrow(dt)
dt <- dt[!is.na(date_occ_parsed)]
cat(sprintf("\nDropped %d rows with missing date_occ. Remaining: %d\n",
            rows_before - nrow(dt), nrow(dt)))

# ── 10. Add Historical Frequency Feature ─────────────────────────────────────
# area x hour x month — used as a feature in predictive modeling
cat("\nComputing historical accident frequency per area-hour-month...\n")
freq_table <- dt[!is.na(area) & !is.na(hour) & !is.na(month_num),
                 .(hist_freq = .N),
                 by = .(area, hour, month_num)]

dt <- merge(dt, freq_table, by = c("area", "hour", "month_num"), all.x = TRUE)
dt[is.na(hist_freq), hist_freq := 0L]

# ── 11. Save Cleaned Data ─────────────────────────────────────────────────────
out_path <- file.path(dirname(getwd()), "data", "traffic_collisions_clean.csv")
fwrite(dt, out_path)
cat(sprintf("\nCleaned data saved to: %s\n", out_path))
cat(sprintf("Final dataset: %d rows x %d columns\n", nrow(dt), ncol(dt)))

cat("\n✓ Module 1 (Preprocessing) complete.\n")
