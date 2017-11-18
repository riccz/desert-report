#!/usr/bin/env python3

import argparse
import matplotlib.pyplot as plt
import numpy as np
import sys

from plot_utils import *

parser = argparse.ArgumentParser()
parser.add_argument('--run', dest='run', action='store_true')
parser.add_argument('--no-run', dest='run', action='store_false')
parser.set_defaults(run=True)
args = parser.parse_args()

### Throughput vs distance, various winsizes ###
dists = np.linspace(25, 120, 25)
ws = range(1,11)
if args.run:
    for w in ws:
        fname = 'thr_dist_{}.csv'.format(w)
        run_ns('single_hop.tcl', fname,
               {'winsize':w, 'CBR_dupack_thresh':1 },#max(1,w-1) },
               map(lambda d: {'node_dist':d}, dists))

### Plot the PDR ###
plt.figure(4)
for w in ws:
    cols = read_csv_columns('../ns/thr_dist_{}.csv'.format(w))
    plt.plot(dists, cols['data_pdr'])
    plt.plot(dists, cols['ack_pdr'])



        
#cols = read_csv_columns('../ns/thr_dist_1.csv')
#ideal_thr = [87768*p[0] for p in zip(cols['data_pdr'], cols['ack_pdr'])]

plt.figure(1)
plt.figure(2)
#plt.plot(cols['node_dist'], ideal_thr, label='Ideal')


coded_rate = 87768
T_pkt = (1000+24+4)*8/coded_rate
T_ack = (24+4)*8/coded_rate
prop = dists / 1500
T_list = 1e-6


for w in ws:
    cols = read_csv_columns('../ns/thr_dist_{}.csv'.format(w))
    plt.figure(1)
    plt.plot(cols['node_dist'], cols['throughput'],
             label='winsize={}'.format(w))

    plt.figure(2)
    effective_rate = coded_rate * w * T_pkt / (2*prop + w*(T_pkt + T_ack + 2*T_list))
    pdr_prod = np.multiply(cols['data_pdr'], cols['ack_pdr'])
    ideal_thr = np.multiply(effective_rate, pdr_prod)
    plt.plot(dists, effective_rate, label="k={}".format(w))

    plt.figure(3)
    plt.plot(dists, ideal_thr, label="k={}".format(w))


plt.figure(1)
plt.xlim(25,120)
plt.ylim(20000,90000)
plt.legend()
plt.grid(True)
plt.savefig('thr_dist.eps')

plt.figure(2)
plt.xlim(25,120)
plt.ylim(20000,90000)
plt.grid(True)
plt.legend()

plt.figure(3)
plt.xlim(25,120)
plt.ylim(20000,90000)
plt.grid(True)
plt.legend()


plt.show()
    
sys.exit(0)

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

plt.figure(1)
plt.figure(2)
plt.figure(3)
for r in runs:
    filename = "../ns/thr_win_{}.csv".format(r["run_num"])
    cols = plot_utils.read_csv_columns(filename)

    plt.figure(1)
    plt.plot(cols["winsize"], cols["throughput"], label=r['run_num'])

    plt.figure(2)
    plt.plot(cols["winsize"], cols["data_pdr"], label=r['run_num'])

    plt.figure(3)
    plt.plot(cols["winsize"], cols["ack_pdr"], label=r['run_num'])

plt.figure(1)
plt.legend()

plt.figure(2)
plt.legend()

plt.figure(3)
plt.legend()

plt.show()

