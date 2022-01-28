# forecast_date <- Sys.Date()
forecast_date <- as.Date("2022-01-26")
cat("Processing", as.character(forecast_date), "...\n")

url <- paste0("https://raw.githubusercontent.com/epiforecasts/eval-germany-sp-nowcasting/main/data/nowcasts/submission/independent/", 
              forecast_date, ".csv")

dat <- read.csv(url)

dat$mean <- NULL

subs_median <- subset(dat, type == "median")
subs_median$type <- "quantile"
subs_median$quantile <- 0.5

subs_not_median <- subset(dat, type != "median")

dat <- rbind(subs_median, subs_not_median)

if(as.Date(forecast_date) < Sys.Date()){
  dir.create("./data-processed_retrospective/Epiforecasts-independent/")
  dir_to_store <- paste0("./data-processed_retrospective/Epiforecasts-independent/", forecast_date, "-Epiforecasts-independent.csv")
}else{
  dir.create("./data-processed/Epiforecasts-independent/")
  dir_to_store <- paste0("./data-processed/Epiforecasts-independent/", forecast_date, "-Epiforecasts-independent.csv")
}

write.csv(dat, 
          file = dir_to_store,
          row.names = FALSE)
