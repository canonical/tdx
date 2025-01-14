#!/bin/bash

DOMAIN="tdvirsh"

./tdvirsh delete all

while true; do

echo "create vm"
./tdvirsh new

sleep 20

./tdvirsh shutdown $DOMAIN

while pidof /usr/bin/qemu-system-x86_64; do
    echo "wait shutting down"
    sleep 1
done
./tdvirsh undefine $DOMAIN

echo "... NEXT"

done
