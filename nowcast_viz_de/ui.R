library(shiny)
library(plotly)
library(shinyhelper)
library(magrittr)

local <- TRUE
if(local){
    available_dates <- sort(read.csv("plot_data/available_dates.csv", colClasses = c("date" = "Date"))$date)
}else{
    available_dates <- sort(read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/available_dates.csv", colClasses = c("date" = "Date"))$date)
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
            radioButtons("select_language", label = "Sprache / language",
                         choices = c("Deutsch" = "DE", "English" = "EN"), inline = TRUE),
            conditionalPanel("input.select_language == 'DE'", strong("Datenstand")),
            conditionalPanel("input.select_language == 'EN'", strong("Data version")),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_backward", "<")),
            div(style="display: inline-block;vertical-align:top;width:200px", 
                dateInput("select_date", label = NULL, value = max(available_dates),
                          min = min(available_dates), max = max(available_dates))),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_forward", ">")),
            conditionalPanel("input.select_language == 'DE'",
                             p("Nowcasts werden werktäglich aktualisiert. Falls ein Nowcast für das gewählte Datum nicht vorliegt wird der aktuellste Nowcast der letzten 7 Tage gezeigt.",
                               style = "font-size:11px;")),
            conditionalPanel("input.select_language == 'EN'",
                             p("Nowcasts are updated on working days. If a nowcast is not available for the chosen date, the most current nowcast from the last 7 days is shown.",
                               style = "font-size:11px;")),
            radioButtons("select_stratification", label = "Stratifizierung",
                         choices = c("Bundesland" = "state", "Altersgruppe" = "age"), inline = TRUE),
            conditionalPanel("input.select_stratification == 'age'",
                             conditionalPanel("input.select_language == 'DE'", strong("Altersgruppe")),
                             conditionalPanel("input.select_language == 'EN'", strong("Datenstand")),
                             selectizeInput("select_age",
                                            label = NULL,
                                            choices = c("0+" = "00+",
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
            conditionalPanel("input.select_language == 'DE'",
                             p("Beachten Sie beim Vergleich der Altersgruppen bzw. der Bundesländer die unterschiedlichen Skalen in der Grafik.",
                               style = "font-size:11px;")),
            conditionalPanel("input.select_language == 'EN'",
                             p("When comparing age groups or Bundesländer please note that the scales in the figure differ.",
                               style = "font-size:11px;")),
            radioButtons("select_interval", label = "Vorhersageintervall", 
                         choices = c("95%" = "95%", "50%" = "50%", "nur Median" = "none"), selected = "95%", inline = TRUE),
            radioButtons("select_scale", label = "Anzeige", 
                         choices = c("absolute Zahlen" = "absolute counts",
                                     "pro 100.000" = "per 100.000"),
                         selected = "absolute counts", inline = TRUE),
            radioButtons("select_log", label = NULL, 
                         choices = c("natürliche Skala" = "natural scale",
                                     "log-Skala"  ="log scale"), 
                         selected = "natural scale", inline = TRUE),
            checkboxInput("show_truth_by_reporting", label = "Zeitreihe nach Erscheinen in RKI-Daten", 
                          value = FALSE),
            checkboxInput("show_truth_frozen", label = "Zeitreihe eingefrorener Werte", 
                          value = FALSE),
            checkboxInput("show_last_two_days", label = "Zeige letzte zwei Tage", 
                          value = FALSE),
            checkboxInput("show_retrospective_nowcasts", label = "Nachträglich erstellte Nowcasts zeigen", 
                          value = FALSE),
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
                             p("- Aufgrund von Verzögerungen sind die für die letzten Tage veröffentlichten rohen Inzidenzwerte stets zu niedrig. Nowcasts helfen, diese Werte zu korrigieren und eine realistischere Einschätzung der aktuellen Entwicklung zu erhalten.", style = style_explanation),
                             p("- Es gibt unterschiedliche Nowcasting-Verfahren. Diese vergleichen wir hier systematisch und kombinieren sie in einem sogenannten Ensemble-Nowcast.", style = style_explanation),
                             strong("Dieses Projekt befindet sich noch im Aufbau und die Verlässlichkeit der Ergebnisse ist noch nicht eingehend evaluiert worden.", style = style_explanation)
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("Short summary"),
                             p('- The 7-day hospitalization incidence is one of the main indicators for the assessment of the COVID-19 pandemic in Germany (see "Background" for the definition).', style = style_explanation),
                             p("- Due to delays, the published raw incidence values for the last few days are biased downward. Nowcasts can help to correct these and obtain a more realistic assessment of recent developments.", style = style_explanation),
                             p("- A variety of nowcasting methods exist. We systematically compile results based on different methods and combine them into so-called ensemble nowcasts.", style = style_explanation),
                             strong("This project is currently still in development and the reliability of results has not yet been assessed systematically.", style = style_explanation)
            ),
            p(),
            conditionalPanel("input.select_language == 'DE'",
                             p("Die interaktive Visualisierung funktioniert am besten unter Google Chrome und ist nicht für Mobilgeräte optimiert.", style = style_explanation)
                             # p("Diese Plattform wird von Mitgliedern des ",
                             #   a("Lehrstuhls für Ökonometrie und Statistik", href = "https://statistik.econ.kit.edu/index.php"),
                             #   "am Karlsruher Institut für Technologie betrieben. Kontakt: forecasthub@econ.kit.edu")
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("The interactive visualization works best under Google Chrome and is not optimized for mobile devices.", style = style_explanation)
                             # p("This platform is run by members of the ",
                             #   a("Chair of Statistics and Econometrics", href = "https://statistik.econ.kit.edu/index.php"),
                             #   "at Karlsruhe Institute of Technology. Contact: forecasthub@econ.kit.edu")
                             )
            
        )
    )
))
