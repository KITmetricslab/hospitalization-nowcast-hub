import pandas as pd
import requests
from pathlib import Path
from tqdm.auto import tqdm
tqdm.pandas()

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
path = Path('../data-truth/COVID-19/rolling-sum')
existing_dates = pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')])
df_files = df_files[~df_files.date.isin(existing_dates)]

# download and process new files
for _, row in tqdm(df_files.iterrows(), total=df_files.shape[0]):
    df = pd.read_csv('https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/raw/master/' + 
                          row['filename'])
    df = process_data(df)
    df.to_csv(f'../data-truth/COVID-19/rolling-sum/{row.date.date()}_COVID-19_hospitalization.csv', index = False)

# update available_dates.csv
available_dates = pd.DataFrame({'date': sorted([f.name[:10] for f in path.glob('**/*.csv')])})
available_dates.to_csv('../nowcast_viz_de/plot_data/available_dates.csv', index = False)
    
