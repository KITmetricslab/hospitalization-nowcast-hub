import os
import pandas as pd

today = pd.to_datetime('today').date()
filename = f'LMU_StaBLab-GAM_nowcast/{today}-LMU_StaBLab-GAM_nowcast.csv'

if os.path.exists(filename):
    print(f'Nowcast for today ({today}) has already been added.')
else:
    df = pd.read_csv('https://raw.githubusercontent.com/MaxWeigert/hospitalization-nowcast-hub/main/data-processed/' + filename)
    df.to_csv('./data-processed/' + filename, index = False)
    