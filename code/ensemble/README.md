### Explanation of procedure for ensemble building:

- `generate_ensembles.R` is run each hour between 12.30 and 3.30pm CET.
- At each run the script checks whether files for all models listed in `expected_members.csv` are available. If so, the ensemble is computed.
- The ensemble will include all submitted nowcasts fulfilling the following technical criteria:
    - All targets between `-28 day ahead inc hosp` and `0 day ahead inc hosp` are addressed, with complete sets of seven quantiles and the mean.
    - After rounding to the next integer, no nowcast median or mean exceeds the currently known number of hospitalizations for a given Meldedatum.
- In the last run at 3.30pm CET (or, as a matter of fact, any run after 3pm), the script also builds an ensemble if some members are missing, provided that at least three submission files have been found.
- The ensemble nowcast files are then submitted via a PR.
- Acceptance of this PR triggers an update of the visualization data (action "prepare-plot-data") and subsequently a re-deploy of the visualization app ("deploy-shiny").
