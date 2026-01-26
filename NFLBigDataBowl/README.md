# NFL Punt Data Analysis

Preliminary analysis of NFL punt data from the Big Data Bowl competitions (2021-2025) to understand when it's beneficial to punt vs. go for it on 4th down.

## Overview

This analysis examines 76,385 plays across 5 years of NFL data to identify trends in 4th down decision-making and evaluate when punting is the optimal choice.

## Key Findings

### Data Summary
- **Total Plays**: 76,385 across 2021-2025
- **4th Down Plays**: 9,498 (12.4% of all plays)
- **Average Yards to Go on 4th Down**: 8.2 yards (median: 7.0)

### Key Insights

1. **Field Position Distribution**: 26% of 4th downs occur in scoring territory (opponent 20+), suggesting teams often face decisions even when close to scoring.

2. **EPA Analysis**: Average EPA on 4th down is positive (0.216), indicating that when teams go for it, outcomes are often favorable.

3. **Field Position Impact**: 
   - Own 20-40 yard line: Negative EPA (-0.668) - punting may be optimal
   - Midfield & opponent territory: Positive EPA - going for it can be beneficial

4. **Time Matters**: 4th quarter success rates are 2x higher than earlier quarters, showing increased aggression when time is limited.

## Files

### Analysis Scripts
- `preliminary_analysis.py` - Initial exploratory analysis with basic statistics
- `punt_decision_analysis.py` - Deep dive into 4th down decision factors

### Output Files
- `analysis_output/` - Directory containing all generated visualizations
- `ANALYSIS_SUMMARY.md` - Comprehensive summary of findings and research questions

### Visualizations Generated
1. `plays_by_down.png` - Distribution of plays across downs
2. `4th_down_yards_to_go.png` - Yards to go distribution on 4th down
3. `4th_down_field_position.png` - Field position analysis on 4th down
4. `epa_by_down.png` - Expected Points Added comparison across downs
5. `yards_gained_by_down.png` - Yardage gained comparison
6. `4th_down_decision_factors.png` - Comprehensive analysis of decision factors

## Running the Analysis

### Prerequisites
```bash
pip install pandas numpy matplotlib seaborn
```

### Run Preliminary Analysis
```bash
python preliminary_analysis.py
```

This will:
- Load data from all 5 years (2021-2025)
- Generate basic statistics
- Create initial visualizations
- Output key insights

### Run Deep Dive Analysis
```bash
python punt_decision_analysis.py
```

This will:
- Analyze 4th down plays in detail
- Break down performance by yards to go, field position, score, and time
- Generate comprehensive visualizations
- Provide recommendations for further research

## Research Questions Identified

1. **When is punting actually beneficial vs. going for it on 4th down?**
   - Compare expected field position after punts vs. failed conversions
   - Factor in yards to go, field position, and game situation

2. **What is the optimal decision threshold for punting vs. going for it?**
   - Build a model considering multiple factors (yards to go, field position, score, time, win probability)

3. **How does field position affect the value of punting?**
   - Analyze net field position gain from punting
   - Compare to expected opponent starting position after failed conversions

4. **Are teams punting too often or too little?**
   - Compare actual decisions to optimal decisions based on EPA
   - Identify situations where teams should be more aggressive

5. **What factors most strongly influence successful 4th down conversions?**
   - Yards to go
   - Field position
   - Game situation
   - Offensive personnel/matchups

## Data Structure

The analysis works with data from the following folders:
- `nfl-big-data-bowl-2021/`
- `nfl-big-data-bowl-2022/`
- `nfl-big-data-bowl-2023/`
- `nfl-big-data-bowl-2024/`
- `nfl-big-data-bowl-2025/`

Each folder contains:
- `plays.csv` - Play-by-play data
- `games.csv` - Game metadata
- `players.csv` - Player information
- Tracking data files (varies by year)

## Next Steps

1. **Separate punts from conversion attempts** - Use playType/playDescription to identify actual punts
2. **Analyze tracking data** - Punt hang time, distance, return yardage, starting field position
3. **Build decision models** - Expected value of punting vs. going for it with optimal boundaries
4. **Compare to historical patterns** - Year-over-year trends in aggression
5. **Contextual factors** - Weather, home/away, team strength matchups

## Notes

- The low conversion success rates for short yardage (5.6% for 1-3 yards) suggest many of these "4th down plays" are actual punts, not conversion attempts
- Further analysis needed to properly separate punts from going-for-it attempts
- The data may represent all 4th down plays regardless of whether teams punted or went for it

## Contact

For questions or suggestions about this analysis, please refer to the detailed findings in `ANALYSIS_SUMMARY.md`.

