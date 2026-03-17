# NFL Punt Returns Analysis

An analytical framework for evaluating punt return decisions in the NFL using player tracking data and win probability modeling. Built on the **NFL Big Data Bowl 2022** dataset (2018 season) and **nflfastR** play-by-play data.

## Research Question

**When should a punt returner return the ball, fair catch, or let it bounce?**

This project quantifies each decision using expected win probability (WP), accounting for physical context like gunner proximity, hang time, and punt distance.

## Project Structure

```
NFL-Punt-Returns-Analysis/
├── README.md
├── NFL Punt Returns.Rproj
│
├── NFLBigDataBowl/                          # Raw data pipeline
│   └── data_filtering/
│       ├── filter_kickoff_punt_data.py       # Filters to Kickoff/Punt plays only
│       └── validate_files.py                 # Validates CSVs for required columns
│
├── prelim_punt_win_probs.R                   # Builds punts_with_wp.csv + enriched tracking
├── punt_return_and_fair_catch_wps.R          # Return vs. fair-catch WP delta analysis
│
├── Decision Model Analysis/                  # Decision model pipeline
│   ├── punt_features.R                       # Extracts physical features at catch frame
│   ├── punt_decision_model_starter.R         # Trains models + Monte Carlo expected WP
│   ├── decision_model_analysis.R             # Summary stats + visualizations
│   └── contextual_analysis.R                 # Contextual validation (Q4, close games, etc.)
│
├── punts_with_wp.csv                         # All punts with WP context (5,991 plays)
└── punt_return_vs_faircatch_wp_delta_return_team.csv
```

## Analysis Pipeline

### 1. Data Preparation (Python)

Filter the raw Big Data Bowl CSVs down to special teams plays:

```bash
cd NFLBigDataBowl/data_filtering
python validate_files.py
python filter_kickoff_punt_data.py
```

**Prerequisite:** Download the [NFL Big Data Bowl 2022](https://www.kaggle.com/competitions/nfl-big-data-bowl-2022) dataset and place it in `NFLBigDataBowl/data_filtering/nfl-big-data-bowl-2022/`.

### 2. Win Probability Enrichment (R)

```r
source("prelim_punt_win_probs.R")
```

Joins BDB tracking/play data with nflfastR play-by-play to produce `punts_with_wp.csv` (all 5,991 punt plays with pre/post WP, score differential, game clock, etc.) and `tracking_punts_enriched.csv`.

### 3. Return vs. Fair Catch Comparison (R)

```r
source("punt_return_and_fair_catch_wps.R")
```

For each non-fair-catch punt, computes the counterfactual: "What would WP have been if the returner had fair caught instead?" Uses `nflfastR::calculate_win_probability()` to estimate the fair-catch state.

### 4. Decision Model (R)

```r
source("Decision Model Analysis/punt_features.R")
source("Decision Model Analysis/punt_decision_model_starter.R")
```

- **Feature extraction:** Computes per-play physical features at the catch frame — closest gunner distance, furthest blocker distance, hang time, kick type, punt direction.
- **Outcome models (baseline):**
  - Muff probability (logistic regression)
  - Return yards (linear regression)
  - Touchback probability (logistic regression)
- **Expected WP engine:** For each play, runs 300 Monte Carlo simulations per action (RETURN / FAIR_CATCH / BOUNCE) and recommends the action with the highest expected WP.

### 5. Model Exploration (R)

```r
source("Decision Model Analysis/decision_model_analysis.R")
source("Decision Model Analysis/contextual_analysis.R")
```

- Strategy distribution and average WP per choice
- Physical context breakdowns (gunner distance, hang time by recommendation)
- Gunner proximity vs. return advantage visualization
- Contextual validation across game situations (Q4, close games, late-in-quarter)

## Key Outputs

| File | Description |
|------|-------------|
| `punts_with_wp.csv` | All 5,991 punt plays with full game-state context and WP |
| `punt_return_vs_faircatch_wp_delta_return_team.csv` | Per-play WP delta (actual return vs. fair catch counterfactual) |
| `Decision Model Analysis/punt_features.csv` | Physical features at catch frame (1,452 plays) |
| `Decision Model Analysis/punt_decision_expected_wp.csv` | Expected WP for each action + recommended decision (863 plays) |

## Tech Stack

- **R:** tidyverse, nflfastR, readr, stringr, lubridate
- **Python:** pandas, numpy
- **Data:** NFL Big Data Bowl 2022 (2018 tracking season), nflfastR play-by-play (2018–2020)

## Dependencies

### R

```r
install.packages(c("tidyverse", "readr", "stringr", "lubridate", "nflfastR"))
```

### Python

```bash
pip install pandas numpy
```
