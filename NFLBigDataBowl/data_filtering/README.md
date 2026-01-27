# Data Filtering Scripts

This folder contains scripts to filter NFL Big Data Bowl 2022 data to keep only Kickoff and Punt plays.

## Scripts

1. **validate_files.py** - Validates that all CSV files have the required columns before filtering
2. **filter_kickoff_punt_data.py** - Main filtering script that removes non-Kickoff/Punt plays from all data files

## Usage

### Step 1: Validate Files (Recommended)
```bash
cd data_filtering
python validate_files.py
```

This will check that all required files exist and have the necessary columns (`gameId`, `playId`, and `specialTeamsPlayType` for plays.csv).

### Step 2: Run Filtering Script
```bash
python filter_kickoff_punt_data.py
```

This will:
- Filter `plays.csv` to keep only rows where `specialTeamsPlayType` is "Kickoff" or "Punt"
- Remove matching plays from `PFFScoutingData.csv`
- Remove matching plays from `tracking2018.csv`, `tracking2019.csv`, and `tracking2020.csv`
- **Overwrite the original files** (no backups are created)

## What Gets Filtered

The script filters data in the `../nfl-big-data-bowl-2022/` directory:
- `plays.csv` - Keeps only Kickoff/Punt plays
- `PFFScoutingData.csv` - Removes plays that aren't Kickoff/Punt
- `tracking2018.csv` - Removes plays that aren't Kickoff/Punt
- `tracking2019.csv` - Removes plays that aren't Kickoff/Punt
- `tracking2020.csv` - Removes plays that aren't Kickoff/Punt

## Important Notes

⚠️ **WARNING**: The filtering script **overwrites original files**. Make sure you have backups elsewhere if needed.

The script matches plays using both `gameId` and `playId` to ensure accurate filtering across all files.

For large tracking files (>200MB), the script processes them in chunks of 100,000 rows to avoid memory issues.

