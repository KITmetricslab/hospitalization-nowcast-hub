library(shiny)
library(plotly)

mondays <- read.csv("plot_data/mondays.csv")$date

# Define UI for application
shinyUI(fluidPage(

    # Application title
    titlePanel("Hospitalization nowcasts"),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            strong("Select data version (also by click in plot)  "),
            br(),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_backward", "<")),
            div(style="display: inline-block;vertical-align:top;width:200px", 
                selectizeInput("select_date", 
                               label = NULL, 
                               choices = rev(mondays))),
            div(style="display: inline-block;vertical-align:top;", actionButton("skip_forward", ">")),
            selectizeInput("select_age",
                           label = "Age group",
                           choices = c("All" = "00+",
                                       "Age 0 - 4" = "00-04",
                                       "Age 5 - 14" = "05-14",
                                       "Age 15 - 34" = "15-34",
                                       "Age 35 - 59" = "35-59",
                                       "Age 60 - 79" = "60-79",
                                       "Age 80 and above" = "80+"), width = "200px")
        ),

        # Show a plot of the generated distribution
        mainPanel(
            plotlyOutput("tsplot")
        )
    )
))
