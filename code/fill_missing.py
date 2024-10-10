import pandas as pd
import requests
from pathlib import Path

rki_to_iso = {0: 'DE',
              1: 'DE-SH',
              2: 'DE-HH',
              3: 'DE-NI',
              4: 'DE-HB',
              5: 'DE-NW',
              6: 'DE-HE',
              7: 'DE-RP',
              8: 'DE-BW',
              9: 'DE-BY',
              10: 'DE-SL',
              11: 'DE-BE',
              12: 'DE-BB',
              13: 'DE-MV',
              14: 'DE-SN',
              15: 'DE-ST',
              16: 'DE-TH'}

def process_data(df):
    df['location'] = df.Bundesland_Id.replace(rki_to_iso)
    df.drop(columns = ['Bundesland', 'Bundesland_Id', '7T_Hospitalisierung_Inzidenz'], inplace = True, errors = 'ignore')
    df.rename({'Datum': 'date', 'Altersgruppe': 'age_group','7T_Hospitalisierung_Faelle': 'value'}, 
          axis = 'columns', inplace = True)
    df = df[['date', 'location', 'age_group', 'value']]
    return df

# get path of all available files
url = "https://api.github.com/repos/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/git/trees/master?recursive=1"
r = requests.get(url)
res = r.json()

files = [file["path"] for file in res["tree"] if (file["path"].startswith('Archiv/') and file["path"].endswith('Deutschland_COVID-19-Hospitalisierungen.csv'))]
df_files = pd.DataFrame({'filename':files})

# extract dates from filenames
df_files['date'] = df_files.filename.apply(lambda f: f.split('/')[1][:10])
df_files.date = pd.to_datetime(df_files.date)

# only consider files that have not been downloaded before
path = Path('data-truth/COVID-19/rolling-sum')
existing_dates = pd.to_datetime(pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')]))

available_dates = df_files.date

today = pd.Timestamp.today(tz = 'Europe/Berlin').date()
required_dates = pd.date_range(end=today, freq='D', periods=60) # 20 dates leading up to today
missing_dates = required_dates.difference(available_dates) # some might have been filled already
dates_to_fill = missing_dates.difference(existing_dates) # remove dates that have been filled already

print(f"The following dates need to be filled {dates_to_fill.strftime('%Y-%m-%d').to_list()}.")

# for each date that needs to be filled, we load the next available file and cut all entries after the respective date
for d in dates_to_fill:
    fill_date = min(available_dates[available_dates > d])
    
    print(f"To fill {d.strftime('%Y-%m-%d')} we use {fill_date.strftime('%Y-%m-%d')}.")
    
    # file we use to fill missing date
    filename = df_files[df_files.date == fill_date].filename.values[0]
    
    # load and reformat file
    df = pd.read_csv('https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/raw/master/' + 
                          filename)
    df = process_data(df)
    
    # cut dataframe 
    df = df[df.date <= d.strftime('%Y-%m-%d')]
    
    df.to_csv(f"data-truth/COVID-19/rolling-sum/{d.strftime('%Y-%m-%d')}_COVID-19_hospitalization.csv", index = False)
    
