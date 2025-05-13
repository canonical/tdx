#!/bin/bash

# this script is supposed to be executed under root
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export no_proxy=127.0.0.1,localhost
sudo yum install -y python3 python3-pip cpuid iperf3

cd ${SCRIPT_DIR}/tdx-tools/
python3 -m pip install ./ 2>&1 | tee install.log
