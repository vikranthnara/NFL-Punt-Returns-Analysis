library(tidyverse)

# ============================================================
# Contextual Validation of Punt Decision Model
#
# Tests how the model's return-vs-fair-catch advantage behaves
# across game situations: fourth quarter, close games,
# late-in-quarter pressure, and blowout / receiving-team-ahead.
#
# INPUTS:
#   - punts_with_wp.csv              (5,991 punts, full game state)
#   - punt_decision_expected_wp.csv  (863 modeled plays)
# ============================================================

# Resolve repo root so the script works from any directory.
# Walks up from cwd looking for the .Rproj file.
find_repo_root <- function(start = getwd()) {
  dir <- normalizePath(start)
  while (dir != dirname(dir)) {
    if (length(list.files(dir, pattern = "\\.Rproj$")) > 0) return(dir)
    dir <- dirname(dir)
  }
  stop("Could not find repo root (.Rproj file). Run from within the project tree.")
}
REPO_ROOT <- find_repo_root()

# -----------------------------
# 1) Load data
# -----------------------------
all_punts <- read_csv(
  file.path(REPO_ROOT, "punts_with_wp.csv"), show_col_types = FALSE
) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId))

# gameClock is HH:MM:SS but the original clock parser only split into 2 parts,
# so game_seconds_remaining / half_seconds_remaining are all NA in the CSV.
# Recompute them here.
all_punts <- all_punts %>%
  mutate(
    clock_parts = str_split(gameClock, ":"),
    mm = map_dbl(clock_parts, ~ suppressWarnings(as.numeric(.x[1]))),
    ss = map_dbl(clock_parts, ~ suppressWarnings(as.numeric(.x[2]))),
    qtr_sec_remaining = 60 * mm + ss,
    game_seconds_remaining = case_when(
      quarter %in% 1:4 ~ (4 - quarter) * 15 * 60 + qtr_sec_remaining,
      TRUE ~ NA_real_
    ),
    half_seconds_remaining = case_when(
      quarter %in% 1:2 ~ (2 - quarter) * 15 * 60 + qtr_sec_remaining,
      quarter %in% 3:4 ~ (4 - quarter) * 15 * 60 + qtr_sec_remaining,
      TRUE ~ NA_real_
    )
  ) %>%
  select(-clock_parts, -mm, -ss, -qtr_sec_remaining)

model_results <- read_csv(
  file.path(REPO_ROOT, "Decision Model Analysis", "punt_decision_expected_wp.csv"),
  show_col_types = FALSE
) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId))

# -----------------------------
# 2) Join model output back to full game context
# -----------------------------
model_with_context <- model_results %>%
  left_join(
    all_punts %>%
      select(gameId, playId, quarter, score_differential,
             game_seconds_remaining, half_seconds_remaining,
             posteam, defteam, home_team, specialTeamsResult),
    by = c("gameId", "playId")
  )

# ============================================================
# FULL-DATASET ANALYSIS (all 5,991 punts via wpa_play)
# ============================================================
cat("\n========================================\n")
cat("FULL DATASET CONTEXTUAL SPLITS (n=5,991)\n")
cat("Metric: wpa_play (punting team WPA)\n")
cat("========================================\n\n")

# --- Q4 vs Non-Q4 ---
q4_split_full <- all_punts %>%
  mutate(is_q4 = quarter == 4) %>%
  group_by(is_q4) %>%
  summarise(
    n = n(),
    avg_wpa = mean(wpa_play, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(label = if_else(is_q4, "Q4", "Non-Q4"))

cat("--- Fourth Quarter Split ---\n")
print(q4_split_full)
cat("\n")

# --- Close Game vs Not ---
# "Close game" = score within 8 points (one possession)
close_split_full <- all_punts %>%
  mutate(is_close = abs(score_differential) <= 8) %>%
  group_by(is_close) %>%
  summarise(
    n = n(),
    avg_wpa = mean(wpa_play, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(label = if_else(is_close, "Close (within 8)", "Not Close"))

cat("--- Close Game Split ---\n")
print(close_split_full)
cat("\n")

# --- Late in Quarter ---
# "Late" = under 5 minutes remaining in the current quarter
late_split_full <- all_punts %>%
  filter(quarter %in% 1:4) %>%
  mutate(
    qtr_sec_remaining = game_seconds_remaining - (4 - quarter) * 15 * 60,
    is_late = qtr_sec_remaining < 5 * 60
  ) %>%
  group_by(is_late) %>%
  summarise(
    n = n(),
    avg_wpa = mean(wpa_play, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(label = if_else(is_late, "Late (<5 min)", "Early (>=5 min)"))

cat("--- Late in Quarter Split ---\n")
print(late_split_full)
cat("\n")

# --- Receiving Team Way Ahead ---
# score_differential is from PUNTING team perspective
# Negative = punting team behind = receiving team ahead
ahead_split_full <- all_punts %>%
  mutate(
    recv_margin = -score_differential,
    recv_ahead_bucket = case_when(
      recv_margin >= 17 ~ "Way Ahead (17+)",
      recv_margin >= 9  ~ "Comfortably Ahead (9-16)",
      recv_margin >= 1  ~ "Slightly Ahead (1-8)",
      recv_margin == 0  ~ "Tied",
      recv_margin >= -8 ~ "Slightly Behind (1-8)",
      TRUE              ~ "Way Behind (9+)"
    ),
    recv_ahead_bucket = factor(recv_ahead_bucket, levels = c(
      "Way Ahead (17+)", "Comfortably Ahead (9-16)", "Slightly Ahead (1-8)",
      "Tied", "Slightly Behind (1-8)", "Way Behind (9+)"
    ))
  ) %>%
  group_by(recv_ahead_bucket) %>%
  summarise(
    n = n(),
    avg_wpa = mean(wpa_play, na.rm = TRUE),
    fair_catch_rate = mean(specialTeamsResult == "Fair Catch", na.rm = TRUE),
    .groups = "drop"
  )

cat("--- Receiving Team Score Margin (Fair Catch Rate Hypothesis) ---\n")
print(ahead_split_full, n = Inf)
cat("\n")


# ============================================================
# DECISION MODEL ANALYSIS (863 modeled plays)
# ============================================================
cat("\n========================================\n")
cat("DECISION MODEL CONTEXTUAL SPLITS (n=863)\n")
cat("Metric: adv_return_vs_fc (model WP advantage)\n")
cat("========================================\n\n")

# --- Q4 vs Non-Q4 ---
q4_split_model <- model_with_context %>%
  mutate(is_q4 = quarter == 4) %>%
  group_by(is_q4) %>%
  summarise(
    n = n(),
    avg_adv_return = mean(adv_return_vs_fc, na.rm = TRUE),
    pct_recommend_return = mean(best_action == "RETURN", na.rm = TRUE),
    avg_wp_fc = mean(wp_fc, na.rm = TRUE),
    avg_wp_return = mean(wp_return, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(label = if_else(is_q4, "Q4", "Non-Q4"))

cat("--- Q4 Split (Model) ---\n")
print(q4_split_model)
cat("\n")

# --- Close Game vs Not ---
close_split_model <- model_with_context %>%
  mutate(is_close = abs(score_differential) <= 8) %>%
  group_by(is_close) %>%
  summarise(
    n = n(),
    avg_adv_return = mean(adv_return_vs_fc, na.rm = TRUE),
    pct_recommend_return = mean(best_action == "RETURN", na.rm = TRUE),
    pct_recommend_fc = mean(best_action == "FAIR_CATCH", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(label = if_else(is_close, "Close (within 8)", "Not Close"))

cat("--- Close Game Split (Model) ---\n")
print(close_split_model)
cat("\n")

# --- Late in Quarter ---
late_split_model <- model_with_context %>%
  filter(quarter %in% 1:4) %>%
  mutate(
    qtr_sec_remaining = game_seconds_remaining - (4 - quarter) * 15 * 60,
    is_late = qtr_sec_remaining < 5 * 60
  ) %>%
  group_by(is_late) %>%
  summarise(
    n = n(),
    avg_adv_return = mean(adv_return_vs_fc, na.rm = TRUE),
    pct_recommend_return = mean(best_action == "RETURN", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(label = if_else(is_late, "Late (<5 min)", "Early (>=5 min)"))

cat("--- Late in Quarter Split (Model) ---\n")
print(late_split_model)
cat("\n")

# --- Receiving Team Way Ahead ---
recv_ahead_model <- model_with_context %>%
  mutate(
    recv_margin = -score_differential,
    recv_ahead_bucket = case_when(
      recv_margin >= 17 ~ "Way Ahead (17+)",
      recv_margin >= 9  ~ "Comfortably Ahead (9-16)",
      recv_margin >= 1  ~ "Slightly Ahead (1-8)",
      recv_margin == 0  ~ "Tied",
      recv_margin >= -8 ~ "Slightly Behind (1-8)",
      TRUE              ~ "Way Behind (9+)"
    ),
    recv_ahead_bucket = factor(recv_ahead_bucket, levels = c(
      "Way Ahead (17+)", "Comfortably Ahead (9-16)", "Slightly Ahead (1-8)",
      "Tied", "Slightly Behind (1-8)", "Way Behind (9+)"
    ))
  ) %>%
  group_by(recv_ahead_bucket) %>%
  summarise(
    n = n(),
    avg_adv_return = mean(adv_return_vs_fc, na.rm = TRUE),
    pct_recommend_return = mean(best_action == "RETURN", na.rm = TRUE),
    pct_recommend_fc = mean(best_action == "FAIR_CATCH", na.rm = TRUE),
    .groups = "drop"
  )

cat("--- Receiving Team Score Margin (Model Recommendations) ---\n")
print(recv_ahead_model, n = Inf)
cat("\n")


# ============================================================
# COMBINED INTERACTION: Q4 x Close Game
# ============================================================
cat("\n========================================\n")
cat("INTERACTION: Q4 x CLOSE GAME\n")
cat("========================================\n\n")

interaction_full <- all_punts %>%
  mutate(
    is_q4 = quarter == 4,
    is_close = abs(score_differential) <= 8,
    bucket = case_when(
      !is_q4 & is_close  ~ "Non-Q4, Close",
      !is_q4 & !is_close ~ "Non-Q4, Not Close",
      is_q4 & is_close   ~ "Q4, Close",
      is_q4 & !is_close  ~ "Q4, Not Close"
    )
  ) %>%
  group_by(bucket) %>%
  summarise(
    n = n(),
    avg_wpa = mean(wpa_play, na.rm = TRUE),
    fair_catch_rate = mean(specialTeamsResult == "Fair Catch", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(bucket)

cat("--- Q4 x Close Game (Full Dataset) ---\n")
print(interaction_full)
cat("\n")


# ============================================================
# VISUALIZATION: Return Advantage by Game Context
# ============================================================

# Plot 1: Q4 effect on model's return advantage
p1 <- model_with_context %>%
  mutate(quarter_label = if_else(quarter == 4, "Q4", "Q1-Q3")) %>%
  ggplot(aes(x = closest_gunner_dist, y = adv_return_vs_fc, color = quarter_label)) +
  geom_point(alpha = 0.4) +
  geom_smooth(method = "lm", se = TRUE) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Return Advantage vs. Gunner Distance by Quarter",
    subtitle = "Does the Q4 penalty persist after controlling for gunner distance?",
    x = "Closest Gunner Distance (yards)",
    y = "WP Advantage of Return over Fair Catch",
    color = "Quarter"
  ) +
  theme_minimal()

print(p1)

# Plot 2: Fair catch rate by receiving team's score margin
p2 <- all_punts %>%
  filter(!is.na(score_differential)) %>%
  mutate(recv_margin_bin = cut(-score_differential, breaks = seq(-30, 30, by = 7))) %>%
  filter(!is.na(recv_margin_bin)) %>%
  group_by(recv_margin_bin) %>%
  summarise(
    n = n(),
    fair_catch_rate = mean(specialTeamsResult == "Fair Catch", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = recv_margin_bin, y = fair_catch_rate)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  geom_text(aes(label = n), vjust = -0.5, size = 3) +
  labs(
    title = "Fair Catch Rate by Receiving Team's Score Margin",
    subtitle = "Hypothesis: teams way ahead fair catch more often",
    x = "Receiving Team Score Margin (binned)",
    y = "Fair Catch Rate"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(p2)

# Plot 3: Model recommendation distribution by Q4 x close game
p3 <- model_with_context %>%
  filter(!is.na(quarter), !is.na(score_differential)) %>%
  mutate(
    context = case_when(
      quarter == 4 & abs(score_differential) <= 8  ~ "Q4, Close",
      quarter == 4 & abs(score_differential) > 8   ~ "Q4, Not Close",
      quarter != 4 & abs(score_differential) <= 8  ~ "Q1-Q3, Close",
      quarter != 4 & abs(score_differential) > 8   ~ "Q1-Q3, Not Close"
    )
  ) %>%
  count(context, best_action) %>%
  group_by(context) %>%
  mutate(pct = n / sum(n)) %>%
  ggplot(aes(x = context, y = pct, fill = best_action)) +
  geom_col(position = "dodge") +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Model Recommendations by Game Context",
    x = "Game Context",
    y = "Percentage of Plays",
    fill = "Recommended Action"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

print(p3)
