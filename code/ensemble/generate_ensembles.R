# generate ensemble forecasts

# needs to be run from repository root folder
# setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub")

# libraries and necessary functions:
install.packages("zoo")
library(zoo)
source("nowcast_viz_de/functions.R")

# nowcasts by default generated for current date:
forecast_date <- Sys.Date()

# read in a vector of names of models for which files should be present when the
# ensemble is run:
expected_members <- read.csv("code/ensemble/expected_members.csv")$model

# get names of all models for which data are available:
models <- list.dirs("data-processed", full.names = FALSE)
models <- models[nchar(models) > 0]
models <- models[!grepl("NowcastHub", models)]


# read in truth data to check that all nowcasts are not below the current value:
dat_truth <- read.csv("data-truth/COVID-19/COVID-19_hospitalizations.csv",
                      colClasses = list("date" = "Date"), stringsAsFactors = FALSE)
truth_states <- truth_as_of_by_strat(dat_truth, by = "state", forecast_date, target_end_dates = forecast_date - (0:28))
truth_age_groups <- truth_as_of_by_strat(dat_truth, by = "age_group", forecast_date, target_end_dates = forecast_date - (0:28))
truth_age_groups <- subset(truth_age_groups, age_group != "00+") # avoid having DE 00+ twice
truth_inc <- rbind(truth_states, truth_age_groups)
colnames(truth_inc)[colnames(truth_inc) == "value"] <- "current_value"
colnames(truth_inc)[colnames(truth_inc) == "date"] <- "target_end_date"

# place holder to check if all forecast files were found
all_files_found <- TRUE # this will be set to FALSE if for any model no file is not found

# check whether after 3pm
time <- as.POSIXct(Sys.time(), tz = "CET")
force_build <- format(time, format = "%H") >= 15

# read in all forecasts:
all_forecasts <- NULL



for(mo in models){
  fls <- list.files(paste0("data-processed/", mo))
  file_forecast_date <- paste0(forecast_date, "-", mo, ".csv")
  if(file_forecast_date %in% fls){
    dat_temp <- read.csv(paste0("data-processed/", mo, "/", file_forecast_date),
                         colClasses = c("forecast_date" = "Date", "target_end_date" = "Date"))
    dat_temp$X <- NULL
    # dat_temp <- subset(dat_temp, target_end_date <= forecast_date - 2)
    dat_temp$model <- mo
    
    # plausibility checks:
    
    # check if quantiles etc are complete per location:
    tab_locations <- table(dat_temp$location[dat_temp$age_group == "00+"])
    locations_to_remove <- names(tab_locations)[tab_locations < (25*8)]
    if(length(locations_to_remove) > 0){
      dat_temp <- subset(dat_temp, !(location %in% locations_to_remove))
      cat("   Removing locations", locations_to_remove, "for", mo, "as nowcasts seem incomplete.\n")
    }
    
    # check if quantiles etc are complete per age group:
    tab_age_groups <- table(dat_temp$age_group[dat_temp$location == "DE"])
    age_groups_to_remove <- names(tab_age_groups)[tab_age_groups < (25*8)]
    if(length(age_groups_to_remove) > 0){
      dat_temp <- subset(dat_temp, !(age_group %in% age_groups_to_remove))
      cat("   Removing age groups", age_groups_to_remove, "for", mo, "as nowcasts seem incomplete.\n")
    }
    
    # check that same number of quantiles is available for each horizon:
    tab_quantiles_horizon <- table(dat_temp$quantile, dat_temp$target, useNA = "ifany")
    check1 <- length(unique(as.vector(tab_quantiles_horizon))) == 1
    if(!check1) cat("   Not all quantiles seem to be present for all addressed horizons", mo, "\n")
    
    # check that same number of quantiles available for each location other than "DE"
    tab_quantiles_location <- table(dat_temp$quantile, dat_temp$location, useNA = "ifany")
    check2 <- length(unique(as.vector(tab_quantiles_location))) <= 2 # can be different for "DE"
    if(!check2) cat("   Not all quantiles seem to be present for all addressed locations", mo, "\n")
    
    # check that same number of quantiles available for each age group other than "00+" 
    tab_quantiles_age <- table(dat_temp$quantile, dat_temp$age_group, useNA = "ifany")
    check3 <- length(unique(as.vector(tab_quantiles_age))) <= 2 # can be different for "DE"
    if(!check3) cat("   Not all quantiles seem to be present for all addressed age groups", mo, "\n")
    
    # check the pre-specified quantiles are all available at all:
    check4 <- all(c(0.025, 0.25, 0.5, 0.75, 0.9, 0.975) %in% dat_temp$quantile) & "mean" %in% dat_temp$type
    if(!check4) cat("   Missing quantile levels or means in", mo, "\n")
    
    # check all horizons are present:
    check5 <- all(paste(0:-28, "day ahead inc hosp") %in% dat_temp$target)
    if(!check5) cat("   Not all horizons between 0 and -28 days addressed in", mo, "\n")
    
    # remove instances where means or medians are below the currently observed value:
    dat_temp2 <- subset(dat_temp, quantile == 0.5 | type == "mean")
    dat_temp2 <- merge(dat_temp2, truth_inc, by = c("target_end_date", "location", "age_group"), all.x = TRUE)
    
    # run through locations and age groups:
    locations_to_remove <- unique(dat_temp2$location[which(round(dat_temp2$value) < dat_temp2$current_value)])
    locations_to_remove <- locations_to_remove[locations_to_remove != "DE"]
    if(length(locations_to_remove) > 0){
      dat_temp <- subset(dat_temp, !(location %in% locations_to_remove))
      cat("   Removing locations", locations_to_remove, "for", mo, "as mean or median is below current value.\n")
    }
    ag_to_remove <- unique(dat_temp2$age_group[which(round(dat_temp2$value) < dat_temp2$current_value)])
    ag_to_remove <- ag_to_remove[ag_to_remove != "00+"]
    if(length(locations_to_remove) > 0){
      dat_temp <- subset(dat_temp, !(age_group %in% ag_to_remove))
      cat("   Removing age groups", ag_to_remove, "for", mo, "as mean or median is below current value.\n")
    }
    # need to handle DE - 00+ separately
    if(any(dat_temp2$location == "DE" & dat_temp2$age_group == "00+" & 
           (round(dat_temp2$value) < dat_temp2$current_value))){
      dat_temp <- subset(dat_temp, !(location == "DE" & age_group == "00+"))
      cat("   Removing DE, 00+ for", mo, "as mean or median is below current value.\n")
    }
    # check if anything is left after removing incomplete or implasible nowcasts:
    check6 <- nrow(dat_temp) > 0
    if(!check6) cat("   No nowcasts left for team", mo, " after finishing plausibility checks.\n")
    
    # add model name (needed for creating documentation file):
    if(nrow(dat_temp) > 0)  dat_temp$model <- mo
    
    # add to overall data.frame with nowcasts if checks passed:
    if(check1 & check2 & check3 & check4 & check5 & check6){
      cat("Including", mo, "\n")
      if(is.null(all_forecasts)){
        all_forecasts <- dat_temp
      }else{
        all_forecasts <- rbind(all_forecasts, dat_temp)
      }
    }else{
      cat("Not including", mo, "\n")
    }
  
  }else{
    cat("   No file found for", mo, "at nowcast date", as.character(forecast_date), "\n")
    if(mo %in% expected_members) all_files_found <- FALSE # if a model which was expected is missing set to FALSE
  }
  cat("------------\n")
}

# only continue if (all expected files found OR a certain time is reached (force_build = TRUE)) AND
# at least three models available:
n_files_found <- length(unique(all_forecasts$model)) # number of models found

if((all_files_found | force_build) & n_files_found >= 3){
  cat("Building ensemble...\n")
  
  cat("     Documenting included models\n")
  
  # document included models:
  
  # create a vector in which to store string on included models:
  locations <- sort(unique(all_forecasts$location))
  age_groups <- unique(all_forecasts$age_group)
  age_groups <- age_groups[age_groups != "00+"]
  included_models <- character(length(locations) + length(age_groups) + 1)
  names(included_models) <- c("forecast_date", locations, paste0("age.", age_groups))
  included_models["forecast_date"] <- as.character(forecast_date)
  
  # fill that vector:
  # for each location and age group add which models were used:
  for(loc in locations){
    subs <- subset(all_forecasts, location == loc & age_group == "00+")
    included_models[loc] <- paste(sort(unique(subs$model)), collapse = ";")
  }
  
  for(ag in age_groups){
    subs <- subset(all_forecasts, age_group == ag & location == "DE")
    included_models[paste0("age.", ag)] <- paste(sort(unique(subs$model)), collapse = ";")
  }
  
  # add to existing csv or create new one:
  if(file.exists("code/ensemble/documentation_members.csv")){
    dat_included_models <- read.csv("code/ensemble/documentation_members.csv")
    if(as.character(forecast_date) %in% dat_included_models$forecast_date){
      warning("There is already an entry with the same forecast_date in documentation_members.csv. Replacing that entry.")
      dat_included_models <- dat_included_models[dat_included_models$forecast_date != forecast_date, ]
    }
    to_add <- data.frame(t(included_models))
    dat_included_models <- rbind(dat_included_models,
                                 to_add)
    write.csv(dat_included_models, file = "code/ensemble/documentation_members.csv", row.names = FALSE)
  }else{
    dat_included_models <- data.frame(t(included_models))
    write.csv(dat_included_models, file = "code/ensemble/documentation_members.csv", row.names = FALSE)
  }
  
  
  # remove model column before actually computing ensembles:
  all_forecasts$model <- NULL
  
  
  # split into means and quantiles:
  mean_forecasts <- subset(all_forecasts, type == "mean")
  quantile_forecasts <- subset(all_forecasts, type == "quantile")
  
  # compute mean ensemble:
  cat("     Compute mean ensemble.\n")
  
  # aggregate means
  means_mean_ensemble <- aggregate(value ~ age_group + location + forecast_date + target_end_date + target + pathogen, 
                                   data = mean_forecasts, FUN = mean, na.rm = TRUE)
  means_mean_ensemble$quantile <- NA
  means_mean_ensemble$type <- "mean"
  
  # aggregate quantiles:
  quantiles_mean_ensemble <- aggregate(value ~ age_group + location + forecast_date + target_end_date + target + pathogen + quantile, 
                                       data = quantile_forecasts, FUN = mean, na.rm = TRUE)
  quantiles_mean_ensemble$type <- "quantile"
  
  # pool:
  mean_ensemble <- rbind(means_mean_ensemble, quantiles_mean_ensemble)
  # round to integer:
  mean_ensemble$value <- round(mean_ensemble$value)
  
  # re-order columns
  mean_ensemble <- mean_ensemble[c("location", "age_group", "forecast_date", "target_end_date", 
                                   "target", "type", "quantile", "value", "pathogen")]
  
  # order by date:
  mean_ensemble <- mean_ensemble[order(mean_ensemble$target_end_date), ]
  
  cat("     Writing out mean ensemble\n")
  dir.create("data-processed/NowcastHub-MeanEnsemble/")
  write.csv(mean_ensemble, file = paste0("data-processed/NowcastHub-MeanEnsemble/",
                                         forecast_date, "-NowcastHub-MeanEnsemble.csv"), row.names = FALSE)
  
  
  # compute median ensemble:
  cat("     computing median ensemble.\n")
  # aggregate means:
  means_median_ensemble <- aggregate(value ~ age_group + location + forecast_date + target_end_date + target + pathogen, 
                                     data = mean_forecasts, FUN = median, na.rm = TRUE)
  means_median_ensemble$quantile <- NA
  means_median_ensemble$type <- "mean"
  
  # aggregate quantiles:
  quantiles_median_ensemble <- aggregate(value ~ age_group + location + forecast_date + target_end_date + target + pathogen + quantile, 
                                         data = quantile_forecasts, FUN = median, na.rm = TRUE)
  quantiles_median_ensemble$type <- "quantile"
  
  # pool:
  median_ensemble <- rbind(means_median_ensemble, quantiles_median_ensemble)
  # round to integer:
  median_ensemble$value <- round(median_ensemble$value)
  
  # re-order columns:
  median_ensemble <- median_ensemble[c("location", "age_group", "forecast_date", "target_end_date", 
                                       "target", "type", "quantile", "value", "pathogen")]
  
  # order by date:
  median_ensemble <- median_ensemble[order(median_ensemble$target_end_date), ]
  
  cat("     Writing out median ensemble.\n")
  dir.create("data-processed/NowcastHub-MedianEnsemble/")
  write.csv(median_ensemble, file = paste0("data-processed/NowcastHub-MedianEnsemble/",
                                           forecast_date, "-NowcastHub-MedianEnsemble.csv"), row.names = FALSE)
}else{
  cat("Not building ensemble as not all expected member forecasts available yet. Reasons:\n")
  if(!force_build  & !all_files_found){
    cat("    Not all expected submissoin files found. Will re-try each hour until 3.30pm CET.\n")
  }
  if(n_files_found < 3){
    cat("    Only", n_files_found, "submission files found.\n")
  }
}





