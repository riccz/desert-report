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
# This script is used to simulate a one-hop acoustic network with a
# CBR source with ARQ. The data-link layer is TDMA, the physical layer
# simulates a pair of Hermes modems.
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
#   |  2. UW/TDMA             |
#   +-------------------------+
#   |  1. UW/HERMES/PHY       |
#   +-------------------------+
#           |         |
#   +-------------------------+
#   |   UnderwaterChannel     |
#   +-------------------------+

######################################
# Flags to enable or disable options #
######################################
set opt(verbose)		1
set opt(trace_files)		1
set opt(bash_parameters)	0

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
load libuwcsmaaloha.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so
load libuwinterference.so
load libUwmStd.so
load libUwmStdPhyBpskTracer.so
load libuwphysical.so
load libuwhermesphy.so

#############################
# NS-Miracle initialization #
#############################
set ns [new Simulator]
$ns use-Miracle

##################
# Tcl variables	 #
##################
set opt(start_clock) [clock seconds]

set opt(nn)		    2; # Number of Nodes
set opt(src_id)             0
set opt(sink_id)            1
set opt(node_dist)	    50.0
set opt(node_depth)         0.5

set opt(starttime)	    1
set opt(stoptime)	    5001
set opt(txduration)	    [expr $opt(stoptime) - $opt(starttime)]

# Hermes settings taken from test_uwhermesphy_simple.tcl
set opt(txpower)            180.0; # Power transmitted in dB re uPa
set opt(freq)               300000.0; # Frequency used in Hz
set opt(bw)                 75000.0; # Bandwidth used in Hz
set opt(bitrate)            87768.0; # bitrate in bps

set opt(maxinterval_)	    20.0

# CBR settings
set opt(target_src_rate)    90000.0; # bits/s
set opt(pktsize)	    1000; # bytes
set opt(cbr_period)         [expr $opt(pktsize) * 8.0 / $opt(target_src_rate)]
set opt(seedcbr)	    1

# TDMA settings
set opt(propagation_speed)  1500.0; # m/s
set opt(pkts_per_frame)     1
set opt(winsize)            $opt(pkts_per_frame); # CBR
set opt(guard_interval)     0;#0.0005

set hdrsize 28; # CBR + UDP + IP
set acksize 0; # + headers

set pkt_time [expr ($opt(pktsize) + $hdrsize) * 8.0 / $opt(bitrate)]
set ack_time [expr ($acksize + $hdrsize) * 8.0 / $opt(bitrate)]
set prop_delay [expr $opt(node_dist) / $opt(propagation_speed)]

set src_slot [expr $opt(pkts_per_frame) * $pkt_time + $opt(guard_interval) + \
		      $prop_delay]
set sink_slot [expr $opt(pkts_per_frame) * $ack_time + $opt(guard_interval) + \
		       $prop_delay]
set frame_duration [expr $src_slot + $sink_slot]



if {$opt(bash_parameters)} {
	if {$argc != 4} {
		puts "The script requires four inputs:"
		puts "- the first for the seed"
		puts "- the second one is for the Poisson CBR period"
		puts "- the third one is the cbr packet size (byte);"
		puts "- the fourth one is the distance between the nodes (m)"
		puts "example: ns TDMA_exp.tcl 1 60 125 100"
		puts "If you want to leave the default values, please set to 0"
		puts "the value opt(bash_parameters) in the tcl script"
		puts "Please try again."
		return
	} else {
		set opt(seedcbr)    [lindex $argv 0]
		set opt(cbr_period) [lindex $argv 1]
		set opt(pktsize)    [lindex $argv 2]
		set opt(node_dist) [lindex $argv 3]
		
	}
}

set rng [new RNG]
$rng seed $opt(seedcbr)
set rnd_gen [new RandomVariable/Uniform]
$rnd_gen use-rng $rng

if {$opt(trace_files)} {
	set opt(tracefilename) "./1hop_ac.tr"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "./1hop_ac.cltr"
	set opt(cltracefile) [open $opt(tracefilename) w]
} else {
	set opt(tracefilename) "/dev/null"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "/dev/null"
	set opt(cltracefile) [open $opt(cltracefilename) w]
}

#########################
# Module Configuration	#
#########################

### TDMA MAC ###
Module/UW/TDMA set fair_mode      0
Module/UW/TDMA set frame_duration $frame_duration
Module/UW/TDMA set check_duration 1
#Module/UW/TDMA set debug_	  -7

### APP ###
Module/UW/CBR set PoissonTraffic_      1
Module/UW/CBR set drop_out_of_order_   0
Module/UW/CBR set dupack_thresh	       1
Module/UW/CBR set packetSize_	       $opt(pktsize)
Module/UW/CBR set period_	       $opt(cbr_period)
Module/UW/CBR set rx_window	       $opt(winsize)
Module/UW/CBR set tx_window	       $opt(winsize)
Module/UW/CBR set use_arq	       1
Module/UW/CBR set timeout_	       [expr $frame_duration * 2.0 ]
Module/UW/CBR set use_rtt_timeout      0
Module/UW/CBR set debug_	       100

### Channel ###
MPropagation/Underwater set practicalSpreading_ 2
MPropagation/Underwater set windspeed_		10
MPropagation/Underwater set shipping_		1
#MPropagation/Underwater set debug_		-7

set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq		$opt(freq)
$data_mask setBandwidth		$opt(bw)
$data_mask setPropagationSpeed	$opt(propagation_speed)

### PHY ###
Module/UW/HERMES/PHY  set BitRate_                    $opt(bitrate)
Module/UW/HERMES/PHY  set AcquisitionThreshold_dB_    15.0
Module/UW/HERMES/PHY  set RxSnrPenalty_dB_            0
Module/UW/HERMES/PHY  set TxSPLMargin_dB_             0
Module/UW/HERMES/PHY  set MaxTxSPL_dB_                $opt(txpower)
Module/UW/HERMES/PHY  set MinTxSPL_dB_                10
Module/UW/HERMES/PHY  set MaxTxRange_                 200
Module/UW/HERMES/PHY  set PER_target_                 0
Module/UW/HERMES/PHY  set CentralFreqOptimization_    0
Module/UW/HERMES/PHY  set BandwidthOptimization_      0
Module/UW/HERMES/PHY  set SPLOptimization_            0
#Module/UW/HERMES/PHY  set debug_                      0

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {
	global channel ns cbr position node udp portnum ipr ipif
	global opt mll mac propagation data_mask interf_data

	set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]
	set cbr($id)  [new Module/UW/CBR]
	set udp($id)  [new Module/UW/UDP]
	set ipr($id)  [new Module/UW/StaticRouting]
	set ipif($id) [new Module/UW/IP]
	set mll($id)  [new Module/UW/MLL]
	set mac($id)  [new Module/UW/TDMA]
	set phy($id)  [new Module/UW/HERMES/PHY]

	$node($id) addModule 7 $cbr($id)   1  "CBR"
	$node($id) addModule 6 $udp($id)   1  "UDP"
	$node($id) addModule 5 $ipr($id)   1  "IPR"
	$node($id) addModule 4 $ipif($id)  1  "IPF"
	$node($id) addModule 3 $mll($id)   1  "MLL"
	$node($id) addModule 2 $mac($id)   1  "MAC"
	$node($id) addModule 1 $phy($id)   1  "PHY"

	$node($id) setConnection $cbr($id)   $udp($id)	 0
	set portnum($id) [$udp($id) assignPort $cbr($id) ]
	$node($id) setConnection $udp($id)   $ipr($id)	 1
	$node($id) setConnection $ipr($id)   $ipif($id)	 1
	$node($id) setConnection $ipif($id)  $mll($id)	 1
	$node($id) setConnection $mll($id)   $mac($id)	 1
	$node($id) setConnection $mac($id)   $phy($id)	 1
	$node($id) addToChannel	 $channel    $phy($id)	 1

	#Set the IP address of the node
	#$ipif($id) addr "1.0.0.${id}"
	$ipif($id) addr [expr $id + 1]

	# Set the MAC address
	$mac($id) setMacAddr [expr $id + 5]

	#Setup positions
	set position($id) [new Position/BM]
	$node($id) addPosition $position($id)

	$position($id) setX_ [expr $id * $opt(node_dist) / sqrt(2)]
	$position($id) setY_ [expr $id * $opt(node_dist) / sqrt(2)]
	$position($id) setZ_ $opt(node_depth)

	#Interference model
	set interf_data($id)  [new Module/UW/INTERFERENCE]
	$interf_data($id) set maxinterval_ $opt(maxinterval_)
	#$interf_data($id) set debug_	    -7

	#Propagation model
	$phy($id) setPropagation $propagation

	$phy($id) setSpectralMask $data_mask
	$phy($id) setInterference $interf_data($id)
	$phy($id) setInterferenceModel "MEANPOWER"
}

proc createSource { id } {
	global opt mac src_slot

	createNode $id
	$mac($id) setStartTime 0
	$mac($id) setSlotDuration $src_slot
	$mac($id) setGuardTime $opt(guard_interval)
}

proc createSink { id } {
	global opt mac src_slot sink_slot

	createNode $id
	$mac($id) setStartTime $src_slot
	$mac($id) setSlotDuration $sink_slot
	$mac($id) setGuardTime $opt(guard_interval)
}

#################
# Node Creation #
#################
createSource $opt(src_id)
createSink $opt(sink_id)

################################
# Inter-node module connection #
################################
$cbr($opt(src_id)) set destAddr_ [$ipif($opt(sink_id)) addr]
$cbr($opt(src_id)) set destPort_ $portnum($opt(sink_id))

###################
# Fill ARP tables #
###################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
	for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
		$mll($id1) addentry [$ipif($id2) addr] [$mac($id2) addr]
	}
}

########################
# Setup routing tables #
########################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
	for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
		if {$id1 != $id2} {
			$ipr($id1) addRoute [$ipif($id2) addr] [$ipif($id2) addr]
		}
	}
}

#####################
# Start/Stop Timers #
#####################
$ns at [expr $opt(starttime) + 3]    "$cbr($opt(src_id)) start"
$ns at [expr $opt(stoptime) - 3]     "$cbr($opt(src_id)) stop"

for {set ii 0} {$ii < $opt(nn)} {incr ii} {
	$ns at $opt(starttime)	  "$mac($ii) start"
	$ns at $opt(stoptime)	  "$mac($ii) stop"
}

###################
# Final Procedure #
###################
# Define here the procedure to call at the end of the simulation
proc finish {} {
	global ns opt outfile
	global mac propagation cbr_sink mac_sink phy_data phy_data_sink channel db_manager propagation
	global node_coordinates
	global ipr_sink ipr ipif udp cbr phy phy_data_sink
	global node_stats tmp_node_stats sink_stats tmp_sink_stats src_id sink_id
	global pkt_time ack_time frame_duration

	if ($opt(verbose)) {
		puts "-----------------------------------------------------------------"
		puts "Simulation summary"
		puts "-----------------------------------------------------------------"
		puts "Total simulation time    : $opt(txduration) s"
		puts "Number of nodes          : $opt(nn)"
		puts "Packet size              : $opt(pktsize) byte(s)"
		puts "CBR period               : $opt(cbr_period) s"
		puts "Window size              : $opt(winsize)"
		puts "-----------------------------------------------------------------"
		puts "Packet time              : $pkt_time"
		puts "ACK time                 : $ack_time"
		puts "Frame duration           : $frame_duration"
		puts "Guard interval           : $opt(guard_interval)"
		puts "-----------------------------------------------------------------"
	}

	set src_id $opt(src_id)
	set sink_id $opt(sink_id)

	set cbr_thr [$cbr($sink_id) getthr]
	set cbr_sent_pkts [$cbr($src_id) getsentpkts]
	set cbr_recv_pkts [$cbr($sink_id) getrecvpkts]
	set cbr_ftt [$cbr($sink_id) getftt]
	set cbr_ftt_stddev [$cbr($sink_id) getfttstd]
	set cbr_btt [$cbr($src_id) getftt]
	set cbr_btt_stddev [$cbr($src_id) getfttstd]
	set cbr_rtt [$cbr($src_id) getrtt]
	set cbr_rtt_stddev [$cbr($src_id) getrttstd]
	set cbr_delay [$cbr($sink_id) getdelay]
	set cbr_delay_stddev [$cbr($sink_id) getdelaystd]

	if ($opt(verbose)) {
		puts "CBR"
		puts "Throughput    : $cbr_thr"
		puts "CBR generated packets    : [$cbr($src_id) getgeneratedpkts]"
		puts "CBR sent Packets	       : $cbr_sent_pkts"
		puts "CBR received Packets     : $cbr_recv_pkts"
		puts "CBR processed pkts       : [$cbr($sink_id) getprocpkts]"

		puts "FTT\t: $cbr_ftt,\tstd.dev. $cbr_ftt_stddev"
		puts "BTT\t: $cbr_btt,\tstd.dev. $cbr_btt_stddev"
		puts "RTT\t: $cbr_rtt,\tstd.dev. $cbr_rtt_stddev"
		puts "Delay\t: $cbr_delay,\tstd.dev. $cbr_delay_stddev"
	}
	
	set mac_sent_src [$mac($src_id) get_sent_pkts]
	set mac_sent_sink [$mac($sink_id) get_sent_pkts]
	set mac_recv_src [$mac($src_id) get_recv_pkts]
	set mac_recv_sink [$mac($sink_id) get_recv_pkts]

	if { $mac_sent_src > 0 } {
		set src_sink_pdr [expr 1.0 * $mac_recv_sink / $mac_sent_src]
	} else {
		set src_sink_pdr NaN
	}

	if { $mac_sent_sink > 0 } {
		set sink_src_pdr [expr 1.0 * $mac_recv_src / $mac_sent_sink]
	} else {
		set sink_src_pdr NaN
	}

	if $opt(verbose) {
		puts "TDMA"
		puts "Sent pkts\t: $mac_sent_src"
		puts "Recvd pkts\t: $mac_recv_sink"
		puts "Sent ACKs\t: $mac_sent_sink"
		puts "Recvd ACKs\t: $mac_recv_src"
		puts "Source -> Sink PDR\t: $src_sink_pdr"
		puts "Sink -> Source PDR\t: $sink_src_pdr"
		puts "-----------------------------------------------------------------"
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

$ns at [expr $opt(stoptime) + 50.0]  "finish; $ns halt"

$ns run

# Local Variables:
# mode: tcl
# tcl-indent-level: 8
# tcl-continued-indent-level: 8
# indent-tabs-mode: t
# tab-width: 8
# End:
