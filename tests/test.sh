#!/usr/bin/expect

set timeout -1

spawn [lindex $argv 0]/run.sh
expect -exact " login:"
