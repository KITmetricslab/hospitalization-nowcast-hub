from urllib.request import urlretrieve
from datetime import date

today = date.today().strftime('%Y-%m-%d')

# Import pandas
import pandas as pd

# Assign url of file: url
url = "https://gfx.sueddeutsche.de/storytelling-assets/datenteam/2021_corona-automation/hosp_incidence/archive/" + today + "_hosp_incidence_nowcast_sz.csv"
date = url[104:114]
# Save file locally
urlretrieve(url, 'sz.{0}.csv'.format(date))
# get the fractions of the age groups to calculate the Incidence in absolute Numbers
age_tup = ["00+","00-04","05-14","15-34","35-59","60-79","80+"]
frac_tup = [1,(3954455/83138368),(7504156/83138368),(18915114/83138368),(28676427/83138368),(18150355/83138368),(5934038/83138368)]
fractions = list(zip(age_tup,frac_tup))
# get the Shortcuts for the states to rename them appropriately later
shortcuts = ["DE",'DE-BW', 'DE-BY', 'DE-HB', 'DE-HH', 'DE-HE', 'DE-NI', 'DE-NW', 'DE-RP', 'DE-SL', 'DE-SH', 'DE-BB', 'DE-MV', 'DE-SN', 'DE-ST', 'DE-TH', 'DE-BE']
regions = ['Bundesgebiet','Baden-Württemberg', 'Bayern','Bremen','Hamburg','Hessen','Niedersachsen','Nordrhein-Westfalen', 'Rheinland-Pfalz', 'Saarland', "Schleswig-Holstein", "Brandenburg", 'Mecklenburg-Vorpommern', 'Sachsen','Sachsen-Anhalt', 'Thüringen', 'Berlin']
population = [83138368, 11097559, 13143271, 680058, 1855315, 6289594, 8020228, 17933411, 4115030, 985524, 2929662, 2522277, 1617005, 4088171, 2179946, 2120909,3663699]
loctup = list(zip(shortcuts,regions,population))
# Read file into a DataFrame and print its head
def get_sz(url):
    df = pd.read_csv('sz.{0}.csv'.format(date), sep=',',parse_dates= ["Datum"] )
    # get rid of non nowcasts
    df = df.dropna(axis = 0)
    # drop irrelevant columns
    df = df.drop(["Bundesland_Id","offizielle Hospitalisierungsinzidenz","Obergrenze","Untergrenze"], axis = 1)
    # get the quantiles from a wide data format into a long one
    quant = ["0.025", "0.1", "0.25", "0.5", "0.75", "0.9", "0.975","mean"]
    df_r = pd.DataFrame(columns=["target_end_date", "location", "age_group", "value"])
    for i in quant[:]:
        help = ["0.025", "0.1", "0.25", "0.5", "0.75", "0.9", "0.975", "mean"]
        help.remove(i)
        df_h = df.drop(labels=help, axis=1)
        df_h = df_h.rename(
            columns={"Datum": "target_end_date", "Bundesland": "location", "Altersgruppe": "age_group", i: "value"})
        if i == "mean":
            df_h["type"] = i
            df_h["quantile"] = ""
        else:
            df_h["quantile"] = i
            df_h["type"] = "quantile"
        df_r = pd.concat([df_r, df_h])
    #add necessary columns
    df_r["pathogen"] = "COVID-19"
    df_r["forecast_date"] = date
    df_r["forecast_date"] = pd.to_datetime(df_r["forecast_date"])
    df_r["target"] = (df_r['target_end_date'] - df_r['forecast_date']).dt.days
    df_r["target"] = df_r["target"].astype(str) + " day ahead inc hosp"
    df_big = df_r[["location","age_group", "forecast_date", "target_end_date", "target", "type","quantile", "value", "pathogen"]]
    df_big = df_big.sort_values(["target_end_date","location","age_group","quantile"])
    # rename the locations with the right code
    for tup in loctup:
        df_big.loc[df_big["location"] == tup[1], "location"] = tup[0]
        df_big.loc[df_big["location"] == tup[0], "value"] = (tup[2] /100000) * df_big.loc[df_big["location"] == tup[0], "value"]
    df_f = df_big[(df_big["location"] == "DE") | (df_big["age_group"] == "00+")]
    # calculate the absolute age group numbers
    for tup2 in fractions:
        df_f.loc[df_f["age_group"] == tup2[0], "value"] = tup2[1] * df_f.loc[df_f["age_group"] == tup2[0], "value"]
    df_f.to_csv("../../data-processed/SZ-hosp_nowcast/{0}-SZ-hosp_nowcast.csv".format(date), index=False)
    return("")
get_sz(url)
