library(tidyverse)

# Load the decision model results
results <- read_csv("Decision Model Analysis/punt_decision_expected_wp.csv")

# Overall Strategy Distribution
# How often does the model recommend each action?
strategy_summary <- results %>%
  count(best_action) %>%
  mutate(pct = n / sum(n) * 100)

print("Recommendation Distribution:")
print(strategy_summary)

# Decision Quality Metric
# Since these were all NON-Fair Catches, how often was that correct?
correct_decision_pct <- mean(results$best_action != "FAIR_CATCH") * 100
message(paste0("Decision Accuracy: ", round(correct_decision_pct, 1), 
               "% of these non-fair catches were mathematically sound."))


# Top 5 Smartest Return Teams
# (Highest average advantage gained over a fair catch)
team_rankings <- results %>%
  group_by(return_team) %>%
  summarise(
    plays = n(),
    avg_edge = mean(adv_return_vs_fc),
    total_wpa_added = sum(adv_return_vs_fc)
  ) %>%
  filter(plays > 5) %>% # Filter for sample size
  arrange(desc(avg_edge))

print("Top 5 Most Efficient Return Teams:")
print(head(team_rankings, 5))


# Visualizing the "Danger Zone"
# This plot shows how Gunner Distance affects the value of a return
ggplot(results, aes(x = closest_gunner_dist, y = adv_return_vs_fc)) +
  geom_point(aes(color = best_action), alpha = 0.6) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  geom_smooth(method = "lm", color = "black") +
  labs(
    title = "The Value of a Return vs. Gunner Proximity",
    subtitle = "Points below the red line indicate 'Bad Returns' (should have Fair Caught)",
    x = "Distance of Closest Gunner (Yards)",
    y = "Advantage of Returning over Fair Catch (WP)"
  ) +
  theme_minimal()
