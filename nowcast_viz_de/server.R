#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

local <- TRUE

library(shiny)
library(plotly)
library(zoo)
library(httr)

Sys.setlocale(category = "LC_TIME", locale = "en_US.UTF8")

source("functions.R")
# setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub/nowcast_viz_de")

# check which forecast files are available:
if(local){
    forecast_files <- list.files("plot_data")
    # get vector of model names:
    dat_models <- read.csv("plot_data/list_teams.csv")
    # get population sizes:
    pop <- read.csv("plot_data/population_sizes.csv")
    # vector of Mondays available in truth data:
    available_dates <- sort(as.Date(read.csv("plot_data/available_dates.csv")$date))
}else{
    req <- GET("https://api.github.com/repos/KITmetricslab/hospitalization-nowcast-hub/git/trees/main?recursive=1")
    stop_for_status(req)
    filelist <- unlist(lapply(content(req)$tree, "[", "path"), use.names = F)
    forecast_files <- grep("forecast_data.csv", filelist, value = TRUE, fixed = TRUE)
    forecast_files <- basename(grep("nowcast_viz_de/plot_data/20", forecast_files, value = TRUE, fixed = TRUE))
    # get vector of model names:
    dat_models <- read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/list_teams.csv")
    # get population sizes:
    pop <- read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/population_sizes.csv")
    # vector of Mondays available in truth data:
    available_dates <- sort(as.Date(read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/available_dates.csv")$date))
}
models <- sort(dat_models$model)


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
path_truth <- ifelse(local,
                     "../data-truth/COVID-19/COVID-19_hospitalizations.csv",
                     "https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/data-truth/COVID-19/COVID-19_hospitalizations.csv")
dat_truth <- read.csv(path_truth,
                      colClasses = c(date = "Date"))
dat_truth <- dat_truth[order(dat_truth$date), ]

# the most recent date in the truth data:
current_date <- max(dat_truth$date)

# Define server logic:
shinyServer(function(input, output, session) {
    
    observe_helpers(withMathJax = TRUE)
    
    ##### UI handling
    
    # # input element to select date:
    # output$select_date <- renderUI(selectInput("select_date",
    #                                            choices = mondays,
    #                                            selected = tail(mondays, 1),
    #                                            label = "Select data version (also by click in plot)")
    # )
    
    # add back in if date selection by click desired
    # # listen to clicks in plot for date selection:
    # observe({
    #     date <- as.Date(event_data("plotly_click", source = "tsplot")$x[1])
    #     # only use if actually available and contained in selection options 
    #     if(length(date) > 0){
    #         if(date %in% available_dates){
    #             updateSelectInput(session = session, inputId = "select_date", 
    #                               selected = as.character(date))
    #         }
    #     }
    # })
    
    # set age_group to "00+" if state != "DE"
    observe({
        if(input$select_stratification == "state"){
            updateSelectInput(session = session, inputId = "select_age", 
                              selected = "00+")
        }
    })
    
    # set state to "DE" if age_group != "00+"
    observe({
        if(input$select_stratification == "age"){
            updateSelectInput(session = session, inputId = "select_state", 
                              selected = "DE")
        }
    })
    
    # listen to "skip backward" button
    observe({
        input$skip_backward
        isolate({
            print(input$select_date)
            if(!is.null(input$select_date) & length(input$select_date) > 0 & input$skip_backward > 0){
                new_date <- as.Date(input$select_date) - 1
                if(new_date %in% available_dates){
                    updateSelectInput(session = session, inputId = "select_date",
                                      selected = new_date)
                }
            }
        })
    })
    
    # listen to "skip forward" button
    observe({
        input$skip_forward
        isolate({
            if(!is.null(input$select_date) & length(input$select_date) > 0 & input$skip_forward > 0){
                new_date <- as.Date(input$select_date) + 1
                if(new_date %in% available_dates){
                    updateSelectInput(session = session, inputId = "select_date",
                                      selected = new_date)
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
            dats <- as.character(as.Date(input$select_date) + (-2:2))
            for (dat in dats) {
                # read in file if available, set NULL otherwise
                file_name <- paste0(dat, "_forecast_data.csv")
                if(file_name %in% forecast_files){
                    if(local){
                        path_forecast_files <- "plot_data/"
                    }else{
                        path_forecast_files <- "https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/"
                    }
                    temp <- read.csv(paste0(path_forecast_files, file_name), 
                                     colClasses = c("retrospective" = "logical",
                                                    "forecast_date" = "Date",
                                                    "target_end_date" = "Date"))
                    temp$q0.5[is.na(temp$q0.5)] <- temp$mean[is.na(temp$q0.5)]
                }else{
                    temp <- NULL
                }
                if(!is.null(input$select_date)){
                    forecast_data[[dat]] <- temp
                }
            }
        }
    })
    
    # prepare data for plotting:
    plot_data <- reactiveValues()
    observe({
        # scaling factor for population:
        pop_factor <-
            if(input$select_scale == "per 100.000"){
                100000/subset(pop, location == input$select_state & age_group == input$select_age)$population
            }else{
                1
            }
        
        max_vals <- numeric(length(models))
        names(max_vals) <- models

        # a mapping to determine which trace corresponds to what (needed to replace things below)
        temp <- list("selected_date" = 1, # 0 is grey area
                     "old_truth" = 2,
                     "current_truth" = 3,
                     "truth_by_reporting" = 4,
                     "truth_frozen" = 5)
        for(i in seq_along(models)) temp[[models[i]]] <- 2*i + 5 - 1:0
        plot_data$mapping <- temp
        
        # truth data as of selected date:
        old_truth <- truth_as_of(dat_truth = dat_truth, 
                                 age_group = input$select_age,
                                 location = input$select_state,
                                 date = input$select_date)
        # reverting necessary to avoid bug with mouseovers (don't know why)
        plot_data$old_truth <- data.frame(x = rev(old_truth$date), y = rev(round(old_truth$value*pop_factor, 2)))
        
        # most recent truth data:
        current_truth <- truth_as_of(dat_truth = dat_truth, 
                                     age_group = input$select_age,
                                     location = input$select_state,
                                     date = current_date)
        # reverting necessary to avoid bug with mouseovers (don't know why)
        plot_data$current_truth <- data.frame(x = rev(current_truth$date), y = rev(round(current_truth$value*pop_factor, 2)))
        
        # truth by reporting:
        if(input$show_truth_by_reporting){
            truth_by_rep <- truth_by_reporting(dat_truth = dat_truth,
                                               age_group = input$select_age,
                                               location = input$select_state)
        }else{
            truth_by_rep <- data.frame(date = min(dat_truth$date),
                                       value = 0)
        }
        plot_data$truth_by_reporting <- data.frame(x = truth_by_rep$date, y = round(truth_by_rep$value*pop_factor, 2))
        
        # frozen truth:
        if(input$show_truth_frozen){
            truth_fr <- truth_frozen(dat_truth = dat_truth,
                                     age_group = input$select_age,
                                     location = input$select_state)
        }else{
            truth_fr <- data.frame(date = min(dat_truth$date),
                                       value = 0)
        }
        plot_data$truth_frozen <- data.frame(x = truth_fr$date, y = round(truth_fr$value*pop_factor, 2))
        
        # nowcasts / forecasts
        if(!is.null(input$select_date)){
            # run through models:
            for(mod in models){
                # only if not already loaded
                if(!is.null(forecast_data[[as.character(input$select_date)]])){
                    # subset to required info:
                    subs <- subset(forecast_data[[as.character(input$select_date)]],
                                   age_group == input$select_age &
                                       model == mod &
                                       location == input$select_state &
                                       pathogen == "COVID-19")
                    
                    # remove retrospective if requested:
                    if(!input$show_retrospective_nowcasts){
                        subs <- subset(subs, !retrospective)
                    }
                    
                    # remove last two days if requested:
                    if(!input$show_last_two_days){
                        subs <- subs[subs$target_end_date <= (subs$forecast_date - 2), ]
                        # subs[subs$target_end_date >= (subs$forecast_date - 1), c("q0.5")] <- NA
                    }
                    
                    
                    if(nrow(subs) > 0){
                        # prepare list of simple data frames for plotting:
                        points <- subs[, c("target_end_date", "q0.5")]
                        if(input$select_interval == "none"){
                            lower <- subs[, c("target_end_date", "q0.5")]
                            upper <- subs[, c("target_end_date", "q0.5")]
                        }
                        if(input$select_interval == "50%"){
                            lower <- subs[, c("target_end_date", "q0.25")]
                            upper <- subs[, c("target_end_date", "q0.75")]
                        }
                        if(input$select_interval == "95%"){
                            lower <- subs[, c("target_end_date", "q0.025")]
                            upper <- subs[, c("target_end_date", "q0.975")]
                        }
                        
                        colnames(points) <- colnames(lower) <- colnames(upper) <- c("x", "y")
                        
                        # take population factor into account (switch between absolute numbers and per 100,000)
                        #print(input$select_scale == "absolute counts")
                        points$y <- round(points$y*pop_factor, ifelse(input$select_scale == "absolute counts", 0, 2))
                        lower$y <- round(lower$y*pop_factor, ifelse(input$select_scale == "absolute counts", 0, 2))
                        upper$y <- round(upper$y*pop_factor, ifelse(input$select_scale == "absolute counts", 0, 2))
                        
                        # pool lower and upper into intervals:
                        intervals <- rbind(lower, upper[nrow(upper):1, ])
                        
                        
                        # add labels:
                        if(input$select_interval %in% c("50%", "95%")){
                            points$text_interval <- paste0(" (", lower$y, " - ", upper$y, ")")
                        }else{
                            points$text_interval <- ""
                        }
                        
                        
                        # reverting necessary to avoid bug with mouseovers (don't know why)
                        points$x <- rev(points$x)
                        points$y <- rev(points$y)
                        intervals$x <- rev(intervals$x)
                        intervals$y <- rev(intervals$y)
                        points$text_interval <- rev(points$text_interval)
                        
                        
                        
                        # store:
                        plot_data[[mod]] <- list(points = points, intervals = intervals)
                        
                        # add largest value to max_vals to compute ylim later:
                        max_vals[mod] <- max(c(1, intervals$y), na.rm = TRUE)
                    }else{
                        plot_data[[mod]] <- NULL
                        max_vals[mod] <- 1
                    }
                }else{
                    plot_data[[mod]] <- NULL
                }
            }
            # y axis limit
            plot_data$ylim <- c(0, 1.1*max(c(plot_data$current_truth$y, max_vals), na.rm = TRUE))
        }
        
    })
    
    # initial plot:
    output$tsplot <- renderPlotly({
        
        # only run at start of app, rest is done in updates below
        isolate({
            
            # compute default zoom (for some reason on millisecond scale):
            min_Date <- Sys.Date() - 45
            min_Date_ms <- as.numeric(difftime(min_Date, "1970-01-01")) * (24*60*60*1000)
            max_Date <- Sys.Date() + 5
            max_Date_ms <- as.numeric(difftime(max_Date, "1970-01-01")) * (24*60*60*1000)
            
            # initialize plot:
            p <- plot_ly(mode = "lines", hovertemplate = '%{y}', source = "tsplot") %>% # last argument ensures labels are completely visible
                layout(yaxis = list(title = '7-Tage Hospitalisierungsinzidenz (absolut)'), # axis + legend settings
                       xaxis = list(title = "Meldedatum", range = c(min_Date_ms, max_Date_ms)),
                       hovermode = "x unified",
                       hoverdistance = 5) %>%
                add_polygons(x = c(min(dat_truth$date), as.Date(input$select_date), # grey shade to separate past and future
                                   as.Date(input$select_date), min(dat_truth$date)),
                             y = rep(plot_data$ylim, each = 2),
                             hoverinfo = "none", hoveron = "points",
                             inherit = FALSE,
                             fillcolor = "rgba(0.9, 0.9, 0.9, 0.5)",
                             line = list(width = 0),
                             showlegend = FALSE) %>%
                add_lines(x = rep(input$select_date, 2), # vertical line for selected date
                          y = plot_data$ylim,
                          name = "current date",
                          hovertemplate = "%{x}",
                          line = list(color = 'rgb(0.5, 0.5, 0.5)', dash = "dot"),
                          showlegend = FALSE) %>%
                # layout(xaxis = list(rangeslider = list(type = "date", thickness = 0.08))) %>%
                add_lines(x = plot_data$old_truth$x, # trace for truth data as of selected date
                          y = plot_data$old_truth$y,
                          name = paste("Datenstand", current_date),
                          hovertemplate = "<b>%{y}</b>",
                          line = list(color = 'rgb(0.5, 0.5, 0.5)')) %>%
                add_lines(x = plot_data$current_truth$x, # trace for most current truth data
                          y = plot_data$current_truth$y,
                          name = paste("Datenstand", current_date),
                          hovertemplate = "<b>%{y}</b>",
                          line = list(color = 'rgb(0, 0, 0)')) %>%
                add_lines(x = plot_data$truth_by_reporting$x, # trace for data by reporting date
                          y = plot_data$truth_by_reporting$y,
                          name = paste("Zeitreihe nach Erscheinen\n in RKI Daten"),
                          line = list(color = 'rgb(0, 0, 0)', dash = "dash"),
                          showlegend = input$show_truth_by_reporting) %>%
                add_lines(x = plot_data$truth_frozen$x, # trace for data by reporting date
                          y = plot_data$truth_frozen$y,
                          name = paste("Zeitreihe eingefrorener Werte"),
                          line = list(color = 'rgb(0, 0, 0)', dash = "dot"),
                          showlegend = input$show_truth_frozen) %>%
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
                    text_interval <- plot_data[[mod]]$points$text_interval
                }else{
                    # if no nowcast available: "hide" the respective trace
                    x <- min(dat_truth$date)
                    y <- 0
                    s <- 0.001
                    x_intervals <- min(dat_truth$date)
                    y_intervals <- 0
                    labels <- ""
                }
                # add shaded areas for uncertainty:
                p <- p%>% add_polygons(x = x_intervals, y = y_intervals,
                                       line = list(width = 0),
                                       fillcolor = cols_transp[mod],
                                       legendgroup = mod,
                                       hoverinfo = "none",
                                       showlegend = FALSE)
                # add point nowcasts:
                p <- p %>% add_trace(x = x, y = y,
                                     name = mod,
                                     type = "scatter",
                                     mode = "lines",
                                     line = list(dash = "dot", 
                                                 width = 2, 
                                                 color = cols[mod]),
                                     text = text_interval,
                                     hovertemplate = "<b>%{y}</b> %{text}",
                                     legendgroup = mod)
            }
            p
        })
    })
    
    # register proxy:
    myPlotProxy <- plotlyProxy("tsplot", session)
    
    # update shaded area to mark selected date:
    observe({
        plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(rep(as.Date(input$select_date), 2)),
                                                       y = list(plot_data$ylim)),
                          list(1))
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
                                                       name = ifelse(input$select_language == "DE",
                                                                     paste("Datenstand", input$select_date),
                                                                     paste("data as of", input$select_date))),
                          list(plot_data$mapping$old_truth))
    })
    
    # update truth by reporting date:
    observe({
        plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(plot_data$truth_by_reporting$x),
                                                       y = list(plot_data$truth_by_reporting$y)),
                          list(plot_data$mapping$truth_by_reporting))
    })
    
    # update frozen truth:
    observe({
        plotlyProxyInvoke(myPlotProxy, "restyle", list(x = list(plot_data$truth_frozen$x),
                                                       y = list(plot_data$truth_frozen$y)),
                          list(plot_data$mapping$truth_frozen))
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
                text_interval <- plot_data[[mod]]$points$text_interval
            }else{
                # if no nowcast available: "hide" the respective trace
                x <- min(dat_truth$date)
                y <- 1
                s <- 0.001
                x_intervals <- min(dat_truth$date)
                y_intervals <- 0
                text_interval <- ""
            }
            # shaded area for uncertainty:
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(x = list(x_intervals),
                                   y = list(y_intervals),
                                   hoverinfo = "none"),
                              list(plot_data$mapping[[mod]][1]))
            # point nowcasts:
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(x = list(x),
                                   y = list(y),
                                   text = list(text_interval)),
                              list(plot_data$mapping[[mod]][2]))
        }
        
        # update time series by reporting date:
        observe({
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(showlegend = input$show_truth_by_reporting,
                                   name = ifelse(input$select_language == "DE",
                                                 "nach Erscheinen in RKI Daten",
                                                 "by appearance in RKI data")),
                              list(plot_data$mapping[["truth_by_reporting"]]))

        })
        
        # update frozen time series:
        observe({
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(showlegend = input$show_truth_frozen,
                                   name = ifelse(input$select_language == "DE",
                                                 "eingefrorene Werte",
                                                 "frozen values")),
                              list(plot_data$mapping[["truth_frozen"]]))
            
        })
        
        # change language in label of old truth:
        observe({
            plotlyProxyInvoke(myPlotProxy, "restyle",
                              list(name = ifelse(input$select_language == "DE",
                                                 paste("Datenstand", current_date),
                                                 paste("data as of", current_date))),
                              list(plot_data$mapping[["current_truth"]]))
        })
        
        # change language in y-label and log vs natural scale:
        observe({
            type <- ifelse(input$select_log == "log scale", "log", "linear")

            ylab <- if(input$select_language == "DE"){
                if(input$select_scale == "absolute counts"){
                    "7-Tages-Hospitalisierungsinzidenz (absolut)"
                }else{
                    "7-Tages-Hospitalisierungsinzidenz (pro 100.000)"
                }
            }else{
                if(input$select_scale == "absolute counts"){
                    '7-day hospitalization incidence (absolute)'
                }else{
                    '7-day hospitalization incidence (per 100,000)'
                }
            }
            plotlyProxyInvoke(myPlotProxy, "relayout",
                              list(yaxis = list(title = ylab, type = type)))
        })
    })
    
    # update language in ui inputs:
    observe({
        input$select_language
        isolate({
            # Prediction interval
            label <- ifelse(input$select_language == "DE", "Vorhersageintervall", "Prediction interval")
            choices <- if(input$select_language == "DE"){
                c("95%" = "95%", "50%" = "50%", "nur Median" = "none")
            }else{
                c("95%" = "95%", "50%" = "50%", "only median" = "none")
            }
            selected <- input$select_interval
            updateRadioButtons(session, "select_interval",
                               label = label,
                               choices = choices,
                               selected = selected,
                               inline = TRUE
            )
            
            # Show as
            label <- ifelse(input$select_language == "DE", "Anzeige", "Show as")
            choices <- if(input$select_language == "DE"){
                c("absolute Zahlen" = "absolute counts",
                  "pro 100.000" = "per 100.000")
            }else{
                c("absolute counts" = "absolute counts",
                  "per 100.000" = "per 100.000")
            }
            selected <- input$select_scale
            updateRadioButtons(session, "select_scale",
                               label = label,
                               choices = choices,
                               selected = selected,
                               inline = TRUE
            )
            
            # log scale
            label <- ifelse(input$select_language == "DE", "Anzeige", "Show as")
            choices <- if(input$select_language == "DE"){
                c("natürliche Skala" = "natural scale",
                  "log-Skala"  ="log scale")
            }else{
                c("natural scale" = "natural scale",
                  "log scale"  ="log scale")
            }
            selected <- input$select_log
            updateRadioButtons(session, "select_log",
                               label = label,
                               choices = choices,
                               selected = selected,
                               inline = TRUE
            )
            
            # Stratification
            label <- ifelse(input$select_language == "DE", "Stratifizierung", "Stratification")
            choices <- if(input$select_language == "DE"){
                c("Bundesland" = "state", "Altersgruppe" = "age")
            }else{
                c("Bundesland" = "state", "Age group" = "age")
            }
            selected <- input$select_stratification
            updateRadioButtons(session, "select_stratification",
                               label = label,
                               choices = choices,
                               selected = selected,
                               inline = TRUE
            )
            
            # Time series by appearance in RKI data
            label <- ifelse(input$select_language == "DE",
                            "Zeitreihe nach Erscheinen in RKI-Daten",
                            "Time series by appearance in RKI data")
            selected <- input$show_truth_by_reporting
            updateCheckboxInput(session, "show_truth_by_reporting",
                               label = label,
                               value = selected
            )
            
            # Time series of frozen values
            label <- ifelse(input$select_language == "DE", 
                            "Zeitreihe eingefrorener Werte", 
                            "Time series of frozen values")
            selected <- input$show_truth_frozen
            updateCheckboxInput(session, "show_truth_frozen",
                               label = label,
                               value = selected
            )
            
            # Show two most recent days
            label <- ifelse(input$select_language == "DE", 
                            "Zeige letzte zwei Tage", 
                            "Show two most recent days")
            selected <- input$show_last_two_days
            updateCheckboxInput(session, "show_last_two_days",
                                label = label,
                                value = selected
            )
            
            # Show retrospective nowcasts
            label <- ifelse(input$select_language == "DE", 
                            "Nachträglich erstellte Nowcasts zeigen", 
                            "Show retrospective nowcasts")
            selected <- input$show_retrospective_nowcasts
            updateCheckboxInput(session, "show_retrospective_nowcasts",
                                label = label,
                                value = selected
            )
        })
    })
})
