library(tidyverse)
library(sf)
library(spData)
library(scales)
library(lubridate)
library(tmap)
library(RColorBrewer)
library(rmapshaper)

setwd("C:/Users/jcinterrante/Documents/GitHub/final-project-jake-interrante")
processed_data_directory <- "./Processed Data/"
shiny_directory <- "./Shiny App/"
plot_directory <- "./Static Plots/"
shapefile_directory <- "./Shapefiles/"

data <- read_csv(paste0(shiny_directory, "complaints_and_sentiments.csv"))

if (!exists("usa_shape")) {
  usa_shape <- st_read(paste0(shapefile_directory, "US ZCTA 3.shp")) %>%
    mutate(ZCTA3 = as.numeric(ZCTA3))
}

complaints <- data %>%
  mutate(ZCTA3 = as.numeric(substr(zip_code, 0, 3))) %>%
  group_by(ZCTA3) %>%
  summarize(afinn = mean(afinn, na.rm = TRUE))%>%
  mutate(afinn = if_else(is.na(afinn), 0, afinn))

complaints_shape <- usa_shape %>%
  left_join(complaints, by = "ZCTA3")

complaints_shape <- st_set_crs(complaints_shape, 4326)
complaints_shape <- st_transform(complaints_shape, crs = 4326)

window <- st_bbox(c(xmin = -125, xmax = -65, ymin = 25, ymax = 50), crs = st_crs(4326))

map <- tm_shape(complaints_shape, bbox = window, simplify = .05) +
  tm_fill("afinn", title = "AFINN", n = 4, style = "quantile") +
  tm_borders() +
  tm_layout(title = "AFINN Quartile Map", title.position = c("right", "bottom"))

tmap_save(map, paste0(plot_directory, "Complaints Map.png"), height = 10)
st_write(complaints_shape, paste0(shiny_directory, "complaints.shp"), delete_layer = TRUE)
