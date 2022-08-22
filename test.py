#! /usr/bin/env python

from scapy.all import * # type: ignore

import argparse

parser = argparse.ArgumentParser(description='Process some pcap.')
parser.add_argument('pcap', action='store', type=str, help='pcapfile')
parser.add_argument('startPacket',  action='store', type=int,  help='start packet')



args = parser.parse_args()
print(args.startPacket)

pcap = PcapReader(args.pcap)
print("pcap read")

packetNumber = 0
filteredPackets = []

for pkt in pcap:
    if packetNumber >= args.startPacket:
        if pkt.haslayer(TCP):
            if (pkt[TCP].dport == 5555) & (len(pkt[TCP].payload) > 0):
                #print("TCP Found", packetNumber)
                #print(pkt[TCP].payload)
                filteredPackets.append(pkt[TCP].payload)
    packetNumber+=1

print(packetNumber)
print(len(filteredPackets))
wrpcap("filtered.pcap",filteredPackets)


#s = TCP_client.tcplink(Raw, "::1", 5555)