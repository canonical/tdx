#!/usr/bin/bash
#
# Copyright 2024 Canonical Ltd.
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

SSH_OPTIONS=" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if [ ! -v DEVICE_IP ]; then
    echo "Must define DEVICE_IP"
    exit 1
fi

echo "Installing linux-crashdump and rebooting"
set -e
ssh ubuntu@$DEVICE_IP sudo apt install linux-crashdump
ssh ubuntu@$DEVICE_IP sudo systemctl reboot
sleep 15

echo "Waiting for system to come back up"
cnt=0
until ssh ubuntu@$DEVICE_IP ls &> /dev/null; do sleep 1; cnt=$(expr $cnt + 1); if [ $cnt -gt 120 ]; then break; fi; done
if [ $cnt -gt 120 ]; then
    echo "Timed out waiting for $DEVICE_IP to come back up ($cnt)"
    exit 1
fi
if [ $cnt == 0 ]; then
    echo "$DEVICE_IP came back quickly, likely did not reboot as expected"
    exit 1
fi

echo "System came back up, printing out useful debug info"

ssh ubuntu@$DEVICE_IP sudo kdump-config show
ssh ubuntu@$DEVICE_IP cat /proc/cmdline

# Get crash directory before to compare later
CRASH_DIR_BEFORE="$(ssh ubuntu@$DEVICE_IP ls /var/crash)"

echo "Crashing system"
ssh ubuntu@$DEVICE_IP "echo c | sudo tee /proc/sysrq-trigger" > /dev/null &
sleep 10

echo "Waiting for system to come back up"
cnt=0
until ssh ubuntu@$DEVICE_IP ls &> /dev/null; do sleep 1; cnt=$(expr $cnt + 1); if [ $cnt -gt 120 ]; then break; fi; done
if [ $cnt -gt 120 ]; then
    echo "Timed out waiting for $DEVICE_IP to come back up ($cnt)"
    exit 1
fi
if [ $cnt == 0 ]; then
    echo "$DEVICE_IP came back quickly, likely did not crash as expected"
    exit 1
fi

echo "System came back up"
CRASH_DIR_AFTER="$(ssh ubuntu@$DEVICE_IP ls /var/crash)"
echo Before crash directory listing: $CRASH_DIR_BEFORE
echo After crash directory listing: $CRASH_DIR_AFTER

# Verifying crash directory are not the same (extra entry should be in place)
if [ "$CRASH_DIR_BEFORE" == "$CRASH_DIR_AFTER" ]; then
    echo "Crash directories are the same"
    exit 1
fi

echo "Kdump Successfully Performed"
