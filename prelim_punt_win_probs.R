# ============================================================
# Punt returns + Win Probability (Option B, NO receive_2h_ko)
# FIXED JOIN: uses nflfastR pbp old_game_id to match BDB gameId
# - Portable paths for GitHub repo
# - Uses pbp wp/wpa and home_wp_post/away_wp_post (no calculate_win_probability)
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(lubridate)
  library(stringr)
  library(nflfastR)
})

# -----------------------------
# 0) Data directory (relative to repo root)
# -----------------------------
DATA_DIR <- file.path(
  "NFLBigDataBowl",
  "data_filtering",
  "nfl-big-data-bowl-2022"
)

# -----------------------------
# 1) Helpers
# -----------------------------
coerce_ids <- function(df) {
  df %>%
    mutate(
      gameId = as.character(gameId),
      playId = as.character(playId)
    )
}

clock_to_seconds <- function(clock_chr) {
  ifelse(is.na(clock_chr), NA_real_,
         {
           parts <- str_split_fixed(clock_chr, ":", 2)
           suppressWarnings(as.numeric(parts[,1]) * 60 + as.numeric(parts[,2]))
         })
}

# -----------------------------
# 2) Read tracking data (BDB 2018-2020)
# -----------------------------
# NOTE: These files are huge. If read_csv is slow, switch to vroom::vroom().
tracking_2018 <- read_csv(file.path(DATA_DIR, "tracking2018.csv"),
                          show_col_types = FALSE) %>% mutate(season = 2018)
tracking_2019 <- read_csv(file.path(DATA_DIR, "tracking2019.csv"),
                          show_col_types = FALSE) %>% mutate(season = 2019)
tracking_2020 <- read_csv(file.path(DATA_DIR, "tracking2020.csv"),
                          show_col_types = FALSE) %>% mutate(season = 2020)

tracking <- bind_rows(tracking_2018, tracking_2019, tracking_2020) %>%
  coerce_ids()

# -----------------------------
# 3) Read plays, games, players
# -----------------------------
plays   <- read_csv(file.path(DATA_DIR, "plays.csv"),   show_col_types = FALSE) %>% coerce_ids()
games   <- read_csv(file.path(DATA_DIR, "games.csv"),   show_col_types = FALSE) %>% mutate(gameId = as.character(gameId))
players <- read_csv(file.path(DATA_DIR, "players.csv"), show_col_types = FALSE) %>%
  rename(position = Position) %>%
  mutate(nflId = as.character(nflId))

# -----------------------------
# 4) Clean games table
# -----------------------------
games2 <- games %>%
  transmute(
    gameId,
    season = as.integer(season),
    week = as.integer(week),
    gameDate = as.Date(gameDate),
    gameTimeEastern,
    home_team = homeTeamAbbr,
    away_team = visitorTeamAbbr
  )

# -----------------------------
# 5) Build punt-only play-level table from plays.csv
# -----------------------------
# NOTE: If your dataset uses different punt labeling, adjust this filter.
punts_base <- plays %>%
  left_join(games2, by = "gameId") %>%
  filter(specialTeamsPlayType == "Punt") %>%
  transmute(
    # keys
    gameId, playId,
    
    # outcomes / descriptors
    playDescription,
    specialTeamsPlayType,
    specialTeamsResult,
    kickLength,
    kickReturnYardage,
    playResult,
    
    # situation
    quarter = as.integer(quarter),
    down = as.integer(down),
    ydstogo = as.integer(yardsToGo),
    possessionTeam,
    absoluteYardlineNumber = as.integer(absoluteYardlineNumber),
    gameClock,
    
    # scores (pre-snap)
    preSnapHomeScore = as.integer(preSnapHomeScore),
    preSnapVisitorScore = as.integer(preSnapVisitorScore),
    
    # special teams ids
    kickerId = as.character(kickerId),
    returnerId = as.character(returnerId),
    kickBlockerId = as.character(kickBlockerId),
    
    # game info
    season, week, gameDate,
    home_team, away_team
  )

# -----------------------------
# 6) Add player metadata (optional)
# -----------------------------
players_small <- players %>%
  select(nflId, displayName, position, height, weight, birthDate, collegeName)

punts_with_players <- punts_base %>%
  left_join(players_small %>% rename(kickerName = displayName, kickerPos = position),
            by = c("kickerId" = "nflId")) %>%
  left_join(players_small %>% rename(returnerName = displayName, returnerPos = position),
            by = c("returnerId" = "nflId")) %>%
  left_join(players_small %>% rename(blockerName = displayName, blockerPos = position),
            by = c("kickBlockerId" = "nflId"))

# -----------------------------
# 7) Load nflfastR play-by-play and create joinable state table
# IMPORTANT FIX:
#   Use old_game_id (GSIS) to match Big Data Bowl gameId like 2018090600.
# -----------------------------
pbp <- nflfastR::load_pbp(2018:2020)

pbp_state <- pbp %>%
  mutate(
    gameId = as.character(old_game_id),  # <-- critical fix
    playId = as.character(play_id)
  ) %>%
  transmute(
    gameId, playId,
    spread_line,
    posteam_timeouts_remaining,
    defteam_timeouts_remaining,
    wp,
    wpa,
    home_wp_post,
    away_wp_post
  )

# -----------------------------
# 8) Join pbp state onto punt plays
# -----------------------------
punts_joined <- punts_with_players %>%
  left_join(pbp_state, by = c("gameId", "playId"))

# -----------------------------
# 9) Create modeling-friendly WP fields + context fields
# -----------------------------
punts_with_wp <- punts_joined %>%
  mutate(
    posteam = possessionTeam,
    defteam = if_else(posteam == home_team, away_team, home_team),
    
    # posteam-oriented pre and post WP
    wp_pre  = wp,
    wp_post = if_else(posteam == home_team, home_wp_post, away_wp_post),
    
    # play WPA (posteam-oriented in nflfastR pbp)
    wpa_play = wpa,
    
    # score differential from posteam perspective
    score_differential = case_when(
      posteam == home_team ~ preSnapHomeScore - preSnapVisitorScore,
      posteam == away_team ~ preSnapVisitorScore - preSnapHomeScore,
      TRUE ~ NA_real_
    ),
    
    # yardline_100 (yards from opponent end zone)
    yardline_100 = case_when(
      posteam == home_team ~ 100 - absoluteYardlineNumber,
      posteam == away_team ~ absoluteYardlineNumber,
      TRUE ~ NA_real_
    ),
    
    # time fields (handy features)
    qtr_sec_remaining = clock_to_seconds(gameClock),
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
  select(-qtr_sec_remaining)

# -----------------------------
# 10) Join punt-play WP context onto tracking frames
# -----------------------------
tracking_punts <- tracking %>%
  inner_join(
    punts_with_wp %>%
      select(
        gameId, playId,
        season, week, gameDate,
        posteam, defteam, home_team,
        quarter, down, ydstogo, yardline_100,
        score_differential,
        game_seconds_remaining, half_seconds_remaining,
        spread_line,
        posteam_timeouts_remaining, defteam_timeouts_remaining,
        wp_pre, wp_post, wpa_play,
        returnerId, returnerName, returnerPos,
        kickLength, kickReturnYardage, specialTeamsResult, playResult,
        playDescription
      ),
    by = c("gameId", "playId")
  )

# -----------------------------
# 11) Sanity checks (run every time)
# -----------------------------
message("Punt play rows: ", nrow(punts_with_wp))
message("Tracking punt rows: ", nrow(tracking_punts))

match_summary <- punts_with_wp %>%
  summarise(
    n_punts = n(),
    matched_wp = sum(!is.na(wp_pre)),
    match_rate = matched_wp / n_punts
  )
print(match_summary)

missing_summary <- punts_with_wp %>%
  summarise(
    wp_pre_missing   = sum(is.na(wp_pre)),
    wp_post_missing  = sum(is.na(wp_post)),
    wpa_missing      = sum(is.na(wpa_play)),
    spread_missing   = sum(is.na(spread_line)),
    pto_missing      = sum(is.na(posteam_timeouts_remaining)),
    dto_missing      = sum(is.na(defteam_timeouts_remaining))
  )
print(missing_summary)

# -----------------------------
# 12) Save outputs (repo root)
# -----------------------------
write_csv(punts_with_wp, "punts_with_wp.csv")
write_csv(tracking_punts, "tracking_punts_enriched.csv")

message("✓ Wrote punts_with_wp.csv")
message("✓ Wrote tracking_punts_enriched.csv")
