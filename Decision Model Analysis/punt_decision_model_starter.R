# ============================================================
# Punt decision / expected-WP starter script (Return/FC/Bounce)
# FIXES INCLUDED:
#  - Compute game_seconds_remaining & half_seconds_remaining from quarter+gameClock
#  - Replace missing punt_direction / kick_type with "UNK"
#  - FIX: force factor levels to include "UNK" BEFORE training (prevents new level error)
#  - Safety fallback if p_muff / mu / p_tb are NA
#
# INPUTS:
#   - punts_with_wp.csv
#   - punt_features.csv
#
# OUTPUT:
#   - punt_decision_expected_wp.csv
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(stringr)
  library(nflfastR)
})

# -----------------------------
# 0) Load data
# -----------------------------
punts <- read_csv("punts_with_wp.csv", show_col_types = FALSE) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId))

feat <- read_csv("punt_features.csv", show_col_types = FALSE) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId))

# -----------------------------
# 1) Compute time vars from quarter + gameClock
# -----------------------------
punts <- punts %>%
  mutate(
    quarter = as.integer(quarter),
    clock_str = str_extract(gameClock, "^\\d{1,2}:\\d{2}"),
    mm = suppressWarnings(as.numeric(str_extract(clock_str, "^\\d{1,2}"))),
    ss = suppressWarnings(as.numeric(str_extract(clock_str, "(?<=:)\\d{2}"))),
    clock_sec = 60 * mm + ss,
    game_seconds_remaining = case_when(
      quarter == 1 ~ 45 * 60 + clock_sec,
      quarter == 2 ~ 30 * 60 + clock_sec,
      quarter == 3 ~ 15 * 60 + clock_sec,
      quarter == 4 ~ 0  * 60 + clock_sec,
      TRUE ~ NA_real_
    ),
    half_seconds_remaining = case_when(
      quarter %in% c(1, 2) ~ 15 * 60 + clock_sec,
      quarter %in% c(3, 4) ~ clock_sec,
      TRUE ~ NA_real_
    )
  ) %>%
  select(-clock_str, -mm, -ss, -clock_sec)

# -----------------------------
# 2) Merge punt-only features
# -----------------------------
df <- punts %>%
  filter(specialTeamsPlayType == "Punt") %>%
  left_join(feat, by = c("gameId", "playId"))

# Neutral default if not present
if (!"receive_2h_ko" %in% names(df)) df$receive_2h_ko <- 0L

# -----------------------------
# 3) Labels for outcome models
# -----------------------------
df <- df %>%
  mutate(
    is_fair_catch = specialTeamsResult == "Fair Catch",
    is_muffed = str_detect(tolower(coalesce(specialTeamsResult, "")), "muff|fumble"),
    return_yards_obs = case_when(
      is_fair_catch ~ 0,
      is_muffed ~ NA_real_,
      TRUE ~ as.numeric(kickReturnYardage)
    ),
    muff_obs = as.integer(is_muffed)
  )

# -----------------------------
# 4) FIX: make punt_direction/kick_type never NA and lock levels INCLUDING "UNK"
# -----------------------------
df <- df %>%
  mutate(
    punt_direction = na_if(punt_direction, ""),
    kick_type = na_if(kick_type, ""),
    punt_direction = replace_na(punt_direction, "UNK"),
    kick_type = replace_na(kick_type, "UNK")
  )

# Force levels (include UNK no matter what)
DIR_LEVELS  <- c("C", "L", "R", "UNK")
KICK_LEVELS <- c("A", "N", "R", "UNK")

df <- df %>%
  mutate(
    punt_direction = factor(punt_direction, levels = DIR_LEVELS),
    kick_type = factor(kick_type, levels = KICK_LEVELS)
  )

# -----------------------------
# 5) Force numeric/integer types used by WP + models
# -----------------------------
df <- df %>%
  mutate(
    posteam = as.character(posteam),
    defteam = as.character(defteam),
    home_team = as.character(home_team),
    
    down = as.integer(down),
    ydstogo = as.integer(ydstogo),
    posteam_timeouts_remaining = as.integer(posteam_timeouts_remaining),
    defteam_timeouts_remaining = as.integer(defteam_timeouts_remaining),
    receive_2h_ko = as.integer(receive_2h_ko),
    
    score_differential = as.numeric(score_differential),
    yardline_100 = as.numeric(yardline_100),
    game_seconds_remaining = as.numeric(game_seconds_remaining),
    half_seconds_remaining = as.numeric(half_seconds_remaining),
    spread_line = as.numeric(spread_line),
    
    punt_distance = as.numeric(punt_distance),
    hang_time = as.numeric(hang_time),
    closest_gunner_dist = as.numeric(closest_gunner_dist),
    furthest_blocker_dist = as.numeric(furthest_blocker_dist)
  )

# -----------------------------
# 6) Train outcome models (baseline)
# -----------------------------
muff_model <- glm(
  muff_obs ~ closest_gunner_dist + hang_time + punt_distance + punt_direction + kick_type,
  data = df,
  family = binomial()
)

ret_train <- df %>%
  filter(!is_fair_catch, muff_obs == 0, !is.na(return_yards_obs))

yard_model <- lm(
  return_yards_obs ~ closest_gunner_dist + furthest_blocker_dist + hang_time +
    punt_distance + punt_direction + kick_type,
  data = ret_train
)

yard_resid_sd <- sd(resid(yard_model), na.rm = TRUE)

bounce_tb_model <- glm(
  as.integer(specialTeamsResult == "Touchback") ~ hang_time + punt_distance + punt_direction + kick_type,
  data = df,
  family = binomial()
)



baseline_muff_rate <- mean(df$muff_obs, na.rm = TRUE)
baseline_return_yards <- mean(ret_train$return_yards_obs, na.rm = TRUE)
baseline_tb_rate <- mean(df$specialTeamsResult == "Touchback", na.rm = TRUE)

# -----------------------------
# 7) WP helper (uses nflfastR WP)
# -----------------------------
wp_next_state <- function(posteam, defteam, home_team,
                          score_differential, yardline_100,
                          down, ydstogo,
                          game_seconds_remaining, half_seconds_remaining,
                          spread_line,
                          posteam_timeouts_remaining, defteam_timeouts_remaining,
                          receive_2h_ko) {
  
  if (length(posteam) == 0) return(NA_real_)
  
  state <- tibble(
    posteam = as.character(posteam),
    defteam = as.character(defteam),
    home_team = as.character(home_team),
    score_differential = as.numeric(score_differential),
    yardline_100 = as.numeric(yardline_100),
    down = as.integer(down),
    ydstogo = as.integer(ydstogo),
    game_seconds_remaining = as.numeric(game_seconds_remaining),
    half_seconds_remaining = as.numeric(half_seconds_remaining),
    spread_line = as.numeric(spread_line),
    posteam_timeouts_remaining = as.integer(posteam_timeouts_remaining),
    defteam_timeouts_remaining = as.integer(defteam_timeouts_remaining),
    receive_2h_ko = as.integer(receive_2h_ko)
  ) %>%
    mutate(across(where(is.logical), ~ as.numeric(.x)))
  
  nflfastR::calculate_win_probability(state) %>% pull(wp)
}

# -----------------------------
# 8) Fair catch spot approximation
# -----------------------------
faircatch_yardline100_recv <- function(yardline_100_punt, punt_distance) {
  land_from_return_ez <- yardline_100_punt - punt_distance
  land_from_return_ez <- max(20, min(land_from_return_ez, 100))
  100 - land_from_return_ez
}

# -----------------------------
# 9) Expected-WP decision engine
# -----------------------------
set.seed(1)
N_SIM <- 300

decision_eval <- df %>%
  filter(!is_fair_catch) %>%
  filter(
    !is.na(defteam), !is.na(posteam), !is.na(home_team),
    !is.na(score_differential), !is.na(yardline_100),
    !is.na(game_seconds_remaining), !is.na(half_seconds_remaining),
    !is.na(spread_line),
    !is.na(posteam_timeouts_remaining), !is.na(defteam_timeouts_remaining),
    !is.na(punt_distance), !is.na(closest_gunner_dist), !is.na(hang_time)
  ) %>%
  rowwise() %>%
  mutate(
    return_team = defteam,
    punt_team   = posteam,
    yardline_fc = faircatch_yardline100_recv(yardline_100, punt_distance),
    
    wp_fc = wp_next_state(
      posteam = return_team,
      defteam = punt_team,
      home_team = home_team,
      score_differential = -score_differential,
      yardline_100 = yardline_fc,
      down = 1L, ydstogo = 10L,
      game_seconds_remaining = game_seconds_remaining,
      half_seconds_remaining = half_seconds_remaining,
      spread_line = spread_line,
      posteam_timeouts_remaining = defteam_timeouts_remaining,
      defteam_timeouts_remaining = posteam_timeouts_remaining,
      receive_2h_ko = receive_2h_ko
    ),
    
    wp_return = {
      # Safely predict, returning NA if a new factor level ("UNK") trips it up
      p_muff <- tryCatch(
        predict(muff_model, newdata = cur_data(), type = "response"),
        error = function(e) NA_real_
      )
      if (is.na(p_muff)) p_muff <- baseline_muff_rate
      
      sims <- replicate(N_SIM, {
        muff <- rbinom(1, 1, p_muff)
        if (is.na(muff)) muff <- 0L
        
        if (muff == 1) {
          wp_punt_team <- wp_next_state(
            posteam = punt_team,
            defteam = return_team,
            home_team = home_team,
            score_differential = score_differential,
            yardline_100 = yardline_fc,
            down = 1L, ydstogo = 10L,
            game_seconds_remaining = game_seconds_remaining,
            half_seconds_remaining = half_seconds_remaining,
            spread_line = spread_line,
            posteam_timeouts_remaining = posteam_timeouts_remaining,
            defteam_timeouts_remaining = defteam_timeouts_remaining,
            receive_2h_ko = receive_2h_ko
          )
          1 - wp_punt_team
        } else {
          # Safely predict yards
          mu <- tryCatch(
            predict(yard_model, newdata = cur_data()),
            error = function(e) NA_real_
          )
          if (is.na(mu)) mu <- baseline_return_yards
          
          ry <- rnorm(1, mean = mu, sd = yard_resid_sd)
          ry <- max(-10, min(ry, 80))
          
          yardline_after <- max(1, min(99, yardline_fc - ry))
          
          wp_next_state(
            posteam = return_team,
            defteam = punt_team,
            home_team = home_team,
            score_differential = -score_differential,
            yardline_100 = yardline_after,
            down = 1L, ydstogo = 10L,
            game_seconds_remaining = game_seconds_remaining,
            half_seconds_remaining = half_seconds_remaining,
            spread_line = spread_line,
            posteam_timeouts_remaining = defteam_timeouts_remaining,
            defteam_timeouts_remaining = posteam_timeouts_remaining,
            receive_2h_ko = receive_2h_ko
          )
        }
      })
      
      mean(sims, na.rm = TRUE)
    },
    
    wp_bounce = {
      # Safely predict touchback prob
      p_tb <- tryCatch(
        predict(bounce_tb_model, newdata = cur_data(), type = "response"),
        error = function(e) NA_real_
      )
      if (is.na(p_tb)) p_tb <- baseline_tb_rate
      
      sims <- replicate(N_SIM, {
        tb <- rbinom(1, 1, p_tb)
        if (is.na(tb)) tb <- 0L
        
        yardline_b <- if (tb == 1) 80 else {
          delta <- rnorm(1, mean = 4, sd = 8)
          max(1, min(99, yardline_fc + delta))
        }
        
        wp_next_state(
          posteam = return_team,
          defteam = punt_team,
          home_team = home_team,
          score_differential = -score_differential,
          yardline_100 = yardline_b,
          down = 1L, ydstogo = 10L,
          game_seconds_remaining = game_seconds_remaining,
          half_seconds_remaining = half_seconds_remaining,
          spread_line = spread_line,
          posteam_timeouts_remaining = defteam_timeouts_remaining,
          defteam_timeouts_remaining = posteam_timeouts_remaining,
          receive_2h_ko = receive_2h_ko
        )
      })
      
      mean(sims, na.rm = TRUE)
    },
    
    best_action = c("RETURN", "FAIR_CATCH", "BOUNCE")[which.max(c(wp_return, wp_fc, wp_bounce))],
    best_wp = max(wp_return, wp_fc, wp_bounce),
    adv_return_vs_fc = wp_return - wp_fc,
    adv_bounce_vs_fc = wp_bounce - wp_fc
  ) %>%
  ungroup() %>%
  select(
    gameId, playId, playDescription,
    punt_team, return_team,
    punt_distance, punt_direction, kick_type, hang_time,
    closest_gunner_dist, furthest_blocker_dist,
    wp_fc, wp_return, wp_bounce,
    adv_return_vs_fc, adv_bounce_vs_fc,
    best_action, best_wp
  )

write_csv(decision_eval, "punt_decision_expected_wp.csv")
message("✓ wrote punt_decision_expected_wp.csv")
