from urllib.request import urlretrieve
import pandas as pd

# Assign url of file: url
url = "https://raw.githubusercontent.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/master/Archiv/2021-11-24_Deutschland_adjustierte-COVID-19-Hospitalisierungen.csv"
date = url[112:122]
# get the csv file form the website
urlretrieve(url, 'rki-{0}.csv'.format(date))
def get_rki_data(url):
    # import the csv file as an Dataframe, drop not necessary and rename necessary columns
    df = pd.read_csv('rki-{0}.csv'.format(date), sep=',', parse_dates=["Datum"])
    df = df.drop(["7T_Hospitalisierung_Faelle","Bevoelkerung","7T_Hospitalisierung_Inzidenz","PS_adjustierte_7T_Hospitalisierung_Inzidenz","UG_PI_adjustierte_7T_Hospitalisierung_Inzidenz","OG_PI_adjustierte_7T_Hospitalisierung_Inzidenz"], axis = 1)
    # csv for the mean prediction
    df1 = df.drop(["OG_PI_adjustierte_7T_Hospitalisierung_Faelle","UG_PI_adjustierte_7T_Hospitalisierung_Faelle"], axis = 1)
    df1 = df1.rename(columns={"Datum": "target_end_date", "PS_adjustierte_7T_Hospitalisierung_Faelle":"value"})
    df1["type"] = "mean"
    df1["quantile"] = ""
    # csv for the 0.025 quantile prediction
    df2 = df.drop(["PS_adjustierte_7T_Hospitalisierung_Faelle", "OG_PI_adjustierte_7T_Hospitalisierung_Faelle"], axis = 1)
    df2 = df2.rename(columns={"Datum": "target_end_date", "UG_PI_adjustierte_7T_Hospitalisierung_Faelle": "value"})
    df2["type"] = "quantile"
    df2["quantile"] = "0.025"
    # csv for the 0.975 quantile prediction
    df3 = df.drop(["PS_adjustierte_7T_Hospitalisierung_Faelle", "UG_PI_adjustierte_7T_Hospitalisierung_Faelle"], axis = 1)
    df3 = df3.rename(columns={"Datum": "target_end_date", "OG_PI_adjustierte_7T_Hospitalisierung_Faelle": "value"})
    df3["type"] = "quantile"
    df3["quantile"] = "0.975"
    # merge these dataframes together
    df_f = pd.concat([df1.iloc[:29],df2.iloc[:29],df3.iloc[:29]])
    # add necessary
    df_f["location"] = "DE"
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













