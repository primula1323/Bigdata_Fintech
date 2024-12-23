import numpy as np, pandas as pd
import glob


sumlist = ['LS_CA', 'LS_PHOS', 'LS_FE', 'LS_VA', 'LS_B1', 'LS_B2', 'LS_NIAC', 'LS_VITC']
droplist = ['mod_d', 'LS_CODE', 'LS_NAME', 'LS_AM_OU', 'LS_AM_U', 'LS_AM', 'LS_SUP_1D', 'LS_FQ_U']
livecol = ['ID', 'ID_fam', 'year', 'town_t', 'apt_t', 'sex', 'age', 'age_month', 'incm5', 'ho_incm5', 'edu', 'occp', 'cfam', 'genertn', 'allownc', 'house']


def fileListLoad(path : str) :
    lst = []
    fileList = glob.glob(path)

    for f in fileList :
        df = pd.read_sas(f)
        lst.append(df)

    return lst

def toOneRow(df, slist, dlist):
    df.drop(columns = dlist, inplace=True)
    gdf = df.groupby('ID').agg({
        **{col: 'sum' for col in slist},
        'LS_SUP': 'mean',
        'LS_DUR': 'max',
        'LS_PHOS': 'max'
    }).reset_index()
    return gdf

#def matchFamily(df) :
#    df_