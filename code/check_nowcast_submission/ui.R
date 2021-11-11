#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)

# Define UI for application that draws a histogram
shinyUI(fluidPage(
  
  # Application title
  titlePanel("Visualize your nowcasts prior to submission (German COVID19 Hospitalization Nowcast Hub)"),
  
  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Choose file to upload", accept = ".csv"),
      textInput("path", "Or paste a URL to a csv file (the raw csv, not github preview)."),
      # uiOutput("inp_select_age_group"),
      # uiOutput("inp_select_location") #,
      # actionButton("run_checks", "Run submission checks")
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      tags$style("#result_checks {font-size:15px;
               font-family:'Courier New';
               display:block; }"),
      
      h6("Even if your files are displayed correctly here it is possible that they fail on the github platform.",
         "The formal evaluation checks are not run on this site, it serves solely for visualization.",
         "Information on how to run local validation checks can be found in the Wiki of or github repository."
      ),
      
      h4("Nowcast visualization:"),
      plotOutput("plot", height = "1200px"),
      tags$div(
        tags$span(style="color:white", ".")
      ),
      # h4("Result of format checks:"),
      # textOutput("result_checks"),
      tags$div(
        tags$span(style="color:white", ".")
      )
      
    )
  )
))
