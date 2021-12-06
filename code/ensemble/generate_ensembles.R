# generate ensemble forecasts

# needs to be run from repository root folder
# setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub_fork")

forecast_date <- Sys.Date()

teams <- list.dirs("data-processed", full.names = FALSE)
teams <- teams[nchar(teams) > 0]
teams <- teams[!grepl("NowcastHub", teams)]

included_models <- character(0)

# read in all forecasts:
all_forecasts <- NULL
for(te in teams){
  fls <- list.files(paste0("data-processed/", te))
  file_forecast_date <- paste0(forecast_date, "-", te, ".csv")
  if(file_forecast_date %in% fls){
    dat_temp <- read.csv(paste0("data-processed/", te, "/", file_forecast_date),
                         colClasses = c("forecast_date" = "Date", "target_end_date" = "Date"))
    dat_temp$X <- NULL
    # dat_temp <- subset(dat_temp, target_end_date <= forecast_date - 2)
    
    # plausibility checks:
    tab_locations <- table(dat_temp$location)
    locations_to_remove <- names(tab_locations)[tab_locations < (25*8)]
    if(length(locations_to_remove) > 0){
      dat_temp <- subset(dat_temp, !(location %in% locations_to_remove))
      cat("   Removing locations", locations_to_remove, "for", te, "as nowcasts seem incomplete.\n")
    }
    
    tab_quantiles_horizon <- table(dat_temp$quantile, dat_temp$target, useNA = "ifany")
    check1 <- length(unique(as.vector(tab_quantiles_horizon))) == 1
    if(!check1) cat("   Not all quantiles seem to be present for all addressed horizons", te, "\n")
    
    tab_quantiles_location <- table(dat_temp$quantile, dat_temp$location, useNA = "ifany")
    check2 <- length(unique(as.vector(tab_quantiles_location))) <= 2 # can be different for "DE"
    if(!check2) cat("   Not all quantiles seem to be present for all addressed locations", te, "\n")
    
    tab_quantiles_age <- table(dat_temp$quantile, dat_temp$age_group, useNA = "ifany")
    check3 <- length(unique(as.vector(tab_quantiles_age))) <= 2 # can be different for "DE"
    if(!check3) cat("   Not all quantiles seem to be present for all addressed age groups", te, "\n")
    
    check4 <- all(c(0.025, 0.25, 0.5, 0.75, 0.9, 0.975) %in% dat_temp$quantile) & "mean" %in% dat_temp$type
    if(!check4) cat("   Missing quantile levels or means in", te, "\n")
    
    check5 <- all(paste(0:-28, "day ahead inc hosp") %in% dat_temp$target)
    if(!check5) cat("   Not all horizons between 0 and -28 days addressed in", te, "\n")
    
    if(check1 & check2 & check3 & check4 & check5){
      cat("Including", te, "\n")
      if(is.null(all_forecasts)){
        all_forecasts <- dat_temp
      }else{
        all_forecasts <- rbind(all_forecasts, dat_temp)
      }
      included_models <- c(included_models, te)
    }else{
      cat("Not including", te, "\n")
    }
    
  }else{
    cat("   No file found for", te, "at nowcast date", as.character(forecast_date), "\n")
  }
  cat("------------\n")
}

# split into means and quantiles:
mean_forecasts <- subset(all_forecasts, type == "mean")
quantile_forecasts <- subset(all_forecasts, type == "quantile")

# compute mean ensemble:
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

dir.create("data-processed/NowcastHub-MeanEnsemble/")
write.csv(mean_ensemble, file = paste0("data-processed/NowcastHub-MeanEnsemble/",
                                       forecast_date, "-NowcastHub-MeanEnsemble.csv"), row.names = FALSE)


# compute median ensemble:
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

dir.create("data-processed/NowcastHub-MedianEnsemble/")
write.csv(median_ensemble, file = paste0("data-processed/NowcastHub-MedianEnsemble/",
                                       forecast_date, "-NowcastHub-MedianEnsemble.csv"), row.names = FALSE)

# store included models:
if(file.exists("code/ensemble/documentation_members.csv")){
  dat_included_models <- read.csv("code/ensemble/documentation_members.csv")
  if(forecast_date %in% dat_included_models$forecast_date){
    warning("There is already an entry with the same forecast_date in documentation_members.csv")
  }else{
    to_add <- data.frame(forecast_date = as.character(forecast_date),
                         included_models = paste(included_models, collapse = ";"))
    dat_included_models <- rbind(dat_included_models,
                                 to_add)
    write.csv(dat_included_models, file = "code/ensemble/documentation_members.csv", row.names = FALSE)
  }
}else{
  dat_included_models <- data.frame(forecast_date = as.character(forecast_date),
                       included_models = paste(included_models, collapse = ";"))
  write.csv(dat_included_models, file = "code/ensemble/documentation_members.csv", row.names = FALSE)
}
 
