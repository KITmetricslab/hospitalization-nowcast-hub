# Data
The presented files are updated each day based on [data made available by RKI](https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/tree/master/Archiv).

The folder `rolling-sum` contains the (reformatted) versioned data as provided by RKI, which is the rolling sum over a 7 day period.

The folder `deconvoluted` contains the deconvoluted data, representing the new hospitalizations per day.

The file `COVID-19_hospitalizations.csv` is in "reporting triangle" format. Each row shows the initially reported count and the reported changes (to the previous day) for the following 50 days.
Note: The row sum is the most recent reported count.
