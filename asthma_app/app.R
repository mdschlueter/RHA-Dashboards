library(shiny)
library(sf)
library(dplyr)
library(tidyverse)
library(leaflet)
library(htmltools)
library(bslib)


ui <- page_fillable(
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2C3E50",
    secondary = "#18BC9C"
  ),
  
  # Add custom CSS for better styling
  tags$head(
    tags$style(HTML("
      .navbar-brand {
        font-size: 24px !important;
        font-weight: bold;
      }
      .nav-tabs .nav-link {
        color: #2C3E50;
        font-weight: 500;
      }
      .nav-tabs .nav-link.active {
        background-color: #18BC9C !important;
        color: white !important;
        border-color: #18BC9C !important;
      }
      .header-panel {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 20px;
        margin-bottom: 20px;
        border-radius: 10px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      }
      .header-panel h1 {
        margin: 0;
        font-size: 32px;
      }
      .header-panel p {
        margin-top: 10px;
        font-size: 16px;
        opacity: 0.95;
      }
    "))
  ),
  
  # Header Panel
  div(class = "header-panel",
      h1("RHA - Asthma Resource Impact Maps"),
      p("Interactive visualization of student return-to-school rates across Illinois")
  ),
  
  # Tab Navigation with Maps
  navset_tab(
    id = "maptabs",
    
    nav_panel(
      "Chicago Neighborhoods",
      card(
        card_header("Student Return Rates by Chicago Neighborhood"),
        leafletOutput("chicagoMap", height = "700px")
      )
    ),
    
    nav_panel(
      "Illinois Counties",
      card(
        card_header("Student Return Rates by Illinois County"),
        leafletOutput("countyMap", height = "700px")
      )
    ),
    
    nav_panel(
      "Congressional Districts",
      card(
        card_header("Student Return Rates by Congressional District"),
        leafletOutput("congressMap", height = "700px")
      )
    ),
    
    nav_panel(
      "Cook County House",
      card(
        card_header("Student Return Rates by Illinois House District (Cook County)"),
        leafletOutput("houseMap", height = "700px")
      )
    ),
    
    nav_panel(
      "Cook County Senate",
      card(
        card_header("Student Return Rates by Illinois Senate District (Cook County)"),
        leafletOutput("senateMap", height = "700px")
      )
    ),
    
    nav_panel(
      "About",
      card(
        card_header("About This Dashboard"),
        card_body(
          h4("Overview"),
          p("This dashboard visualizes the impact of asthma resources on student return-to-school rates 
            across various political and administrative boundaries in Illinois."),
          br(),
          h4("Data Source"),
          p("Data includes participating schools in the asthma resource program, tracking incidents 
            and student return rates after receiving asthma-related support."),
          br(),
          h4("Return Rate Calculation"),
          p("Rate of return is calculated as the percentage of students who returned to class after 
            utilizing asthma resources compared to the total number of asthma incidents."),
          br(),
          h4("Color Coding"),
          tags$ul(
            tags$li(tags$span(style="color: green; font-weight: bold;", "Green:"), " High return rates (good outcomes)"),
            tags$li(tags$span(style="color: yellow; font-weight: bold;", "Yellow:"), " Moderate return rates"),
            tags$li(tags$span(style="color: red; font-weight: bold;", "Red:"), " Low return rates (areas needing attention)"),
            tags$li(tags$span(style="color: gray; font-weight: bold;", "Gray:"), " No data available")
          ),
          br(),
          h4("Interactive Features"),
          p("Hover over any region to see detailed statistics including total incidents, 
            students returned, and the calculated return rate percentage.")
        )
      )
    )
  )
)

# ===============================
# Server (Error validation and loading)
# ===============================

# Helper function to use for all map loading logic
load_map_data <- function(file_path, display_name) {
  withProgress(message = sprintf('Loading %s map...', display_name), {
    
    # 1. Check file existence
    if (!file.exists(file_path)) {
      stop(sprintf("Error: %s file not found. Please run 'preprocess_data.R' first or check the file path.", file_path))
    }
    
    # 2. Attempt to read file and catch errors
    data <- tryCatch({
      readRDS(file_path)
    }, error = function(e) {
      stop(sprintf("Error: Problem occurred while reading %s file: %s", file_path, e$message))
    })
    
    # 3. Validate data (sf object)
    if (!inherits(data, "sf")) {
      stop(sprintf("Error: Loaded %s data is not a valid map object (sf). Please check the output of 'preprocess_data.R'.", file_path))
    }
    
    return(data)
  })
}


server <- function(input, output, session) {
  
  # --- 1. Map 1: Chicago Neighborhoods ---
  chicago_map_data_r <- eventReactive(input$maptabs == "Chicago Neighborhoods", {
    load_map_data("chicago_map_data.rds", "Chicago Neighborhoods")
  })
  
  output$chicagoMap <- renderLeaflet({
    chicago_map_data <- chicago_map_data_r()
    
    # Validate required columns exist
    validate(
      need(!is.null(chicago_map_data$return_rate), "Chicago map data error: 'return_rate' column is missing. (Check preprocess_data.R)"),
      need(!is.null(chicago_map_data$total_incidents), "Chicago map data error: 'total_incidents' column is missing. (Check preprocess_data.R)"),
      need(!is.null(chicago_map_data$total_returned), "Chicago map data error: 'total_returned' column is missing. (Check preprocess_data.R)"),
      need(!is.null(chicago_map_data$community), "Chicago map data error: 'community' column is missing. (Check preprocess_data.R)")
    )
    
    color_pallete <- colorNumeric(palette = "RdYlGn", 
                                  domain = chicago_map_data$return_rate,
                                  na.color = "#D3D3D3")
    
    leaflet(chicago_map_data) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~color_pallete(return_rate),
        fillOpacity = 0.7,
        color = "#333",
        weight = 1,
        highlightOptions = highlightOptions(weight = 3, color = "#666", 
                                            fillOpacity = 1, bringToFront = TRUE),
        label = ~lapply(
          ifelse(is.na(total_incidents),
                 sprintf("<strong>%s</strong><br/>No schools with incidents", community),
                 sprintf("<strong>%s</strong><br/><b>Total Incidents:</b> %s<br/><b>Students Returned:</b> %s<br/><b>Return Rate:</b> %s%%",
                         community, total_incidents, total_returned, sprintf("%.1f", return_rate))
          ),
          htmltools::HTML
        ),
        labelOptions = labelOptions(textsize = "12px", direction = "auto")
      ) %>%
      addLegend(pal = color_pallete, values = ~return_rate[!is.na(return_rate)], 
                title = "Return-to-Class<br/>Rate (%)", position = "bottomright", na.label = "No Data")
  })
  
  
  # --- 2. Map 2: Illinois Counties ---
  county_map_data_r <- eventReactive(input$maptabs == "Illinois Counties", {
    load_map_data("county_map_data.rds", "Counties")
  })
  
  output$countyMap <- renderLeaflet({
    il_map <- county_map_data_r()
    
    # Validate required columns exist
    validate(
      need(!is.null(il_map$return_rate), "County map data error: 'return_rate' column is missing. (Check preprocess_data.R)"),
      need(!is.null(il_map$n_incidents), "County map data error: 'n_incidents' column is missing. (Check preprocess_data.R)"),
      need(!is.null(il_map$n_disp_return), "County map data error: 'n_disp_return' column is missing. (Check preprocess_data.R)"),
      need(!is.null(il_map$NAME), "County map data error: 'NAME' column is missing. (Check preprocess_data.R)")
    )
    
    pal_rr <- colorNumeric(palette = "RdYlGn", 
                           domain = il_map$return_rate,
                           na.color = "#D3D3D3") 
    
    leaflet(il_map) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~pal_rr(return_rate),
        fillOpacity = 0.7,
        color = "#333",
        weight = 1,
        highlightOptions = highlightOptions(weight = 3, color = "#666", 
                                            fillOpacity = 1, bringToFront = TRUE),
        label = ~lapply(ifelse(is.na(return_rate),
                               sprintf("<strong>%s County</strong><br/>No data", NAME),
                               sprintf("<strong>%s County</strong><br/><b>Total Incidents:</b> %s<br/><b>Students Returned:</b> %s<br/><b>Return Rate:</b> %s%%",
                                       NAME, format(n_incidents, big.mark=","), 
                                       format(n_disp_return, big.mark=","), 
                                       sprintf("%.1f", return_rate))),
                        htmltools::HTML)
      ) %>%
      addLegend(pal = pal_rr, values = ~return_rate[!is.na(return_rate)], 
                title = "Return-to-Class<br/>Rate (%)", position = "bottomright", na.label = "No Data")
  })
  
  
  # --- 3. Map 3: Congressional Districts ---
  congress_map_data_r <- eventReactive(input$maptabs == "Congressional Districts", {
    load_map_data("congress_map_data.rds", "Congressional Districts")
  })
  
  output$congressMap <- renderLeaflet({
    il_congress_map <- congress_map_data_r()
    
    # Validate required columns exist
    validate(
      need(!is.null(il_congress_map$return_rate), "Congressional district map data error: 'return_rate' column is missing. (Check preprocess_data.R)"),
      need(!is.null(il_congress_map$n_incidents), "Congressional district map data error: 'n_incidents' column is missing. (Check preprocess_data.R)"),
      need(!is.null(il_congress_map$n_disp_return), "Congressional district map data error: 'n_disp_return' column is missing. (Check preprocess_data.R)"),
      need(!is.null(il_congress_map$district_num), "Congressional district map data error: 'district_num' column is missing. (Check preprocess_data.R)")
    )
    
    pal_congress <- colorNumeric(palette = "RdYlGn", 
                                 domain = il_congress_map$return_rate,
                                 na.color = "#D3D3D3") 
    
    leaflet(il_congress_map) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~pal_congress(return_rate),
        fillOpacity = 0.7,
        color = "#333",
        weight = 1,
        highlightOptions = highlightOptions(
          weight = 3, 
          color = "#666", 
          fillOpacity = 1, 
          bringToFront = TRUE
        ),
        label = ~lapply(
          ifelse(is.na(return_rate),
                 sprintf("<strong>Congressional District %s</strong><br/>No data", district_num),
                 sprintf("<strong>Congressional District %s</strong><br/><b>Total Incidents:</b> %s<br/><b>Students Returned:</b> %s<br/><b>Return Rate:</b> %s%%",
                         district_num, 
                         format(n_incidents, big.mark=","), 
                         format(n_disp_return, big.mark=","), 
                         sprintf("%.1f", return_rate))
          ),
          htmltools::HTML
        ),
        labelOptions = labelOptions(textsize = "12px", direction = "auto")
      ) %>%
      addLegend(
        pal = pal_congress, 
        values = ~return_rate[!is.na(return_rate)], 
        title = "Return-to-Class<br/>Rate (%)", 
        position = "bottomright", 
        na.label = "No Data"
      )
  })
  
  
  # --- 4. Map 4: House Districts ---
  house_map_data_r <- eventReactive(input$maptabs == "Cook County House", {
    load_map_data("house_map_data.rds", "House Districts")
  })
  
  output$houseMap <- renderLeaflet({
    cook_house_map <- house_map_data_r()
    
    # Validate required columns exist
    validate(
      need(!is.null(cook_house_map$return_rate), "House district map data error: 'return_rate' column is missing. (Check preprocess_data.R)"),
      need(!is.null(cook_house_map$n_incidents), "House district map data error: 'n_incidents' column is missing. (Check preprocess_data.R)"),
      need(!is.null(cook_house_map$n_disp_return), "House district map data error: 'n_disp_return' column is missing. (Check preprocess_data.R)"),
      need(!is.null(cook_house_map$district), "House district map data error: 'district' column is missing. (Check preprocess_data.R)")
    )
    
    pal_rr <- colorNumeric(palette = "RdYlGn", 
                           domain = cook_house_map$return_rate,
                           na.color = "#D3D3D3") 
    
    leaflet(cook_house_map) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~pal_rr(return_rate),
        fillOpacity = 0.7,
        color = "#333", weight = 1,
        highlightOptions = highlightOptions(weight = 3, color = "#666", 
                                            fillOpacity = 1, bringToFront = TRUE),
        label = ~lapply(
          ifelse(
            is.na(return_rate),
            sprintf("<strong>House District %s</strong><br/>No data", district),
            sprintf(
              "<strong>House District %s</strong><br/>
              <b>Total Incidents:</b> %s<br/>
              <b>Students Returned:</b> %s<br/>
              <b>Return Rate:</b> %s%%",
              district,
              format(n_incidents, big.mark = ","),
              format(n_disp_return, big.mark = ","),
              sprintf("%.1f", return_rate)
            )
          ),
          htmltools::HTML
        )
      ) %>%
      addLegend(
        pal = pal_rr,
        values = ~return_rate[!is.na(return_rate)],
        title = "Return-to-Class<br/>Rate (%)",
        position = "bottomright",
        na.label = "No Data"
      )
  })
  
  
  # --- 5. Map 5: Senate Districts ---
  senate_map_data_r <- eventReactive(input$maptabs == "Cook County Senate", {
    load_map_data("senate_map_data.rds", "Senate Districts")
  })
  
  output$senateMap <- renderLeaflet({
    cook_senate_map <- senate_map_data_r()
    
    # Validate required columns exist
    validate(
      need(!is.null(cook_senate_map$return_rate), "Senate district map data error: 'return_rate' column is missing. (Check preprocess_data.R)"),
      need(!is.null(cook_senate_map$n_incidents), "Senate district map data error: 'n_incidents' column is missing. (Check preprocess_data.R)"),
      need(!is.null(cook_senate_map$n_disp_return), "Senate district map data error: 'n_disp_return' column is missing. (Check preprocess_data.R)"),
      need(!is.null(cook_senate_map$district), "Senate district map data error: 'district' column is missing. (Check preprocess_data.R)")
    )
    
    pal_rr <- colorNumeric(palette = "RdYlGn", 
                           domain = cook_senate_map$return_rate,
                           na.color = "#D3D3D3") 
    
    leaflet(cook_senate_map) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~pal_rr(return_rate),
        fillOpacity = 0.7,
        color = "#333", weight = 1,
        highlightOptions = highlightOptions(weight = 3, color = "#666", 
                                            fillOpacity = 1, bringToFront = TRUE),
        label = ~lapply(
          ifelse(
            is.na(return_rate),
            sprintf("<strong>Senate District %s</strong><br/>No data", district),
            sprintf(
              "<strong>Senate District %s</strong><br/>
              <b>Total Incidents:</b> %s<br/>
              <b>Students Returned:</b> %s<br/>
              <b>Return Rate:</b> %s%%",
              district,
              format(n_incidents, big.mark = ","),
              format(n_disp_return, big.mark = ","),
              sprintf("%.1f", return_rate)
            )
          ),
          htmltools::HTML
        )
      ) %>%
      addLegend(
        pal = pal_rr,
        values = ~return_rate[!is.na(return_rate)],
        title = "Return-to-Class<br/>Rate (%)",
        position = "bottomright",
        na.label = "No Data"
      )
  })
  
}

# ===============================
# Run the App
# ===============================

shinyApp(ui = ui, server = server)