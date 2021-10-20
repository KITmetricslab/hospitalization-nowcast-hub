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

forecast_dates = pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')])

models = [f.name for f in path.iterdir() if not f.name.endswith('.csv')]

for date in forecast_dates:
    dfs = []
    for m in models:
        p = path/m
        forecasts = [file.name for file in p.iterdir() if date in file.name]
        for f in forecasts:
            df_temp = pd.read_csv(path/m/f)
            df_temp['model'] = m
            dfs.append(df_temp)

    df = pd.concat(dfs)
    df = process_forecasts(df)
    df.to_csv(f'plot_data/{date}_forecast_data.csv', index=False)
    