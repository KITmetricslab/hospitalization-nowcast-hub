import pandas as pd
import numpy as np
from pathlib import Path
from tqdm.auto import tqdm
tqdm.pandas()

def deconvolute(y):
    y = y.to_numpy()
    n = len(y)
    
    A = np.eye(n, n)
    for k in range(1, 7):
        A += np.eye(n, n, k)
    A = A[:-6]
    
    initial_conditions = np.append(np.eye(6), np.zeros((6, n-6)), axis = 1)
    A = np.append(initial_conditions, A, axis = 0)
    
    A_inv = np.linalg.inv(A) 
    x = np.dot(A_inv,y)
    
    return x


path = Path('../data-truth/COVID-19/rolling-sum/')
files = [f.name for f in path.glob('**/*')]

# only consider files that have not been processed before
path2 = Path('../data-truth/COVID-19/deconvoluted/')
existing_dates = pd.unique([f.name[:10] for f in path2.glob('**/*')])
files = [f for f in files if f[:10] not in existing_dates]

df_init = pd.read_csv('../data-truth/COVID-19/initial_values.csv')

for f in tqdm(files, total = len(files)):
    df = pd.read_csv(path/f)
    df.dropna(inplace = True)
    df = df[df.date >= '2020-03-12']
    df = pd.concat([df, df_init])
    df.sort_values(['location', 'age_group', 'date'], inplace = True)
    df.reset_index(drop = True, inplace = True)
    df.value = df.groupby(['location', 'age_group'])['value'].transform(deconvolute).astype(int)
    df.to_csv('../data-truth/COVID-19/deconvoluted/' + f.replace('.csv', '_deconvoluted.csv'), index = False)
    