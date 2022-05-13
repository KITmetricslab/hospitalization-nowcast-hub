# This script serves to access old versions of  the file
# data-truth/COVID-19/COVID-19_hospitalizations_preprocessed.csv
# It can be used to run models retrospectively in a "fair" way using the data
# as available on a given date.

library("gh")

# versions of which file to get:
owner <- "KITmetricslab"
repo <- "hospitalization-nowcast-hub"
path <- "data-truth/COVID-19/COVID-19_hospitalizations_preprocessed.csv"

# list in which to store data sets:
data <- list()
# prepare query:
query <- "/repos/{owner}/{repo}/commits?path={path}"

# get list of commits:
commits <-
  gh::gh(query,
         owner = owner,
         repo = repo,
         path = path,
         .limit = Inf
  )

# extract relevant info from list of commits:
shas <- vapply(commits, "[[", "", "sha")
dates <- vapply(commits, function(x) x[["commit"]][["author"]][["date"]], "")
dates <- as.Date(substr(dates, 1, 10)) # convert commit dates to Date
duplicated(dates)
# some dates seem to be in there twice.

# specify dates for which to get data
dates_to_load <- as.Date(c("2022-01-01", "2022-01-02"))
select_commits <- commits

# fill the list:
# each element contains
#   - the date at which the respective data version was published
#   - the data set COVID-19_hospitalizations_preprocessed.csv as of that date
#   - the commit ID
for(i in seq_along(dates_to_load)){
  data[[i]] <- list()
  data[[i]]$date <- dates_to_load[i]
  
  index_commit <- tail(which(dates == dates_to_load[i]), 1) # use last commit of the day
  data[[i]]$commit <- commits[index_commit]
  path_this_commit <- paste("https://github.com", owner, repo, "raw",
                            shas[index_commit], path, sep = "/")
  
  # load rda:
  dat <- read.csv(path_this_commit)
  data[[i]]$data <- dat
  cat(as.character(dates_to_load[i]), "...\n")
}

# name elements:
names(data) <- paste0("data_", dates_to_load)
