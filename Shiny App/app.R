library(tidyverse)
library(sf)
library(spData)
library(scales)
library(lubridate)
library(shiny)
library(plotly)
library(tmap)
library(RColorBrewer)
library(rmapshaper)
library(ggthemes)
library(stargazer)


products <- list(
  "Checking or savings account" = "Checking or savings account",
  "Credit card" = "Credit card",
  "Credit card or prepaid card" = "Credit card or prepaid card",
  "Credit reporting, credit repair services, or other personal consumer reports" = "Credit reporting, credit repair services, or other personal consumer reports",
  "Debt collection" = "Debt collection",
  "Money transfer, virtual currency, or money service" = "Money transfer, virtual currency, or money service",
  "Mortgage" = "Mortgage",
  "Vehicle loan or lease" = "Vehicle loan or lease")


ui <- fluidPage(
  fluidRow(
    column(
      width = 12,
      tags$h1("CFPB Complaint Explorer"),
      tags$hr()
    )
  ),
  fluidRow(
    mainPanel(
      width = 12, "Since 2017, the Consumer Financial Protection Bureau has released consumer complaints against financial corporations. This is a valuable source of information about the problems Americans face in accessing credit, savings, investments.",
      tags$br(),tags$br(),
      "True, the people who submit complaints often write them in the heat of anger or at moments of maximal stress. And there is certainly no indication from the CFPB data which of the complaints are legally in the right. But the complaints nevertheless reflect a moment, perhaps fleeting or perhaps sustained, when a person's expectations of their financial system are mismatched with the reality; a moment where in some fundamental sense, the financial system  has failed the people it was putatively designed to serve.",
      tags$br(),tags$br(),
      "In short, while the complaints database is a somewhat imperfect reflection of financial inclusion, it's nevertheless useful in conceptualizing our financial system and its discontents. Because the financial system is a product not just of law but also of democratic statecraft, these narratives provide real critiques of how our financial system is failing - even if they have not been subject to legal rulings and are presented without evidence.",
      tags$hr()
    )
  ),
  
  fluidRow(
    column(width = 12, 
           tags$h2("Criteria"))
  ),
  
  fluidRow(
    column(
      width = 6,
      dateRangeInput("dates", "Date range", start = "2017-01-01", end = "2020-01-01"),
      sliderInput("asset_range", "Asset Size", min = 10000000000, max = 5000000000000, value = c(10000000000, 5000000000000))
    ),
    column(
      width = 6,
      checkboxGroupInput("product", "Product Category",
        choices = products,
        selected = products
      )
    )
  ),
    
  fluidRow(
    column(
      width = 12,
      actionButton("submit", "Submit"),
      tags$hr()
    )
  ),
  
  fluidRow(
    column(
      width = 12,
      tags$h2("Map"),
      tmapOutput("map")
    )
  ),
  fluidRow(
    tags$h2("Complaint Type"),
    column(
      width = 12,
      plotlyOutput("type_plot")
    )
  ),
  fluidRow(
    tags$h2("Regression"),
    column(
      width = 6,
      plotlyOutput("regression_plot")
    ),
    column(
      width = 6,
      uiOutput("regression_table")
    )
  ),

  fluidRow(
    tags$h2("Random Complaint"),
    actionButton("get_complaint", "Get a New Complaint"),
    column(
      width = 12,
      uiOutput("random_complaint")
    )
  )
)


server <- function(input, output) {
  timezone <- "America/Chicago"
  unit <- "days"
  window <- st_bbox(c(xmin = -125, xmax = -65, ymin = 25, ymax = 50), crs = st_crs(4326))

  complaints_data <- read_csv("complaints_and_sentiments.csv")

  complaints_shape <- st_read("complaints.shp")%>%
    mutate(ZCTA3 = as.numeric(ZCTA3))
  
  date_range <- reactive({
    interval(ymd(input$dates[1]), ymd(input$dates[2]), tzone = timezone)
  })
  
  complaint_subset_data <- eventReactive(input$submit,{
    complaints_data %>%
      filter(
        product %in% input$product,
        date_received %within% date_range(),
        ((assets >= input$asset_range[1]) & (assets<=input$asset_range[2]))
      )
  })
  
  complaint_subset_shape <- eventReactive(input$submit, {
    grouped_subset <- complaint_subset_data()%>%
      mutate(ZCTA3 = as.numeric(substr(zip_code, 0, 3))) %>%
      group_by(ZCTA3) %>%
      summarize(afinn = mean(afinn, na.rm = TRUE))%>%
      mutate(afinn = if_else(is.na(afinn), 0, afinn))
    
    complaints_shape %>%
      select(-afinn)%>%
      left_join(grouped_subset, by = "ZCTA3")
  })
  
  output$map <- renderTmap({
    #map<-complaint_subset_shape()
    #print(map)
    tm_shape(complaint_subset_shape(), bbox = window) + #, simplify = .05) +
      tm_fill("afinn", title = "AFINN", n = 4, style = "quantile") +
      tm_borders() +
      tm_layout(title = "AFINN Quartile Map", title.position = c("right", "bottom"))
  })

  output$regression_plot <- renderPlotly({
    ggplot(complaint_subset_data(), aes(x = log(assets), y = afinn)) +
      geom_point() +
      geom_smooth(method = lm) +
      ggtitle("AFINN Sentiment Score vs (log) Assets for the Selected Group") +
      theme_calc()
  })

  output$type_plot <- renderPlotly({
    graph_data <- complaint_subset_data() %>%
      group_by(product, sub_product) %>%
      summarize(count = n()) %>%
      ungroup() %>%
      mutate(sub_product = reorder(sub_product, count)) %>%
      filter(!is.na(sub_product))

    ggplot(graph_data, aes(x = sub_product, y = count, fill = product)) +
      geom_bar(stat = "identity") +
      coord_flip() +
      labs(title = "Complaints by Type", x = "") +
      scale_fill_brewer(palette = "Dark2") +
      theme(legend.position = "none")
  })

  output$regression_table <- renderText({
    complaints_lm <- lm(afinn ~ log(assets), data = complaint_subset_data())
    stargazer(complaints_lm, type = "html")
  })
  
  random_complaint <- eventReactive(input$get_complaint, {
    sample_n(complaint_subset_data(), 1)$consumer_complaint_narrative
  })

  output$random_complaint <- renderText({
    sample_n(complaint_subset_data(), 1)$consumer_complaint_narrative
    random_complaint()
  })
}


shinyApp(ui = ui, server = server)