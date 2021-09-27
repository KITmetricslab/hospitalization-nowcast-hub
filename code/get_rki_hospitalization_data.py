import pandas as pd
import requests
from pathlib import Path
from tqdm.auto import tqdm
tqdm.pandas()

rki_to_fips = {0: 'GM',
               1: 'GM10',
               2: 'GM04',
               3: 'GM06',
               4: 'GM03',
               5: 'GM07',
               6: 'GM05',
               7: 'GM08',
               8: 'GM01',
               9: 'GM02',
               10: 'GM09',
               11: 'GM16',
               12: 'GM11',
               13: 'GM12',
               14: 'GM13',
               15: 'GM14',
               16: 'GM15'}

def process_data(df):
    df['location'] = df.Bundesland_Id.replace(rki_to_fips)
    df.drop(columns = ['Bundesland', 'Bundesland_Id', '7T_Hospitalisierung_Faelle'], inplace = True, errors = 'ignore')
    df.rename({'Datum': 'date', 'Altersgruppe': 'age_group','7T_Hospitalisierung_Inzidenz': 'value'}, 
          axis = 'columns', inplace = True)
    df = df[['date', 'location', 'age_group', 'value']]
    return df


# get path of all available files
url = "https://api.github.com/repos/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/git/trees/master?recursive=1"
r = requests.get(url)
res = r.json()

files = [file["path"] for file in res["tree"] if (file["path"].startswith('Archiv/') and file["path"].endswith('.csv'))]
df_files = pd.DataFrame({'filename':files})

# extract dates from filenames
df_files['date'] = df_files.filename.apply(lambda f: f.split('/')[1][:10])
df_files.date = pd.to_datetime(df_files.date)

# only consider files that have not been downloaded before
path = Path('../data-truth/COVID-19/')
existing_dates = pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')])
df_files = df_files[df_files.date > max(existing_dates)]

# download and process new files
for _, row in tqdm(df_files.iterrows(), total=df_files.shape[0]):
    df = pd.read_csv('https://github.com/robert-koch-institut/COVID-19-Hospitalisierungen_in_Deutschland/raw/master/' + 
                          row['filename'])
    df = process_data(df)
    df.to_csv(f'../data-truth/COVID-19/{row.date.date()}_COVID-19_hospitalization.csv', index = False)
    