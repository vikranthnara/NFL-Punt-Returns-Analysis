library(tidyverse)

# Load the decision model results
results <- read_csv("Decision Model Analysis/punt_decision_expected_wp.csv")

# Overall Strategy Distribution
# How often does the model recommend each action?
strategy_summary <- results %>%
  count(best_action) %>%
  mutate(percentage = round((n / sum(n)) * 100, 2)) %>%
  arrange(desc(n))

print("--- Strategy Distribution (The Model's Recommendations) ---")
print(strategy_summary)



# WIN PROBABILITY COMPARISON
# This shows the 'Expected Value' of each choice across all 864 plays
wp_comparison <- results %>%
  summarise(
    avg_wp_if_fair_catch = mean(wp_fc, na.rm = TRUE),
    avg_wp_if_return = mean(wp_return, na.rm = TRUE),
    avg_wp_if_bounce = mean(wp_bounce, na.rm = TRUE)
  )

print("--- Average Win Probability per Choice ---")
print(wp_comparison)



# Contextual Metrics
# Showing physical conditions that lead to each recommendation
context_analysis <- results %>%
  group_by(best_action) %>%
  summarise(
    play_count = n(),
    avg_gunner_dist = mean(closest_gunner_dist, na.rm = TRUE),
    avg_hang_time = mean(hang_time, na.rm = TRUE),
    avg_wp_gained_by_returning = mean(adv_return_vs_fc, na.rm = TRUE)
  )

print("--- Physical Context for Decisions ---")
print(context_analysis)


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
