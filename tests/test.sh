#!/usr/bin/expect

set timeout -1

spawn ./run.sh
expect -exact "localhost login:"
