import pandas as pd
from pathlib import Path
from tqdm.auto import tqdm
tqdm.pandas()

path = Path('../data-truth/COVID-19/deconvoluted/')
files = sorted([f.name for f in path.glob('**/*')])
dates = [f[:10] for f in files]

dfs = []
for f in files:
    date = f[:10]
    df_temp = pd.read_csv(path/f)
    df_temp = df_temp[df_temp.date == date]
    dfs.append(df_temp)

df = pd.concat(dfs)
df.date = pd.to_datetime(df.date)
dates = pd.Series(df.date.unique())
df.rename(columns = {'value': 'value_0d'}, inplace = True)

for delay in tqdm(range(1, 81), total = 80):
    dfs_delayed = []
    for date in dates:
        date_delayed = date + pd.Timedelta(days = delay)
        if date_delayed <= max(dates):
            df_temp = pd.read_csv(path/f'{date_delayed.date()}_COVID-19_hospitalization_deconvoluted.csv', parse_dates = ['date'])
            df_temp = df_temp[df_temp.date == date]
            dfs_delayed.append(df_temp)
    df_delayed = pd.concat(dfs_delayed)
    df_delayed.rename(columns = {'value': f'value_{delay}d'}, inplace = True)
    df = df.merge(df_delayed, how = 'left')
    
df_latest = pd.read_csv(path/files[-1], parse_dates = ['date'])
df_latest.rename(columns = {'value': f'value_>80d'}, inplace = True)
df = df.merge(df_latest, how = 'left')
    
df.iloc[:, 4:] = df.iloc[:, 3:].diff(axis=1).iloc[:, 1:]

value_cols = [c for c in df.columns if 'value' in c]
for col in value_cols:
    df[col] = df[col].astype('Int64')
    
df.sort_values(['location', 'age_group', 'date'], inplace = True)

df.to_csv('../data-truth/COVID-19/COVID-19_hospitalizations.csv', index = False)
