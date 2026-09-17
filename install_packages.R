# Run this once, right after opening the project in RStudio for the first time.
# Installs every R package both dashboards need.
# How to run: open this file in RStudio, then click "Source" (top-right of
# this pane) or press Cmd+Shift+Enter (Mac) / Ctrl+Shift+Enter (Windows).

install.packages(c(
  "shiny", "sf", "dplyr", "tidyverse", "tigris", "leaflet", "htmltools",
  "bslib", "tidygeocoder", "stringr", "lwgeom", "janitor", "readxl",
  "rsconnect"
))
