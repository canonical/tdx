#!/bin/bash

# this script is supposed to be executed under root

DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-pip

cd lib/tdx-tools/
python3 -m pip install --break-system-packages ./
sudo apt remove iperf3 -y
sudo add-apt-repository ppa:kobuk-team/testing -y
sudo apt update
sudo apt install iperf-vsock -y
