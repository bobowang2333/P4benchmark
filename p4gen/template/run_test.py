#!/usr/bin/env python

# Copyright 2013-present Barefoot Networks, Inc. 
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import time

P4BENCH_PORT = 0x9091

import random
import argparse

import threading
from scapy.all import sniff
from scapy.all import Ether, IP, IPv6, TCP, UDP
from scapy.all import Packet, ShortField, bind_layers

parser = argparse.ArgumentParser(description='run_test.py')
parser.add_argument('-n', '--nb-packets', default=10, type=int,
                    help='Send [n] packets to the switch')
parser.add_argument('-c', '--nb-headers', default=1, type=int,
                    help='Add [c] P4Bench headers to each packet')
parser.add_argument('-f', '--nb-fields', default=1, type=int,
                    help='Add [f] fields to each P4Bench header')
parser.add_argument('--random-dport',
                    help='Use a random TCP dest port for each packet',
                    action="store_true", default=False)
args = parser.parse_args()

class PacketQueue:
    def __init__(self):
        self.pkts = []
        self.lock = threading.Lock()
        self.ifaces = set()

    def add_iface(self, iface):
        self.ifaces.add(iface)

    def get(self):
        self.lock.acquire()
        if not self.pkts:
            self.lock.release()
            return None, None
        pkt = self.pkts.pop(0)
        self.lock.release()
        return pkt

    def add(self, iface, pkt):
        if iface not in self.ifaces:
            return
        self.lock.acquire()
        self.pkts.append( (iface, pkt) )
        self.lock.release()

queue = PacketQueue()

def pkt_handler(pkt, iface):
    if IPv6 in pkt:
        return
    # pkt.show()
    queue.add(iface, pkt)

class SnifferThread(threading.Thread):
    def __init__(self, iface, handler = pkt_handler):
        threading.Thread.__init__(self)
        self.iface = iface
        self.handler = handler

    def run(self):
        sniff(
            iface = self.iface,
            prn = lambda x: self.handler(x, self.iface)
        )

class PacketDelay:
    def __init__(self, bsize, bdelay, imin, imax, num_pkts = 100):
        self.bsize = bsize
        self.bdelay = bdelay
        self.imin = imin
        self.imax = imax
        self.num_pkts = num_pkts
        self.current = 1

    def __iter__(self):
        return self

    def next(self):
        if self.num_pkts <= 0:
            raise StopIteration
        self.num_pkts -= 1
        if self.current == self.bsize:
            self.current = 1
            return random.randint(self.imin, self.imax)
        else:
            self.current += 1
            return self.bdelay

class P4Bench(Packet):
    name = "P4Bench Message"
    fields_desc =  []
    for i in range(args.nb_fields):  
        fields_desc.append(ShortField('field_%d' %i , 0))

bind_layers(UDP, P4Bench, dport=P4BENCH_PORT)
bind_layers(P4Bench, P4Bench, field_0=1)

pkt = Ether(dst='00:00:00:00:00:02')/IP(dst='10.0.0.2', ttl=64)/UDP(sport=65231, dport=P4BENCH_PORT)

pkt_ext = ''
for i in range(args.nb_headers):
    if i < (args.nb_headers - 1):
        pkt_ext = pkt_ext/P4Bench(field_0=1)
    else:
        pkt_ext = pkt_ext/P4Bench(field_0=0)

pkt = pkt / pkt_ext

port_map = {
    0: "veth0",
    1: "veth2",
    2: "veth4",
}

iface_map = {}
for p, i in port_map.items():
    iface_map[i] = p

queue.add_iface("veth2")
queue.add_iface("veth4")

for p, iface in port_map.items():
    t = SnifferThread(iface)
    t.daemon = True
    t.start()

import socket

send_socket = socket.socket(socket.AF_PACKET, socket.SOCK_RAW,
                            socket.htons(0x03))
send_socket.bind((port_map[0], 0))

# wait for receiving threads start
time.sleep(1)

delays = PacketDelay(10, 5, 25, 100, args.nb_packets)
ports = []
print "Sending", args.nb_packets, "packets ..."
for d in delays:
    if args.random_dport:
        pkt["UDP"].dport = random.randint(1024, 65535)
    # pkt.show()
    send_socket.send(str(pkt))
    time.sleep(d / 1000.)

# time.sleep(1)

iface, pkt = queue.get()
while pkt:
    ports.append(iface_map[iface])
    iface, pkt = queue.get()
# print ports
print "DISTRIBUTION..."
for p in port_map:
    c = ports.count(p)
    print "port {}: {:>3} [ {:>5}% ]".format(p, c, 100. * c / args.nb_packets)