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

# function to get truth data by date of appearance in RKI data:
truth_by_reporting <- function(dat_truth, age_group = "00+", location = "DE"){
  subs <- dat_truth[dat_truth$age_group == age_group &
                      dat_truth$location == location, ]
  matr <- subs[, grepl("value_", colnames(subs))]
  nr <- nrow(matr)
  for(i in 1:ncol(matr)){
    matr[, i] <- c(rep(0, i - 1), head(matr[, i], nr - i + 1))
  }
  data.frame(date = subs$date,
             value = c(rep(NA, 6), rollapply(rowSums(matr), 7, sum)))
}

# function to get "frozen" truth data, where for each day the number for the respective day
# as available on the same day are shown
truth_frozen <- function(dat_truth, age_group = "00+", location = "DE"){
  subs <- dat_truth[dat_truth$age_group == age_group &
                      dat_truth$location == location, ]
  matr <- subs[, grepl("value_", colnames(subs))]
  nr <- nrow(matr)
  frozen <- rep(NA, nr)
  indices_frozen <- lower.tri(diag(7), diag = TRUE)[7:1, ]
  for(i in 7:nr){
    subs_matr <- matr[i-(6:0), 1:7]
    frozen[i] <- sum(subs_matr*as.numeric(indices_frozen), na.rm = TRUE)
  }
  data.frame(date = subs$date,
             value = frozen)
}

# get Monday closest to a given date:
closest_monday <- function(date){
  wk <- date + (-3:3)
  wk[weekdays(wk) == "Monday"]
}