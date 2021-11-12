library(shiny)
library(plotly)
library(shinyhelper)
library(magrittr)

local <- FALSE
if(local){
    available_dates <- sort(read.csv("plot_data/available_dates.csv")$date)
}else{
    available_dates <- sort(read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/available_dates.csv")$date)
}
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

style_explanation <- "font-size:13px;"

# Define UI for application
shinyUI(fluidPage(
    
    # Application title
    titlePanel("Nowcasts der Hospitalisierungsinzidenz in Deutschland (COVID-19)"),
    
    br(),
    
    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            strong("Datenstand / data version "),
            br(),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_backward", "<")),
            div(style="display: inline-block;vertical-align:top;width:200px", 
                selectizeInput("select_date", 
                               label = NULL, 
                               choices = rev(available_dates))),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_forward", ">")),
            radioButtons("select_stratification", label = "Stratifizierung / stratification",
                         choices = c("Altersgruppe / age group" = "age", "Bundesland" = "state"), inline = TRUE),
            conditionalPanel("input.select_stratification == 'age'",
                             selectizeInput("select_age",
                                            label = "Altersgruppe / age group",
                                            choices = c("Alle / all" = "00+",
                                                        "0 - 4" = "00-04",
                                                        "5 - 14" = "05-14",
                                                        "15 - 34" = "15-34",
                                                        "35 - 59" = "35-59",
                                                        "60 - 79" = "60-79",
                                                        "80+" = "80+"), width = "200px")),
            conditionalPanel("input.select_stratification == 'state'",
                             selectizeInput("select_state",
                                            label = "Bundesland",
                                            choices = bundeslaender, width = "200px")),
            radioButtons("select_interval", label = "Vorhersageintervall / prediction interval:", 
                         choices = c("95%" = "95%", "50%" = "50%", "nur Median / only median" = "none"), selected = "95%", inline = TRUE),
            radioButtons("select_scale", label = "Anzeige / show as:", 
                         choices = c("absolute Zahlen / absolute counts" = "absolute counts",
                                     "pro / per 100.000" = "per 100.000"),
                         selected = "absolute counts", inline = TRUE),
            radioButtons("select_log", label = NULL, 
                         choices = c("natürliche Skala / natural scale" = "natural scale",
                                     "log-Skala / log scale"  ="log scale"), 
                         selected = "natural scale", inline = TRUE),
            checkboxInput("show_truth_by_reporting", label = "Zeitreihe nach Erscheinen in RKI-Daten / time series by appearance in RKI data", 
                          value = FALSE),
            checkboxInput("show_last_two_days", label = "Zeige letzte zwei Tage / show two most recent days", 
                          value = FALSE),
            checkboxInput("show_retrospective_nowcasts", label = "Nachträglich erstellte Nowcasts zeigen / show retrospective nowcasts", 
                          value = FALSE),
            radioButtons("select_language", label = "Sprache / language",
                         choices = c("Deutsch" = "DE", "Englisch" = "EN")),
            conditionalPanel("input.select_language == 'DE'",
                             helper(strong("Erklärung der Kontrollelemente"),
                                    content = "erklaerung",
                                    type = "markdown",
                                    size = "m")),
            conditionalPanel("input.select_language == 'EN'",
                             helper(strong("Explanation of control elements"),
                                    type = "markdown",
                                    content = "explanation",
                                    size = "m")),
        ),
        
        mainPanel(
            conditionalPanel("input.select_language == 'DE'",
                             p("Diese Plattform vereint Nowcasts der COVID19-7-Tages-Hospitalisierungsinzidenz in Deutschland basierend auf verschiedenen Methoden, mit dem Ziel einer verlässlichen Einschätzung aktueller Trends."),
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("This platform unites nowcasts of the COVID-19 7-day hospitalization incidence in Germany, with the goal of providing reliable assessments of recent trends."),
            ),
            plotlyOutput("tsplot"),
            p(),
            conditionalPanel("input.select_language == 'DE'",
                             p("Das Wichtigste in Kürze"),
                             p('- Die 7-Tages-Hospitalisierungsinzidenz ist einer der Leitindikatoren für die COVID-19 Pandemie in Deutschland (siehe "Hintergrund" für die Definition).', style = style_explanation),
                             p("- Aufgrund von Verzögerungen sind die für die letzten Tage angegebenen Werte stets zu niedrig. Dadurch kann der Eindruck einer fallenden Tendenz entstehen, selbst wenn die Hospitalisierungen tatsächlich ansteigen.", style = style_explanation),
                             p("- Nowcasts helfen, diese Werte zu korrigieren und eine realistischere Einschätzung der aktuellen Entwicklung zu erhalten.", style = style_explanation),
                             p("- Es gibt unterschiedliche Nowcasting-Verfahren. Diese vergleichen wir hier systematisch und kombinieren sie in einem sogenannten Ensemble-Nowcast.", style = style_explanation),
                             strong("Dieses Projekt befindet sich noch im Aufbau und die Verlässlichkeit der Ergebnisse ist noch nicht eingehend evaluiert worden.", style = style_explanation)
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("Short summary"),
                             p('- The 7-day hospitalization incidence is one of the main indicators for the assessment of the COVID-19 pandemic in Germany (see "Background" for the definition).', style = style_explanation),
                             p("- Due to delays recent values are biased downward. This can create the impression of a downward trend even if hospitalizations are actually increasing.", style = style_explanation),
                             p("- Nowcasts can help to correct these values and obtain a more realistic assessment of recent developments.", style = style_explanation),
                             p("- A variety of nowcasting methods exist. We systematically compile results based on different methods and combine them into so-called ensemble nowcasts.", style = style_explanation),
                             strong("This project is currently still in development and the reliability of results has not yet been assessed systematically.", style = style_explanation)
            ),
            p(),
            conditionalPanel("input.select_language == 'DE'",
                             p("Die interaktive Visualisierung funktioniert am besten unter Google Chrome.", style = style_explanation)
                             # p("Diese Plattform wird von Mitgliedern des ",
                             #   a("Lehrstuhls für Ökonometrie und Statistik", href = "https://statistik.econ.kit.edu/index.php"),
                             #   "am Karlsruher Institut für Technologie betrieben. Kontakt: forecasthub@econ.kit.edu")
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("The interactive visualization works best under Google Chrome.", style = style_explanation)
                             # p("This platform is run by members of the ",
                             #   a("Chair of Statistics and Econometrics", href = "https://statistik.econ.kit.edu/index.php"),
                             #   "at Karlsruhe Institute of Technology. Contact: forecasthub@econ.kit.edu")
                             )
            
        )
    )
))
