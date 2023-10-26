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

If you have an existing Ubuntu 23.10 VM up and running, you can enable the TDX feature by following
these instructions:

- Get the script

  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-guest.sh

- Run the script

  $ chmod a+x ./setup-guest.sh && sudo ./setup-guest.sh

### Create TD guest image

If you want to create a Ubuntu 23.10 TDX guest image for QEMU (qcow2) from scratch.
You will need to follow these instructions that can be executed directly on the host you previously setup
or on any other Ubuntu (>= 22.04):

- Clone the current repo
- Generate TD guest image

  The original image is ubuntu-23.10-server-cloudimg-amd64.img and it can be foud here
	https://cloud-images.ubuntu.com/releases/mantic/release/

  $ (cd  guest-tools/image/ ; sudo ./create-td-image.sh)

The TD image will be available at : /tmp/tdx-guest-ubuntu-23.10.qcow2
The root passwordis set to 123456.

## Run a TD guest with QEMU

On the TDX host previously setup, to run the TD guest with QEMU:

  $ TD_IMG=/tmp/tdx-guest-ubuntu-23.10.qcow2 ./run_td.sh

To access the guest:

  $ ssh -p 10022 root@localhost

The password is : 123456