import numpy as np
import pandas as pd
from pathlib import Path

def process_forecasts(df):
    df.loc[df.type == 'quantile', 'quantile'] = 'q' + df.loc[df.type == 'quantile', 'quantile'].astype(str)

    df.loc[df.type == 'mean', 'quantile'] = 'mean'

    df = df.pivot(index = ['location', 'age_group', 'forecast_date', 'target_end_date', 'target',
                           'pathogen', 'model', 'retrospective'], values='value', columns='quantile')

    df.columns.name = None
    df.reset_index(inplace=True)

    df['target_type'] = 'hosp'

    df.drop(columns=['type', 'target'], inplace = True, errors = 'ignore')
    
    # add columns for quantiles if they are not present in submissions
    required_quantiles = ['q0.025', 'q0.1', 'q0.25', 'q0.5', 'q0.75', 'q0.9', 'q0.975']
    missing_quantiles = [q for q in required_quantiles if q not in df.columns]
    for q in missing_quantiles:
        df[q] = np.nan

    df = df[['model', 'target_type', 'forecast_date', 'target_end_date', 'location', 'age_group', 'pathogen', 'mean', 
             'q0.025', 'q0.1', 'q0.25', 'q0.5', 'q0.75', 'q0.9', 'q0.975', 'retrospective']]

    df.sort_values(['model', 'target_type', 'forecast_date', 'target_end_date', 'location', 'age_group', 'pathogen'], inplace=True)
    
    return(df)

path1 = Path('../data-processed')
df1 = pd.DataFrame({'file': [f.name for f in path1.glob('**/*.csv')]})
df1['path'] = [str(f) for f in path1.glob('**/*.csv')]

path2 = Path('../data-processed_retrospective')
df2 = pd.DataFrame({'file': [f.name for f in path2.glob('**/*.csv')]})
df2['path'] = [str(f) for f in path2.glob('**/*.csv')]

df_files = pd.concat([df1, df2], ignore_index = True)

df_files['date'] = pd.to_datetime(df_files.file.str[:10])
df_files['model'] = df_files.file.str[11:-4]
df_files['retrospective'] = df_files.path.str.contains('retrospective')

all_models = df_files.model.unique()
dates = pd.date_range(df_files.date.min(), pd.to_datetime('today'))

for date in dates:
    df_temp = df_files[df_files.date == date]
    missing = [m for m in all_models if m not in df_temp.model.unique()]
    
    for m in missing:
        df_old = df_files[(df_files.model == m) & (df_files.date.between(date - pd.Timedelta(days = 7), date))]
        df_old = df_old[df_old.date == df_old.date.max()]
        df_temp = pd.concat([df_temp, df_old])
    
    dfs = []
    for _, row in df_temp.iterrows():
        df_temp2 = pd.read_csv(f'../data-processed{"_retrospective" if row.retrospective else ""}/{row.model}/{row.file}', 
                               parse_dates = ['target_end_date'])
        df_temp2['model'] = row.model
        df_temp2['retrospective'] = row.retrospective
        dfs.append(df_temp2)
        
    if len(dfs) > 0:
        df = pd.concat(dfs)

        df = df[df.target_end_date >= date - pd.Timedelta(days = 28)]

        df = process_forecasts(df)
        df.to_csv(f'plot_data/{str(date)[:10]}_forecast_data.csv', index=False)

# save list of available teams
df_models = pd.DataFrame({'model': all_models})
df_models.to_csv('plot_data/list_teams.csv', index = False)

# save list of all plot data files
df_plot_data = pd.DataFrame({'file': [f.name for f in Path('plot_data').glob('**/*forecast_data.csv')]})
df_plot_data.to_csv('plot_data/list_plot_data.csv', index = False)
