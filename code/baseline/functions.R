# compute the point forecast:
# Arguments:
#' @param observed: the observations / reporting triangle matrix
#' @param n_history: how many past observations to use to compute point forecast
#' @param remove observed: should available observations be removed in the return matrix?
#' @return a matrix of the asme dimensions as observed, but with the expectations added
compute_expectations <- function(observed, n_history = 60, remove_observed = TRUE){
  # restrict to last n_history observations
  observed <- tail(observed, n_history)
  nr <- nrow(observed)
  nc <- ncol(observed)
  # initialize results matrix:
  expectation <- observed
  # compute expectations iteratively
  for(co in 2:nc){
    block_top_left <- expectation[1:(nr - co + 1), 1:(co - 1), drop = FALSE]
    block_top <- expectation[1:(nr - co + 1), co, drop = FALSE]
    factor <- sum(block_top)/sum(block_top_left)
    block_left <- expectation[(nr - co + 2):nr, 1:(co - 1), drop = FALSE]
    expectation[(nr - co + 2):nr, co] <- factor*rowSums(block_left)
  }
  # remove the observed values if desired:
  if(remove_observed){
    expectation[!is.na(observed)] <- NA
  }
  # return
  return(expectation)
}

# restrict a reporting triangle to the information available at a given time point t
#' @param observed the observations / reporting triangle matrix
#' @param t said time point
back_in_time <- function(observed, t){
  observed <- observed[1:t, ]
  for(i in 1:(ncol(observed) - 1)){
    observed[t - i + 1, (i + 1):ncol(observed)] <- NA
  }
  observed
}

# wrapper around back_in_time to apply it to a data frame in our usual format
#' @param observed the observations / reporting triangle data.frame
#' @param date date (which data version should be retrieved?)
back_in_time_df <- function(observed, date){
  observed <- observed[observed$date <= date, ]
  cols_value <- grepl("value_", colnames(observed))
  matr <- as.matrix(observed[, cols_value])
  for(i in 0:(ncol(matr) - 2)){
    matr[nrow(matr) - i, (i + 2):ncol(matr)] <- NA
  }
  observed[, cols_value] <- matr
  return(observed)
}

# get the indices corresponding to the nowcasted quantities for a w-day rolling sum
#' @param observed the observations / reporting triangle matrix
#' @param d the nowcast horizon (d days back)
#' @param w the window size for the rolling sum, usually 7 days
#' @param n_history_expectations the number of past observations to use in the computations
indices_nowcast <- function(observed, d, w = 7, n_history_expectations = 60){
  observed <- tail(observed, n_history_expectations)
  res <- is.na(observed)
  res[1:(nrow(observed) - d - w), ] <- FALSE
  if(d > 0){
    res[(nrow(res) - d + 1):nrow(res), ] <- FALSE
  }
  return(res)
}

# fit the size parameter of a negative binomial via maximum likelihood
#' @param x the observed values
#' @param mu the expected values
fit_nb <- function(x, mu){
  nllik <- function(size){-sum(dnbinom(x = x, mu = mu, size = size, log = TRUE), na.rm = TRUE)}
  opt <- optimize(nllik, c(0.1, 1000))
  opt$minimum
}

#' Generate a nowcast
#' @param observed the observations / reporting triangle data.frame
#' @param location the location for which to generate nowcasts
#' @param age_group the age group for which to generate nowcasts
#' @param min_horizon the minimum horizon for which to generate a nowcast (e.g., 2 for up to 2 days before the current date)
compute_nowcast <- function(observed, location = "DE", age_group = "00+",
                            min_horizon = 2, max_horizon = 28, 
                            max_delay = 40, n_history_expectations = 60, n_history_dispersion = 60){
  
  # subset to location and age group:
  observed <- subset(observed, location == "DE" & age_group == "00+")
  
  # reporting triangle as matrix
  matr_observed <- as.matrix(observed[, grepl("value", colnames(observed))])
  # reduce to max delay:
  matr_observed <- cbind(matr_observed[, 1:(max_delay + 1)], 
                         matrix(rowSums(matr_observed[, -(1:(max_delay))], 
                                        na.rm = TRUE), ncol = 1))
  
  colnames(matr_observed)[max_delay + 2] <- paste0("value_", max_delay + 1, "d")
  observed[nrow(matr_observed) - 0:max_delay, max_delay + 2] <- NA
  rownames(matr_observed) <- observed$date
  
  nr <- nrow(matr_observed)
  nc <- ncol(matr_observed)
  
  # compute point forecasts
  expectation_to_add <- # full expectations
    expectation_to_add_already_observed <- # expectations of the sum over already observable quantities
    to_add_already_observed <- # sums over the respective observed quantities
    matrix(NA, nrow = nr, ncol = max_horizon + 1,
           dimnames = list(observed$date, NULL))
  
  # generate point forecasts for current date and n_history_dispersion preceding weeks
  # these are necessary to estimate dispersion parameters
  for(t in (nr - n_history_dispersion):nr){
    matr_observed_temp <- back_in_time(matr_observed, t)
    point_forecasts_temp <- compute_expectations(matr_observed_temp, n_history = n_history_expectations)
    
    for(d in min_horizon:max_horizon){
      inds_nowc <- indices_nowcast(matr_observed_temp, d = d, n_history_expectations = n_history_expectations)
      inds_already_observed <- tail(!is.na(matr_observed[1:t, ]), n_history_expectations)
      
      expectation_to_add[t, d + 1] <- sum(point_forecasts_temp*inds_nowc, na.rm = TRUE)
      expectation_to_add_already_observed[t, d + 1] <- sum(point_forecasts_temp*inds_already_observed*inds_nowc, na.rm = TRUE)
      to_add_already_observed[t, d + 1] <- sum(tail(matr_observed[1:t, ], n_history_expectations)*
                                                 inds_already_observed*inds_nowc, na.rm = TRUE)
    }
  }
  
  # remove last row to estimate dispersion
  expectation_to_add_already_observed <- expectation_to_add_already_observed[-nrow(expectation_to_add_already_observed), ]
  to_add_already_observed <- to_add_already_observed[-nrow(to_add_already_observed), ]
  
  # estimate dispersion
  size_params <- numeric(max_horizon +1)
  for(i in min_horizon:max_horizon){
    size_params[i + 1] <- fit_nb(x = to_add_already_observed[, i + 1], 
                                 mu = expectation_to_add_already_observed[, i + 1])
  }
  
  
  # generate actual nowcast in standard format:
  mu <- expectation_to_add[nrow(expectation_to_add), ]
  forecast_date <- as.Date(tail(observed$date, 1))
  quantile_levels <- c(0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975)
  df_all <- NULL
  
  # run through horizons:
  for(d in min_horizon:max_horizon){
    # by how mch do we need to shift quantiles upwards?
    already_observed <- sum(matr_observed[nrow(matr_observed) - ((d + 6):d), ], na.rm = TRUE)
    
    # data frame for expecations:
    df_mean <- data.frame(location = "DE",
                          age_group = "00+",
                          forecast_date = forecast_date,
                          target_end_date = forecast_date - d,
                          target = paste0(-d, " day ahead inc hosp"),
                          type = "mean",
                          quantile = NA,
                          value = round(mu[d + 1] + already_observed),
                          pathogen = "COVID-19")
    
    # obtain quantiles:
    qtls0 <- qnbinom(quantile_levels, 
                     size = size_params[d + 1], mu = mu[d + 1])
    # shift them up by already oberved values
    qtls <- qtls0 + already_observed
    # data.frame for quantiles:
    df_qtls <- data.frame(location = "DE",
                          age_group = "00+",
                          forecast_date = forecast_date,
                          target_end_date = forecast_date - d,
                          target = paste0(-d, " day ahead inc hosp"),
                          type = "quantile",
                          quantile = quantile_levels,
                          value = qtls,
                          pathogen = "COVID-19")
    
    # join:
    df <- rbind(df_mean, df_qtls)
    
    # add to results from other horizons
    if(is.null(df_all)){
      df_all <- df
    }else{
      df_all <- rbind(df_all, df)
    }
  }
  
  # return
  return(df_all)
}
