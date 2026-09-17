# Asthma Program Impact Dashboard (current)

This is the current, working visualization of the Illinois state-wide asthma
program's effectiveness (student return-to-class rates), built for RHA.

Live at: shinyapps.io (see deployment section below for the URL once deployed).

## Files
- `app.R` — the Shiny app (5 tabs: Chicago Neighborhoods, Illinois Counties,
  Congressional Districts, Cook County House, Cook County Senate, About).
- `preprocess_data.R` — geocodes school addresses, joins them to the map
  boundaries below, and writes out the five `.rds` files that `app.R` reads
  (`chicago_map_data.rds`, `county_map_data.rds`, `congress_map_data.rds`,
  `house_map_data.rds`, `senate_map_data.rds`). Aborts before writing anything
  if fewer than 90% of Chicago addresses geocode successfully, so a bad run
  can't silently produce a broken dashboard.
- `Boundaries_-_Community_Areas_20260507.geojson` — Chicago community area
  boundaries, used by `preprocess_data.R`.
- `school_level_linked_incs_251008.csv` — school-level incident/return data.
  **Trimmed to only the 12 columns the pipeline actually reads**
  (`school_name_std`, `address`, `city`, `zip`, `county`, `FedCong`,
  `included_in_program`, `registered`, `n_incidents`, `had_incident`,
  `n_disp_return`, `perc_disp_return`). The full source file has additional
  student subgroup columns (income, IEP, race/ethnicity, etc.) that were
  deliberately dropped before this went into version control, since the
  pipeline never uses them and they don't need to sit in git history. This
  repo is private — keep it that way, since this file still has school
  names/addresses.

## Updating the data (automated)
Replacing `school_level_linked_incs_251008.csv` in this folder (via a normal
commit, or by uploading a replacement through the GitHub web UI) and pushing
to `main` automatically triggers `.github/workflows/update-asthma-dashboard.yml`,
which reruns `preprocess_data.R` and redeploys to shinyapps.io. No local R
install or IDE needed to update the live dashboard — see the repo root
README for the one-time setup this depends on (GitHub Secrets for the
shinyapps.io deploy credentials).

If a new data drop introduces addresses that don't geocode well, the workflow
fails loudly (check the Actions tab) instead of deploying bad data — GitHub
emails repo collaborators on failed runs by default.

## Running locally
1. Open this folder in R (or set it as your working directory).
2. Run `preprocess_data.R` once (takes ~3–5 min; it geocodes addresses live
   via ArcGIS and downloads TIGER/Line shapefiles via `tigris`).
3. Run `app.R` (e.g. `shiny::runApp("app.R")`).

## Manual deploy (if not relying on the GitHub Action)
```r
install.packages("rsconnect")
rsconnect::deployApp(
  appDir = "asthma_app",
  appFiles = c("app.R", "chicago_map_data.rds", "county_map_data.rds",
               "congress_map_data.rds", "house_map_data.rds", "senate_map_data.rds"),
  appName = "asthma-program-dashboard"
)
```
