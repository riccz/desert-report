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
#load libuwcsmaaloha.so
load libuwtdma.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so
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

#set opt(pktsize)            125  ;# Pkt sike in byte
set opt(starttime)          1	
set opt(stoptime)           101 
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation
#set opt(ack_mode)           "setNoAckMode"
set opt(maxinterval_)       10.0

set opt(freq)              10000000
set opt(bw)                100000
set opt(bitrate)           1000000
set opt(txpower)           0.58
set opt(opt_acq_db)        10
set opt(temperatura)       293.15 ; # in Kelvin
set opt(txArea)            0.000010
set opt(rxArea)            0.0000011 ; # receveing area, it has to be the same for optical physical and propagation
set opt(c)                 0.043 ; # pure seawater attenation coefficient
set opt(theta)             1
set opt(id)                [expr 1.0e-9]
set opt(il)                [expr 1.0e-6]
set opt(shuntRes)          [expr 1.49e9]
set opt(sensitivity)       0.26
set opt(LUTpath)           "dbs/optical_noise/LUT.txt"

set rng [new RNG]

if {$opt(bash_parameters)} {
	if {$argc != 5} {
		puts "The script requires three inputs:"
		puts "- the first for the seed"
		puts "- the second one is for the Poisson CBR period"
		puts "- the third one is the cbr packet size (byte);"
		puts "example: ns test_uw_csma_aloha_simple.tcl 1 60 125"
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
	    $rng seed         $opt(seedcbr)
	}
} else {
	set opt(cbr_period) 0.1
	set opt(pktsize)	125
	set opt(seedcbr)	1
}

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

set opt(frame_duration)    1
set opt(num_slots)         10;#$opt(nn)
set opt(guard_time)        0.01


#########################
# Module Configuration  #
#########################
Module/UW/CBR set packetSize_          $opt(pktsize)
Module/UW/CBR set period_              $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_      1
#Module/UW/CBR set debug_               -7

Module/UW/OPTICAL/PHY   set TxPower_                    $opt(txpower)
Module/UW/OPTICAL/PHY   set BitRate_                    $opt(bitrate)
Module/UW/OPTICAL/PHY   set AcquisitionThreshold_dB_    $opt(opt_acq_db)
Module/UW/OPTICAL/PHY   set Id_                         $opt(id)
Module/UW/OPTICAL/PHY   set Il_                         $opt(il)
Module/UW/OPTICAL/PHY   set R_                          $opt(shuntRes)
Module/UW/OPTICAL/PHY   set S_                          $opt(sensitivity)
Module/UW/OPTICAL/PHY   set T_                          $opt(temperatura)
Module/UW/OPTICAL/PHY   set Ar_                         $opt(rxArea)
Module/UW/OPTICAL/PHY   set debug_                      -7

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
#Module/UW/TDMA set debug_ -7
Module/UW/TDMA set fair_mode 1
Module/UW/TDMA set tot_slots $opt(num_slots)
Module/UW/TDMA set guard_time $opt(guard_time)

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {

    global channel ns cbr position node udp portnum ipr ipif
    global opt mll mac propagation data_mask
    
    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)] 

    set ipr($id)  [new Module/UW/StaticRouting]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL] 
    set mac($id)  [new Module/UW/TDMA] 
    set phy($id)  [new Module/UW/OPTICAL/PHY]
	    
    $node($id) addModule 5 $ipr($id)   1  "IPR"
    $node($id) addModule 4 $ipif($id)  1  "IPF"   
    $node($id) addModule 3 $mll($id)   1  "MLL"
    $node($id) addModule 2 $mac($id)   1  "MAC"
    $node($id) addModule 1 $phy($id)   1  "PHY"

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

    $ipif($id) addr [expr $id +1]

    $mac($id) setMacAddr [expr $id + 5]
    $mac($id) setSlotNumber [expr $id % $opt(num_slots)]
    
    set position($id) [new "Position/BM"]
    $node($id) addPosition $position($id)
}

proc makeSourceNode { id } {
    global node cbr udp portnum ipr
    
    set cbr($id)  [new Module/UW/CBR]
    set udp($id)  [new Module/UW/UDP]

    $node($id) addModule 7 $cbr($id)   1  "CBR_source"
    $node($id) addModule 6 $udp($id)   1  "UDP"

    $node($id) setConnection $cbr($id)   $udp($id)   1
    set portnum($id) [$udp($id) assignPort $cbr($id) ]
    $node($id) setConnection $udp($id)   $ipr($id)   1
}

proc makeDestNode { id } {
    global node cbr udp portnum ipr
    
    set cbr($id)  [new Module/UW/CBR]
    set udp($id)  [new Module/UW/UDP]

    $node($id) addModule 7 $cbr($id)   1  "CBR_sink"
    $node($id) addModule 6 $udp($id)   1  "UDP"

    $node($id) setConnection $cbr($id)   $udp($id)   1
    set portnum($id) [$udp($id) assignPort $cbr($id) ]
    $node($id) setConnection $udp($id)   $ipr($id)   1
}

#################
# Node Creation #
#################
# Create here all the nodes you want to network together
for {set id 0} {$id < $opt(nn)} {incr id}  {
    createNode $id
}
set src_id 0
set dst_id [expr $opt(nn) - 1]
makeSourceNode $src_id
makeDestNode $dst_id

################################
# Inter-node module connection #
################################
$cbr($src_id) set destAddr_ [$ipif($dst_id) addr]
$cbr($src_id) set destPort_ $portnum($dst_id)

# Also dst -> src?

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
for {set id 0} {$id < [expr $opt(nn) - 1]} {incr id}  {
    $ipr($id) addRoute [$ipif([expr $dst_id]) addr] [$ipif([expr $id+1]) addr]
}

# Positions
set internode_dist [expr $opt(tot_dist) / ($opt(nn) - 1.0)]
for {set id 0} {$id < $opt(nn)} {incr id} {    
    $position($id) setZ_ -10
    $position($id) setX_ [expr {$id * $internode_dist}]
    $position($id) setY_ 0    
}

#####################
# Start/Stop Timers #
#####################
# Set here the timers to start and/or stop the timers
# for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
# 	for {set id2 0} {$id2 < $opt(nn)} {incr id2} {
# 		if {$id1 != $id2} {
# 			$ns at $opt(starttime)    "$cbr($id1,$id2) start"
# 			$ns at $opt(stoptime)     "$cbr($id1,$id2) stop"
# 		}
# 	}
# }

for {set i 0} {$i < $opt(nn)} {incr i} {
    $ns at $opt(starttime)    "$mac($i) start"
    $ns at $opt(stoptime)     "$mac($i) stop"
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

    global src_id dst_id
    global position

    if ($opt(verbose)) {
        puts "---------------------------------------------------------------------"
        puts "Simulation summary"
	puts "src-dst distance : $opt(tot_dist) m"
        puts "number of nodes  : $opt(nn)"
        puts "packet size      : $opt(pktsize) byte"
        puts "cbr period       : $opt(cbr_period) s"
        puts "TDMA frame       : $opt(frame_duration) s"
	puts "TDMA slots       : $opt(num_slots)"
        puts "---------------------------------------------------------------------"
    }
    if ($opt(verbose)) {
	puts "Node positions (x, y, z)"
	for {set id 0} {$id < $opt(nn)} {incr id} {
	    puts "Node $id : \([$position($id) getX_], [$position($id) getY_], [$position($id) getZ_]\)"
	}
	puts "---------------------------------------------------------------------"
    }
    
    set cbr_throughput [$cbr($dst_id) getthr]
    set cbr_sent_pkts [$cbr($src_id) getsentpkts]
    set cbr_rcv_pkts [$cbr($dst_id) getrecvpkts]
    
    set tdma_sent_pkts_sum 0.0
    set tdma_recv_pkts_sum 0.0
    for {set i 0} {$i < $opt(nn)} {incr i} {
	set tdma_sent_pkts($i) [$mac($i) get_sent_pkts]
	set tdma_recv_pkts($i) [$mac($i) get_recv_pkts]
	set tdma_sent_pkts_sum [expr $tdma_sent_pkts_sum + $tdma_sent_pkts($i)]
	set tdma_recv_pkts_sum [expr $tdma_recv_pkts_sum + $tdma_recv_pkts($i)]
    }
    
    if ($opt(verbose)) {
        puts "Throughput               : [expr $cbr_throughput] bit/s"
        puts "Sent Packets             : $cbr_sent_pkts"
        puts "Received Packets         : $cbr_rcv_pkts"
	puts "Packet error rate        : [expr 1 - $tdma_recv_pkts_sum/$tdma_sent_pkts_sum]"
    }

    if ($opt(verbose)) {
	puts "Packets delivery ratio per link"
	for {set i 1} {$i < $opt(nn)} {incr i} {
	    set pdr [expr $tdma_recv_pkts($i) / ($tdma_sent_pkts([expr $i - 1]) + 0.0)]
	    puts "[expr $i - 1] -> $i : $pdr"
	}
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
