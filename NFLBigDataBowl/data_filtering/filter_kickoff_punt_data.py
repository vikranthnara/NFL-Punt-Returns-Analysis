import pandas as pd
import numpy as np
from pathlib import Path
import warnings
import csv
from io import StringIO
warnings.filterwarnings('ignore')

# Configuration - point to parent directory
BASE_DIR = Path("NFLBigDataBowl/data_filtering/nfl-big-data-bowl-2022").resolve()
CHUNK_SIZE = 100000  # For processing large tracking files in chunks

print("="*70)
print("FILTERING DATA: Keeping only Kickoff and Punt plays")
print("="*70)
print()

# Validation: Check that all files have required columns
print("Validating file structures...")
required_cols = {
    "plays.csv": ["gameId", "playId", "specialTeamsPlayType"],
    "PFFScoutingData.csv": ["gameId", "playId"],
    "tracking2018.csv": ["gameId", "playId"],
    "tracking2019.csv": ["gameId", "playId"],
    "tracking2020.csv": ["gameId", "playId"]
}

validation_errors = []
for filename, cols in required_cols.items():
    file_path = BASE_DIR / filename
    if file_path.exists():
        try:
            if filename.startswith("tracking"):
                # For tracking files, read just header
                with open(file_path, 'r') as f:
                    header = f.readline().strip()
                reader = csv.reader(StringIO(header))
                file_cols = next(reader)
            else:
                df = pd.read_csv(file_path, nrows=0)
                file_cols = df.columns.tolist()
            
            missing = [c for c in cols if c not in file_cols]
            if missing:
                validation_errors.append(f"{filename}: missing {missing}")
        except Exception as e:
            validation_errors.append(f"{filename}: error - {e}")

if validation_errors:
    print("✗ Validation failed:")
    for error in validation_errors:
        print(f"  - {error}")
    print("\nPlease fix these issues before proceeding.")
    exit(1)
else:
    print("✓ All files have required columns")
    print()

# Step 1: Filter plays.csv
print("Step 1: Filtering plays.csv...")
plays_file = BASE_DIR / "plays.csv"
plays_df = pd.read_csv(plays_file)

print(f"  Original plays.csv: {len(plays_df):,} rows")

# Check for specialTeamsPlayType column and values
if 'specialTeamsPlayType' not in plays_df.columns:
    print("  ✗ Error: 'specialTeamsPlayType' column not found in plays.csv")
    exit(1)

# Filter to keep only Kickoff or Punt
filtered_plays = plays_df[
    plays_df['specialTeamsPlayType'].isin(['Kickoff', 'Punt'])
].copy()

print(f"  Filtered plays.csv: {len(filtered_plays):,} rows (Kickoff/Punt only)")
print(f"  Removed: {len(plays_df) - len(filtered_plays):,} rows")

# Get the removed (gameId, playId) pairs
removed_plays = plays_df[
    ~plays_df['specialTeamsPlayType'].isin(['Kickoff', 'Punt'])
][['gameId', 'playId']].copy()

# Create a set for fast lookup
removed_play_keys = set(zip(removed_plays['gameId'], removed_plays['playId']))
print(f"  Unique plays to remove from other files: {len(removed_play_keys):,}")
print()

# Save filtered plays.csv (overwrite original)
filtered_plays.to_csv(plays_file, index=False)
print(f"  ✓ Saved filtered plays.csv")
print()

# Step 2: Filter PFFScoutingData.csv
print("Step 2: Filtering PFFScoutingData.csv...")
pff_file = BASE_DIR / "PFFScoutingData.csv"

if pff_file.exists():
    pff_df = pd.read_csv(pff_file)
    print(f"  Original PFFScoutingData.csv: {len(pff_df):,} rows")
    
    # Validate columns
    if 'gameId' not in pff_df.columns or 'playId' not in pff_df.columns:
        print(f"  ✗ Error: Missing gameId or playId columns")
    else:
        # Filter out removed plays
        pff_filtered = pff_df[
            pff_df.apply(lambda row: (row['gameId'], row['playId']) not in removed_play_keys, axis=1)
        ].copy()
        
        print(f"  Filtered PFFScoutingData.csv: {len(pff_filtered):,} rows")
        print(f"  Removed: {len(pff_df) - len(pff_filtered):,} rows")
        
        # Overwrite original
        pff_filtered.to_csv(pff_file, index=False)
        print(f"  ✓ Saved filtered PFFScoutingData.csv")
else:
    print(f"  ⚠ File not found: {pff_file}")
print()

# Step 3: Filter tracking files
tracking_files = [
    BASE_DIR / "tracking2018.csv",
    BASE_DIR / "tracking2019.csv",
    BASE_DIR / "tracking2020.csv"
]

for tracking_file in tracking_files:
    if not tracking_file.exists():
        print(f"  ⚠ File not found: {tracking_file.name}")
        continue
    
    print(f"Step 3: Filtering {tracking_file.name}...")
    print(f"  This may take a while for large files...")
    
    # Process in chunks to handle large files
    filtered_chunks = []
    total_rows = 0
    
    try:
        # First, verify the file has required columns by reading header
        with open(tracking_file, 'r') as f:
            header_line = f.readline().strip()
        reader = csv.reader(StringIO(header_line))
        header_cols = next(reader)
        
        if 'gameId' not in header_cols or 'playId' not in header_cols:
            print(f"  ✗ Error: Missing gameId or playId columns in {tracking_file.name}")
            continue
        
        # Process file in chunks
        chunk_count = 0
        for chunk in pd.read_csv(tracking_file, chunksize=CHUNK_SIZE):
            chunk_count += 1
            total_rows += len(chunk)
            
            # Filter chunk
            chunk_filtered = chunk[
                chunk.apply(lambda row: (row['gameId'], row['playId']) not in removed_play_keys, axis=1)
            ]
            
            filtered_chunks.append(chunk_filtered)
            
            if chunk_count % 10 == 0:
                print(f"    Processed {chunk_count} chunks ({total_rows:,} rows so far)...")
        
        # Combine all filtered chunks
        print(f"  Combining {chunk_count} chunks...")
        tracking_filtered = pd.concat(filtered_chunks, ignore_index=True)
        
        print(f"  Original {tracking_file.name}: {total_rows:,} rows")
        print(f"  Filtered {tracking_file.name}: {len(tracking_filtered):,} rows")
        print(f"  Removed: {total_rows - len(tracking_filtered):,} rows")
        
        # Overwrite original file
        tracking_filtered.to_csv(tracking_file, index=False)
        print(f"  ✓ Saved filtered {tracking_file.name}")
        
    except Exception as e:
        print(f"  ✗ Error processing {tracking_file.name}: {e}")
        import traceback
        traceback.print_exc()
    
    print()

# Summary
print("="*70)
print("FILTERING COMPLETE")
print("="*70)
print()
print("Summary:")
print(f"  - plays.csv: Kept {len(filtered_plays):,} Kickoff/Punt plays")
print(f"  - Removed {len(removed_play_keys):,} unique plays from:")
print(f"    • PFFScoutingData.csv")
print(f"    • tracking2018.csv")
print(f"    • tracking2019.csv")
print(f"    • tracking2020.csv")
print()
print("All original files have been overwritten with filtered versions.")
print("="*70)

