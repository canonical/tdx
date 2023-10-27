# tdx
Intel confidential computing - TDX

This procedure shows how to enable the TDX feature on host and guest
on top of Ubuntu 23.10

## Enable TDX on host

- Install Ubuntu 23.10 image on the host machine
  
  https://releases.ubuntu.com/23.10/ubuntu-23.10-live-server-amd64.iso

- Get the setup script

```bash
  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-host.sh
```

- Run the script

```bash
  $ chmod a+x ./setup-host.sh && sudo ./setup-host.sh
```

- Reboot

## Enable TDX on guest

If you have an existing Ubuntu 23.10 VM up and running, you can enable the TDX feature by following
these instructions:

- Get the script

```bash
  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-guest.sh
```

- Run the script

```bash
  $ chmod a+x ./setup-guest.sh && sudo ./setup-guest.sh
```

Now the VM is TDX ready and needs to reboot with appropriate QEMU flags, please refer to	https://raw.githubusercontent.com/canonical/tdx/main/guest-tools/run_td.sh as an example.

### Create TD guest image

If you want to create a Ubuntu 23.10 TDX guest image for QEMU (qcow2) from scratch.
You will need to follow these instructions that can be executed directly on the host you previously setup
or on any other Ubuntu (>= 22.04):

- Clone the current repo
- Generate TD guest image

```bash
  $ (cd  guest-tools/image/ ; sudo ./create-td-image.sh)
```

This script will create a TD image based on the Ubuntu 23.10 Cloud Image ubuntu-23.10-server-cloudimg-amd64.img
and can be found at : https://cloud-images.ubuntu.com/releases/mantic/release/

This base image can be customized by setting two environment variables:

```bash
  $ export OFFICIAL_UBUNTU_IMAGE="https://cloud-images.ubuntu.com/releases/mantic/release/"
  $ export CLOUD_IMG="ubuntu-23.10-server-cloudimg-amd64.img"
```

The TD image will be available at : /tmp/tdx-guest-ubuntu-23.10.qcow2

The root password is set to 123456

## Run a TD guest with QEMU

On the TDX host previously setup, to run the TD guest with QEMU:

If you have cloned this repository, the script wil be in guest-tools.

```bash
  $ cd guest-tools
```

If not, you can download the script as follow:

```bash
  $ https://raw.githubusercontent.com/canonical/tdx/dev-review/guest-tools/run_td.sh
  $ chmod a+x run_td.sh
```

To run the TD:

```bash
  $ TD_IMG=/tmp/tdx-guest-ubuntu-23.10.qcow2 ./run_td.sh
```

The script will run the TD in the background and if the guest image has been created from scratch previously,
it can be accessed via SSH:

```bash
  $ ssh -p 10022 root@localhost
```