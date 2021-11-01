dat <- read.csv("https://raw.githubusercontent.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/master/Archiv/2021-10-08_Deutschland_COVID-19-Hospitalisierungen.csv")
dat$pop <- dat$X7T_Hospitalisierung_Faelle/dat$X7T_Hospitalisierung_Inzidenz*100000
subset(dat, Bundesland == "Bundesgebiet" & Altersgruppe == "00+")



dat2 <- aggregate(dat$pop, by = list(dat$Bundesland, dat$Altersgruppe), FUN = mean, na.rm = TRUE)
head(dat2)
unique(dat2$Group.1)


dat_truth <- read.csv("/home/johannes/Documents/Projects/hospitalization-nowcast-hub/data-truth/COVID-19/COVID-19_hospitalizations.csv")
unique(dat_truth$location)

mapping_locations <- c("DE" = "Bundesgebiet",
                       "DE-BB" = "Brandenburg",
                       "DE-BE" = "Berlin",
                       "DE-BW" = "Baden-Württemberg",
                       "DE-BY" = "Bayern",
                       "DE-HH" = "Hamburg",
                       "DE-HE" = "Hessen",
                       "DE-HB" = "Bremen",
                       "DE-HH" = "Hamburg",
                       "DE-MV" = "Mecklenburg-Vorpommern",
                       "DE-NI" = "Niedersachsen",
                       "DE-NW" = "Nordrhein-Westfalen",
                       "DE-RP" = "Rheinland-Pfalz",
                       "DE-SH" = "Schleswig-Holstein",
                       "DE-SL" = "Saarland",
                       "DE-SN" = "Sachsen",
                       "DE-ST" = "Sachsen-Anhalt",
                       "DE-TH" = "Thüringen")
mapping_locations2 <- names(mapping_locations)
names(mapping_locations2) <- mapping_locations

dat2$location <- mapping_locations2[dat2$Group.1]
dat2 <- dat2[, c(4, 2, 3)]
colnames(dat2) <- c("location", "age_group", "population")
dat2$population <- round(dat2$population)
write.csv(dat2, file = "../plot_data/population_sizes.csv")


dates <- data.frame(date = unique(dat_truth$date))
write.csv(dates, file = "available_dates.csv")
