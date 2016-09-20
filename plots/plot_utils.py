import csv
import numpy as np

def read_csv_columns(filename):
    data = np.loadtxt(filename, delimiter=",",skiprows=1,unpack=True)
    cols = dict()
    with open(filename, "r") as f:
        reader = csv.reader(f)
        first = next(reader)
        first = list(map(lambda c: c.strip(), first))
        if len(first) != len(data):
            raise RuntimeError("Column number does not match")
        for i in range(0,len(first)):
            cols[first[i]] = data[i].tolist()
    return cols
