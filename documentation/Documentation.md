# Documentation of regular tasks related to the Nowcast Hub

## Keeping an eye on things

- The RKI data is usually updated at around 4am in the morning, but sometimes later. Need to check in the morning whether new data are there, otherwise need to notify teams who may already have run things on old data.
- Teams should submit new nowcasts until 12 noon; accept PRs at the latest 12:15; run `prepare-plot-data` after accepting PRs.



## Updating nowcasts

All nowcasts should be uploaded to a fork first and then added to the main repo via PR. It would be great to automate all of this, but submission checks would still need to be performed. After adding a nowcast, the `prepare-plot-data` job should be run.

### KIT-simple_nowcast

Run script `code/baseline/KIT-simple_nowcast`, commit new file in `data-processed/KIT-simple_nowcast`.

### SZ-hosp_nowcast

Run script `code/fetch_nowcasts/sz-url2nowcast.py`, commit new file in `data-processed/SZ-hosp_nowcast`. This file usually becomes available between 11.30am and 12.

### Epiforecasts-independent

Run script `code/fetch_nowcasts/epiforecasts_url2nowcast.R`, commit new file in `data-processed/Epifprecasts-independent`. This file usually becomes available at 11am.

### RKI-weekly_report

Run script `code/fetch_nowcasts/RKI_weekly_report2nowcast.py`, commit new file in `data-processed/RKI-weekly_report`. Currently only available on Thursdays (or, with a slight delay, Fridays), but should soon be available every day. Currently requires manual adaptation of date inside file as I never know whether it will be available on Thursday or Friday.

## Update ensemble

Once all submissions for a given day are there (excluding RKI, which will is not complete enough to be inlcuded into the ensemble; should be the case by 12 noon) the ensemble can be created:
- Run `code/ensemble/generate_ensembles.R`
- Commit `data-processed/NowcastHub-MeanEnsemble`, `data-processed/NowcastHub-MeanEnsemble` and `code/ensemble/documentation_members.csv`

