#!/bin/bash


#BMV2_PATH=${P4BENCHMARK_ROOT:?}/behavioral-model
#P4C_BM_PATH=$P4BENCHMARK_ROOT/p4c-bm
#P4C_BM_SCRIPT=$P4C_BM_PATH/p4c_bm/__main__.py
BMV2_PATH=/home/jingbo/P4/behavioral-model
P4BENCHMARK_ROOT=/home/jingbo/P4/p4benchmark
P4C_BM_PATH=/home/jingbo/P4/p4c-bm
P4C_BM_SCRIPT=$P4C_BM_PATH/p4c_bm/__main__.py
P4C_BM2_SS=/home/jingbo/P4/p4c/build/p4c-bm2-ss


PROG="main-transmit-P4-16"

set -m
#$P4C_BM_SCRIPT $PROG.p4 --json $PROG.json
# add the compilation for p4-16
$P4C_BM2_SS -o $PROG.json $PROG.p4


if [ $? -ne 0 ]; then
echo "p4 compilation failed"
exit 1
fi

SWITCH_PATH=$BMV2_PATH/targets/simple_switch/simple_switch

CLI_PATH=$BMV2_PATH/tools/runtime_CLI.py

sudo echo "sudo" > /dev/null
sudo $SWITCH_PATH >/dev/null 2>&1
sudo $SWITCH_PATH $PROG.json \
    -i 0@veth0 -i 1@veth2 -i 2@veth4 -i 3@veth6 -i 4@veth8 \
    --log-console &

sleep 2
echo "**************************************"
echo "Sending commands to switch through CLI"
echo "**************************************"
$CLI_PATH --json $PROG.json < commands.txt
echo "READY!!!"
fg
