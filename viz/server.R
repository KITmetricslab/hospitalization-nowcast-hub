#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(plotly)
library(zoo)
Sys.setlocale(category = "LC_TIME", locale = "en_US.UTF8")

source("functions.R")
# setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub/viz/app")


# get vector of model names:
dat_models <- read.csv("plot_data/list_teams.csv")
models <- dat_models$model

# assign colors:
cols <- c('rgb(31, 119, 180)',
          'rgb(255, 127, 14)',
          'rgb(44, 160, 44)',
          'rgb(214, 39, 40)',
          'rgb(148, 103, 189)',
          'rgb(140, 86, 75)',
          'rgb(227, 119, 194)',
          'rgb(127, 127, 127)',
          'rgb(188, 189, 34)',
          'rgb(23, 190, 207)')
cols <- cols[seq_along(models)]
names(cols) <- models
cols_transp <- gsub("rgb", "rgba", cols, fixed = TRUE)
cols_transp <- gsub(")", ", 0.5)", cols_transp, fixed = TRUE)

# get truth data in format which allows for re-construction of old data versions
dat_truth <- read.csv("../data-truth/COVID-19/COVID-19_hospitalizations.csv",
                      colClasses = c(date = "Date"))
dat_truth <- dat_truth[order(dat_truth$date), ]

# vector of Mondays available in truth data:
mondays <- unique(dat_truth$date[weekdays(dat_truth$date) == "Monday"])

# the most recent date in the truth data:
current_date <- max(dat_truth$date)

# Define server logic:
shinyServer(function(input, output, session) {
    
    ##### UI handling
    
    # # input element to select date:
    # output$select_date <- renderUI(selectInput("select_date",
    #                                            choices = mondays,
    #                                            selected = tail(mondays, 1),
    #                                            label = "Select data version (also by click in plot)")
    # )
    
    # listen to clicks in plot for date selection:
    observe({
        date <- closest_monday(as.Date(event_data("plotly_click", source = "tsplot")$x[1]))
        # only use if actually available and contained in selection options 
        if(length(date) > 0){
            if(date %in% mondays){
                updateSelectInput(session = session, inputId = "select_date", 
                                  selected = as.character(date))
            }
        }
    })
    
    # listen to "skip backward" button
    observe({
        input$skip_backward
        isolate({
            if(!is.null(input$select_date) & input$skip_backward > 0){
                new_date <- as.Date(input$select_date) - 7
                if(new_date %in% dat_truth$date){
                    updateSelectInput(session = session, inputId = "select_date", 
                                      selected = as.character(new_date))
                }
            }
        })
    })
    
    # listen to "skip forward" button
    observe({
        input$skip_forward
        isolate({
            if(!is.null(input$select_date) & input$skip_forward > 0){
                new_date <- as.Date(input$select_date) + 7
                if(new_date %in% dat_truth$date){
                    updateSelectInput(session = session, inputId = "select_date", 
                                      selected = as.character(new_date))
                }
            }
        })
    })
    
    ####### reactive handling of data sets:
    
    # getting in forecast data from selected date:
    forecast_data <- reactiveValues()
    observe({
        # only read in if not already read in:
        if(is.null(forecast_data[[paste0(input$select_date)]])){
            # read in file if available, set NULL otherwise
            file_name <- paste0(input$select_date, "_forecast_data.csv")
            if(file_name %in% list.files("plot_data")){
                temp <- read.csv(paste0("plot_data/", file_name))
            }else{
                temp <- NULL
            }
            if(!is.null(input$select_date)){
                forecast_data[[paste0(input$select_date)]] <- temp
            }
        }
    })
    
    # prepare data for plotting:
    plot_data <- reactiveValues()
    observe({
        # a mapping to determine which trace corresponds to what (needed to replace things below)
        temp <- list("selected_date" = 0,
                     "old_truth" = 1,
                     "current_truth" = 2)
        for(i in seq_along(models)) temp[[models[i]]] <- 2*i + 2 - 1:0
        plot_data$mapping <- temp
        
        # truth data as of selected date:
        old_truth <- truth_as_of(dat_truth = dat_truth, age_group = input$select_age,
                                 date = input$select_date)
        plot_data$old_truth <- data.frame(x = old_truth$date, y = old_truth$value)
        
        # most recent truth data:
        current_truth <- truth_as_of(dat_truth = dat_truth, age_group = input$select_age,
                                     date = current_date)
        plot_data$current_truth <- data.frame(x = current_truth$date, y = current_truth$value)
        
        # y axis limit
        plot_data$ylim <- c(0, 1.1*max(plot_data$current_truth$y, na.rm = TRUE))
        
        # nowcasts / forecasts
        if(!is.null(input$select_date)){
            # run through models:
            for(mod in models){
                # only if not already loaded
                if(!is.null(forecast_data[[input$select_date]])){
                    # subset to required info:
                    subs <- subset(forecast_data[[input$select_date]],
                                   age_group == input$select_age &
                                       model == mod &
                                       location == "DE" &
                                       pathogen == "COVID-19")
                    # prepare list of simple data frames for plotting:
                    points <- subs[, c("target_end_date", "q0.5")]
                    lower <- subs[, c("target_end_date", "q0.025")]
                    upper <- subs[, c("target_end_date", "q0.975")]
                    colnames(points) <- colnames(lower) <- colnames(upper) <- c("x", "y")
                    intervals <- rbind(lower, upper[nrow(upper):1, ])
                    
                    plot_data[[mod]] <- list(points = points, intervals = intervals)
                }else{
                    plot_data[[mod]] <- NULL
                }
            }
        }
        
    })
    
    # initial plot:
    output$tsplot <- renderPlotly({
        
        # only run at start of app, rest is done in updates below
        isolate({
            
            # get truth curves:
            old_truth <- truth_as_of(dat_truth = dat_truth, age_group = input$select_age,
                                     date = max(mondays))
            
            current_truth <- truth_as_of(dat_truth = dat_truth, age_group = input$select_age,
                                         date = current_date)
            
            
            # initlize plot:
            p <- plot_ly(mode = "lines", hovertemplate = '%{y}', source = "tsplot") %>% # last argument ensures labels are completely visible
                layout(yaxis = list(title = '7-day hospitalization incidence'), # axis + legend settings
                       xaxis = list(title = "time"),
                       hovermode = "x unified") %>%
                add_polygons(x = c(min(dat_truth$date), as.Date(input$select_date), # grey shade to separate past and future
                                       as.Date(input$select_date), min(dat_truth$date)),
                             y = rep(plot_data$ylim, each = 2),
                             fillcolor = "rgba(0.9, 0.9, 0.9, 0.5)",
                             line = list(width = 0),
                             showlegend = FALSE) %>%
                # add_lines(x = rep(current_date, 2), # vertical line for selected date
                #           y = 0:1, 
                #           line = list(color = 'rgb(0.5, 0.5, 0.5)', dash = "dot"),
                #           showlegend = FALSE) %>%
                # layout(xaxis = list(rangeslider = list(type = "date", thickness = 0.08))) %>%
                add_lines(x = old_truth$date, # trace for truth data as of selected date
                          y = old_truth$value,
                          name = paste("data as of", current_date),
                          line = list(color = 'rgb(0.5, 0.5, 0.5)')) %>%
                add_lines(x = current_truth$date, # trace for most current truth data
                          y = current_truth$value,
                          name = paste("data as of", current_date),
                          line = list(color = 'rgb(0, 0, 0)')) %>%
                event_register(event = "plotly_click") # enable clicking to select date
            
            # add nowcasts: run through models
            for(mod in models){
                if(!is.null(plot_data[[mod]])){
                    # if nowcast available: prepare plot data
                    x <- plot_data[[mod]]$points$x
                    y <- plot_data[[mod]]$points$y
                    s <- 5
                    x_intervals <- plot_data[[mod]]$intervals$x
                    y_intervals <- plot_data[[mod]]$intervals$y
                }else{
                    # if no nowcast available: "hide" the respective trace
                    x <- as.Date("2021-04-12")
                    y <- 0
                    s <- 0.001
                    x_intervals <- as.Date("2021-04-12")
                    y_intervals <- 0
                }
                # add shaded areas for uncertainty:
                p <- p%>% add_polygons(x = x_intervals, y = y_intervals,
                                       line = list(width = 0),
                                       fillcolor = cols_transp[mod],
                                       legendgroup = mod, showlegend = FALSE)
                # add point nowcasts:
                p <- p %>% add_trace(x = x, y = y,
                                     name = mod,
                                     type = "scatter",
                                     mode = "lines+markers",
                                     line = list(dash = "dot", 
                                                 width = 1, 
                                                 color = cols[mod]),
                                     marker = list(symbol = "circle",
                                                   size = s),
                                     legendgroup = mod)
            }
            p
        })
    })
    
    # register proxy:
    myPlotProxy <- plotlyProxy("tsplot", session)
    
    # update shaded area to mark selected date:
    observe({
        # plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(rep(as.Date(input$select_date), 2)),
        #                                                y = list(plot_data$ylim)),
        #                   list(0))
        plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(c(min(dat_truth$date), as.Date(input$select_date),
                                                             as.Date(input$select_date), min(dat_truth$date))),
                                                       y = list(rep(plot_data$ylim, each = 2))),
                          list(0))
    })
    
    # updating most recent truth:
    observe({
        plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(plot_data$current_truth$x),
                                                       y = list(plot_data$current_truth$y)),
                          list(plot_data$mapping$current_truth))
    })
    
    # update truth as of selected date:
    observe({
        plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(plot_data$old_truth$x),
                                                       y = list(plot_data$old_truth$y),
                                                       name = paste("data as of", input$select_date)),
                          list(plot_data$mapping$old_truth))
    })
    
    # update nowcasts:
    observe({
        for(mod in models){
            if(!is.null(plot_data[[mod]])){
                # if nowcast available: prepare plot data
                x <- plot_data[[mod]]$points$x
                y <- plot_data[[mod]]$points$y
                s <- 5
                x_intervals <- plot_data[[mod]]$intervals$x
                y_intervals <- plot_data[[mod]]$intervals$y
            }else{
                # if no nowcast available: "hide" the respective trace
                x <- as.Date("2021-04-12")
                y <- 1
                s <- 0.001
                x_intervals <- as.Date("2021-04-12")
                y_intervals <- 0
            }
            # shaded area for uncertainty:
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(x = list(x_intervals),
                                   y = list(y_intervals)),
                              list(plot_data$mapping[[mod]][1]))
            # point nowcasts:
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(x = list(x),
                                   y = list(y), 
                                   marker = list(size = s)),
                              list(plot_data$mapping[[mod]][2]))
        }
    })
    
})
