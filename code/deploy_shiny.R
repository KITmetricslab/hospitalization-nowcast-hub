install.packages(c("shiny", "shinyhelper", "rsconnect", "plotly", "zoo", "httr", "magrittr"), dependencies = TRUE)

library("shiny")
library("shinyhelper")
library("rsconnect")
library("plotly")
library("zoo")
library("httr")
library("magrittr")

SHINYAPPS_NAME = Sys.getenv("SHINYAPPS_NAME")
SHINYAPPS_TOKEN = Sys.getenv("SHINYAPPS_TOKEN")
SHINYAPPS_SECRET = Sys.getenv("SHINYAPPS_SECRET")

setAccountInfo(name=SHINYAPPS_NAME, token=SHINYAPPS_TOKEN, secret=SHINYAPPS_SECRET)
deployApp(appDir = "./nowcast_viz_de", appName = "github-viz-test")
