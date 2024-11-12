import re
import requests
import pandas as pd
from tqdm import tqdm
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

# GitHub repository information
repo_owner = "robert-koch-institut"
repo_name = "COVID-19-Hospitalisierungen_in_Deutschland"
file_path = "Aktuell_Deutschland_COVID-19-Hospitalisierungen.csv"
commits_api_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/commits"

# Set parameters only for pagination
params = {"per_page": 100}

# List to store date and raw file URLs
commit_dates_urls = []

# Regular expression to match "Update YYYY-MM-DD" format
date_pattern = re.compile(r"^Update \d{4}-\d{2}-\d{2}$")

while True:
    response = requests.get(commits_api_url, params=params)
    response.raise_for_status()
    commits = response.json()
    
    if not commits:
        break
    
    for commit in commits:
        message = commit["commit"]["message"]
        
        # Only process commits with message format "Update YYYY-MM-DD"
        if date_pattern.match(message):
            date = message.replace("Update ", "")
            commit_hash = commit["sha"]
            raw_url = f"https://raw.githubusercontent.com/{repo_owner}/{repo_name}/{commit_hash}/{file_path}"
            commit_dates_urls.append({"date": date, "raw_url": raw_url})
    
    # Check for pagination
    if 'next' in response.links:
        params["page"] = params.get("page", 1) + 1
    else:
        break

# Create DataFrame from commit dates and URLs
df_files = pd.DataFrame(commit_dates_urls)
df_files['date'] = pd.to_datetime(df_files['date'])

# Path for saving downloaded files and checking existing files
path = Path('../data-truth/COVID-19/rolling-sum')
existing_dates = pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')])

df_files = df_files[~df_files.date.dt.strftime('%Y-%m-%d').isin(existing_dates)]

# Download and process files
for _, row in tqdm(df_files.iterrows(), total=df_files.shape[0]):
    # Read file from the raw URL
    df = pd.read_csv(row['raw_url'])
    
    # Process the data (assuming process_data is defined elsewhere)
    df = process_data(df)
    
    # Save processed data with date in filename
    output_path = path / f"{row.date.date()}_COVID-19_hospitalization.csv"
    df.to_csv(output_path, index=False)

# Update available_dates.csv
available_dates = pd.DataFrame({'date': sorted([f.name[:10] for f in path.glob('**/*.csv')])})
available_dates.to_csv('../nowcast_viz_de/plot_data/available_dates.csv', index=False)
