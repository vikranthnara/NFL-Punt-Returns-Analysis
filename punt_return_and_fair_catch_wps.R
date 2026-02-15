suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(stringr)
  library(nflfastR)
})

# -----------------------------
# 0) Paths (edit if needed)
# -----------------------------
DATA_DIR <- file.path(
  "NFLBigDataBowl",
  "data_filtering",
  "nfl-big-data-bowl-2022"
)

# -----------------------------
# 1) Read plays + filter punts that were NOT fair caught
# -----------------------------
plays <- read_csv(file.path(DATA_DIR, "plays.csv"), show_col_types = FALSE) %>%
  mutate(
    gameId = as.character(gameId),
    playId = as.character(playId)
  )

punts <- plays %>%
  filter(specialTeamsPlayType == "Punt") %>%
  filter(is.na(specialTeamsResult) | specialTeamsResult != "Fair Catch") %>%
  transmute(
    gameId, playId,
    specialTeamsResult,
    kickLength = as.numeric(kickLength),
    kickReturnYardage = as.numeric(kickReturnYardage),
    playDescription
  )

# -----------------------------
# 2) Load nflfastR pbp and make it joinable to BDB IDs
#    Use old_game_id + play_id
# -----------------------------
pbp <- nflfastR::load_pbp(2018:2020)

pbp_core <- pbp %>%
  mutate(
    gameId = as.character(old_game_id),
    playId = as.character(play_id)
  ) %>%
  transmute(
    gameId, playId,
    
    # team identities (during the punt play)
    posteam, defteam, home_team,
    
    # game-state inputs for counterfactual WP
    down, ydstogo, yardline_100,
    score_differential,
    game_seconds_remaining,
    half_seconds_remaining,
    spread_line,
    posteam_timeouts_remaining,
    defteam_timeouts_remaining,
    
    # actual wp outputs from pbp
    home_wp_post, away_wp_post,
    
    # punt info
    kick_distance,
    return_yards
  )

# -----------------------------
# 3) Join punts to pbp
# -----------------------------
punt_joined <- punts %>%
  left_join(pbp_core, by = c("gameId", "playId"))

# -----------------------------
# 4) Actual post-play WP for the RETURN TEAM
#    Return team on punt plays is defteam.
# -----------------------------
punt_joined <- punt_joined %>%
  mutate(
    wp_post_actual_return_team =
      if_else(defteam == home_team, home_wp_post, away_wp_post)
  )

# -----------------------------
# 5) Fair-catch counterfactual state
#    After a punt (fair catch), RETURN TEAM (defteam) starts:
#      1st & 10 at the fair-catch spot
#
#    We approximate fair-catch spot using kick distance:
#      land_from_return_endzone = yardline_100 - punt_distance
#      clamp to at least 20 (touchback rule simplification)
#      convert to return team's yardline_100:
#        yardline_100_fc_recv = 100 - land_from_return_endzone_fc
# -----------------------------
punt_joined <- punt_joined %>%
  mutate(
    punt_dist_use = if_else(!is.na(kickLength), kickLength, kick_distance),
    land_from_return_endzone = yardline_100 - punt_dist_use,
    land_from_return_endzone_fc = pmax(20, pmin(land_from_return_endzone, 100)),
    yardline_100_fc_recv = 100 - land_from_return_endzone_fc
  )

# -----------------------------
# 6) Compute WP for return team under the fair-catch counterfactual
#    We use calculate_win_probability(), and set receive_2h_ko = 0 to satisfy schema.
#
#    IMPORTANT: score_differential and timeouts must be from NEW offense (return team).
# -----------------------------
fc_state <- punt_joined %>%
  transmute(
    posteam = defteam,          # return team now on offense
    defteam = posteam,          # punt team now on defense
    home_team = home_team,
    down = 1L,
    ydstogo = 10L,
    yardline_100 = as.numeric(yardline_100_fc_recv),
    game_seconds_remaining = as.numeric(game_seconds_remaining),
    half_seconds_remaining = as.numeric(half_seconds_remaining),
    
    # flip score differential to return team's perspective
    score_differential = -as.numeric(score_differential),
    
    # spread_line stays as home spread
    spread_line = as.numeric(spread_line),
    
    # swap timeouts so posteam_timeouts refers to the new offense (return team)
    posteam_timeouts_remaining = as.integer(defteam_timeouts_remaining),
    defteam_timeouts_remaining = as.integer(posteam_timeouts_remaining),
    
    # required by function but missing in your pbp schema -> neutral placeholder
    receive_2h_ko = 0L
  )

fc_with_wp <- fc_state %>%
  nflfastR::calculate_win_probability()

# This wp is the return team's WP in the fair-catch scenario
wp_post_faircatch_return_team <- fc_with_wp$wp

# -----------------------------
# 7) Final result: delta from RETURN TEAM perspective
# -----------------------------
result <- punt_joined %>%
  mutate(
    wp_post_faircatch_return_team = wp_post_faircatch_return_team,
    delta_wp_return_team = wp_post_actual_return_team - wp_post_faircatch_return_team,
    
    actual_return_yards = kickReturnYardage,
    faircatch_return_yards = 0
  ) %>%
  select(
    gameId, playId, playDescription,
    specialTeamsResult,
    punt_dist_use,
    actual_return_yards, faircatch_return_yards,
    wp_post_actual_return_team,
    wp_post_faircatch_return_team,
    delta_wp_return_team
  )

write_csv(result, "punt_return_vs_faircatch_wp_delta_return_team.csv")
message("✓ Wrote punt_return_vs_faircatch_wp_delta_return_team.csv")
