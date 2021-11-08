library(shiny)
library(plotly)

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

# Define UI for application
shinyUI(fluidPage(
    
    # Application title
    titlePanel("Nowcasts der Hospitalisierungsinzidenz in Deutschland (COVID-19)"),
    
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
                         choices = c("95%", "50%", "none"), selected = "95%", inline = TRUE),
            radioButtons("select_scale", label = "Anzeige / Show as:", 
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
            radioButtons("select_language", label = "Sprache / Language",
                         choices = c("Deutsch" = "DE", "Englisch" = "EN"))
        ),
        
        mainPanel(
            conditionalPanel("input.select_language == 'DE'",
                             p("Sieben-Tages-Hospitalisierungsinzidenzen (wie ",  
                               a("vom RKI berichtet", href = "https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland"),
                               "sind einer der Hauptindikatoren für die Pandemielage in Deutschland. Durch ", 
                               a("Meldeverzüge", href = "https://www.rki.de/SharedDocs/FAQ/NCOV2019/FAQ_Liste_Epidemiologie.html"), 
                               "sind die Daten für die letzten Tage stets unvollständig und unterschätzen die wahre Zahl an Hospitalisierungen. 
              Dieses Dashboard fasst de Ergebnisse verschiedener Nowcassting-Modelle zusammen, d.h. statistischer Korrekturverfahren
              um die Meldeverzüge zu berücksichtigen."),
                             p("Dieses Projekt befindet sich noch im Aufbau und die Verlässlichkeit der Ergebnisse ist noch nicht systematisch evaluiert worden."),
                             p("Wichtig: testmodel1 und testmodel2 dienen nur zum Test der Webseite und sind keine tatsächlichen Nowcasts!")
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("Seven-day hospitalization incidences (as ",  
                               a("reported by RKI", href = "https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland"),
                               "have become one of the main indicators for the
              spread of COVID-19 in Germany. However, due to ", 
                               a("reporting lags", href = "https://www.rki.de/SharedDocs/FAQ/NCOV2019/FAQ_Liste_Epidemiologie.html"), 
                               ", the most recent data points
              are incomplete and tend to underestimate the true number of hospitalization. This dashboard
              summarizes outputs from different nowcasting models, i.e. statistical methods to correct
              for reporting delays."),
                             p("This project is currently still in development and the
              reliability of results has not yet been assessed systematically."),
                             p("Note: testmodel1 and testmodel2 only serve to test the visualization dashboard and are not actual nowcasts!")
            ),
            plotlyOutput("tsplot"),
            p(),
            conditionalPanel("input.select_language == 'DE'",
                             p("Rohdaten und detailliertere Informationen sind in unserem",
                               a("GitHub-Repository.", href = "https://github.com/KITmetricslab/hospitalization-nowcast-hub"),
                               "verfügbar."),
                             p("Diese Plattform wird von Mitgliedern des ",
                               a("Lehrstuhls für Ökonometrie und Statistik", href = "https://statistik.econ.kit.edu/index.php"),
                               "am Karlsruher Institut für Technologie betrieben. Kontakt: forecasthub@econ.kit.edu")
            ),
            conditionalPanel("input.select_language == 'EN'",
                             p("Raw forecast data and more information can be found in our",
                               a("GitHub repository.", href = "https://github.com/KITmetricslab/hospitalization-nowcast-hub")),
                             p("This platform is run by members of the ",
                               a("Chair of Statistics and Econometrics", href = "https://statistik.econ.kit.edu/index.php"),
                               "at Karlsruhe Institute of Technology. Contact: forecasthub@econ.kit.edu")
                             )
            
        )
    )
))
