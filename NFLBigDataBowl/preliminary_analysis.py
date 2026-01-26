import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# Set style for better looking plots
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)

# Base directory
base_dir = Path(".")

# Years to analyze
years = ['2021', '2022', '2023', '2024', '2025']

print("="*60)
print("NFL PUNT DATA PRELIMINARY ANALYSIS")
print("="*60)
print()

# Load and combine data from all years
all_plays = []
all_games = []

for year in years:
    folder = f"nfl-big-data-bowl-{year}"
    plays_file = base_dir / folder / "plays.csv"
    games_file = base_dir / folder / "games.csv"
    
    if plays_file.exists():
        try:
            plays_df = pd.read_csv(plays_file)
            plays_df['year'] = year
            all_plays.append(plays_df)
            print(f"Loaded {len(plays_df):,} plays from {year}")
        except Exception as e:
            print(f"Error loading {year} plays: {e}")
    
    if games_file.exists():
        try:
            games_df = pd.read_csv(games_file)
            games_df['year'] = year
            all_games.append(games_df)
        except Exception as e:
            print(f"Error loading {year} games: {e}")

print()

if not all_plays:
    print("No play data found!")
    exit()

# Combine all plays
plays = pd.concat(all_plays, ignore_index=True)
games = pd.concat(all_games, ignore_index=True) if all_games else None

print(f"Total plays loaded: {len(plays):,}")
print()

# Identify punts - look for 4th down plays (most common punt situation)
# Also check playType and playDescription for punt indicators
print("Identifying punt plays...")
plays['is_punt'] = False
plays['is_4th_down'] = plays['down'] == 4

# Check for punt in play description (case insensitive)
if 'playDescription' in plays.columns:
    plays['has_punt_desc'] = plays['playDescription'].astype(str).str.lower().str.contains('punt', na=False)
    plays.loc[plays['has_punt_desc'], 'is_punt'] = True

# Check for punt in playType
if 'playType' in plays.columns:
    plays['has_punt_type'] = plays['playType'].astype(str).str.lower().str.contains('punt', na=False)
    plays.loc[plays['has_punt_type'], 'is_punt'] = True

# If this is Big Data Bowl, it might be ALL punt plays
# Check if majority are 4th down or have punt indicators
pct_4th_down = plays['is_4th_down'].mean() * 100
pct_has_punt = plays['is_punt'].mean() * 100

print(f"Percentage of plays that are 4th down: {pct_4th_down:.1f}%")
print(f"Percentage of plays with 'punt' in description/type: {pct_has_punt:.1f}%")
print()

# Basic statistics
print("="*60)
print("BASIC STATISTICS")
print("="*60)

if 'down' in plays.columns:
    print("\nPlay Distribution by Down:")
    down_counts = plays['down'].value_counts().sort_index()
    for down, count in down_counts.items():
        pct = (count / len(plays)) * 100
        print(f"  {down}th down: {count:,} ({pct:.1f}%)")

if 'quarter' in plays.columns:
    print("\nPlay Distribution by Quarter:")
    qtr_counts = plays['quarter'].value_counts().sort_index()
    for qtr, count in qtr_counts.items():
        pct = (count / len(plays)) * 100
        print(f"  Quarter {qtr}: {count:,} ({pct:.1f}%)")

if 'yardsToGo' in plays.columns:
    print(f"\nYards to Go Statistics:")
    print(f"  Mean: {plays['yardsToGo'].mean():.1f} yards")
    print(f"  Median: {plays['yardsToGo'].median():.1f} yards")
    print(f"  Min: {plays['yardsToGo'].min():.0f} yards")
    print(f"  Max: {plays['yardsToGo'].max():.0f} yards")

if 'absoluteYardlineNumber' in plays.columns:
    print(f"\nField Position (Absolute Yardline):")
    print(f"  Mean: {plays['absoluteYardlineNumber'].mean():.1f}")
    print(f"  Median: {plays['absoluteYardlineNumber'].median():.1f}")
    print(f"  (50 = midfield, 100 = opponent endzone)")

print()

# Analysis of 4th down situations (when punts typically occur)
print("="*60)
print("4TH DOWN ANALYSIS (TYPICAL PUNT SITUATIONS)")
print("="*60)

if 'down' in plays.columns:
    fourth_down = plays[plays['down'] == 4].copy()
    print(f"\nTotal 4th down plays: {len(fourth_down):,}")
    
    if len(fourth_down) > 0:
        if 'yardsToGo' in fourth_down.columns:
            print(f"\nYards to Go on 4th Down:")
            print(f"  Mean: {fourth_down['yardsToGo'].mean():.1f} yards")
            print(f"  Median: {fourth_down['yardsToGo'].median():.1f} yards")
            
            # Distribution
            print(f"\nDistribution by Yards to Go:")
            bins = [0, 3, 7, 10, 15, 99]
            labels = ['1-3', '4-7', '8-10', '11-15', '15+']
            fourth_down['yards_range'] = pd.cut(fourth_down['yardsToGo'], bins=bins, labels=labels)
            range_counts = fourth_down['yards_range'].value_counts().sort_index()
            for rng, count in range_counts.items():
                pct = (count / len(fourth_down)) * 100
                print(f"  {rng} yards: {count:,} ({pct:.1f}%)")
        
        if 'absoluteYardlineNumber' in fourth_down.columns:
            print(f"\nField Position on 4th Down:")
            print(f"  Mean: {fourth_down['absoluteYardlineNumber'].mean():.1f}")
            print(f"  Median: {fourth_down['absoluteYardlineNumber'].median():.1f}")
            
            # Field position distribution
            def get_field_zone(yardline):
                if yardline < 20:
                    return "Own 0-20 (Danger Zone)"
                elif yardline < 40:
                    return "Own 20-40"
                elif yardline < 60:
                    return "Midfield 40-60"
                elif yardline < 80:
                    return "Opponent 40-20"
                else:
                    return "Opponent 20+ (Scoring Zone)"
            
            fourth_down['field_zone'] = fourth_down['absoluteYardlineNumber'].apply(get_field_zone)
            zone_counts = fourth_down['field_zone'].value_counts()
            print(f"\nField Position Zones:")
            for zone, count in zone_counts.items():
                pct = (count / len(fourth_down)) * 100
                print(f"  {zone}: {count:,} ({pct:.1f}%)")

print()

# Check for outcome metrics
print("="*60)
print("OUTCOME ANALYSIS")
print("="*60)

# Look for yardage gained, EPA, win probability changes
if 'yardsGained' in plays.columns:
    print(f"\nYards Gained Statistics:")
    print(f"  Mean: {plays['yardsGained'].mean():.2f} yards")
    print(f"  Median: {plays['yardsGained'].median():.0f} yards")
    print(f"  Min: {plays['yardsGained'].min():.0f} yards")
    print(f"  Max: {plays['yardsGained'].max():.0f} yards")
    
    if 'down' in plays.columns:
        print(f"\nYards Gained by Down:")
        for down in sorted(plays['down'].dropna().unique()):
            down_plays = plays[plays['down'] == down]
            avg_yards = down_plays['yardsGained'].mean()
            print(f"  {down}th down: {avg_yards:.2f} yards")

if 'expectedPointsAdded' in plays.columns or 'epa' in plays.columns:
    epa_col = 'expectedPointsAdded' if 'expectedPointsAdded' in plays.columns else 'epa'
    print(f"\nExpected Points Added (EPA) Statistics:")
    epa_data = plays[epa_col].dropna()
    if len(epa_data) > 0:
        print(f"  Mean: {epa_data.mean():.3f}")
        print(f"  Median: {epa_data.median():.3f}")
        print(f"  Std Dev: {epa_data.std():.3f}")
        
        positive_epa = (epa_data > 0).sum()
        print(f"  Positive EPA plays: {positive_epa:,} ({positive_epa/len(epa_data)*100:.1f}%)")
        
        if 'down' in plays.columns:
            print(f"\nEPA by Down:")
            for down in sorted(plays['down'].dropna().unique()):
                down_plays = plays[plays['down'] == down]
                if epa_col in down_plays.columns:
                    avg_epa = down_plays[epa_col].dropna().mean()
                    print(f"  {down}th down: {avg_epa:.3f}")

print()

# Create visualizations
print("="*60)
print("GENERATING VISUALIZATIONS")
print("="*60)

# Create output directory for plots
output_dir = Path("analysis_output")
output_dir.mkdir(exist_ok=True)

# Plot 1: Distribution of plays by down
if 'down' in plays.columns:
    plt.figure(figsize=(10, 6))
    down_counts = plays['down'].value_counts().sort_index()
    plt.bar(down_counts.index, down_counts.values, color='steelblue', alpha=0.7)
    plt.xlabel('Down', fontsize=12)
    plt.ylabel('Number of Plays', fontsize=12)
    plt.title('Distribution of Plays by Down', fontsize=14, fontweight='bold')
    plt.grid(axis='y', alpha=0.3)
    for i, v in enumerate(down_counts.values):
        plt.text(down_counts.index[i], v, f'{v:,}', ha='center', va='bottom')
    plt.tight_layout()
    plt.savefig(output_dir / 'plays_by_down.png', dpi=150)
    print(f"  Saved: plays_by_down.png")
    plt.close()

# Plot 2: Yards to Go distribution on 4th down
if 'down' in plays.columns and 'yardsToGo' in plays.columns:
    fourth_down = plays[plays['down'] == 4]
    if len(fourth_down) > 0:
        plt.figure(figsize=(12, 6))
        plt.hist(fourth_down['yardsToGo'].dropna(), bins=30, color='coral', alpha=0.7, edgecolor='black')
        plt.xlabel('Yards to Go', fontsize=12)
        plt.ylabel('Frequency', fontsize=12)
        plt.title('Distribution of Yards to Go on 4th Down', fontsize=14, fontweight='bold')
        plt.axvline(fourth_down['yardsToGo'].median(), color='red', linestyle='--', 
                   label=f'Median: {fourth_down["yardsToGo"].median():.1f} yds')
        plt.legend()
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        plt.savefig(output_dir / '4th_down_yards_to_go.png', dpi=150)
        print(f"  Saved: 4th_down_yards_to_go.png")
        plt.close()

# Plot 3: Field position on 4th down
if 'down' in plays.columns and 'absoluteYardlineNumber' in plays.columns:
    fourth_down = plays[plays['down'] == 4]
    if len(fourth_down) > 0:
        plt.figure(figsize=(14, 6))
        plt.hist(fourth_down['absoluteYardlineNumber'].dropna(), bins=50, color='green', alpha=0.7, edgecolor='black')
        plt.axvline(50, color='red', linestyle='--', linewidth=2, label='Midfield (50)')
        plt.xlabel('Absolute Yardline Number', fontsize=12)
        plt.ylabel('Frequency', fontsize=12)
        plt.title('Field Position Distribution on 4th Down Plays', fontsize=14, fontweight='bold')
        plt.legend()
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        plt.savefig(output_dir / '4th_down_field_position.png', dpi=150)
        print(f"  Saved: 4th_down_field_position.png")
        plt.close()

# Plot 4: EPA distribution by down
if 'down' in plays.columns and ('expectedPointsAdded' in plays.columns or 'epa' in plays.columns):
    epa_col = 'expectedPointsAdded' if 'expectedPointsAdded' in plays.columns else 'epa'
    if epa_col in plays.columns:
        plt.figure(figsize=(12, 6))
        plays_with_epa = plays[plays[epa_col].notna()].copy()
        if len(plays_with_epa) > 0:
            sns.boxplot(data=plays_with_epa, x='down', y=epa_col, palette='Set2')
            plt.xlabel('Down', fontsize=12)
            plt.ylabel('Expected Points Added (EPA)', fontsize=12)
            plt.title('EPA Distribution by Down', fontsize=14, fontweight='bold')
            plt.axhline(0, color='red', linestyle='--', alpha=0.5)
            plt.grid(axis='y', alpha=0.3)
            plt.tight_layout()
            plt.savefig(output_dir / 'epa_by_down.png', dpi=150)
            print(f"  Saved: epa_by_down.png")
            plt.close()

# Plot 5: Yards gained by down
if 'down' in plays.columns and 'yardsGained' in plays.columns:
    plt.figure(figsize=(12, 6))
    plays_with_yards = plays[plays['yardsGained'].notna()].copy()
    if len(plays_with_yards) > 0:
        sns.boxplot(data=plays_with_yards, x='down', y='yardsGained', palette='Set3')
        plt.xlabel('Down', fontsize=12)
        plt.ylabel('Yards Gained', fontsize=12)
        plt.title('Yards Gained Distribution by Down', fontsize=14, fontweight='bold')
        plt.axhline(0, color='red', linestyle='--', alpha=0.5)
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        plt.savefig(output_dir / 'yards_gained_by_down.png', dpi=150)
        print(f"  Saved: yards_gained_by_down.png")
        plt.close()

print()
print("="*60)
print("KEY INSIGHTS AND RESEARCH DIRECTIONS")
print("="*60)
print()

# Generate insights
print("Based on the preliminary analysis, here are some key trends:")
print()

if 'down' in plays.columns:
    fourth_pct = (plays['down'] == 4).mean() * 100
    if fourth_pct > 50:
        print("1. This dataset appears to focus heavily on 4th down situations,")
        print("   suggesting it's specifically designed for punt analysis.")
    elif fourth_pct > 20:
        print("1. A significant portion of plays are 4th down situations,")
        print("   which are critical decision points for punting vs going for it.")

if 'yardsToGo' in plays.columns and 'down' in plays.columns:
    fourth_down = plays[plays['down'] == 4]
    if len(fourth_down) > 0:
        avg_yards = fourth_down['yardsToGo'].mean()
        print(f"\n2. Average yards to go on 4th down: {avg_yards:.1f} yards")
        print("   This suggests the difficulty of conversion attempts.")

if 'absoluteYardlineNumber' in plays.columns and 'down' in plays.columns:
    fourth_down = plays[plays['down'] == 4]
    if len(fourth_down) > 0:
        avg_field_pos = fourth_down['absoluteYardlineNumber'].mean()
        if avg_field_pos < 50:
            print(f"\n3. Average field position on 4th down: {avg_field_pos:.1f}")
            print("   Teams are typically punting from their own territory.")

if 'expectedPointsAdded' in plays.columns or 'epa' in plays.columns:
    epa_col = 'expectedPointsAdded' if 'expectedPointsAdded' in plays.columns else 'epa'
    if epa_col in plays.columns and 'down' in plays.columns:
        fourth_down = plays[plays['down'] == 4]
        if len(fourth_down) > 0 and epa_col in fourth_down.columns:
            avg_epa_4th = fourth_down[epa_col].dropna().mean()
            print(f"\n4. Average EPA on 4th down: {avg_epa_4th:.3f}")
            if avg_epa_4th < 0:
                print("   Negative average EPA suggests punting may often be the")
                print("   safer choice, but context matters (field position, score, etc.).")

print()
print("\nPotential Research Questions:")
print("- When is it actually beneficial to punt vs. going for it on 4th down?")
print("- How does field position affect the decision to punt?")
print("- What is the optimal yards-to-go threshold for punting vs. going for it?")
print("- How do game situation factors (score, time remaining) affect punt decisions?")
print("- What is the expected value difference between punting and going for it?")

print()
print(f"\nAnalysis complete! Check the '{output_dir}' folder for visualizations.")
print("="*60)

