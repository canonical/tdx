# tdx
Intel confidential computing - TDX

This procedure shows how to enable the TDX feature on host and guest
on top of Ubuntu 23.10

## Enable TDX on host

- Install Ubuntu 23.10 image on the host machine
  
  https://releases.ubuntu.com/23.10/ubuntu-23.10-live-server-amd64.iso

- Get the setup script

  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-host.sh

- Run the script

  $ chmod a+x ./setup-host.sh && sudo ./setup-host.sh

- Reboot

## Enable TDX on guest

- Get the script

  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-guest.sh

- Run the script

  $ chmod a+x ./setup-guest.sh && sudo ./setup-guest.sh
