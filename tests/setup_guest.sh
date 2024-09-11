#!/bin/bash

# this script is supposed to be executed under root

apt install -y python3 python3-pip

cd lib/tdx-tools/
python3 -m pip install --break-system-packages ./
