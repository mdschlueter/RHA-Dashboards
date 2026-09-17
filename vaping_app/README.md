# Youth Vaping Attendees Dashboard (current)

Shiny app visualizing youth vaping-prevention program attendance by Chicago
neighborhood.

## Files
- `app.R` — the Shiny app. Reads the Excel file below, geocodes addresses
  (results cached to a `geocoded_attendees.csv` it creates on first run),
  joins to Chicago community area boundaries, and renders an interactive map
  with year / school-type filters and multiple color-by metrics.
- `Youth Vaping Data 2022-2026.xlsx` — source attendance data, read directly
  by `app.R`.
- `chicago_neighborhoods.geojson` — Chicago community area boundaries used
  for the spatial join.
- `vaping_2022_2026_count_Report.xlsx` — supporting vaping count report.
  Not currently read by any script, but kept alongside the app's data since
  it's the same dataset family.

## How to run
1. Open this folder in R (or set it as your working directory).
2. Run `app.R` (e.g. `shiny::runApp("app.R")`). The first run will geocode
   addresses live via ArcGIS and write `geocoded_attendees.csv`; subsequent
   edits to `app.R` re-read that cached file if you wire it up to check for
   it (currently it re-geocodes every run — see the two back-to-back
   `df_geo <-` assignments near the top of the script if you want to add a
   file-exists cache check).
