#!/bin/bash

# this script is supposed to be executed under root

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-pip

cd ${SCRIPT_DIR}/tdx-tools/
python3 -m pip install --break-system-packages ./
sudo apt remove iperf3 -y
sudo add-apt-repository ppa:kobuk-team/tdx-testing -y
sudo apt update
sudo apt install iperf-vsock -y
