# function to compute truth data as of a certain time:
truth_as_of <- function(dat_truth, age_group = "00+", location = "DE", date){
  if(is.null(date)){
    date <- max(dat_truth$date)
  }
  date <- as.Date(date)
  subs <- dat_truth[dat_truth$age_group == age_group &
                      dat_truth$location == location &
                      dat_truth$date <= date, ]
  matr <- subs[, grepl("value_", colnames(subs))]
  matr_dates <- matrix(subs$date, nrow = nrow(matr), ncol = ncol(matr))
  matr_delays <- matrix((1:ncol(matr_dates)) - 1, byrow = TRUE,
                        nrow = nrow(matr), ncol = ncol(matr))
  matr_reporting_date <- matr_dates + matr_delays
  matr[matr_reporting_date > date] <- 0
  data.frame(date = subs$date,
             value = c(rep(NA, 6), rollapply(rowSums(matr), 7, sum)))
}

# get Monday closest to a given date:
closest_monday <- function(date){
  wk <- date + (-3:3)
  wk[weekdays(wk) == "Monday"]
}