# ===============================
# NuBiokind - Data Preprocessing Script
# Run this script *once* before running the Shiny app.
# All heavy computations (geocoding, spatial joins) are performed in advance
# and results are saved as .rds files.
# ===============================

library(shiny)
library(sf)
library(dplyr)
library(tidyverse)
library(tigris)
library(leaflet)
library(htmltools)
library(tidygeocoder)
library(stringr)
library(lwgeom)
library(janitor)

# Set options
sf_use_s2(FALSE)
options(tigris_use_cache = TRUE, tigris_cache_dir = "tigris_cache")

message("===============================================")
message("Starting data preprocessing. (Takes approximately 3-5 minutes)")
message("===============================================")

# --- 0. Load basic data ---
message("Loading basic data...")
chicago_neighborhoods_geom <- st_read("Boundaries_-_Community_Areas_20260507.geojson", quiet = TRUE)
school_df_raw <- read_csv("school_level_linked_incs_251008.csv", show_col_types = FALSE) %>%
  filter(included_in_program == 1)


# --- 1. Generate Chicago Neighborhoods map data (most time-consuming task) ---
message("Map 1: Starting Chicago Neighborhoods data generation (geocoding)...")

# 1-1. Perform geocoding
school_data_chicago <- school_df_raw %>%
  filter(included_in_program == 1,
         city == "Chicago",
         !is.na(address) & address != "",
         had_incident == 1,
         !is.na(n_disp_return)) %>%
  select(school_name_std, address, city, zip,
         n_incidents, n_disp_return, perc_disp_return, included_in_program) %>%
  mutate(full_address = paste(address, city, "IL", zip, sep = ", "))

# ★★★ This is the step that takes 3 minutes ★★★
school_data_geocoded <- school_data_chicago %>%
  geocode(address = full_address, method = "arcgis", lat = latitude, long = longitude)

# Safety check: abort before writing any output if geocoding mostly failed
# (bad ArcGIS response, address format change, etc.) so a broken run can't
# silently overwrite good data or get deployed.
geocode_success_rate <- mean(!is.na(school_data_geocoded$latitude))
message(sprintf(
  "Geocoding success rate: %.1f%% (%d/%d addresses)",
  geocode_success_rate * 100,
  sum(!is.na(school_data_geocoded$latitude)),
  nrow(school_data_geocoded)
))
if (geocode_success_rate < 0.90) {
  stop(sprintf(
    "Geocoding success rate (%.1f%%) is below the 90%% safety threshold. Aborting before writing output files - investigate failed addresses before rerunning.",
    geocode_success_rate * 100
  ))
}

# 1-2. Spatial join and calculate statistics
school_points <- st_as_sf(school_data_geocoded,
                          coords = c("longitude", "latitude"),
                          crs = 4326) %>%
  st_transform(st_crs(chicago_neighborhoods_geom))

schools_with_neighborhood <- st_join(school_points,
                                     chicago_neighborhoods_geom %>%
                                       select(community, area_numbe))

neighborhood_stats <- schools_with_neighborhood %>%
  as.data.frame() %>%
  group_by(community) %>%
  summarise(total_incidents = sum(n_incidents),
            total_returned = sum(n_disp_return),
            .groups = 'drop') %>%
  mutate(return_rate = (total_returned / total_incidents) * 100)

chicago_map_data <- chicago_neighborhoods_geom %>%
  left_join(neighborhood_stats, by = "community")

# 1-3. Save to file
saveRDS(chicago_map_data, "chicago_map_data.rds")
message("Map 1: Chicago data saved successfully! (chicago_map_data.rds)")


# --- 2. Generate Illinois Counties map data ---
message("Map 2: Starting Illinois Counties data generation...")

il_counties <- counties(state = "IL", year = 2023, cb = TRUE) %>%
  st_transform(4326)

data_county <- school_df_raw %>%
  filter(included_in_program == 1, registered == 1, !is.na(n_disp_return))

norm_cty <- function(x) {
  x %>%
    str_replace_all("[,.]", " ") %>%
    str_remove(regex("\\bcounty\\b", ignore_case = TRUE)) %>%
    str_squish() %>% str_to_title() %>%
    str_replace("^Dekalb$", "DeKalb") %>%
    str_replace("^Dupage$", "DuPage") %>%
    str_replace("^Lasalle$", "LaSalle") %>%
    str_replace("^Mchenry$", "McHenry") %>%
    str_replace("^Mclean$", "McLean") %>%
    str_replace("^Saint Clair$", "St. Clair")
}

county_summary_clean <- data_county %>%
  mutate(county_key = norm_cty(county)) %>%
  group_by(county_key) %>%
  summarize(n_incidents = sum(n_incidents, na.rm = TRUE),
            n_disp_return = sum(n_disp_return, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(return_rate = ifelse(n_incidents > 0,
                              (n_disp_return / n_incidents) * 100,
                              NA_real_))

county_map_data <- il_counties %>%
  mutate(county_clean = norm_cty(NAME)) %>%
  left_join(county_summary_clean, by = c("county_clean" = "county_key"))

saveRDS(county_map_data, "county_map_data.rds")
message("Map 2: County data saved successfully! (county_map_data.rds)")


# --- 3. Generate Congressional Districts map data ---
message("Map 3: Starting Congressional Districts data generation...")

il_congress <- congressional_districts(state = "IL", year = 2023, cb = TRUE) %>%
  st_transform(4326)

congress_summary <- school_df_raw %>%
  filter(included_in_program == 1,
         registered == 1,
         !is.na(FedCong),
         !is.na(n_disp_return)) %>%
  group_by(FedCong) %>%
  summarise(
    n_incidents = sum(n_incidents, na.rm = TRUE),
    n_disp_return = sum(n_disp_return, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(return_rate = ifelse(n_incidents > 0,
                              (n_disp_return / n_incidents) * 100,
                              NA_real_))

dist_col <- if("CD118FP" %in% names(il_congress)) {
  "CD118FP"
} else if("GEOID" %in% names(il_congress)) {
  il_congress <- il_congress %>%
    mutate(district_num = as.numeric(str_sub(GEOID, 3, 4)))
  "district_num"
} else {
  dist_cols <- grep("CD|DIST", names(il_congress), value = TRUE, ignore.case = TRUE)
  if(length(dist_cols) > 0) dist_cols[1] else names(il_congress)[1]
}

if(dist_col != "district_num") {
  il_congress_map <- il_congress %>%
    mutate(district_num = as.numeric(!!sym(dist_col))) %>%
    filter(!is.na(district_num))
} else {
  il_congress_map <- il_congress %>%
    filter(!is.na(district_num))
}

congress_map_data <- il_congress_map %>%
  left_join(
    congress_summary %>%
      mutate(district_num = as.numeric(FedCong)),
    by = "district_num"
  )

saveRDS(congress_map_data, "congress_map_data.rds")
message("Map 3: Congressional data saved successfully! (congress_map_data.rds)")


# --- 4. Generate Cook County House map data ---
message("Map 4: Starting Cook County House data generation...")

# Common data (Cook County boundaries, ZIP codes)
cook_geom <- counties(state = "IL", year = 2023, cb = TRUE) %>%
  st_transform(4326) %>%
  filter(NAME == "Cook") %>%
  st_union() %>%
  st_as_sf()

zctas_il <- tigris::zctas(year = 2020, cb = TRUE) %>% st_transform(4326)
cook_zctas_indices <- st_intersects(zctas_il, cook_geom, sparse = FALSE)
cook_zctas <- zctas_il[cook_zctas_indices[,1], ]
zip_pts <- st_point_on_surface(cook_zctas)
suppressWarnings({
  zip_pts_fix <- st_make_valid(zip_pts)
})

# Cook County school data by ZIP code
by_zip_cook <- school_df_raw %>%
  filter(included_in_program == 1,
         registered == 1,
         !is.na(n_disp_return),
         str_to_title(county) == "Cook") %>%
  mutate(zip5 = str_extract(as.character(zip), "\\d{5}")) %>%
  filter(!is.na(zip5)) %>%
  group_by(zip5) %>%
  summarize(
    n_incidents = sum(n_incidents, na.rm = TRUE),
    n_disp_return = sum(n_disp_return, na.rm = TRUE),
    .groups = "drop"
  )

# House calculation
il_house <- tigris::state_legislative_districts(
  state = "IL", year = 2023, house = "lower", cb = TRUE
) %>% st_transform(4326)
cook_house <- st_intersection(il_house, cook_geom)
cook_house <- cook_house %>%
  mutate(district = if ("SLDLST" %in% names(.)) as.character(SLDLST) else as.character(GEOID))
suppressWarnings({
  cook_house_fix <- st_make_valid(cook_house)
})
zip2house <- zip_pts_fix %>%
  transmute(zip5 = ZCTA5CE20) %>%
  st_join(cook_house_fix %>% select(district), join = st_within) %>%
  st_drop_geometry()

by_house <- by_zip_cook %>%
  left_join(zip2house, by = "zip5") %>%
  filter(!is.na(district)) %>%
  group_by(district) %>%
  summarize(
    n_incidents = sum(n_incidents, na.rm = TRUE),
    n_disp_return = sum(n_disp_return, na.rm = TRUE),
    .groups = "drop"
  )

cook_house_poly <- cook_house_fix %>%
  st_collection_extract("POLYGON") %>%
  group_by(district) %>%
  summarize(.groups = "drop") %>%
  st_cast("MULTIPOLYGON")

house_map_data <- cook_house_poly %>%
  left_join(by_house, by = "district") %>%
  mutate(return_rate = ifelse(n_incidents > 0,
                              100 * n_disp_return / n_incidents,
                              NA_real_))

saveRDS(house_map_data, "house_map_data.rds")
message("Map 4: House data saved successfully! (house_map_data.rds)")


# --- 5. Generate Cook County Senate map data ---
message("Map 5: Starting Cook County Senate data generation...")

il_senate <- tigris::state_legislative_districts(
  state = "IL", year = 2023, house = "upper", cb = TRUE
) %>% st_transform(4326)
cook_senate <- st_intersection(il_senate, cook_geom)
cook_senate <- cook_senate %>%
  mutate(district = if ("SLDUST" %in% names(.)) as.character(SLDUST) else as.character(GEOID))
suppressWarnings({
  cook_senate_fix <- st_make_valid(cook_senate)
})
zip2senate <- zip_pts_fix %>%
  transmute(zip5 = ZCTA5CE20) %>%
  st_join(cook_senate_fix %>% select(district), join = st_within) %>%
  st_drop_geometry()

by_senate <- by_zip_cook %>%
  left_join(zip2senate, by = "zip5") %>%
  filter(!is.na(district)) %>%
  group_by(district) %>%
  summarize(
    n_incidents = sum(n_incidents, na.rm = TRUE),
    n_disp_return = sum(n_disp_return, na.rm = TRUE),
    .groups = "drop"
  )

cook_senate_poly <- cook_senate_fix %>%
  st_collection_extract("POLYGON") %>%
  group_by(district) %>%
  summarize(.groups = "drop") %>%
  st_cast("MULTIPOLYGON")

senate_map_data <- cook_senate_poly %>%
  left_join(by_senate, by = "district") %>%
  mutate(return_rate = ifelse(n_incidents > 0,
                              100 * n_disp_return / n_incidents,
                              NA_real_))

saveRDS(senate_map_data, "senate_map_data.rds")
message("Map 5: Senate data saved successfully! (senate_map_data.rds)")
message("===============================================")
message("All data preprocessing completed. Now run app.R.")
message("===============================================")