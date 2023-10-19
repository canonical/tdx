# tdx
Intel confidential computing - TDX

This procedure shows how to enable the TDX feature on host and guest
on top of Ubuntu 23.10

## Enable TDX on host

- Deploy Ubuntu 23.10 cloud image on the server

  https://cloud-images.ubuntu.com/mantic/current/mantic-server-cloudimg-amd64.img

  If you are not able to deploy image on the server, you can try to install it from
	an ISO:

	https://cdimage.ubuntu.com/ubuntu-server/daily-live/20230927/mantic-live-server-amd64.iso

- Get the script

  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-host.sh

- Run the script

  $ chmod a+x ./setup-host.sh && sudo ./setup-host.sh

- Reboot

## Enable TDX on guest

- Get the script

  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-guest.sh

- Run the script

  $ chmod a+x ./setup-guest.sh && sudo ./setup-guest.sh
