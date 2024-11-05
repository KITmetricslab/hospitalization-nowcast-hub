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

# GitHub repository information
repo_owner = "robert-koch-institut"
repo_name = "COVID-19-Hospitalisierungen_in_Deutschland"
file_path = "Aktuell_Deutschland_COVID-19-Hospitalisierungen.csv"
commits_api_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/commits"

# Set parameters only for pagination
params = {"per_page": 100}

# List to store date and raw file URLs
commit_dates_urls = []
while True:
    response = requests.get(commits_api_url, params=params)
    response.raise_for_status()
    commits = response.json()
    if not commits:
        break
    for commit in commits:
        message = commit["commit"]["message"]
        if message.startswith("Update"):
            date = message.replace("Update ", "")
            commit_hash = commit["sha"]
            raw_url = f"https://raw.githubusercontent.com/{repo_owner}/{repo_name}/{commit_hash}/{file_path}"
            commit_dates_urls.append({"date": date, "raw_url": raw_url})
    if 'next' in response.links:
        params["page"] = params.get("page", 1) + 1
    else:
        break

# Create DataFrame from commit dates and URLs
df_files = pd.DataFrame(commit_dates_urls)
df_files['date'] = pd.to_datetime(df_files['date'])

# only consider files that have not been downloaded before
path = Path('data-truth/COVID-19/rolling-sum')
existing_dates = pd.to_datetime(pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')]))

available_dates = df_files.date

print(available_dates)

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
    filename = df_files[df_files.date == fill_date].raw_url.values[0]
    
    # load and reformat file
    df = pd.read_csv(filename)
    df = process_data(df)
    
    # cut dataframe 
    df = df[df.date <= d.strftime('%Y-%m-%d')]
    
    df.to_csv(f"data-truth/COVID-19/rolling-sum/{d.strftime('%Y-%m-%d')}_COVID-19_hospitalization.csv", index = False)
    
