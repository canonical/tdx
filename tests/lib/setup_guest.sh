#!/bin/bash

# this script is supposed to be executed under root
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

sudo yum install -y python3 python3-pip

cd ${SCRIPT_DIR}/tdx-tools/
python3 -m pip install ./ 2>&1 | tee install.log
sudo yum install -y iperf3
