import pandas as pd
from tqdm.auto import tqdm
tqdm.pandas()

df = pd.read_csv('../data-truth/COVID-19/COVID-19_hospitalizations.csv')

for i, row in tqdm(df.iterrows(), total = len(df)):
    to_subtract = 0
    for j, value in row[:2:-1].items():
        value += to_subtract
        if value < 0:
            to_subtract = value
            df.loc[i, j] = 0
        else:
            df.loc[i, j] = value
            to_subtract = 0
            
value_cols = [c for c in df.columns if 'value' in c]
for col in value_cols:
    df[col] = df[col].astype('Int64')
    
df.sort_values(['location', 'age_group', 'date'], inplace = True)

df.to_csv('../data-truth/COVID-19/COVID-19_hospitalizations_preprocessed.csv', index = False)
