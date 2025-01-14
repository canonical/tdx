#!/bin/bash

DOMAIN="tdvirsh"

./tdvirsh delete all

while true; do

echo "create vm"
./tdvirsh new

while ! sshpass -p 123456 ssh -o StrictHostKeyChecking=no -p 10022 root@localhost exit; do
    echo "wait VM up"
    sleep 1
done

./tdvirsh shutdown $DOMAIN

while pidof /usr/bin/qemu-system-x86_64; do
    echo "wait shutting down"
    sleep 1
done
./tdvirsh undefine $DOMAIN

echo "... NEXT"

done
