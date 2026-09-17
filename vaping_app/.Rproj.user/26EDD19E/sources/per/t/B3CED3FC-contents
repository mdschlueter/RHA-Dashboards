
library(shiny)
library(readxl)
library(tidyverse)
library(sf)
library(leaflet)
library(tidygeocoder)
library(htmltools)

# -----------------------------
# Load + prepare data
# -----------------------------

# ---- THIS IS WHERE YOU ADD YOUR DATA ------
# Geocoding is cached to geocoded_attendees.csv so a deployed app doesn't
# re-hit the live ArcGIS geocoder on every cold start. Delete that file (or
# call source("geocode_attendees.R") - see that script) to regenerate it
# after the source Excel file changes.
if (file.exists("geocoded_attendees.csv")) {
  df_geo <- read_csv("geocoded_attendees.csv")
} else {
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

  write_csv(df_geo, "geocoded_attendees.csv")
}

community_areas <- st_read(
  "chicago_neighborhoods.geojson",
  quiet = TRUE
) %>%
  rename(community = pri_neigh)

school_points <- df_geo %>%
  filter(!is.na(latitude), !is.na(longitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
  st_transform(st_crs(community_areas))

schools_with_neighborhood <- st_join(
  school_points,
  community_areas %>% select(community),
  join = st_within
)


schools_with_neighborhood$Year <- as.character(
  lubridate::year(as.POSIXct(
    schools_with_neighborhood$Year,
    origin = "1970-01-01"
  ))
)



ui <- fluidPage(
  
  titlePanel("Youth Vaping Attendees by Chicago Neighborhood"),
  
  sidebarLayout(
    
    sidebarPanel(
      
      selectInput(
        "year",
        "Select Year:",
        choices = c("All Years", sort(unique(schools_with_neighborhood$Year))),
        selected = "All Years"
      ),
      
      selectInput(
        "school_type",
        "Filter by School Type:",
        choices = c("All School Types", sort(unique(schools_with_neighborhood$`School Type`))),
        selected = "All School Types"
      ),
      
      selectInput(
        "metric",
        "Color neighborhoods by:",
        choices = c(
          "Total attendees" = "total_attendees",
          "Median attendees per school" = "median_attendees",
          "Number of schools" = "num_schools",
          "% change from baseline" = "pct_change_from_baseline"
        )
      ),
      
      tags$hr(),
      
      tags$p(
        tags$b("How to read this map:")
      ),
      
      tags$p(
        "Neighborhoods are shaded based on the selected metric. Dark gray means no data is available for that neighborhood under the selected filters."
      ),
      
      tags$p(
        "For % change from baseline, green indicates an increase from the school's first recorded year, while red indicates a decrease."
      ),
      
      tags$p(
        tags$i("Note: 2026 data are not complete yet, so 2026 values may be lower or more limited.")
      )
    ),
    
    mainPanel(
      leafletOutput("map", height = 700)
    )
  )
)
  
growth_by_school <- schools_with_neighborhood %>%
  st_drop_geometry() %>%
  group_by(`School Name`, Year) %>%
  summarize(
    yearly_attendees = sum(`Youth Attendees`, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(`School Name`, Year) %>%
  group_by(`School Name`) %>%
  mutate(
    baseline_attendees = first(yearly_attendees),
    pct_change_from_baseline = ifelse(
      baseline_attendees > 0,
      100 * (yearly_attendees - baseline_attendees) / baseline_attendees,
      NA_real_
    )
  ) %>%
  ungroup()


  
  
server <- function(input, output, session) {
  
  filtered_data <- reactive({
    data <- schools_with_neighborhood
    
    if (input$year != "All Years") {
      data <- data %>% filter(Year == input$year)
    }
    
    if (input$school_type != "All School Types") {
      data <- data %>% filter(`School Type` == input$school_type)
    }
    
    data
  })
  
  neighborhood_summary <- reactive({
    data <- filtered_data() %>%
      st_drop_geometry() %>%
      left_join(
        growth_by_school,
        by = c("School Name", "Year")
      )
    
    data %>%
      group_by(community) %>%
      summarize(
        total_attendees = sum(`Youth Attendees`, na.rm = TRUE),
        median_attendees = median(`Youth Attendees`, na.rm = TRUE),
        num_schools = n_distinct(`School Name`),
        top_school = `School Name`[which.max(`Youth Attendees`)],
        top_school_attendees = max(`Youth Attendees`, na.rm = TRUE),
        pct_change_from_baseline = ifelse(
          all(is.na(pct_change_from_baseline)),
          NA_real_,
          mean(pct_change_from_baseline, na.rm = TRUE)
        ),
        .groups = "drop"
      )
  })
  
  map_data <- reactive({
    community_areas %>%
      left_join(neighborhood_summary(), by = "community")
  })
  
  output$map <- renderLeaflet({
    data <- map_data()
    
    metric_values <- data[[input$metric]]
    
    if (input$metric == "pct_change_from_baseline") {
      max_abs <- max(abs(metric_values), na.rm = TRUE)
      
      if (!is.finite(max_abs) || max_abs == 0) {
        max_abs <- 1
      }
      
      pal <- colorNumeric(
        palette = c("red", "white", "green"),
        domain = c(-max_abs, max_abs),
        na.color = "#4d4d4d"
      )
      
    } else {
      pal <- colorNumeric(
        palette = "Blues",
        domain = metric_values,
        na.color = "#4d4d4d"
      )
    }
    
    labels <- sprintf(
      "<strong>%s</strong><br/>
       <b>Total attendees:</b> %s<br/>
       <b>Median attendees per school:</b> %s<br/>
       <b>Number of schools:</b> %s<br/>
       <b>Highest-attendance school:</b> %s<br/>
       <b>Highest school attendance:</b> %s<br/>
       <b>%% change from baseline:</b> %s",
      data$community,
      ifelse(is.na(data$total_attendees), "—", data$total_attendees),
      ifelse(is.na(data$median_attendees), "—", round(data$median_attendees, 1)),
      ifelse(is.na(data$num_schools), "—", data$num_schools),
      ifelse(is.na(data$top_school), "—", data$top_school),
      ifelse(is.na(data$top_school_attendees), "—", data$top_school_attendees),
      ifelse(is.na(data$pct_change_from_baseline), "—",
             paste0(round(data$pct_change_from_baseline, 1), "%"))
    )
    
    map <- leaflet(data) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~ifelse(
          is.na(data[[input$metric]]),
          "#4d4d4d",
          pal(data[[input$metric]])
        ),
        fillOpacity = 0.75,
        color = "black",
        weight = 1,
        opacity = 0.7,
        label = lapply(labels, HTML),
        highlightOptions = highlightOptions(
          weight = 2,
          color = "black",
          fillOpacity = 0.9,
          bringToFront = TRUE
        )
      ) %>%
      addLegend(
        colors = "#4d4d4d",
        labels = "No data",
        title = "Missing data",
        position = "bottomleft"
      )
    
    if (input$metric == "pct_change_from_baseline") {
      map <- map %>%
        addLegend(
          colors = c("red", "white", "green"),
          labels = c("Decrease", "No change", "Increase"),
          title = "% Change from Baseline",
          position = "bottomright"
        )
    } else {
      map <- map %>%
        addLegend(
          pal = pal,
          values = metric_values,
          title = input$metric,
          position = "bottomright"
        )
    }
    
    map
  })
}

shinyApp(ui, server)
  

