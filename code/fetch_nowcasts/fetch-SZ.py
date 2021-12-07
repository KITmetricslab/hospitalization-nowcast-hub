import pandas as pd

# create lookup tables for region codes and population sizes
abbreviations = ["DE",'DE-BW', 'DE-BY', 'DE-HB', 'DE-HH', 'DE-HE', 
                 'DE-NI', 'DE-NW', 'DE-RP', 'DE-SL', 'DE-SH', 'DE-BB', 
                 'DE-MV', 'DE-SN', 'DE-ST', 'DE-TH', 'DE-BE']

regions = ['Bundesgebiet', 'Baden-Württemberg', 'Bayern','Bremen', 'Hamburg','Hessen',
           'Niedersachsen', 'Nordrhein-Westfalen', 'Rheinland-Pfalz', 'Saarland', "Schleswig-Holstein", "Brandenburg", 
           'Mecklenburg-Vorpommern', 'Sachsen', 'Sachsen-Anhalt', 'Thüringen', 'Berlin']

population = [83138368, 11097559, 13143271, 680058, 1855315, 6289594, 
              8020228, 17933411, 4115030, 985524, 2929662, 2522277, 
              1617005, 4088171, 2179946, 2120909,3663699]

region_dict = dict(zip(regions, abbreviations))
population_dict = dict(zip(abbreviations, population))

# create lookup table for fraction of age groups
age_groups = ["00+", "00-04", "05-14", "15-34", "35-59", "60-79", "80+"]
fractions = [1, 3954455/83138368, 7504156/83138368, 18915114/83138368,
             28676427/83138368, 18150355/83138368, 5934038/83138368]

age_group_fractions = dict(zip(age_groups, fractions))

# get current date
date = pd.to_datetime('today').date()

url = f"https://gfx.sueddeutsche.de/storytelling-assets/datenteam/2021_corona-automation/hosp_incidence/" \
    f"archive/{date}_hosp_incidence_nowcast_sz.csv"

# import csv file as a dataframe
df = pd.read_csv(url, sep=',', parse_dates=["Datum"] )

# remove rows with missing values
df.dropna(inplace = True)

# drop irrelevant columns
df.drop(columns = ["Bundesland_Id","offizielle Hospitalisierungsinzidenz","Obergrenze","Untergrenze"], inplace = True)

# rename locations according to submission guidelines
df.Bundesland.replace(region_dict, inplace = True)

# rename columns
df.rename(columns = {'Datum': 'target_end_date', 'Bundesland': 'location', 'Altersgruppe': 'age_group'}, inplace = True)

# rearrange in long format
df = pd.melt(df, id_vars = ['target_end_date', 'location', 'age_group'], var_name = 'quantile')

df['quantile'].replace({'mean': ''}, inplace = True)

# add column 'type'
df['type'] = 'quantile'
df.loc[df['quantile'] == '', 'type'] = 'mean'

# add necessary columns
df["pathogen"] = "COVID-19"
df["forecast_date"] = pd.to_datetime(date)
df["target"] = (df['target_end_date'] - df['forecast_date']).dt.days
df["target"] = df["target"].astype(str) + " day ahead inc hosp"

# sort columns
df = df[["location","age_group", "forecast_date", "target_end_date", "target", "type","quantile", "value", "pathogen"]]

# sort rows
df.sort_values(["target_end_date","location","age_group","quantile"], inplace = True)

# we only consider stratification by age group on a national level (DE) and by location across all age groups (00+)
df = df.loc[(df.location == "DE") | (df.age_group == "00+")]

# rescale values with lookup tables
df.value = df.apply(lambda row: (population_dict[row.location]/100000) * row.value, axis = 1)
df.value = df.apply(lambda row: age_group_fractions[row.age_group] * row.value, axis = 1)

df.to_csv(f"./data-processed/SZ-hosp_nowcast/{date}-SZ-hosp_nowcast.csv", index=False)
