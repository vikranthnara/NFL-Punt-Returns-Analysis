suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(stringr)
})

DATA_DIR <- file.path(
  "NFLBigDataBowl",
  "data_filtering",
  "nfl-big-data-bowl-2022"
)

# -----------------------------
# 1) Load source data
# -----------------------------
plays <- read_csv(file.path(DATA_DIR, "plays.csv"), show_col_types = FALSE) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId)) %>%
  filter(specialTeamsPlayType == "Punt")

pff <- read_csv(file.path(DATA_DIR, "PFFScoutingData.csv"), show_col_types = FALSE) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId))

# Tracking files are huge; load only what you need if possible.
# For a starter, just show reading one season; in production bind 2018-2020.
tracking_2018 <- read_csv(file.path(DATA_DIR, "tracking2018.csv"),
                          show_col_types = FALSE) %>%
  mutate(gameId = as.character(gameId), playId = as.character(playId), nflId = as.character(nflId))

# If you already created a combined tracking tibble, replace tracking_2018 with tracking
tracking <- tracking_2018

# -----------------------------
# 2) Helper: parse a "list column" like gunners into nflId values
# PFF list columns are often semi/pipe delimited or contain names/ids.
# This tries to pull out sequences of digits (nflIds) robustly.
# -----------------------------
extract_nflIds <- function(x) {
  if (is.na(x)) return(character(0))
  ids <- str_extract_all(as.character(x), "\\d+")[[1]]
  unique(ids)
}

# -----------------------------
# 3) Identify the "catch/fielding frame" for each punt play
# You may need to adjust these event labels depending on what your tracking files use.
# -----------------------------
CATCH_EVENTS <- c(
  "punt_received", "fair_catch", "punt_muffed", "punt_land", "punt_downed"
)

catch_frames <- tracking %>%
  filter(event %in% CATCH_EVENTS) %>%
  group_by(gameId, playId) %>%
  summarise(catch_frameId = min(frameId, na.rm = TRUE), .groups = "drop")

# -----------------------------
# 4) Pull returner position at catch frame
# returnerId is from plays.csv (already on punt plays)
# -----------------------------
returner_at_catch <- plays %>%
  transmute(gameId, playId, returnerId = as.character(returnerId), kickLength = as.numeric(kickLength)) %>%
  left_join(catch_frames, by = c("gameId", "playId")) %>%
  filter(!is.na(catch_frameId), !is.na(returnerId)) %>%
  left_join(
    tracking %>%
      transmute(gameId, playId, frameId,
                nflId = as.character(nflId), team, x, y, playDirection),
    by = c("gameId", "playId", "catch_frameId" = "frameId", "returnerId" = "nflId")
  ) %>%
  rename(returner_team = team, returner_x = x, returner_y = y, playDirection = playDirection)

# -----------------------------
# 5) Build a per-play table of all players at the catch frame (excluding football)
# -----------------------------
players_at_catch <- catch_frames %>%
  left_join(
    tracking %>%
      transmute(gameId, playId, frameId, nflId = as.character(nflId), team, x, y, displayName),
    by = c("gameId", "playId", "catch_frameId" = "frameId")
  ) %>%
  filter(!is.na(nflId), team %in% c("home", "away"))

# -----------------------------
# 6) Merge PFF punt features (hang time, kick type, direction)
# -----------------------------
pff_punt_feats <- pff %>%
  transmute(
    gameId, playId,
    hang_time = as.numeric(hangTime),
    kick_type = as.character(kickType),
    kick_contact_type = as.character(kickContactType),
    punt_direction = coalesce(as.character(kickDirectionActual), as.character(kickDirectionIntended)),
    gunners_raw = as.character(gunners)
  )

# -----------------------------
# 7) Compute closest gunner distance + furthest blocker distance at catch frame
# -----------------------------
punt_features <- returner_at_catch %>%
  left_join(pff_punt_feats, by = c("gameId", "playId")) %>%
  # attach all players at catch to compute distances
  left_join(players_at_catch, by = c("gameId", "playId")) %>%
  mutate(
    dx = x - returner_x,
    dy = y - returner_y,
    dist_to_returner = sqrt(dx^2 + dy^2),
    
    is_returner = (nflId == returnerId),
    is_same_team_as_returner = (team == returner_team),
    is_opponent = (team != returner_team),
    
    # parse gunner ids from PFF
    gunner_ids = map(gunners_raw, extract_nflIds),
    is_gunner = map2_lgl(gunner_ids, nflId, ~ .y %in% .x)
  ) %>%
  group_by(gameId, playId) %>%
  summarise(
    punt_distance = first(kickLength),
    
    # PFF-derived
    hang_time = first(hang_time),
    kick_type = first(kick_type),
    kick_contact_type = first(kick_contact_type),
    punt_direction = first(punt_direction),
    
    # Furthest blocker: max dist among same-team players (excluding returner)
    furthest_blocker_dist = suppressWarnings(
      max(dist_to_returner[is_same_team_as_returner & !is_returner], na.rm = TRUE)
    ),
    
    # Closest gunner: min dist among opponent players flagged as gunners
    closest_gunner_dist = suppressWarnings(
      min(dist_to_returner[is_opponent & is_gunner], na.rm = TRUE)
    ),
    
    # Fallback: closest opponent regardless of gunner tag
    closest_defender_dist = suppressWarnings(
      min(dist_to_returner[is_opponent], na.rm = TRUE)
    ),
    
    .groups = "drop"
  ) %>%
  mutate(
    # if closest_gunner_dist couldn't be computed (no parsed gunners), use fallback
    closest_gunner_dist = if_else(is.infinite(closest_gunner_dist) | is.na(closest_gunner_dist),
                                  closest_defender_dist, closest_gunner_dist)
  ) %>%
  select(
    gameId, playId,
    punt_distance,
    punt_direction,
    kick_type, kick_contact_type,
    hang_time,
    furthest_blocker_dist,
    closest_gunner_dist
  )

# -----------------------------
# 8) Save for modeling
# -----------------------------
write_csv(punt_features, "punt_features.csv")
message("✓ Wrote punt_features.csv")
