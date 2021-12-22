library(shiny)
library(plotly)
library(shinyhelper)
library(magrittr)
library(shinybusy)
library(DT)

# get auxiliary functions:
source("functions.R")

local <- TRUE
if(local){
    # get vector of model names:
    dat_models <- read.csv("plot_data/list_teams.csv")
    # available versions of truth_data:
    available_dates <- sort(read.csv("plot_data/available_dates.csv", colClasses = c("date" = "Date"))$date)
    # available plot_data with nowcasts:
    available_nowcast_dates <- date_from_filename(sort(read.csv("plot_data/list_plot_data.csv")$file))
    
}else{
    # available versions of truth_data:
    available_dates <- sort(read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/available_dates.csv", colClasses = c("date" = "Date"))$date)
    # available plot_data with nowcasts:
    available_nowcast_dates <- date_from_filename(sort(read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/list_plot_data.csv")$file))
    # get vector of model names:
    dat_models <- read.csv("https://raw.githubusercontent.com/KITmetricslab/hospitalization-nowcast-hub/main/nowcast_viz_de/plot_data/list_teams.csv")
}
bundeslaender <- c("Alle (Deutschland)" = "DE",
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

# check whether a disclaimer for a missing nowcast is needed:
update_available <- ((Sys.Date()) %in% available_nowcast_dates)
time <- as.POSIXct(Sys.time(), tz = "CET")
disclaimer_necessary <- ifelse((!update_available) & (format(time, format = "%H") >= 15), "true", "false")
# (a string to be added in a JS command)

# Define UI for application
shinyUI(fluidPage(
    
    # Application title
    conditionalPanel("input.select_language == 'DE'", 
                     titlePanel("Nowcasts der Hospitalisierungsinzidenz in Deutschland (COVID-19)")),
    conditionalPanel("input.select_language == 'EN'", 
                     titlePanel("Nowcasts of the hospitalization incidence in Germany (COVID-19)")),
    
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
                dateInput("select_date", label = NULL, value = max(available_nowcast_dates),
                          min = min(available_dates), max = max(available_dates))),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_forward", ">")),
            conditionalPanel("input.select_language == 'DE'",
                             p("Nowcasts werden täglich gegen 13:00 aktualisiert, können aber verspätet sein falls Daten des RKI verzögert veröffentlicht werden. Falls ein Nowcast für das gewählte Datum nicht vorliegt wird der aktuellste Nowcast der letzten 7 Tage gezeigt.",
                               style = "font-size:11px;")),
            conditionalPanel("input.select_language == 'EN'",
                             p("Nowcasts are updated on daily at around 1pm, but may be delayed if input data from RKI are published later than usually. If a nowcast is not available for the chosen date, the most current nowcast from the last 7 days is shown.",
                               style = "font-size:11px;")),
            radioButtons("select_stratification", label = "Stratifizierung",
                         choices = c("Bundesland" = "state", "Altersgruppe" = "age"), inline = TRUE),
            conditionalPanel("input.select_stratification == 'age'",
                             conditionalPanel("input.select_language == 'DE'", strong("Altersgruppe")),
                             conditionalPanel("input.select_language == 'EN'", strong("Age group")),
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
            checkboxInput("show_truth_frozen", label = "Zeitreihe eingefrorener Werte", 
                          value = FALSE),
            checkboxInput("show_last_two_days", label = "Zeige letzte zwei Tage (weniger verlässliche Schätzung)", 
                          value = FALSE),
            checkboxInput("show_table", label = "Zeige Übersichtstabelle", 
                          value = FALSE),
            conditionalPanel("input.select_language == 'DE'", strong("Weitere Optionen")),
            conditionalPanel("input.select_language == 'EN'", strong("More options")),
            strong(checkboxInput("show_additional_controls", label = "Zeige weitere Optionen", 
                          value = FALSE)),
            
            conditionalPanel("input.show_additional_controls",
                             radioButtons("select_scale", label = "Anzeige", 
                                          choices = c("pro 100.000" = "per 100.000",
                                                      "absolute Zahlen" = "absolute counts"),
                                          selected = "per 100.000", inline = TRUE),
                             radioButtons("select_log", label = NULL, 
                                          choices = c("natürliche Skala" = "natural scale",
                                                      "log-Skala"  ="log scale"), 
                                          selected = "natural scale", inline = TRUE),
                             radioButtons("select_point_estimate", label = "Punktschätzer:", 
                                          choices = c("Median" = "median", "Erwartungswert" = "mean"),
                                          selected = "median", inline = TRUE),
                             radioButtons("select_interval", label = "Unsicherheitsintervall", 
                                          choices = c("95%" = "95%", "50%" = "50%", "keines" = "none"), selected = "95%", inline = TRUE),
                             
                             conditionalPanel("input.select_language == 'DE'", strong("Weitere Anzeigeoptionen")),
                             conditionalPanel("input.select_language == 'EN'", strong("Further display options")),
                             
                             checkboxInput("show_truth_by_reporting", label = "Zeitreihe nach Erscheinen in RKI-Daten", 
                                           value = FALSE),
                             checkboxInput("show_retrospective_nowcasts", label = "Nachträglich erstellte Nowcasts zeigen", 
                                           value = FALSE)
            ),
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
            add_busy_spinner(spin = "fading-circle"),
            conditionalPanel("input.select_language == 'DE'",
                             p("Diese Plattform vereint Nowcasts der COVID19-7-Tages-Hospitalisierungsinzidenz in Deutschland basierend auf verschiedenen Methoden, mit dem Ziel einer verlässlichen Einschätzung aktueller Trends. Detaillierte Erläuterungen gibt es unter ", a('"Hintergrund".', href="https://covid19nowcasthub.de/hintergrund.html")),
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("This platform unites nowcasts of the COVID-19 7-day hospitalization incidence in Germany, with the goal of providing reliable assessments of recent trends. Detailed explanations are given in ", a('"Background".', href="https://covid19nowcasthub.de/background.html")),
            ),
            
            conditionalPanel("input.select_language == 'DE'",
                             p("Über den Jahreswechsel kann es zu Verzögerungen bei der Erstellung der Nowcasts kommen. Außerdem ist zu erwarten, dass sich die Verzüge, mit denen Hospitalisierungen gemeldet werden während dieser Zeit anders verhalten als im Rest des Jahres. Dies kann die Verlässlichkeit der Nowcasts vermindern und diese sollten mit besonderer Vorsicht interpretiert werden."),
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("During the holiday period delays may occur in the creation of nowcasts. Moreover, the delays with which hospitalizations get reported are expected to behave differently than during the rest of the year. This can reduce the reliability of nowcasts, which should be interpreted with particular care."),
            ),
            
            conditionalPanel(paste("input.select_language == 'DE' &", disclaimer_necessary),
                             strong("Nowcasts werden gewöhnlich gegen 13:00 aktualisiert, jedoch scheint für den heutigen Tag noch kein Update vorzuliegen. Eine Aktualisiserung wird u.U. erst morgen wieder verfügbar (dies ist ein automatischer Hinweis)."),
            ),
            conditionalPanel(paste("input.select_language == 'EN' &", disclaimer_necessary),
                             strong("Nowcasts are usually updated at around 1pm, but it seems that there has not yet been an update for today. An update may only become available tomorrow (this is an automated notification)."),
            ),
            plotlyOutput("tsplot", height = "440px"),
            conditionalPanel("input.show_table",
                             br(),
                             conditionalPanel("input.select_language == 'DE'",
                                              p("Untenstehende Tabelle fasst die Nowcasts eines gewählten Modells für ein bestimmtes Meldedatum und verschiedene Bundesländer oder Altersgruppen zusammen. Der verwendete Datenstand ist der selbe wie für die grafischen Darstellung."),
                             ),
                             conditionalPanel("input.select_language == 'EN'",
                                              p("This table summarizes the nowcasts made by the selected model for a given Meldedatum (target date) and all German states or age groups. The data version is the same as in the graphical display."),
                             ),
                             div(style="display: inline-block;vertical-align:top;width:400px",
                                 selectInput("select_model", "Modell:",
                                             choices = dat_models$model,
                                             selected = "NowcastHub-MeanEnsemble")),
                             div(style="display: inline-block;vertical-align:top;width:200px",
                                 dateInput("select_target_end_date", label = "Meldedatum", value = max(available_dates) - 2,
                                           min = min(available_dates), max = max(available_dates))),
                             DTOutput("table"), 
                             br()),
            
            
            p(),
            conditionalPanel("input.select_language == 'DE'",
                             p('Das Wichtigste in Kürze (siehe', a('"Hintergrund"', href="https://covid19nowcasthub.de/hintergrund.html"), " für Details)"),
                             p('- Die 7-Tages-Hospitalisierungsinzidenz ist einer der Leitindikatoren für die COVID-19 Pandemie in Deutschland (siehe "Hintergrund" für die Definition).', style = style_explanation),
                             p("- Aufgrund von Verzögerungen sind die für die letzten Tage veröffentlichten rohen Inzidenzwerte stets zu niedrig. Nowcasts helfen, diese Werte zu korrigieren und eine realistischere Einschätzung der aktuellen Entwicklung zu erhalten.", style = style_explanation),
                             p('- Es gibt unterschiedliche Nowcasting-Verfahren. Diese vergleichen wir hier systematisch und kombinieren sie in einem sogenannten Ensemble-Nowcast. Modellbeschreibungen und Details zur Interpretation sind unter "Hintergrund" verfügbar.', style = style_explanation),
                             strong("- Starke Belastung des Gesundheits- und Meldewesens kann dazu führen, dass sich Meldeverzögerungen anders verhalten als in der Vergangenheit. Die Verlässlichkeit von Nowcasts kann hierdurch beeinträchtigt und die wahren Hospitalisierungszahlen tendenziell unterschätzt werden.", style = style_explanation),
                             br(),
                             br(),
                             strong("Dieses Projekt ist erst kürzlich gestartet worden und die Verlässlichkeit der Echtzeit-Analysen kann noch nicht systematisch evaluiert werden.", style = style_explanation)
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p('Short summary (see',  a('"Background"', href="https://covid19nowcasthub.de/background.html"), "for details)"),
                             p('- The 7-day hospitalization incidence is one of the main indicators for the assessment of the COVID-19 pandemic in Germany (see "Background" for the definition).', style = style_explanation),
                             p("- Due to delays, the published raw incidence values for the last few days are biased downward. Nowcasts can help to correct these and obtain a more realistic assessment of recent developments.", style = style_explanation),
                             p('- A variety of nowcasting methods exist. We systematically compile results based on different methods and combine them into so-called ensemble nowcasts. Model descriptions and details on the interpretation are available in the "Background" section.', style = style_explanation),
                             strong("- High burden on the health and reporting system can change delay patterns. Nowcasts may then be less reliable and tend to underestimate the true number of hospitalizations.", style = style_explanation),
                             br(),
                             br(),
                             strong("This project has been launched recently reliability of nowcasts made in real time cannot yet be assessed systematically.", style = style_explanation)
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
            ),
            conditionalPanel("input.select_language == 'DE'",
                             p(a("covid19nowcasthub.de", href = "https://covid19nowcasthub.de"), " - ",
                               a("Lehrstuhl für Ökonometrie und Statistik, Karlsruher Institut für Technologie", href = "https://statistik.econ.kit.edu/index.php"), " - ",
                               a("Kontakt", href = "https://covid19nowcasthub.de/contact.html"))
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p(a("covid19nowcasthub.de", href = "https://covid19nowcasthub.de"), " - ",
                               a("Chair of Statistics and Econometrics, Karlsruhe Institute of Technology", href = "https://statistik.econ.kit.edu/index.php"), "-",
                               a("Contact", href = "https://covid19nowcasthub.de/contact.html"))
            )
        )
    )
))
