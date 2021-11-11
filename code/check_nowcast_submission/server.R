#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

# setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub/code/app_check_submission")
library(shiny)
library(zoo)
# library(reticulate)
source("plot_functions.R")

# unix command to change language
Sys.setlocale(category = "LC_TIME", locale = "en_US.UTF8")

# command that should work cross-platform
# Sys.setlocale(category = "LC_TIME","English")

local <- FALSE

# get truth data:
dat_truth <- NULL
if(local){
  dat_truth <- read.csv("../../data-truth/COVID-19/COVID-19_hospitalizations.csv",
                        colClasses = list("date" = "Date"), stringsAsFactors = FALSE)
}else{
  dat_truth <- read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/data-truth/COVID-19/COVID-19_hospitalizations.csv",
                        colClasses = list("date" = "Date"), stringsAsFactors = FALSE)
}

cols_legend <- c("#699DAF", "#D3D3D3")

# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {
  
  
  dat <- reactiveValues()
  
  # Handle reading in of files:
  observe({
    inFile <- input$file # file upload
    query <- parseQueryString(session$clientData$url_search) # arguments provided in URL
    
    # initialization:
    dat$path <- ""
    dat$forecasts <- NULL
    
    # if path to csv provided in URL:
    if(!is.null(query$file) & is.null(inFile) & input$path == ""){
      dat$path <- query$file
      dat$name <- basename(query$file)
      dat$forecasts <- NULL
      try(dat$forecasts <- read.csv(dat$path, 
                                    colClasses = c(forecast_date = "Date",
                                                   target_end_date = "Date"))) # wrapped in try() to avoid crash if no valid csv
    }
    
    # if file uploaded:
    if(!is.null(inFile) & input$path == ""){
      dat$path <- inFile$datapath
      dat$name <- basename(inFile$name)
      dat$forecasts <- NULL
      try(dat$forecasts <- read.csv(dat$path, 
                                    colClasses = c(forecast_date = "Date",
                                                   target_end_date = "Date"))) # wrapped in try() to avoid crash if no valid csv
    }
    
    # if path to csv provided in input field:
    if(input$path != ""){
      dat$path <- input$path
      dat$name <- basename(input$path)
      dat$forecasts <- NULL
      try(dat$forecasts <- read.csv(dat$path,
                                    colClasses = c(forecast_date = "Date",
                                                   target_end_date = "Date"))) # wrapped in try() to avoid crash if no valid csv
    }
    
    # extact locations:
    if(!is.null(dat$forecasts)){
      locations <- unique(dat$forecasts$location)
      dat$locations <- locations
      
      age_groups <- unique(dat$forecasts$age_group)
      dat$age_groups <- age_groups
    }
    
  })
  
  # observe({
  #   inFile <- input$file1
  # 
  #   if (is.null(inFile)){
  #     dat$forecasts <- NULL
  #   }else{
  #     dat$forecasts <- read_week_ahead(inFile$datapath)
  #     locations <- unique(dat$forecasts$location)
  #     if(!is.null(dat$forecasts$location_name)) names(locations) <- unique(dat$forecasts$location_name)
  #     dat$locations <- locations
  #   }
  # })
  
  # input element to select location:
  output$inp_select_location <- renderUI(
    selectInput("select_location", "Select location:", choices = dat$locations,
                selected = "DE")
  )
  
  # output$inp_select_age_group <- renderUI(
  #   selectInput("select_age_group", "Select age group:", choices = dat$age_groups,
  #               selected = "00+")
  # )
  
  output$plot <- renderPlot({
    if(!is.null(dat$forecasts)){
      
      target_type <- "hosp"
      forecast_date <- dat$forecasts$forecast_date[1]
      print(forecast_date)
      
      # print(dat_truth)
      

      # print(truth_inc)
      
      par(mfrow = c(6, 4))
      
      if(any(grepl("inc", dat$forecasts$target))){
        
        print(unique(dat$forecasts$age_group))
        for(ag in unique(dat$forecasts$age_group)){
          truth_inc <- truth_as_of(dat_truth, age_group = ag,
                                   location = "DE",
                                   date = Sys.Date())
          
          plot_forecast(dat$forecasts, forecast_date = forecast_date,
                        location = "DE", age_group = ag,
                        truth = truth_inc, target_type = paste("inc", target_type),
                        levels_coverage = c(0.5, 0.95),
                        start = as.Date(forecast_date) - 35,
                        end = as.Date(forecast_date) + 28)
          title(paste0("Incident ", target_type, " - ", "DE", " - ", ag))
          legend("topright", legend = c("50%PI", "95% PI"), col = cols_legend, pch = 15, bty = "n")
        }

        print(unique(dat$forecasts$location))
        for(loc in unique(dat$forecasts$location)){
          truth_inc <- truth_as_of(dat_truth, age_group = "00+",
                                   location = loc,
                                   date = Sys.Date())

          plot_forecast(dat$forecasts, forecast_date = forecast_date,
                        location = loc, age_group = "00+",
                        truth = truth_inc, target_type = paste("inc", target_type),
                        levels_coverage = c(0.5, 0.95),
                        start = as.Date(forecast_date) - 35,
                        end = as.Date(forecast_date) + 28)
          title(paste0("Incident ", target_type, " - ", loc, " - ", "00+"))
          legend("topright", legend = c("50%PI", "95% PI"), col = cols_legend, pch = 15, bty = "n")
        }
        
        
      }else{
        plot(NULL, xlim = 0:1, ylim = 0:1, xlab = "", ylab = "", axes = FALSE)
        text(0.5, 0.5, paste("No incident", target_type, "forecasts found."))
      }
      
    }else{
      plot(NULL, xlim = 0:1, ylim = 0:1, xlab = "", ylab = "", axes = FALSE)
      text(0.5, 0.85, "Please select file.")
    }
  })
  
})
