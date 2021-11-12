install.packages(c("shiny", "shinyhelper", "rsconnect"))

library("shiny")
library("shinyhelper")
library("rsconnect")

SHINYAPPS_NAME = Sys.getenv("SHINYAPPS_NAME")
SHINYAPPS_TOKEN = Sys.getenv("SHINYAPPS_TOKEN")
SHINYAPPS_SECRET = Sys.getenv("SHINYAPPS_SECRET")

setAccountInfo(name=SHINYAPPS_NAME, token=SHINYAPPS_TOKEN, secret=SHINYAPPS_SECRET)
deployApp(appDir = "./nowcast_viz_de", appName = "github-viz-test")
