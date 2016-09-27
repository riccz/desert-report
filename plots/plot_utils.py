import csv
import numpy as np
import os
import subprocess

def build_cmdline(scriptname, args):
    args_str = list(map(lambda k: '--{}={}'.format(k, args[k]), args))
    args_str.insert(0, 'ns')
    args_str.insert(1, scriptname)
    return args_str

def merge_dicts(a, b):
    m = a.copy()
    m.update(b)
    return m

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

def run_ns(scriptname, csvname, fixed_params={}, run_params={}):
    relative_fn = os.path.join("../ns/", csvname)
    if os.path.exists(relative_fn):
        os.remove(relative_fn)

    for r in run_params:
        args = {'csv_output': 1, 'csv_filename': csvname}
        args.update(fixed_params)
        args.update(r)
        subprocess.check_call(build_cmdline(scriptname, args), cwd='../ns/')
