from urllib.request import urlretrieve
import pandas as pd
from datetime import datetime,timedelta
shortcuts = ["DE",'DE-BW', 'DE-BY', 'DE-HB', 'DE-HH', 'DE-HE', 'DE-NI', 'DE-NW', 'DE-RP', 'DE-SL', 'DE-SH', 'DE-BB', 'DE-MV', 'DE-SN', 'DE-ST', 'DE-TH', 'DE-BE']
regions = ['Bundesgebiet','Baden-Württemberg', 'Bayern','Bremen','Hamburg','Hessen','Niedersachsen','Nordrhein-Westfalen', 'Rheinland-Pfalz', 'Saarland', "Schleswig-Holstein", "Brandenburg", 'Mecklenburg-Vorpommern', 'Sachsen','Sachsen-Anhalt', 'Thüringen', 'Berlin']
regtup = list(zip(shortcuts,regions))
# Assign url of file: url
url = "/home/johannes/Documents/Projects/hospitalization-nowcast-hub_fork/temp/2021-12-05_Deutschland_adjustierte-COVID-19-Hospitalisierungen.csv"
date = url[112:122]
# get the csv file form the website
urlretrieve(url, 'rki-{0}.csv'.format(date))
def get_rki_data(url):
    # import the csv file as an Dataframe, drop not necessary and rename necessary columns
    df = pd.read_csv('rki-{0}.csv'.format(date), sep=',', parse_dates=["Datum"])
    # drop the most recent two dates and dates older than 28 days
    df = df.drop(df[df["Datum"] >= (datetime.fromisoformat(date) - timedelta(days = 2))].index)
    df = df.drop(df[df["Datum"] <= (datetime.fromisoformat(date) - timedelta(days=29))].index)
    df = df.drop(["Bundesland_Id","Altersgruppe","Bevoelkerung","fixierte_7T_Hospitalisierung_Faelle","aktualisierte_7T_Hospitalisierung_Faelle","fixierte_7T_Hospitalisierung_Inzidenz","aktualisierte_7T_Hospitalisierung_Inzidenz","PS_adjustierte_7T_Hospitalisierung_Inzidenz","UG_PI_adjustierte_7T_Hospitalisierung_Inzidenz","OG_PI_adjustierte_7T_Hospitalisierung_Inzidenz"], axis = 1)
    # rename locations according to submission guidelines
    for tup in regtup:
        df.loc[df["Bundesland"] == tup[1], "Bundesland"] = tup[0]
    # csv for the mean prediction
    df1 = df.drop(["OG_PI_adjustierte_7T_Hospitalisierung_Faelle","UG_PI_adjustierte_7T_Hospitalisierung_Faelle"], axis = 1)
    df1 = df1.rename(columns={"Datum": "target_end_date", "Bundesland" : "location","PS_adjustierte_7T_Hospitalisierung_Faelle":"value"})
    df1["type"] = "mean"
    df1["quantile"] = ""
    # csv for the 0.025 quantile prediction
    df2 = df.drop(["PS_adjustierte_7T_Hospitalisierung_Faelle", "OG_PI_adjustierte_7T_Hospitalisierung_Faelle"], axis = 1)
    df2 = df2.rename(columns={"Datum": "target_end_date", "Bundesland" : "location", "UG_PI_adjustierte_7T_Hospitalisierung_Faelle": "value"})
    df2["type"] = "quantile"
    df2["quantile"] = "0.025"
    # csv for the 0.975 quantile prediction
    df3 = df.drop(["PS_adjustierte_7T_Hospitalisierung_Faelle", "UG_PI_adjustierte_7T_Hospitalisierung_Faelle"], axis = 1)
    df3 = df3.rename(columns={"Datum": "target_end_date", "Bundesland" : "location", "OG_PI_adjustierte_7T_Hospitalisierung_Faelle": "value"})
    df3["type"] = "quantile"
    df3["quantile"] = "0.975"
    # merge these dataframes together
    df_f = pd.concat([df1,df2,df3])
    # add necessary
    df_f["age_group"] = "00+"
    df_f["forecast_date"] = date
    df_f["pathogen"] = "COVID-19"
    # calculate the values of the "target" column
    df_f["forecast_date"] = pd.to_datetime(df_f["forecast_date"])
    df_f["target"] = (df_f['target_end_date'] - df_f['forecast_date']).dt.days
    df_f["target"] = df_f["target"].astype(str) + " day ahead inc hosp"
    #sort the columns and save the dataframe as an csv
    df_finish = df_f[["location","age_group", "forecast_date", "target_end_date", "target", "type","quantile", "value", "pathogen"]]
    df_finish.to_csv("{0}-RKI-weekly_report.csv".format(date), index = False)
    return("")
get_rki_data(url)













