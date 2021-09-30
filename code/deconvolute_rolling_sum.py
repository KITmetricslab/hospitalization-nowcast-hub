import pandas as pd
import numpy as np
from pathlib import Path
from tqdm.auto import tqdm
tqdm.pandas()

def deconvolute(y):
    y = y.to_numpy()
    start = np.repeat(y[0]//7, 6)
    if y[0]%7 != 0:
        start += np.append(np.repeat(0, 7 - y[0]%7), np.repeat(1, y[0]%7 -1))
    y = np.append(start, y)
    n = len(y)
    
    A = np.eye(n, n)
    for k in range(1, 7):
        A += np.eye(n, n, k)
    A = A[:-6]
    
    initial_conditions = np.append(np.eye(6), np.zeros((6, n-6)), axis = 1)
    A = np.append(initial_conditions, A, axis = 0)
    
    A_inv = np.linalg.inv(A) 
    x = np.dot(A_inv,y)
    x = x[6:]
    
    return x


path = Path('../data-truth/COVID-19/rolling-sum/')
files = [f.name for f in path.glob('**/*')]

# only consider files that have not been processed before
path2 = Path('../data-truth/COVID-19/deconvoluted/')
existing_dates = pd.unique([f.name[:10] for f in path2.glob('**/*')])
files = [f for f in files if f[:10] not in existing_dates]

for f in tqdm(files, total = len(files)):
    df = pd.read_csv(path/f)
    df.dropna(inplace = True)
    df.sort_values(['location', 'age_group', 'date'], inplace = True)
    df.value = df.groupby(['location', 'age_group'])['value'].transform(deconvolute)
    df.to_csv('../data-truth/COVID-19/deconvoluted/' + f.replace('.csv', '_deconvoluted.csv'), index = False)
    