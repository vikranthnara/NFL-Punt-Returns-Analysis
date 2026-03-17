# Decision Model Analysis — Results

Contextual validation of the punt return decision model across 5,991 punt plays (2018–2020 NFL seasons) and 863 modeled non-fair-catch plays.

## Full Dataset Splits (n=5,991)

Metric: **wpa_play** — win probability added from the punting team's perspective. Positive means the punt helped the punting team; negative means the return team benefited.

### Fourth Quarter

| Subset | n | Avg WPA |
|--------|-------|---------|
| Non-Q4 | 4,634 | +0.0065 |
| Q4 | 1,357 | -0.0078 |

Q4 punts show a clear negative shift. Fourth-quarter punts hurt the punting team on average — higher game leverage means return outcomes swing WP more. This is the strongest contextual signal in the data.

### Close Game (within 8 points)

| Subset | n | Avg WPA |
|--------|-------|---------|
| Not Close | 2,093 | -0.0018 |
| Close (within 8) | 3,898 | +0.0060 |

Close-game punts are "more correct" decisions — the punting team gains WP on average. In blowouts, the team that's behind punts out of necessity in worse field position, dragging the average negative.

### Late in Quarter (under 5 minutes)

| Subset | n | Avg WPA |
|--------|-------|---------|
| Early (>=5 min) | 3,911 | +0.0039 |
| Late (<5 min) | 2,049 | -0.0033 |

Weak signal. The Q4 effect is not just "late in any quarter" — it's driven by fourth-quarter game dynamics specifically (clock pressure, score urgency), not generic end-of-quarter situations.

### Receiving Team Score Margin — Fair Catch Rate

| Receiving Team Margin | n | Avg WPA | Fair Catch Rate |
|----------------------|-------|---------|-----------------|
| Way Ahead (17+) | 392 | -0.0034 | 24.2% |
| Comfortably Ahead (9-16) | 683 | +0.0003 | 28.3% |
| Slightly Ahead (1-8) | 1,436 | +0.0026 | 26.9% |
| Tied | 1,175 | +0.0256 | 28.5% |
| Slightly Behind (1-8) | 1,287 | -0.0082 | 27.4% |
| Way Behind (9+) | 1,018 | -0.0026 | 27.4% |

Teams way ahead fair catch **less** (24.2%), not more — they feel safe to return. Tied games have the highest fair catch rate (28.5%), where a muff or bad return could swing the outcome.

---

## Decision Model Splits (n=863)

Metric: **adv_return_vs_fc** — the model's estimated WP advantage of returning over fair catching, computed via Monte Carlo simulation (300 sims per play).

### Fourth Quarter

| Subset | n | Avg Return Advantage | % Recommend Return | Avg WP (FC) | Avg WP (Return) |
|--------|-----|----------------------|--------------------|----|-----|
| Non-Q4 | 680 | +0.0134 | 95.3% | 0.533 | 0.546 |
| Q4 | 184 | +0.0088 | 79.9% | 0.404 | 0.413 |

The model captures the Q4 penalty — return advantage drops 34% and the return recommendation rate drops from 95% to 80%. The model recommends fair catches ~5x more often in Q4.

### Close Game (within 8 points)

| Subset | n | Avg Return Advantage | % Recommend Return | % Recommend FC |
|--------|-----|----------------------|--------------------|----------------|
| Not Close | 272 | +0.0050 | 77.9% | 19.9% |
| Close (within 8) | 592 | +0.0158 | 98.5% | 1.5% |

In close games, returning is almost always optimal (98.5%) because the WP curve is steepest around 50/50 games — every yard of field position matters more. In blowouts, the return advantage shrinks to +0.005 and fair catch recommendations rise to 20%.

### Late in Quarter (under 5 minutes)

| Subset | n | Avg Return Advantage | % Recommend Return |
|--------|-----|----------------------|--------------------|
| Early (>=5 min) | 573 | +0.0122 | 92.5% |
| Late (<5 min) | 291 | +0.0130 | 91.1% |

Nearly identical. The model's physical features (gunner distance, hang time) don't change based on clock, so the recommendation stays flat. Confirms this is a weak signal.

### Receiving Team Score Margin — Model Recommendations

| Receiving Team Margin | n | Avg Return Advantage | % Recommend Return | % Recommend FC |
|----------------------|-----|----------------------|--------------------|----------------|
| Way Ahead (17+) | 52 | +0.0009 | 40.4% | 51.9% |
| Comfortably Ahead (9-16) | 85 | +0.0063 | 87.1% | 11.8% |
| Slightly Ahead (1-8) | 226 | +0.0154 | 97.8% | 2.2% |
| Tied | 179 | +0.0169 | 99.4% | 0.6% |
| Slightly Behind (1-8) | 187 | +0.0154 | 98.4% | 1.6% |
| Way Behind (9+) | 135 | +0.0058 | 86.7% | 12.6% |

Score margin is the model's strongest lever. When the receiving team is way ahead, the model recommends fair catch 52% of the time — extra yards provide near-zero marginal WP. When tied, it recommends returning 99.4% of the time. Teams way behind also see reduced return rates (87%) because field position matters less than possession when trailing big.

---

## Interaction: Q4 x Close Game

| Bucket | n | Avg WPA | Fair Catch Rate |
|--------|-------|---------|-----------------|
| Non-Q4, Close | 3,255 | +0.0097 | 27.4% |
| Non-Q4, Not Close | 1,379 | -0.0011 | 28.3% |
| Q4, Close | 643 | -0.0129 | 28.1% |
| Q4, Not Close | 714 | -0.0033 | 24.8% |

The sharpest contrast: close-game Q4 punts produce an average WPA of **-0.0129** — the most negative bucket — yet the fair catch rate barely changes (28.1% vs 27.4% for non-Q4 close). Teams are not adjusting their return behavior enough for the elevated stakes. This is where the model's punt-by-punt recommendations (based on gunner distance and hang time) could add the most value.

---

## Key Takeaways

1. **Q4 is the dominant contextual factor.** The punting team loses WP on average in Q4, and the model correctly shifts toward fair catch recommendations.
2. **Close games amplify the return advantage**, not reduce it. The WP curve is steepest when the game is competitive, making every yard of return more valuable.
3. **Score margin drives model behavior more than any other context.** Way-ahead receiving teams get fair catch recommendations 52% of the time; tied teams get return recommendations 99.4%.
4. **Late-in-quarter is noise on its own.** The effect is Q4-specific, not a generic clock phenomenon.
5. **The biggest opportunity gap is Q4 close games** — high-leverage punts where teams don't adjust their return strategy despite the data showing these plays swing WP the most.
