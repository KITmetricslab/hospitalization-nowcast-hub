import pandas as pd
from pathlib import Path

path = Path('../data-truth/COVID-19/deconvoluted/')
files = [f.name for f in path.glob('**/*')]

dfs = []
for f in files:
    temp = pd.read_csv(path/f)
    temp = temp.groupby(['location', 'age_group'], as_index = False).value.sum()
    temp ['date'] = pd.to_datetime(f[:10])
    dfs.append(temp)
df = pd.concat(dfs, ignore_index = True)

df = df.sort_values(by=['location', 'age_group', 'date'], ignore_index = True)

df['value'] = df.groupby(['location', 'age_group'])['value'].diff()
df.dropna(inplace = True)
df.value = df.value.astype(int)

df['value_7d'] = df.groupby(['location', 'age_group']).value.transform(lambda x: x.rolling(7).sum())
df.value_7d = df.value_7d.astype('Int64')

df = df[['location', 'age_group', 'date', 'value', 'value_7d']]

df.to_csv('../data-truth/COVID-19/COVID-19_hospitalizations_by_reporting.csv', index = False)
