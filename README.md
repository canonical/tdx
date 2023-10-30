# tdx
Intel confidential computing - TDX

## What is Intel TDX ?

Intel® Trust Domain Extensions (Intel® TDX) is a confidential computing technology which deploys hardware-isolated,
Virtual Machines (VMs) called Trust Domains (TDs). It protects TD VMs from a broad range of software attacks by
isolating them from the Virtual-Machine Manager (VMM), hypervisor and other non-TD software on the host platform.
As a result, it enhances a platform user’s control of data security and IP protection.  Also, it enhances the
Cloud Service Providers’ (CSP) ability to provide managed cloud services without exposing tenant data to adversaries.
For more information see the Intel article on TDX architecture.

This tech preview of TDX 1.0 on Ubuntu 23.10  provides host and guest functionalities. Follow these instructions
to setup the TDX host, create a TD guest, and boot it. 

## Supported Hardware

  4th Generation Intel® Xeon® Scalable Processors or newer with Intel® TDX.

## Setup TDX Host

In this section, you will install a generic Ubuntu 23.10 server, install necessary packages to turn the host
into a TDX host, and enable TDX settings in the BIOS.

- Install Ubuntu 23.10 image on the host machine
  
  https://releases.ubuntu.com/23.10/ubuntu-23.10-live-server-amd64.iso

- Get the setup script

```bash
  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-tdx-host.sh
```

- Run the script

```bash
  $ chmod a+x ./setup-tdx-host.sh && sudo ./setup-tdx-host.sh
```

- Reboot

- Go into the BIOS and configure these settings to enable TDX:

Go to EDKII MENU -> Socket Configuration -> Processor Configuration -> TME, TME-MT, TDX

  - Set Total Memory Encryption (TME) to Enable
  - Set Total Memory Encryption Bypass to Enable (optional; for best host and non-TDVM performance)
  - Set Total Memory Encryption Multi-Tenant (TME-MT) to Enable
  - Set TME-MT memory integrity to Disable
  - Set Trust Domain Extension (TDX) to Enable
  - Set the TME-MT/TDX key split to a non zero value
  - Set TDX Secure Arbitration Mode Loader (SEAM Loader) to Enable. This allows loading SEAMLDR and TDX module
    from the ESP or BIOS.

Go to EDKII MENU -> Socket Configuration -> Processor Configuration -> Software Guard Extension (SGX)

  - Set SW Guard Extensions (SGX) to Enable

Save BIOS settings and boot up.

- Verify that TDX is enabled using the dmesg command:

$ sudo dmesg | grep -i tdx

Example output:

```
...
[    5.300843] tdx: BIOS enabled: private KeyID range [16, 32)
[   15.960876] tdx: TDX module: attributes 0x0, vendor_id 0x8086, major_version 1, minor_version 5, build_date 20230323, build_num 481
[   15.960879] tdx: CMR: [0x100000, 0x77800000)
[   15.960881] tdx: CMR: [0x100000000, 0x407a000000)
[   15.960882] tdx: CMR: [0x4080000000, 0x807c000000)
[   15.960883] tdx: CMR: [0x8080000000, 0xc07c000000)
[   15.960884] tdx: CMR: [0xc080000000, 0x1007c000000)
[   18.149996] tdx: 4202516 KBs allocated for PAMT.
[   18.150000] tdx: module initialized.
…
```

## Setup TDX Guest

### Create a new TD Guest image

In this section, you will create an Ubuntu 23.10-based TD guest. This can be performed on any Ubuntu 22.04 or
newer system and a TDX-specific environment is not required.

- Get the current repository

```bash
  $ wget https://github.com/canonical/tdx/archive/refs/heads/main.zip
  $ unzip main.zip
  $ cd tdx-main/
```

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

The produced TD guest image will be available at : guest-tools/image/tdx-guest-ubuntu-23.10.qcow2

The root password is set to 123456

### Boot TD Guest with QEMU

Now that you have a TD guest image, let’s boot it with QEMU.

- Start the TD guest

If you have downloaded this repository, the script wil be in guest-tools.

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
  $ TD_IMG=<path_to_td_qcow2> ./run_td.sh
```

- Log into the guest

The script will run the TD in the background and if the guest image has been created from scratch previously,
it can be accessed via SSH:

```bash
  $ ssh -p 10022 root@localhost
```

- Verify TDX in the guest

```bash
$ dmesg | grep -i tdx
```

Example output:

```bash
[    0.000000] tdx: Guest detected
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 2023.05-2+tdx1.0~ubuntu23.10.1 10/17/2023
[    0.395218] process: using TDX aware idle routine
[    0.395218] Memory Encryption Features active: Intel TDX
```

Please check that the tdx device is available :

```bash
root@tdx-guest:~# ls /dev/tdx_guest 
/dev/tdx_guest
root@tdx-guest:~# 
```

### Convert regular Guest into a TD Guest

If you have an existing Ubuntu 23.10 VM up and running, you can enable the TDX feature by following
these instructions:

- Get the script

```bash
  $ wget https://raw.githubusercontent.com/canonical/tdx/main/setup-tdx-guest.sh
```

- Run the script

```bash
  $ chmod a+x ./setup-tdx-guest.sh && sudo ./setup-tdx-guest.sh
```

Now the VM is TDX ready and needs to reboot with appropriate QEMU flags, please refer to	https://raw.githubusercontent.com/canonical/tdx/main/guest-tools/run_td.sh as an example.
