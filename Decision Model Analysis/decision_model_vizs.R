# Visualizations
suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(scales)
})


# 1. Load Data
df <- read_csv(
  here("Decision Model Analysis", "punt_decision_expected_wp.csv"),
  show_col_types = FALSE
)

df <- df %>%
  mutate(
    return_adv = adv_return_vs_fc,
    wp_optimal = pmax(wp_return, wp_fc, wp_bounce, na.rm = TRUE),
    wp_lost_vs_fc = wp_optimal - wp_fc
  )

# DECISION BOUNDARY HEATMAP

p1 <- ggplot(df, aes(x = closest_gunner_dist, y = hang_time)) +
  stat_summary_2d(aes(z = return_adv), bins = 30) +
  scale_fill_distiller(
    palette = "Spectral",
    direction = 1,
    name = "Return WP Advantage",
    labels = percent_format(accuracy = 0.1)
  ) +
  labs(
    title = "Heatmap of Return Advantage Based on Coverage Conditions ",
    x = "Closest Gunner Distance (yards)",
    y = "Hang Time (seconds)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5)
  )

print(p1)


# RETURN ADVANTAGE VS GUNNER DISTANCE (SCATTER)

p2 <- ggplot(df, aes(x = clo
                     sest_gunner_dist, y = return_adv)) +
  geom_point(alpha = 0.5, color = "darkblue") +
  geom_smooth(method = "loess", color = "black") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  scale_y_continuous(labels = percent_format(accuracy = 0.01)) +
  labs(
    title = "Return Advantage by Closest Gunner Distance",
    x = "Closest Gunner Distance (yards)",
    y = "Return Advantage (WP)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5)
  )

print(p2)
