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

set -e

echo "Getting information for kexec call"
UNAME_RELEASE="$(ssh ubuntu@$DEVICE_IP uname -r)"
KERNEL="/boot/vmlinuz-$UNAME_RELEASE"
INITRD="/boot/initrd.img-$UNAME_RELEASE"
ssh $SSH_OPTIONS ubuntu@$DEVICE_IP ls $KERNEL > /dev/null
ssh $SSH_OPTIONS ubuntu@$DEVICE_IP ls $INITRD > /dev/null
CMDLINE="$(ssh $SSH_OPTIONS ubuntu@$DEVICE_IP cat /proc/cmdline)"

echo "Calling kexec: ssh $SSH_OPTIONS ubuntu@$DEVICE_IP sudo kexec -l $KERNEL --initrd=$INITRD --command-line=\"$CMDLINE\""
ssh $SSH_OPTIONS ubuntu@$DEVICE_IP sudo kexec -l $KERNEL --initrd=$INITRD --command-line=\"$CMDLINE\"

echo "Running kexec -e in background"
ssh $SSH_OPTIONS ubuntu@$DEVICE_IP sudo kexec -e &

echo "Waiting for system to go down"
cnt=0
until ! ssh -o ConnectTimeout=2 $SSH_OPTIONS ubuntu@$DEVICE_IP ls &> /dev/null; do 
    sleep 1; 
    cnt=$(expr $cnt + 1); 
    if [ $cnt -gt 30 ]; then
        echo "$DEVICE_IP did not reboot"
        exit 1
    fi
done

echo "Waiting for system to come back up"
cnt=0
until ssh -o ConnectTimeout=2 $SSH_OPTIONS ubuntu@$DEVICE_IP ls &> /dev/null; do 
    sleep 1; 
    cnt=$(expr $cnt + 1); 
    if [ $cnt -gt 120 ]; then
        echo "Timed out waiting for $DEVICE_IP to come back up ($cnt)"
        exit 1
    fi
done

echo "Kexec Successfully Performed"
