# Data

The presented files are updated each day based on [data made available by RKI](https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/tree/master/Archiv).

The folder `rolling-sum` contains the (reformatted) versioned data as provided by RKI, which is the rolling sum over a 7 day period.

The folder `deconvoluted` contains a deconvoluted version of the data, representing the new hospitalizations per day.

The file `COVID-19_hospitalizations.csv` is in "reporting triangle" format. Each row shows the initially reported count for a given *Meldedatum* and the reported changes (to the previous day) for the following 80 days. Note that due to reporting irregularities these can occasionally be negative. The row sum correspond to the most recent total hospitalizations reported for each *Meldedatum*.

The file `COVID-19_hospitalizations_preprocessed.csv` is a processed version of `COVID-19_hospitalizations.csv` where negative values have been re-distributed to the previous observation(s).

Additionally, we provide a timeseries by reporting date (of hospitalization) in `COVID-19_hospitalizations_by_reporting.csv`. This is created by computing the increments between subsequent reports (stratified by age group and Bundesland).

See the wiki entry on [truth data](https://github.com/KITmetricslab/hospitalization-nowcast-hub/wiki/Truth-data) for more details.
