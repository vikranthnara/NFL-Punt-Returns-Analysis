import pandas as pd
from pathlib import Path
import csv
from io import StringIO

# Configuration - point to parent directory
BASE_DIR = Path("../nfl-big-data-bowl-2022")

print("="*70)
print("VALIDATING CSV FILE STRUCTURES")
print("="*70)
print()

# Files to check
files_to_check = {
    "plays.csv": ["gameId", "playId", "specialTeamsPlayType"],
    "PFFScoutingData.csv": ["gameId", "playId"],
    "tracking2018.csv": ["gameId", "playId"],
    "tracking2019.csv": ["gameId", "playId"],
    "tracking2020.csv": ["gameId", "playId"]
}

validation_passed = True

for filename, required_cols in files_to_check.items():
    file_path = BASE_DIR / filename
    
    print(f"Checking {filename}...")
    
    if not file_path.exists():
        print(f"  ✗ File not found: {filename}")
        validation_passed = False
        print()
        continue
    
    try:
        # For large files, just read the header
        if filename.startswith("tracking"):
            # Read just first row for tracking files (they're huge)
            with open(file_path, 'r') as f:
                header_line = f.readline().strip()
            # Parse CSV header
            reader = csv.reader(StringIO(header_line))
            columns = next(reader)
        else:
            # For smaller files, use pandas
            df = pd.read_csv(file_path, nrows=0)  # Read only header
            columns = df.columns.tolist()
        
        print(f"  Columns found: {len(columns)}")
        print(f"  First 5 columns: {columns[:5]}")
        
        # Check for required columns
        missing_cols = []
        for col in required_cols:
            if col not in columns:
                missing_cols.append(col)
        
        if missing_cols:
            print(f"  ✗ Missing required columns: {missing_cols}")
            validation_passed = False
        else:
            print(f"  ✓ All required columns present: {required_cols}")
        
        # Special check for plays.csv
        if filename == "plays.csv":
            # Check if specialTeamsPlayType has the values we expect
            df_sample = pd.read_csv(file_path, nrows=1000)
            unique_types = df_sample['specialTeamsPlayType'].dropna().unique()
            print(f"  specialTeamsPlayType values (sample): {sorted(unique_types)}")
            if 'Kickoff' not in unique_types and 'Punt' not in unique_types:
                print(f"  ⚠ Warning: No 'Kickoff' or 'Punt' found in sample (may be in full dataset)")
        
    except Exception as e:
        print(f"  ✗ Error reading file: {e}")
        validation_passed = False
    
    print()

# Final validation result
print("="*70)
if validation_passed:
    print("✓ VALIDATION PASSED - All files have required columns")
    print("  The filtering script should work correctly.")
else:
    print("✗ VALIDATION FAILED - Some files are missing required columns")
    print("  Please fix the issues above before running the filtering script.")
print("="*70)

