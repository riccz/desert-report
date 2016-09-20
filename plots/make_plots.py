#!/usr/bin/env python3

import argparse
import glob
import matplotlib.pyplot as plt
import os
import subprocess

import plot_utils

parser = argparse.ArgumentParser()
parser.add_argument('--run', dest='run', action='store_true')
parser.add_argument('--no-run', dest='run', action='store_false')
parser.set_defaults(run=True)
args = parser.parse_args()

### Throughput vs winsize, various time+wait combinations ###
wl_vals = [0, 1e-6, 1e-3]
runs = []
run_num = 0
for v1 in wl_vals:
    for v2 in wl_vals:
        runs.append({"wait_time": v1, "listen_time": v2, "run_num": run_num})
        run_num += 1

if args.run:
    for f in glob.glob("../ns/thr_win_?*.csv"):
        os.remove(f)        
    for r in runs:
        filename = "thr_win_{}.csv".format(r["run_num"])
        for w in range(1,51):
            cmdline = ("ns single_hop.tcl "
                       "--wait_time={:e} --listen_time={:e} "
                       "--winsize={} --csv_filename={} --csv_output=1")
            cmdline = cmdline.format(r["wait_time"], r["listen_time"], w, filename)
            subprocess.check_call(cmdline.split(), cwd='../ns/')

plt.figure()    
for r in runs:
    filename = "../ns/thr_win_{}.csv".format(r["run_num"])
    cols = plot_utils.read_csv_columns(filename)

    
    plt.title("run {}".format(r['run_num']))
    plt.plot(cols["winsize"], cols["throughput"])

plt.show()
