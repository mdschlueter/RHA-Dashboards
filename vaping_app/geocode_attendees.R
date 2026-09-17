# Regenerates geocoded_attendees.csv from the source Excel file.
# Run this once locally whenever "Youth Vaping Data 2022-2026.xlsx" changes,
# then redeploy - app.R reads the cached CSV instead of geocoding live.

library(readxl)
library(tidyverse)
library(tidygeocoder)

df <- read_excel("Youth Vaping Data 2022-2026.xlsx") %>%
  mutate(
    `Youth Attendees` = as.numeric(`Youth Attendees`),
    full_address = paste(Address, "Chicago, IL")
  )

df_geo <- df %>%
  geocode(
    address = full_address,
    method = "arcgis",
    lat = latitude,
    long = longitude
  )

geocode_success_rate <- mean(!is.na(df_geo$latitude))
message(sprintf(
  "Geocoding success rate: %.1f%% (%d/%d addresses)",
  geocode_success_rate * 100,
  sum(!is.na(df_geo$latitude)),
  nrow(df_geo)
))
if (geocode_success_rate < 0.90) {
  stop(sprintf(
    "Geocoding success rate (%.1f%%) is below the 90%% safety threshold. Aborting before overwriting geocoded_attendees.csv - investigate failed addresses before rerunning.",
    geocode_success_rate * 100
  ))
}

write_csv(df_geo, "geocoded_attendees.csv")
message("Saved geocoded_attendees.csv")
