#!/usr/bin/env python3
#
# Copyright 2024 Canonical Ltd.
# Authors:
# - Hector Cao <hector.cao@canonical.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranties of MERCHANTABILITY,
# SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#

import socket
import time
from functools import wraps
import subprocess

def timeit(func):
    @wraps(func)
    def timeit_wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        result = func(*args, **kwargs)
        end_time = time.perf_counter()
        total_time = end_time - start_time
        # first item in the args, ie `args[0]` is `self`
        print(f'Function {func.__name__}{args} {kwargs} Took {total_time:.4f} seconds')
        return result
    return timeit_wrapper

def tcp_port_available():
    sock = socket.socket()
    sock.bind(('', 0))
    port = sock.getsockname()[1]
    sock.close()
    return port

def get_max_td_vms():
    cmd = ['rdmsr', '0x87']
    rc = subprocess.run(cmd, capture_output=True)
    assert rc.returncode == 0, "Failed getting max td vms"
    data = rc.stdout.decode().split()
    assert len(data) > 0, "Failed getting max td vms"
    rdmsr = int(data[0], 16)
    max_td_vms = (rdmsr >> 32) - 1
    return max_td_vms

def get_num_cpus():
    cmd = ['grep', '-c', 'processor', '/proc/cpuinfo']
    rc = subprocess.run(cmd, capture_output=True)
    assert rc.returncode == 0, "Failed getting number of cpus"
    return int(rc.stdout.decode())

def get_memory_free_gb():
    cmd = ['free', '-hg']
    rc = subprocess.run(cmd, capture_output=True)
    assert rc.returncode == 0, "Failed getting free memory"
    lines = rc.stdout.decode().split('\n')
    assert len(lines) >= 2, "Invalid response to free command"
    assert "Mem" in lines[1], "Invalid response to free command"
    assert len(lines[1].split()) > 3, "Invalid response to free command"
    free_mem = lines[1].split()[3]
    assert 'Gi' in free_mem, "Invalid response to free command"
    return float(free_mem.split('Gi')[0])

def get_current_td_vms():
    current_td_vms = 0
    cmd = ['ps', 'wwaux']
    rc = subprocess.run(cmd, capture_output=True)
    assert rc.returncode == 0, "Failed getting max td vms"
    lines = rc.stdout.decode().split('\n')
    for l in lines:
        if "qemu-system" in l and "tdx" in l:
            current_td_vms += 1
    return current_td_vms
