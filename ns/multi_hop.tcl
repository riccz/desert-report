# -*- mode: tcl; indent-tabs-mode: t; tab-width: 8; tcl-indent-level: 8; tcl-continued-indent-level: 8; -*-
#
# Copyright (c) 2015 Regents of the SIGNET lab, University of Padova.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University of Padova (SIGNET lab) nor the
#    names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# This script is used to test UW-OPTICAL-Propagation and UW-OPTICAL-PHY with
# addition of ambient light noise provided by Hydrolight LUT.
# There are 2 nodes that can transmit each other packets in a point 2 point
# netwerk with a CBR (Constant Bit Rate) Application Module
#
# UW/Optical/Channel and UW/OPTICAL/PHY is used for PHY layer and channel
#
# Author: Filippo Campagnaro <campagn1@dei.unipd.it>
# Version: 1.0.0
#
#
# Stack of the nodes
#   +-------------------------+
#   |  7. UW/CBR              |
#   +-------------------------+
#   |  6. UW/UDP              |
#   +-------------------------+
#   |  5. UW/STATICROUTING    |
#   +-------------------------+
#   |  4. UW/IP               |
#   +-------------------------+
#   |  3. UW/MLL              |
#   +-------------------------+
#   |  2. UW/CSMA_ALOHA       |
#   +-------------------------+
#   |  1. UW/OPTICAL/PHY      |
#   +-------------------------+
#           |         |
#   +-------------------------+
#   |   UW/Optical/Channel    |
#   +-------------------------+

######################################
# Flags to enable or disable options #
######################################
set opt(verbose) 		1
set opt(trace_files)		1
set opt(bash_parameters) 	1

#####################
# Library Loading   #
#####################
load libMiracle.so
load libMiracleWirelessCh.so
load libMiracleBasicMovement.so
load libuwip.so
load libuwstaticrouting.so
load libmphy.so
load libmmac.so
load libuwtdma.so
load libuwmll.so
load libuwudp.so
load libuwcbrmh.so
load libuwoptical_propagation.so
load libuwoptical_channel.so
load libuwoptical_phy.so

#############################
# NS-Miracle initialization #
#############################
# You always need the following two lines to use the NS-Miracle simulator
set ns [new Simulator]
$ns use-Miracle

##################
# Tcl variables  #
##################
set opt(start_clock) [clock seconds]

set opt(starttime)          1
set opt(stoptime)           101
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation

set opt(maxinterval_)       10.0

set opt(freq)              10000000
set opt(bw)                100000
set opt(bitrate)           1000000
set opt(txpower)           50; # Watt
set opt(opt_acq_db)        10
set opt(temperatura)       293.15 ; # in Kelvin
set opt(txArea)            0.000010
set opt(rxArea)            0.0000011 ; # receveing area, it has to be the same for optical physical and propagation
set opt(c)                 0.4 ; # seawater attenation coefficient
set opt(theta)             1
set opt(id)                [expr 1.0e-9]
set opt(il)                [expr 1.0e-6]
set opt(shuntRes)          [expr 1.49e9]
set opt(sensitivity)       0.26
#set opt(LUTpath)           "dbs/optical_noise/LUT.txt"
set opt(LUTpath)           "dbs/optical_noise/scenario2/Pc0.4ab_depth40.ascii"

set rng [new RNG]

if {$opt(bash_parameters)} {
	if {$argc != 7} {
		puts "The script requires 7 inputs:"
		puts "ns nhops_optical.tcl <seed> <packet period> <packet length> <src-dst distance> <num. of nodes> <num. of slots> <guard interval>"
		puts "If you want to leave the default values, please set to 0"
		puts "the value opt(bash_parameters) in the tcl script"
		puts "Please try again."
		return
	} else {
		set opt(seedcbr)    [lindex $argv 0]
		set opt(cbr_period) [lindex $argv 1]
		set opt(pktsize)    [lindex $argv 2]
		set opt(tot_dist)   [lindex $argv 3]
		set opt(nn)         [lindex $argv 4]
		set opt(num_slots)  [lindex $argv 5]
		set opt(guard_time)  [lindex $argv 6]
		$rng seed         $opt(seedcbr)
	}
} else {
	set opt(seedcbr)    1
	set opt(cbr_period) [expr 1e-3]
	set opt(pktsize)    1000
	set opt(tot_dist)   100
	set opt(nn)         21
	set opt(num_slots)  5
	set opt(guard_time)  0.001
	$rng seed         $opt(seedcbr)
}

set opt(use_reed_solomon) 0
set opt(rs_n) 5
set opt(rs_k) 5

set opt(use_arq) 1
set opt(use_relays) 0
set opt(use_rtt_timeout) 0
set opt(dupack_thresh) 2
set opt(cbr_timeout) 10000.0
set opt(cbr_window) \
	[expr round(ceil($opt(num_slots)/2.0 + $opt(nn) + \
				 ($opt(nn)-2) * ($opt(num_slots)-1) + 1)) ]

# Set the slot duration to transmit exactly one packet (with headers + coding)
# and one ACK if ARQ is enabled
set packet_header_size 4; #UDP+IP
set ack_size [expr 24+$packet_header_size]; # CBR header+UDP+IP
set packet_time [expr ($opt(pktsize) + $packet_header_size) * 8.0 / $opt(bitrate)]
if $opt(use_arq) {
	set packet_time [expr $packet_time + $ack_size * 8.0 / $opt(bitrate)]
}
if $opt(use_reed_solomon) {
	set packet_time [expr $packet_time * $opt(rs_n) / $opt(rs_k)]
}
set opt(frame_duration) [expr ($packet_time + $opt(guard_time)) * $opt(num_slots)]

set rnd_gen [new RandomVariable/Uniform]
$rnd_gen use-rng $rng
if {$opt(trace_files)} {
	set opt(tracefilename) "./nhops_optical.tr"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "./nhops_optical.cltr"
	set opt(cltracefile) [open $opt(tracefilename) w]
} else {
	set opt(tracefilename) "/dev/null"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "/dev/null"
	set opt(cltracefile) [open $opt(cltracefilename) w]
}

#########################
# Module Configuration  #
#########################
Module/UW/CBRMH_SRC set PoissonTraffic_      1
Module/UW/CBRMH_SRC set dupack_thresh        $opt(dupack_thresh)
Module/UW/CBRMH_SRC set packetSize_          $opt(pktsize)
Module/UW/CBRMH_SRC set period_              $opt(cbr_period)
Module/UW/CBRMH_SRC set timeout_             $opt(cbr_timeout)
Module/UW/CBRMH_SRC set tx_window            $opt(cbr_window)
Module/UW/CBRMH_SRC set use_arq              $opt(use_arq)
Module/UW/CBRMH_SRC set use_rtt_timeout      $opt(use_rtt_timeout)

Module/UW/CBRMH_SINK set rx_window            $opt(cbr_window)
Module/UW/CBRMH_SINK set use_arq              $opt(use_arq)

Module/UW/CBRMH_RELAY set dupack_thresh       $opt(dupack_thresh)
Module/UW/CBRMH_RELAY set buffer_enabled      $opt(use_relays)

#Module/UW/CBRMH_RELAY set debug_            100
#Module/UW/CBRMH_SINK set debug_               100
#Module/UW/CBRMH_SRC set debug_               100

Module/UW/OPTICAL/PHY   set TxPower_                    $opt(txpower)
Module/UW/OPTICAL/PHY   set BitRate_                    $opt(bitrate)
Module/UW/OPTICAL/PHY   set AcquisitionThreshold_dB_    $opt(opt_acq_db)
Module/UW/OPTICAL/PHY   set Id_                         $opt(id)
Module/UW/OPTICAL/PHY   set Il_                         $opt(il)
Module/UW/OPTICAL/PHY   set R_                          $opt(shuntRes)
Module/UW/OPTICAL/PHY   set S_                          $opt(sensitivity)
Module/UW/OPTICAL/PHY   set T_                          $opt(temperatura)
Module/UW/OPTICAL/PHY   set Ar_                         $opt(rxArea)
#Module/UW/OPTICAL/PHY   set debug_                      -7
#Module/UW/OPTICAL/PHY   set interference_threshold_     1e-15
Module/UW/OPTICAL/PHY set use_reed_solomon $opt(use_reed_solomon)
Module/UW/OPTICAL/PHY set rs_n $opt(rs_n)
Module/UW/OPTICAL/PHY set rs_k $opt(rs_k)

Module/UW/OPTICAL/Propagation set Ar_       $opt(rxArea)
Module/UW/OPTICAL/Propagation set At_       $opt(txArea)
Module/UW/OPTICAL/Propagation set c_        $opt(c)
Module/UW/OPTICAL/Propagation set theta_    $opt(theta)
#Module/UW/OPTICAL/Propagation set debug_    -7
set propagation [new Module/UW/OPTICAL/Propagation]
$propagation setOmnidirectional

set channel [new Module/UW/Optical/Channel]

set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       $opt(freq)
$data_mask setBandwidth  $opt(bw)

Module/UW/TDMA set frame_duration $opt(frame_duration)
Module/UW/TDMA set fair_mode 1
Module/UW/TDMA set tot_slots $opt(num_slots)
Module/UW/TDMA set guard_time $opt(guard_time)
#Module/UW/TDMA set debug_ -7

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {
	global channel ns cbr position node udp portnum ipr ipif
	global opt mll mac propagation data_mask

	set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

	set udp($id)  [new Module/UW/UDP]
	set ipr($id)  [new Module/UW/StaticRouting]
	set ipif($id) [new Module/UW/IP]
	set mll($id)  [new Module/UW/MLL]
	set mac($id)  [new Module/UW/TDMA]
	set phy($id)  [new Module/UW/OPTICAL/PHY]

	$node($id) addModule 6 $udp($id)   1  "UDP"
	$node($id) addModule 5 $ipr($id)   1  "IPR"
	$node($id) addModule 4 $ipif($id)  1  "IPF"
	$node($id) addModule 3 $mll($id)   1  "MLL"
	$node($id) addModule 2 $mac($id)   1  "MAC"
	$node($id) addModule 1 $phy($id)   1  "PHY"

	$node($id) setConnection $udp($id)   $ipr($id)   1
	$node($id) setConnection $ipr($id)   $ipif($id)  1
	$node($id) setConnection $ipif($id)  $mll($id)   1
	$node($id) setConnection $mll($id)   $mac($id)   1
	$node($id) setConnection $mac($id)   $phy($id)   1
	$node($id) addToChannel  $channel    $phy($id)   1

	set interf_data($id) [new "MInterference/MIV"]
	$interf_data($id) set maxinterval_ $opt(maxinterval_)
	#$interf_data($id) set debug_       -7

	$phy($id) setInterference $interf_data($id)
	$phy($id) setPropagation $propagation
	$phy($id) setSpectralMask $data_mask
	$phy($id) setLUTFileName "$opt(LUTpath)"
	$phy($id) setLUTSeparator " "
	$phy($id) useLUT
	$phy($id) setInterferenceModel "OOK"


	$ipif($id) addr [expr $id +1]

	$mac($id) setMacAddr [expr $id + 5]
	$mac($id) setSlotNumber [expr $id % $opt(num_slots)]
}

proc createSourceNode { id } {
	createNode $id

	global node cbr udp portnum ipr

	set cbr($id)  [new Module/UW/CBRMH_SRC]

	$node($id) addModule 7 $cbr($id)   1  "CBR"

	$node($id) setConnection $cbr($id)   $udp($id)   1
	set portnum($id) [$udp($id) assignPort $cbr($id) ]
}

proc createSinkNode { id } {
	createNode $id

	global node cbr udp portnum ipr

	set cbr($id)  [new Module/UW/CBRMH_SINK]

	$node($id) addModule 7 $cbr($id)   1  "CBR"

	$node($id) setConnection $cbr($id)   $udp($id)   1
	set portnum($id) [$udp($id) assignPort $cbr($id) ]
}

proc createRelayNode { id } {
	createNode $id

	global node cbr udp portnum ipr

	set cbr($id)  [new Module/UW/CBRMH_RELAY]

	$node($id) addModule 7 $cbr($id)   1  "CBR"

	$node($id) setConnection $cbr($id)   $udp($id)   1
	set portnum($id) [$udp($id) assignPort $cbr($id) ]
}

#################
# Node Creation #
#################
# Create here all the nodes you want to network together
set src_id 0
createSourceNode $src_id

for {set id 1} {$id < [expr $opt(nn)-1]} {incr id}  {
	createRelayNode $id
}

set sink_id [expr $opt(nn) - 1]
createSinkNode $sink_id

################################
# Inter-node module connection #
################################
for { set id 1} {$id < [expr $opt(nn)]} {incr id} {
	$cbr($src_id) appendtopath [$ipif($id) addr] $portnum($id)
}

###################
# Fill ARP tables #
###################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
	for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
		$mll($id1) addentry [$ipif($id2) addr] [$mac($id2) addr]
	}
}

##################
# Routing tables #
##################

# ->
for {set id 0} {$id < [expr $opt(nn) - 1]} {incr id}  {
	$ipr($id) addRoute [$ipif([expr $id + 1]) addr] [$ipif([expr $id + 1]) addr]
}

# <-
for {set id 1} {$id < [expr $opt(nn)]} {incr id}  {
	$ipr($id) addRoute [$ipif([expr $id - 1]) addr] [$ipif([expr $id - 1]) addr]
}

##################
# Node positions #
##################
set internode_dist [expr $opt(tot_dist) / ($opt(nn) - 1.0)]
for {set id 0} {$id < $opt(nn)} {incr id} {
	set position($id) [new "Position/BM"]
	$node($id) addPosition $position($id)

	$position($id) setZ_ -40
	$position($id) setX_ [expr {$id * $internode_dist}]
	$position($id) setY_ 0
}

#####################
# Start/Stop Timers #
#####################
for {set i 0} {$i < $opt(nn)} {incr i} {
	$ns at $opt(starttime)    "$mac($i) start"
	$ns at [expr $opt(stoptime) + 245]     "$mac($i) stop"
}

$ns at $opt(starttime)    "$cbr($src_id) start"
$ns at $opt(stoptime)     "$cbr($src_id) stop"

###################
# Final Procedure #
###################
# Define here the procedure to call at the end of the simulation
proc finish {} {
	global ns opt outfile
	global mac propagation phy_data phy_data_sink channel db_manager propagation
	global node_coordinates
	global ipr_sink ipr ipif udp cbr phy phy_data_sink
	global node_stats tmp_node_stats sink_stats tmp_sink_stats

	global src_id sink_id
	global position
	global packet_time

	if ($opt(verbose)) {
		puts "---------------------------------------------------------------------"
		puts "Simulation summary"
		puts "src-dst distance\t: $opt(tot_dist) m"
		puts "number of nodes\t\t: $opt(nn)"
		puts ""
		puts "packet size\t\t: $opt(pktsize) byte"
		puts "cbr period\t\t: $opt(cbr_period) s"
		puts "ARQ enabled\t\t: $opt(use_arq)"
		if ($opt(use_arq)) {
			puts "RX/TX window\t\t: $opt(cbr_window)"
			puts "Retx timeout\t\t: $opt(cbr_timeout)"
			puts "Use RTT estimate\t: $opt(use_rtt_timeout)"
		}

		puts ""
		puts "packet time\t: $packet_time s"
		puts "TDMA frame\t: $opt(frame_duration) s"
		puts "TDMA slots\t: $opt(num_slots)"
		puts "TDMA guard time\t: $opt(guard_time) s"
		puts ""
		puts "Reed solomon enabled\t: $opt(use_reed_solomon)"
		if $opt(use_reed_solomon) {
			puts "N = $opt(rs_n), K = $opt(rs_k)"
		}

		puts ""
		puts "CBR header size\t: [$cbr($src_id) getcbrheadersize]"
		puts "UDP header size\t: [$udp($src_id) getudpheadersize]"
		puts "IP header size\t: [$ipif($src_id) getipheadersize]"
		puts "---------------------------------------------------------------------"
	}

	if ($opt(verbose)) {
		puts "Node positions (x, y, z)"
		for {set id 0} {$id < $opt(nn)} {incr id} {
			puts "Node $id\t: \([$position($id) getX_], [$position($id) getY_], [$position($id) getZ_]\)"
		}
		puts "---------------------------------------------------------------------"
	}

	set cbr_throughput [$cbr($sink_id) getthr]
	set cbr_delay [$cbr($sink_id) getdelay]
	set cbr_delay_stddev [$cbr($sink_id) getdelaystd]
	set cbr_ftt [$cbr($sink_id) getftt]
	set cbr_ftt_stddev [$cbr($sink_id) getfttstd]
	set cbr_btt [$cbr($src_id) getftt]
	set cbr_btt_stddev [$cbr($src_id) getfttstd]
	set cbr_rtt [$cbr($src_id) getrtt]
	set cbr_rtt_stddev [$cbr($src_id) getrttstd]

	set cbr_generated_pkts [$cbr($src_id) getgeneratedpkts]
	set cbr_sent_pkts [$cbr($src_id) getsentpkts]
	set cbr_resent_pkts [$cbr($src_id) getretxpkts]
	set cbr_rcv_pkts [$cbr($sink_id) getrecvpkts]
	set cbr_proc_pkts [$cbr($sink_id) getprocpkts]
	set cbr_dup_pkts [$cbr($sink_id) getduppkts]

	set cbr_sent_acks [$cbr($sink_id) getsentacks]
	set cbr_sent_dupacks [$cbr($sink_id) getsentdupacks]
	set cbr_recv_acks [$cbr($src_id) getrecvacks]
	set cbr_dup_acks [$cbr($src_id) getdupacks]

	if ($opt(verbose)) {
		puts "CBR"
		puts "Throughput\t: $cbr_throughput bit/s"
		puts "Delay\t\t: $cbr_delay s,\tstddev: $cbr_delay_stddev"
		puts "FTT\t\t: $cbr_ftt s,\tstddev: $cbr_ftt_stddev"
		puts "BTT\t\t: $cbr_btt s,\tstddev: $cbr_btt_stddev"
		puts "RTT\t\t: $cbr_rtt s,\tstddev: $cbr_rtt_stddev"
		puts ""
		puts "Gen. pkts\t\t\t: $cbr_generated_pkts"
		puts "Sent packets\t\t\t: $cbr_sent_pkts"
		puts "Resent packets\t\t\t: $cbr_resent_pkts"
		puts "Received packets\t\t: $cbr_rcv_pkts"
		puts "Processed packets\t\t: $cbr_proc_pkts"
		puts "Received duplicate packets\t: $cbr_dup_pkts"
		puts ""
		puts "Sent ACKs\t\t\t: $cbr_sent_acks"
		puts "Sent ACKs for duplicate pkts\t: $cbr_sent_dupacks"
		puts "Received ACKs\t\t\t: $cbr_recv_acks"
		puts "Received duplicate ACKs\t\t: $cbr_dup_acks"

		puts "---------------------------------------------------------------------"
	}

	set tdma_sent_pkts_sum 0.0
	set tdma_recv_pkts_sum 0.0
	for {set i 0} {$i < $opt(nn)} {incr i} {
		set tdma_sent_pkts($i) [expr 0.0 + [$mac($i) get_sent_pkts]]
		set tdma_recv_pkts($i) [expr 0.0 + [$mac($i) get_recv_pkts]]
		set tdma_sent_pkts_sum [expr $tdma_sent_pkts_sum + $tdma_sent_pkts($i)]
		set tdma_recv_pkts_sum [expr $tdma_recv_pkts_sum + $tdma_recv_pkts($i)]
	}

	if {$tdma_sent_pkts_sum > 0} {
		set tdma_per [expr 1 - $tdma_recv_pkts_sum/$tdma_sent_pkts_sum]
	} else {
		set tdma_per NaN
	}

	if {$tdma_sent_pkts($src_id) > 0} {
		set tdma_per_srcdst [expr 1 - $tdma_recv_pkts($sink_id)/$tdma_sent_pkts($src_id)]
	} else {
		set tdma_per_srcdst NaN
	}

	if {$tdma_sent_pkts($sink_id) > 0} {
		set tdma_per_dstsrc [expr 1 - $tdma_recv_pkts($src_id)/$tdma_sent_pkts($sink_id)]
	} else {
		set tdma_per_dstsrc NaN
	}

	if ($opt(verbose)) {
		puts "TDMA"
		puts "Global packet error rate\t: $tdma_per"
		puts "src -> sink packet error rate\t: $tdma_per_srcdst"
		puts "sink -> src packet error rate\t: $tdma_per_dstsrc"
	}

	$ns flush-trace
	close $opt(tracefile)
}


###################
# start simulation
###################
if ($opt(verbose)) {
	puts "\nStarting Simulation\n"
}


$ns at [expr $opt(stoptime) + 250.0]  "finish; $ns halt"

$ns run
