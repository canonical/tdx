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

# sudo apt install linux-crashdump
# reboot
# kdump-config show
# cat /proc/cmdline --> verify crashkernel value in place 
# validate cat /proc/sys/kernel/sysrq > 0
# trigger crash --> sudo "echo c > /proc/sysrq-trigger"
# find crashdump in /var/crash

if [ ! -v DEVICE_IP ]; then
    DEVICE_IP="192.168.102.125"
fi

echo "Installing linux-crashdump and rebooting"
ssh ubuntu@$DEVICE_IP sudo apt install linux-crashdump
if [ $? != 0 ]; then
    echo "Can't install linux-crashdump"
    exit -1
fi

ssh ubuntu@$DEVICE_IP sudo systemctl reboot
if [ $? != 0 ]; then
    echo "Can't reboot"
    exit -2
fi

sleep 30
echo "Waiting for system to come back up"

cnt=0
until ssh ubuntu@$DEVICE_IP ls &> /dev/null; do sleep 1; cnt=$(expr $cnt + 1); if [ $cnt -gt 120 ]; then break; fi; done
if [ $cnt -gt 60 ]; then
    echo "Timed out waiting for $DEVICE_IP to come back up ($cnt)"
    exit -3
fi
if [ $cnt == 0 ]; then
    echo "$DEVICE_IP came back too quickly"
    exit -4
fi

echo "System came back up"

KDUMP_CONFIG="$(ssh ubuntu@$DEVICE_IP sudo kdump-config show)"
if [ $? != 0 ]; then
    echo "Failed getting kdump config"
    exit -5
fi

CMDLINE="$(ssh ubuntu@$DEVICE_IP cat /proc/cmdline)"
if [ $? != 0 ]; then
    echo "Failed getting cmd line"
    exit -6
fi

CRASH_DIR="$(ssh ubuntu@$DEVICE_IP ls /var/crash)"
if [ $? != 0 ]; then
    echo "Failed getting crash directory"
    exit -7
fi


echo "Crashing system"
ssh ubuntu@$DEVICE_IP "echo c | sudo tee /proc/sysrq-trigger" &

sleep 10
echo "Waiting for system to come back up"

cnt=0
until ssh ubuntu@$DEVICE_IP ls &> /dev/null; do sleep 1; cnt=$(expr $cnt + 1); if [ $cnt -gt 120 ]; then break; fi; done
if [ $cnt -gt 60 ]; then
    echo "Timed out waiting for $DEVICE_IP to come back up ($cnt)"
    exit -9
fi
if [ $cnt == 0 ]; then
    echo "$DEVICE_IP came back too quickly"
    exit -10
fi

echo "System came back up"
CRASH_DIR2="$(ssh ubuntu@$DEVICE_IP ls /var/crash)"
if [ $? != 0 ]; then
    echo "Failed getting crash directory"
    exit -11
fi

echo $CRASH_DIR
echo "----------------------------------------------------"
echo "----------------------------------------------------"
echo "----------------------------------------------------"
echo $CRASH_DIR2
