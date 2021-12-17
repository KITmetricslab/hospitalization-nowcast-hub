import os
import pandas as pd

today = pd.to_datetime('today').date()
filename = f'data-processed/SU-hier_bayes/{today}-SU-hier_bayes.csv'

if os.path.exists(filename):
    print(f'Nowcast for today ({today}) has already been added.')
else:
    df = pd.read_csv('https://raw.githubusercontent.com/FelixGuenther/hospitalization-nowcast-hub/main/' + filename)
    df.to_csv(filename, index = False)
    