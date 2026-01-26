import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (14, 8)

# Load data
base_dir = Path(".")
years = ['2021', '2022', '2023', '2024', '2025']

all_plays = []
for year in years:
    folder = f"nfl-big-data-bowl-{year}"
    plays_file = base_dir / folder / "plays.csv"
    if plays_file.exists():
        plays_df = pd.read_csv(plays_file)
        plays_df['year'] = year
        all_plays.append(plays_df)

plays = pd.concat(all_plays, ignore_index=True)

print("="*70)
print("DEEP DIVE: WHEN SHOULD TEAMS PUNT vs GO FOR IT?")
print("="*70)
print()

# Focus on 4th down plays
fourth_down = plays[plays['down'] == 4].copy()
print(f"Analyzing {len(fourth_down):,} 4th down plays...")
print()

# Key columns to use
epa_col = 'expectedPointsAdded' if 'expectedPointsAdded' in plays.columns else 'epa'
yards_col = 'yardsGained' if 'yardsGained' in plays.columns else 'playResult'

# Analysis 1: Success rate by yards to go
print("="*70)
print("1. SUCCESS RATE BY YARDS TO GO")
print("="*70)

if 'yardsToGo' in fourth_down.columns:
    fourth_down['yards_category'] = pd.cut(
        fourth_down['yardsToGo'],
        bins=[0, 3, 5, 7, 10, 15, 99],
        labels=['1-3', '4-5', '6-7', '8-10', '11-15', '15+']
    )
    
    success_analysis = []
    for cat in fourth_down['yards_category'].cat.categories:
        subset = fourth_down[fourth_down['yards_category'] == cat]
        if len(subset) > 0:
            # Success = converting (yards gained >= yards to go)
            if yards_col in subset.columns:
                success = (subset[yards_col] >= subset['yardsToGo']).sum()
                success_rate = success / len(subset) * 100
                avg_epa = subset[epa_col].dropna().mean() if epa_col in subset.columns else None
                avg_yards = subset[yards_col].mean()
                
                success_analysis.append({
                    'yards_to_go': cat,
                    'count': len(subset),
                    'success_rate': success_rate,
                    'success_count': success,
                    'avg_epa': avg_epa,
                    'avg_yards': avg_yards
                })
    
    success_df = pd.DataFrame(success_analysis)
    print("\nConversion Success by Yards to Go:")
    print(success_df.to_string(index=False))
    print()

# Analysis 2: Field Position Impact
print("="*70)
print("2. FIELD POSITION IMPACT ON 4TH DOWN DECISIONS")
print("="*70)

if 'absoluteYardlineNumber' in fourth_down.columns:
    def get_field_zone(yardline):
        if yardline < 20:
            return "Own 0-20"
        elif yardline < 40:
            return "Own 20-40"
        elif yardline < 60:
            return "Midfield 40-60"
        elif yardline < 80:
            return "Opponent 40-20"
        else:
            return "Opponent 20+"
    
    fourth_down['field_zone'] = fourth_down['absoluteYardlineNumber'].apply(get_field_zone)
    
    field_analysis = []
    for zone in fourth_down['field_zone'].unique():
        subset = fourth_down[fourth_down['field_zone'] == zone]
        if len(subset) > 0 and yards_col in subset.columns:
            success = (subset[yards_col] >= subset['yardsToGo']).sum()
            success_rate = success / len(subset) * 100
            avg_epa = subset[epa_col].dropna().mean() if epa_col in subset.columns else None
            avg_yards = subset[yards_col].mean()
            avg_yards_to_go = subset['yardsToGo'].mean()
            
            field_analysis.append({
                'field_zone': zone,
                'count': len(subset),
                'success_rate': success_rate,
                'avg_epa': avg_epa,
                'avg_yards': avg_yards,
                'avg_yards_to_go': avg_yards_to_go
            })
    
    field_df = pd.DataFrame(field_analysis)
    field_df = field_df.sort_values('field_zone')
    print("\n4th Down Performance by Field Position:")
    print(field_df.to_string(index=False))
    print()

# Analysis 3: Score Differential Impact
print("="*70)
print("3. SCORE DIFFERENTIAL IMPACT")
print("="*70)

if 'preSnapHomeScore' in fourth_down.columns and 'preSnapVisitorScore' in fourth_down.columns:
    # Calculate score differential (from offensive team's perspective)
    # This is approximate - we'd need possessionTeam to be precise
    # For now, use home score - visitor score as proxy
    fourth_down['score_diff'] = fourth_down['preSnapHomeScore'] - fourth_down['preSnapVisitorScore']
    
    fourth_down['score_category'] = pd.cut(
        fourth_down['score_diff'],
        bins=[-99, -7, -3, 0, 3, 7, 99],
        labels=['Down 7+', 'Down 4-6', 'Down 1-3', 'Tied/Up 1-3', 'Up 4-6', 'Up 7+']
    )
    
    score_analysis = []
    for cat in fourth_down['score_category'].cat.categories:
        subset = fourth_down[fourth_down['score_category'] == cat]
        if len(subset) > 0 and yards_col in subset.columns:
            success = (subset[yards_col] >= subset['yardsToGo']).sum()
            success_rate = success / len(subset) * 100
            avg_epa = subset[epa_col].dropna().mean() if epa_col in subset.columns else None
            
            score_analysis.append({
                'score_situation': cat,
                'count': len(subset),
                'success_rate': success_rate,
                'avg_epa': avg_epa
            })
    
    score_df = pd.DataFrame(score_analysis)
    print("\n4th Down Performance by Score Situation:")
    print(score_df.to_string(index=False))
    print()

# Analysis 4: Time Remaining Impact
print("="*70)
print("4. QUARTER/TIME IMPACT")
print("="*70)

if 'quarter' in fourth_down.columns:
    quarter_analysis = []
    for qtr in sorted(fourth_down['quarter'].unique()):
        subset = fourth_down[fourth_down['quarter'] == qtr]
        if len(subset) > 0 and yards_col in subset.columns:
            success = (subset[yards_col] >= subset['yardsToGo']).sum()
            success_rate = success / len(subset) * 100
            avg_epa = subset[epa_col].dropna().mean() if epa_col in subset.columns else None
            avg_yards_to_go = subset['yardsToGo'].mean()
            
            quarter_analysis.append({
                'quarter': qtr,
                'count': len(subset),
                'success_rate': success_rate,
                'avg_epa': avg_epa,
                'avg_yards_to_go': avg_yards_to_go
            })
    
    qtr_df = pd.DataFrame(quarter_analysis)
    print("\n4th Down Performance by Quarter:")
    print(qtr_df.to_string(index=False))
    print()

# Analysis 5: Win Probability Impact
print("="*70)
print("5. WIN PROBABILITY ANALYSIS")
print("="*70)

if 'preSnapHomeTeamWinProbability' in fourth_down.columns and epa_col in fourth_down.columns:
    wp_col = 'preSnapHomeTeamWinProbability'
    
    # Categorize win probability
    fourth_down['wp_category'] = pd.cut(
        fourth_down[wp_col],
        bins=[0, 0.25, 0.4, 0.6, 0.75, 1.0],
        labels=['<25%', '25-40%', '40-60%', '60-75%', '>75%']
    )
    
    wp_analysis = []
    for cat in fourth_down['wp_category'].cat.categories:
        subset = fourth_down[fourth_down['wp_category'] == cat]
        if len(subset) > 0:
            avg_epa = subset[epa_col].dropna().mean()
            if yards_col in subset.columns:
                success = (subset[yards_col] >= subset['yardsToGo']).sum()
                success_rate = success / len(subset) * 100
            else:
                success_rate = None
            
            wp_analysis.append({
                'win_prob': cat,
                'count': len(subset),
                'success_rate': success_rate,
                'avg_epa': avg_epa
            })
    
    wp_df = pd.DataFrame(wp_analysis)
    print("\n4th Down Performance by Win Probability:")
    print(wp_df.to_string(index=False))
    print()

# Create combined visualization
output_dir = Path("analysis_output")
output_dir.mkdir(exist_ok=True)

# Visualization 1: Success Rate vs Yards to Go
if 'yards_category' in fourth_down.columns and yards_col in fourth_down.columns:
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    
    # Success rate by yards to go
    success_by_yards = fourth_down.groupby('yards_category').apply(
        lambda x: (x[yards_col] >= x['yardsToGo']).mean() * 100 if yards_col in x.columns else 0
    )
    axes[0, 0].bar(range(len(success_by_yards)), success_by_yards.values, 
                   color='steelblue', alpha=0.7, edgecolor='black')
    axes[0, 0].set_xticks(range(len(success_by_yards)))
    axes[0, 0].set_xticklabels(success_by_yards.index, rotation=45)
    axes[0, 0].set_ylabel('Success Rate (%)', fontsize=12)
    axes[0, 0].set_title('4th Down Conversion Rate by Yards to Go', fontsize=13, fontweight='bold')
    axes[0, 0].grid(axis='y', alpha=0.3)
    for i, v in enumerate(success_by_yards.values):
        axes[0, 0].text(i, v, f'{v:.1f}%', ha='center', va='bottom')
    
    # EPA by yards to go
    if epa_col in fourth_down.columns:
        epa_by_yards = fourth_down.groupby('yards_category')[epa_col].mean()
        axes[0, 1].bar(range(len(epa_by_yards)), epa_by_yards.values,
                      color='coral', alpha=0.7, edgecolor='black')
        axes[0, 1].set_xticks(range(len(epa_by_yards)))
        axes[0, 1].set_xticklabels(epa_by_yards.index, rotation=45)
        axes[0, 1].set_ylabel('Average EPA', fontsize=12)
        axes[0, 1].set_title('Average EPA by Yards to Go', fontsize=13, fontweight='bold')
        axes[0, 1].axhline(0, color='red', linestyle='--', alpha=0.5)
        axes[0, 1].grid(axis='y', alpha=0.3)
        for i, v in enumerate(epa_by_yards.values):
            axes[0, 1].text(i, v, f'{v:.2f}', ha='center', 
                           va='bottom' if v > 0 else 'top')
    
    # Success rate by field position
    if 'field_zone' in fourth_down.columns:
        success_by_field = fourth_down.groupby('field_zone').apply(
            lambda x: (x[yards_col] >= x['yardsToGo']).mean() * 100 if yards_col in x.columns else 0
        )
        field_order = ["Own 0-20", "Own 20-40", "Midfield 40-60", "Opponent 40-20", "Opponent 20+"]
        success_by_field = success_by_field.reindex([f for f in field_order if f in success_by_field.index])
        axes[1, 0].bar(range(len(success_by_field)), success_by_field.values,
                      color='green', alpha=0.7, edgecolor='black')
        axes[1, 0].set_xticks(range(len(success_by_field)))
        axes[1, 0].set_xticklabels(success_by_field.index, rotation=45, ha='right')
        axes[1, 0].set_ylabel('Success Rate (%)', fontsize=12)
        axes[1, 0].set_title('4th Down Conversion Rate by Field Position', fontsize=13, fontweight='bold')
        axes[1, 0].grid(axis='y', alpha=0.3)
        for i, v in enumerate(success_by_field.values):
            axes[1, 0].text(i, v, f'{v:.1f}%', ha='center', va='bottom')
    
    # EPA by field position
    if 'field_zone' in fourth_down.columns and epa_col in fourth_down.columns:
        epa_by_field = fourth_down.groupby('field_zone')[epa_col].mean()
        epa_by_field = epa_by_field.reindex([f for f in field_order if f in epa_by_field.index])
        axes[1, 1].bar(range(len(epa_by_field)), epa_by_field.values,
                      color='purple', alpha=0.7, edgecolor='black')
        axes[1, 1].set_xticks(range(len(epa_by_field)))
        axes[1, 1].set_xticklabels(epa_by_field.index, rotation=45, ha='right')
        axes[1, 1].set_ylabel('Average EPA', fontsize=12)
        axes[1, 1].set_title('Average EPA by Field Position', fontsize=13, fontweight='bold')
        axes[1, 1].axhline(0, color='red', linestyle='--', alpha=0.5)
        axes[1, 1].grid(axis='y', alpha=0.3)
        for i, v in enumerate(epa_by_field.values):
            axes[1, 1].text(i, v, f'{v:.2f}', ha='center',
                           va='bottom' if v > 0 else 'top')
    
    plt.tight_layout()
    plt.savefig(output_dir / '4th_down_decision_factors.png', dpi=150, bbox_inches='tight')
    print(f"\nSaved: 4th_down_decision_factors.png")
    plt.close()

# Summary insights
print()
print("="*70)
print("KEY FINDINGS & RECOMMENDATIONS")
print("="*70)
print()

if 'yards_category' in fourth_down.columns and yards_col in fourth_down.columns:
    short_yds = fourth_down[fourth_down['yardsToGo'] <= 3]
    medium_yds = fourth_down[(fourth_down['yardsToGo'] > 3) & (fourth_down['yardsToGo'] <= 7)]
    long_yds = fourth_down[fourth_down['yardsToGo'] > 7]
    
    if len(short_yds) > 0:
        short_success = (short_yds[yards_col] >= short_yds['yardsToGo']).mean() * 100
        short_epa = short_yds[epa_col].dropna().mean() if epa_col in short_yds.columns else None
        print(f"SHORT YARDAGE (1-3 yards):")
        print(f"  Success Rate: {short_success:.1f}%")
        if short_epa is not None:
            print(f"  Average EPA: {short_epa:.3f}")
        print()
    
    if len(medium_yds) > 0:
        med_success = (medium_yds[yards_col] >= medium_yds['yardsToGo']).mean() * 100
        med_epa = medium_yds[epa_col].dropna().mean() if epa_col in medium_yds.columns else None
        print(f"MEDIUM YARDAGE (4-7 yards):")
        print(f"  Success Rate: {med_success:.1f}%")
        if med_epa is not None:
            print(f"  Average EPA: {med_epa:.3f}")
        print()
    
    if len(long_yds) > 0:
        long_success = (long_yds[yards_col] >= long_yds['yardsToGo']).mean() * 100
        long_epa = long_yds[epa_col].dropna().mean() if epa_col in long_yds.columns else None
        print(f"LONG YARDAGE (8+ yards):")
        print(f"  Success Rate: {long_success:.1f}%")
        if long_epa is not None:
            print(f"  Average EPA: {long_epa:.3f}")
        print()

print("RECOMMENDATIONS FOR FURTHER ANALYSIS:")
print("1. Compare EPA of punting vs. going for it in similar situations")
print("2. Analyze expected field position after punts vs. failed conversions")
print("3. Factor in opponent starting field position after punts")
print("4. Consider game context (score, time remaining, timeout situation)")
print("5. Build a decision model based on yards to go + field position + game situation")
print()
print("="*70)

