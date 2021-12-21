# get date from a file name of plot_data:
date_from_filename <- function(files){
  as.Date(gsub("_forecast_data.csv", "", files))
}

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

# function to et truth data as of a certain time for a certain date for all age groups or all regions:
truth_as_of_by_strat <- function(dat_truth, by = c("state", "age"), forecast_date, target_end_dates){
  forecast_date <- as.Date(forecast_date)
  target_end_dates <- as.Date(target_end_dates)
  if(forecast_date < max(target_end_dates)) stop("forecast_date needs to be after target_end_date")
  
  dates_to_keep <- (min(target_end_dates) - 6):forecast_date
  subs <- dat_truth[dat_truth$date %in% dates_to_keep, ]
  
  
  res <- NULL
  
  if(by == "state"){
    bundeslaender <- unique(dat_truth$location)
    for(loc in bundeslaender){
      dat_temp <- truth_as_of(subs, age_group = "00+", location = loc, date = forecast_date)
      dat_temp <- subset(dat_temp, date %in% target_end_dates)
      dat_temp$location <- loc
      dat_temp$age_group <- "00+"
      if(is.null(res)){
        res <- dat_temp
      }else{
        res <- rbind(res, dat_temp)
      }
    }
  }else{
    age_groups <- unique(dat_truth$age_group)
    for(age in age_groups){
      dat_temp <- truth_as_of(subs, age_group = age, location = "DE", date = forecast_date)
      dat_temp <- subset(dat_temp, date %in% target_end_dates)
      dat_temp$location <- "DE"
      dat_temp$age_group <- age
      if(is.null(res)){
        res <- dat_temp
      }else{
        res <- rbind(res, dat_temp)
      }
    }
  }
  
  return(res)
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


# create overview table:
create_table <- function(forecasts, dat_truth, population, model,
                         forecast_date, target_end_date, current_date,
                         by = "state",
                         median_or_mean = "median", interval_level = "95%",
                         scale = "absolute", pathogen = "COVID-19", target_type = "hosp"){
  
  # mapping between state codes and human-readable names
  bundeslaender <- c("DE" = "Alle (Deutschland)",
                     "DE-BW" = "Baden-Württemberg", 	
                     "DE-BY" = "Bayern", 	
                     "DE-BE" = "Berlin", 	
                     "DE-BB" = "Brandenburg", 	
                     "DE-HB" = "Bremen", 	
                     "DE-HH" = "Hamburg", 	
                     "DE-HE" = "Hessen", 	
                     "DE-MV" = "Mecklenburg-Vorpommern", 	
                     "DE-NI" = "Niedersachsen", 	
                     "DE-NW" = "Nordrhein-Westfalen", 	
                     "DE-RP" = "Rheinland-Pfalz", 	
                     "DE-SL" = "Saarland", 	
                     "DE-SN" = "Sachsen",
                     "DE-ST" = "Sachsen-Anhalt",
                     "DE-SH" = "Schleswig-Holstein", 	
                     "DE-TH" = "Thüringen")
  
  # subset to relevant rows of forecast data:
  sub <- forecasts[forecasts$target_end_date == target_end_date &
                     forecasts$model == model &
                     forecasts$pathogen == "COVID-19" &
                     forecasts$target_type == target_type, ]
  # depending on whether by state or age group:
  if(by == "state"){
    sub <- subset(sub, age_group == "00+")
  }
  if(by == "age_group"){
    sub <- subset(sub, location == "DE")
  }
  
  # return NULL if no data available:
  if(nrow(sub) == 0){
    warning("No nowcast data available")
    return(NULL)
  }
  
  # remove columns not needed:
  sub$target_type <- sub$pathogen <- sub$model <- NULL
  
  # choose point nowcast (median or mean):
  sub$point <- if(median_or_mean == "median"){
    sub$q0.5
  }else{
    sub$mean
  }
  
  # choose lower and upper bound of uncertainty interval:
  sub$lower <- NA
  if(interval_level == "50%"){
    sub$lower <- sub$q0.25
  }
  if(interval_level == "95%"){
    sub$lower <- sub$q0.025
  }
  
  sub$upper <- NA
  if(interval_level == "50%"){
    sub$upper <- sub$q0.75
  }
  if(interval_level == "95%"){
    sub$upper <- sub$q0.975
  }
  
  # add population data:
  sub <- merge(sub, population, by = c("location", "age_group"))
  
  # compute scaling factor:
  if(scale == "per 100.000"){
    sub$pop_factor <- 100000/sub$population
  }else{
    sub$pop_factor <- 1
  }
  # apply to nowcast:
  sub$point <- round(sub$pop_factor*sub$point, 2)
  sub$lower <- round(sub$pop_factor*sub$lower, 2)
  sub$upper <- round(sub$pop_factor*sub$upper, 2)
  
  # how many spaces do we need to add to remain sortable:
  point_character <- as.character(floor(sub$point))
  max_n_char <- max(nchar(point_character))
  spaces_to_add <- n_spaces(max_n_char - nchar(point_character))
  
  # create column with point nowcast and interval:
  if(interval_level %in% c("50%", "95%")){
    sub$nowcast <- paste0(spaces_to_add, sub$point, " (", sub$lower, " - ", sub$upper, ")")
  }else{
    sub$nowcast <- paste0(spaces_to_add, sub$point)
  }
  
  # get truth as of when the nowcast was made:
  truths_forecast_date <- truth_as_of_by_strat(dat_truth, by = by,
                                               forecast_date = forecast_date,
                                               target_end_date = target_end_date)
  colnames(truths_forecast_date)[1:2] <- c("target_end_date", "value_forecast_date")
  # add:
  sub <- merge(sub, truths_forecast_date, by = c("target_end_date", "location", "age_group"))
  # apply population factor
  sub$value_forecast_date <- sub$pop_factor*sub$value_forecast_date
  
  # # get truth as of target date (i.e. frozen value):
  # truths_target_end_date <- truth_as_of_by_strat(dat_truth, by = by,
  #                                                forecast_date = target_end_date,
  #                                                target_end_date = target_end_date)
  # colnames(truths_target_end_date)[1:2] <- c("target_end_date", "value_target_end_date")
  # # add:
  # sub <- merge(sub, truths_target_end_date, by = c("target_end_date", "location", "age_group"))
  # # apply population factor
  # sub$value_target_end_date <- sub$pop_factor*sub$value_target_end_date
  
  # get current truth:
  truths_current <- truth_as_of_by_strat(dat_truth, by = by,
                                         forecast_date = current_date,
                                         target_end_date = target_end_date)
  colnames(truths_current)[1:2] <- c("target_end_date", "value_current_date")
  # add:
  sub <- merge(sub, truths_current, by = c("target_end_date", "location", "age_group"))
  # apply population factor
  sub$value_current_date <- sub$pop_factor*sub$value_current_date
  
  # get nowcasts from seven days ago:
  sub_7days_ago <- forecasts[forecasts$target_end_date == target_end_date - 7 &
                               forecasts$model == model &
                               forecasts$pathogen == "COVID-19" &
                               forecasts$target_type == target_type, ]
  if(by == "state"){
    sub_7days_ago <- subset(sub_7days_ago, age_group == "00+")
  }
  if(by == "age_group"){
    sub_7days_ago <- subset(sub_7days_ago, location == "DE")
  }
  # take only point nowcast:
  sub_7days_ago$nowcast_7days_ago <- if(median_or_mean == "median"){
    sub_7days_ago$q0.5
  }else{
    sub_7days_ago$mean
  }
  sub_7days_ago <- sub_7days_ago[, c("location", "age_group", "nowcast_7days_ago")]
  # add:
  sub <- merge(sub, sub_7days_ago, by = c("location", "age_group"), all.x = TRUE)
  # apply population factor:
  sub$nowcast_7days_ago <- sub$pop_factor*sub$nowcast_7days_ago
  
  # compute correction factors:
  sub$correction_factor_forecast_date <- sub$point / sub$value_forecast_date
  # sub$correction_factor_target_end_date <- sub$point / sub$value_target_end_date
  
  # compute nowcasted increase over last seven days
  sub$perc_increase_7d <- 100*(sub$point/sub$nowcast_7days_ago - 1)
  
  # re-order columns:
  sub <- sub[, c("location", "age_group", "value_current_date", 
                 "value_forecast_date", "nowcast", "correction_factor_forecast_date",
                 "perc_increase_7d"
                 # "value_target_end_date", "correction_factor_target_end_date",
                 )]
  
  # formatting:
  sub$perc_increase_7d <- round(sub$perc_increase_7d, 2)
  sub$correction_factor_forecast_date <- round(sub$correction_factor_forecast_date, 2)
  sub$value_forecast_date <- round(sub$value_forecast_date, 2)
  sub$value_current_date <- round(sub$value_current_date, 2)
  # sub$value_target_end_date <- round(sub$value_target_end_date, 2)
  # sub$correction_factor_target_end_date <- round(sub$correction_factor_target_end_date, 2)
  
  # remove redundant column depending on "by":
  if(by == "state"){
    sub$age_group <- NULL
    sub$location <- bundeslaender[sub$location]
    sub <- sub[order(sub$location), ]
  }
  if(by == "age"){
    sub$location <- NULL
  }
  
  # return
  return(sub)
}

# a string of spaces of a given length. Needed to generate properly sortable strings
n_spaces <- function(n){
  spaces <- character(length(n))
  for(i in seq_along(spaces)){
    spaces[i] <- paste(rep(" ", n[i]), collapse = "")
  }
  spaces
}
