setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub/baseline")
source("functions.R")
source("../code/check_nowcast_submission/plot_functions.R")

library(zoo)

# read truth data:
observed0 <- read.csv("../data-truth/COVID-19/COVID-19_hospitalizations_preprocessed.csv",
                     colClasses = c("date" = "Date"))
observed0 <- subset(observed0, location == "DE" & age_group == "00+")
# prepare for plotting:
observed_for_plot <- truth_as_of(observed0, age_group = "00+",
                         location = "DE",
                         date = Sys.Date() - 3)

# dates for which to produce nowcasts:
forecast_dates <- Sys.Date() # seq(from = as.Date("2021-11-08"), to = as.Date("2021-11-08"), by = 1)

# generate nowcasts:
for(i in seq_along(forecast_dates)){
  # generate truth data as of forecast_date
  forecast_date <- forecast_dates[i]
  observed <- back_in_time_df(observed0, date = forecast_date)
  
  # compute nowcast:
  nc <- compute_nowcast(observed = observed, 
                        location = "DE", 
                        age_group = "00+",
                        min_horizon = 0,
                        max_horizon = 28)
  
  # truth data as of forecast_date for plot:
  dat_truth_temp <- truth_as_of(dat_truth, age_group = "00+",
                                             location = "DE",
                                             date = forecast_date)
  
  # generate a plot:
  plot_forecast(forecasts = nc,
                location = "DE", age_group = "00+",
                truth = truth_inc, target_type = paste("inc hosp"),
                levels_coverage = c(0.5, 0.95),
                start = as.Date(forecast_date) - 35,
                end = as.Date(forecast_date) + 28,
                forecast_date = forecast_date)
  axis(1)
  title(forecast_date)
  lines(dat_truth_temp$date, dat_truth_temp$value, col = "darkgrey", lty  ="dashed")
  
  # write out:
  write.csv(nc, file = paste0(forecast_date, "-KIT-simple_nowcast.csv"), row.names = FALSE)
}




