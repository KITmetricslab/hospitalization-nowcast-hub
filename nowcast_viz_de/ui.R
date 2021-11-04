library(shiny)
library(plotly)

available_dates <- sort(read.csv("plot_data/available_dates.csv")$date)
bundeslaender <- c("All (Germany)" = "DE",
                   "Baden-Württemberg" = "DE-BW", 	
                   "Bayern" = "DE-BY", 	
                   "Berlin" = "DE-BE", 	
                   "Brandenburg" = "DE-BB", 	
                   "Bremen" = "DE-HB", 	
                   "Hamburg" = "DE-HH", 	
                   "Hessen" = "DE-HE", 	
                   "Mecklenburg-Vorpommern" = "DE-MV", 	
                   "Niedersachsen" = "DE-NI", 	
                   "Nordrhein-Westfalen" = "DE-NW", 	
                   "Rheinland-Pfalz" = "DE-RP", 	
                   "Saarland" = "DE-SL", 	
                   "Sachsen" = "DE-SN",
                   "Sachsen-Anhalt" = "DE-ST",
                   "Schleswig-Holstein" = "DE-SH", 	
                   "Thüringen" = "DE-TH")

# Define UI for application
shinyUI(fluidPage(
    
    # Application title
    titlePanel("Nowcasting hospitalizations from COVID-19 in Germany"),
    
    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            strong("Select data version (also by click in plot)  "),
            br(),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_backward", "<")),
            div(style="display: inline-block;vertical-align:top;width:200px", 
                selectizeInput("select_date", 
                               label = NULL, 
                               choices = rev(available_dates))),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_forward", ">")),
            radioButtons("select_stratification", label = "Stratify by",
                         choices = c("Age group" = "age", "Bundesland" = "state"), inline = TRUE),
            conditionalPanel("input.select_stratification == 'age'",
                             selectizeInput("select_age",
                                            label = "Age group",
                                            choices = c("All" = "00+",
                                                        "Age 0 - 4" = "00-04",
                                                        "Age 5 - 14" = "05-14",
                                                        "Age 15 - 34" = "15-34",
                                                        "Age 35 - 59" = "35-59",
                                                        "Age 60 - 79" = "60-79",
                                                        "Age 80 and above" = "80+"), width = "200px")),
            conditionalPanel("input.select_stratification == 'state'",
                             selectizeInput("select_state",
                                            label = "Bundesland",
                                            choices = bundeslaender, width = "200px")),
            radioButtons("select_interval", label = "Show prediction interval:", 
                         choices = c("95%", "50%", "none"), selected = "95%", inline = TRUE),
            radioButtons("select_scale", label = "Show as:", 
                         choices = c("absolute counts", "per 100.000"), selected = "absolute counts", inline = TRUE),
            radioButtons("select_log", label = NULL, 
                         choices = c("natural scale", "log scale"), selected = "natural scale", inline = TRUE)
        ),
        
        # Show a plot of the generated distribution
        mainPanel(
            p("Seven-day hospitalization incidences (as ",  
            a("reported by RKI", href = "https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland"),
            "have become one of the main indicators for the
              spread of COVID-19 in Germany. However, due to ", 
              a("reporting lags", href = "https://www.rki.de/SharedDocs/FAQ/NCOV2019/FAQ_Liste_Epidemiologie.html"), 
              ", the most recent data points
              are incomplete and tend to underestimate the true number of hospitalization. This dashboard
              summarizes outputs from different nowcasting models, i.e. statistical methods to correct
              for reporting delays. Below, outputs from individual models and a combined ensemble nowcast
              (nowcasthub-ensemble) are shown."),
            p("This project is currently still in development and the
              reliability of results has not yet been assessed systematically."),
            p("Note: testmodel1 and testmodel2 only serve to test the visualization dashboard and are not actual nowcasts!"),
            plotlyOutput("tsplot"),
            p(),
            p("Raw forecast data and more information can be found in our",
              a("GitHub repository.", href = "https://github.com/KITmetricslab/hospitalization-nowcast-hub")),
            p("This platform is run by members of the ",
              a("Chair of Statistics and Econometrics", href = "https://statistik.econ.kit.edu/index.php"),
              "at Karlsruhe Institute of Technology. Contact: forecasthub@econ.kit.edu")
        )
    )
))
