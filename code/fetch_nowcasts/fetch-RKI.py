import pandas as pd

abbreviations = ["DE",'DE-BW', 'DE-BY', 'DE-HB', 'DE-HH', 'DE-HE', 
                 'DE-NI', 'DE-NW', 'DE-RP', 'DE-SL', 'DE-SH', 'DE-BB', 
                 'DE-MV', 'DE-SN', 'DE-ST', 'DE-TH', 'DE-BE']

regions = ['Bundesgebiet','Baden-Württemberg', 'Bayern','Bremen','Hamburg','Hessen','Niedersachsen','Nordrhein-Westfalen', 'Rheinland-Pfalz', 'Saarland', "Schleswig-Holstein", "Brandenburg", 'Mecklenburg-Vorpommern', 'Sachsen','Sachsen-Anhalt', 'Thüringen', 'Berlin']

# dictionary to map region names to abbreviations
region_dict = dict(zip(regions, abbreviations))

# get current date
date = pd.to_datetime('today').date()

url = "https://raw.githubusercontent.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/master/" \
    f"Archiv/{date}_Deutschland_adjustierte-COVID-19-Hospitalisierungen.csv"   

# import the csv file as an Dataframe
df = pd.read_csv(url, sep=',', parse_dates=["Datum"])

# drop the most recent two dates and dates older than 28 days
df = df[df.Datum.dt.date.between(date - pd.Timedelta(days = 28), date - pd.Timedelta(days = 2), inclusive = 'left')]

# rename locations according to submission guidelines
df.Bundesland.replace(region_dict, inplace = True)

# drop unnecessary  columns
df.drop(columns = ["Bundesland_Id","Altersgruppe","Bevoelkerung","fixierte_7T_Hospitalisierung_Faelle", 
                   "aktualisierte_7T_Hospitalisierung_Faelle","fixierte_7T_Hospitalisierung_Inzidenz",
                   "aktualisierte_7T_Hospitalisierung_Inzidenz","PS_adjustierte_7T_Hospitalisierung_Inzidenz",
                   "UG_PI_adjustierte_7T_Hospitalisierung_Inzidenz","OG_PI_adjustierte_7T_Hospitalisierung_Inzidenz"], 
        inplace = True)

df.rename(columns = {'Datum': 'target_end_date', 'Bundesland': 'location'}, inplace = True)

# rearrange in long format
df = pd.melt(df, id_vars = ['target_end_date', 'location'], var_name = 'quantile')

# add column 'quantile'
df['quantile'].replace({'PS_adjustierte_7T_Hospitalisierung_Faelle': '',
                        'UG_PI_adjustierte_7T_Hospitalisierung_Faelle': '0.025',
                        'OG_PI_adjustierte_7T_Hospitalisierung_Faelle': '0.975'},
                       inplace = True)

# add column 'type'
df['type'] = 'quantile'
df.loc[df['quantile'] == '', 'type'] = 'mean'

# add necessary
df["age_group"] = "00+"
df["forecast_date"] = date
df["pathogen"] = "COVID-19"

# calculate the values of the "target" column
df["forecast_date"] = pd.to_datetime(df["forecast_date"])
df["target"] = (df['target_end_date'] - df['forecast_date']).dt.days
df["target"] = df["target"].astype(str) + " day ahead inc hosp"

# sort the columns
df = df[["location","age_group", "forecast_date", "target_end_date", "target", "type","quantile", "value", "pathogen"]]

# export to csv
df.to_csv(f"./data-processed/RKI-weekly_report/{date}-RKI-weekly_report.csv", index = False)