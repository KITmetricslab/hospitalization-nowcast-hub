import pandas as pd
from pathlib import Path

def process_forecasts(df):
    df.loc[df.type == 'quantile', 'quantile'] = 'q' + df.loc[df.type == 'quantile', 'quantile'].astype(str)

    df.loc[df.type == 'mean', 'quantile'] = 'mean'

    df = df.pivot(index = ['location', 'age_group', 'forecast_date', 'target_end_date', 'target',
                           'pathogen', 'model'], values='value', columns='quantile')

    df.columns.name = None
    df.reset_index(inplace=True)

    df['target_type'] = 'hosp'

    df.drop(columns=['forecast_date', 'type', 'target'], inplace = True, errors = 'ignore')

    cols = ['model', 'target_type', 'target_end_date', 'location', 'age_group', 'pathogen']
    df = df[cols + [c for c in df.columns if c not in cols]]

    df.sort_values(['model', 'target_type', 'target_end_date', 'location', 'age_group', 'pathogen'], inplace=True)
    
    return(df)

path = Path('../data-processed')
df_files = pd.DataFrame({'file': [f.name for f in path.glob('**/*') if f.name.endswith('.csv')]})
df_files['date'] = pd.to_datetime(df_files.file.str[:10])
df_files['model'] = df_files.file.str[11:-4]

all_models = df_files.model.unique()

for date in sorted(df_files.date.unique()):
    df_temp = df_files[df_files.date == date]
    missing = [m for m in all_models if m not in df_temp.model.unique()]
    
    for m in missing:
        df_old = df_files[(df_files.model == m) & (df_files.date.between(date - pd.Timedelta(days = 7), date))]
        df_old = df_old[df_old.date == df_old.date.max()]
        df_temp = df_temp.append(df_old)
    
    dfs = []
    for _, row in df_temp.iterrows():
        df_temp2 = pd.read_csv(f'../data-processed/{row.model}/{row.file}', parse_dates = ['target_end_date'])
        df_temp2['model'] = row.model
        dfs.append(df_temp2)

    df = pd.concat(dfs)
    
    df = df[df.target_end_date >= date - pd.Timedelta(days = 28)]

    df = process_forecasts(df)
    df.to_csv(f'plot_data/{str(date)[:10]}_forecast_data.csv', index=False)

# save list of available teams
df_models = pd.DataFrame({'model': all_models})
df_models.to_csv('plot_data/list_teams.csv', index = False)
