# Boreal soundscape gallery: pull clips from WildTrax and build a manifest
# ---------------------------------------------------------------------------
# Output: a folder of short compressed audio clips + gallery_manifest.json
# that the viewer reads (one entry per point).
#
# Needs: wildrtrax, dplyr, purrr, jsonlite, and ffmpeg on the PATH.
# Credentials: set WT_USERNAME and WT_PASSWORD in .Renviron (wt_auth reads them).
# Column names below match current wildrtrax reports as far as I know;
# run names() on each report first and adjust any that differ.

library(wildrtrax)
library(dplyr)
library(purrr)
library(jsonlite)

wt_auth()

# ---- 1. Choose projects -----------------------------------------------------
# Only projects you can access, and whose admins are OK with public audio.
projects <- wt_get_projects("ARU")
project_ids <- c(0000, 0000)   # <- fill in

out_dir   <- "gallery_audio"   # copy clips/ and gallery_manifest.json into the site repo afterwards
clip_dir  <- file.path(out_dir, "clips")
dir.create(clip_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 2. Reports -------------------------------------------------------------
# "recording" gives recording_url; "main" gives the tags (species) per task.
get_reports <- function(pid) {
  r <- wt_download_report(pid, sensor_id = "ARU", reports = c("main", "recording"))
  list(main = r[[1]], rec = r[[2]])   # check order/names with str(r)
}
reps  <- map(project_ids, get_reports)
main  <- bind_rows(map(reps, "main"))
recs  <- bind_rows(map(reps, "rec"))

# ---- 3. Summarize each processed recording -----------------------------------
# What a visitor will hear: tagged species, richness, and whether it is
# abiotic/noise-heavy (useful for colouring and for filtering).
abiotic_codes <- c("LIWI","HEWI","LIRA","HERA","LITR","HETR","NONE")  # adjust to your project's codes
rec_summary <- main |>
  group_by(project_id, location, latitude, longitude, recording_date_time) |>
  summarise(
    species      = list(sort(unique(species_code[!species_code %in% abiotic_codes]))),
    common_names = list(sort(unique(species_common_name[!species_code %in% abiotic_codes]))),
    richness     = n_distinct(species_code[!species_code %in% abiotic_codes]),
    abiotic      = paste(unique(species_code[species_code %in% abiotic_codes]), collapse = ";"),
    .groups = "drop"
  )

pool <- rec_summary |>
  inner_join(recs |> select(location, recording_date_time, recording_url),
             by = c("location", "recording_date_time")) |>
  filter(!is.na(recording_url), !is.na(latitude)) |>
  mutate(hour = as.numeric(format(recording_date_time, "%H")) +
                as.numeric(format(recording_date_time, "%M")) / 60,
         doy  = as.integer(format(recording_date_time, "%j")))

# ---- 4. Stratified sample ----------------------------------------------------
# Spread across hour-of-day and season so the gallery isn't all dawn chorus.
set.seed(2026)
n_target <- 300
sampled <- pool |>
  mutate(hour_bin = cut(hour, c(-Inf, 4, 8, 12, 18, 22, Inf)),
         season   = cut(doy,  c(0, 140, 165, 190, 366))) |>
  group_by(hour_bin, season) |>
  slice_sample(n = ceiling(n_target / 20)) |>
  ungroup() |>
  slice_head(n = n_target) |>
  mutate(id = sprintf("%s_%s", location, format(recording_date_time, "%Y%m%d_%H%M%S")))

# ---- 5. Download recordings, trim, compress -----------------------------------
# 30 s from the start (or wherever you prefer), mono, 64 kbps MP3: ~240 KB each.
# ffmpeg reads straight from the WildTrax URL and stops after 30 s, so the
# full recording never lands on disk. If streaming fails for a file, it falls
# back to downloading it to a temp file and deletes it right after trimming.
encode <- function(src, clip) {
  system2("ffmpeg", c("-y", "-loglevel", "error", "-ss", "0", "-t", "30", "-i", shQuote(src),
                      "-ac", "1", "-ar", "32000", "-b:a", "64k",
                      "-af", shQuote("afade=t=in:d=0.4,afade=t=out:st=29.2:d=0.8"),
                      shQuote(clip)))
}
clip_one <- function(url, id) {
  clip <- file.path(clip_dir, paste0(id, ".mp3"))
  if (!file.exists(clip)) {
    status <- encode(url, clip)
    if (status != 0 || !file.exists(clip)) {
      tmp <- tempfile(fileext = paste0(".", sub(".*\\.(\\w+)(\\?.*)?$", "\\1", url)))
      httr2::request(url) |> httr2::req_perform(path = tmp)
      encode(tmp, clip)
      unlink(tmp)
    }
  }
  basename(clip)
}
sampled$file <- map2_chr(sampled$recording_url, sampled$id, possibly(clip_one, NA_character_))
sampled <- filter(sampled, !is.na(file))

# ---- 6. Manifest for the viewer ----------------------------------------------
# Jitter or round coordinates if any project requires buffered locations.
# Project names for the wall labels (check the name column in names(projects)).
proj_names <- projects |> select(project_id, project_name = project)

manifest <- sampled |>
  left_join(proj_names, by = "project_id") |>
  transmute(id, file, project_id, project_name, area = project_name, location,
            lat = round(latitude, 2), lon = round(longitude, 2),
            datetime = format(recording_date_time, "%Y-%m-%dT%H:%M:%S"),
            hour, doy, richness, abiotic, species, common_names)
write_json(manifest, file.path(out_dir, "gallery_manifest.json"), auto_unbox = TRUE, pretty = TRUE)

message(nrow(manifest), " clips ready in ", clip_dir)
# Before publishing: listen through for human voices and delete those clips.
