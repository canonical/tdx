## Intel® Trust Domain Extensions (TDX)

Intel® TDX is a confidential computing technology which deploys hardware-isolated,
Virtual Machines (VMs) called Trust Domains (TDs). It protects TD VMs from a broad range of software attacks by
isolating them from the Virtual-Machine Manager (VMM), hypervisor and other non-TD software on the host platform.
As a result, it enhances a platform user’s control of data security and IP protection.  Also, it enhances the
Cloud Service Providers’ (CSP) ability to provide managed cloud services without exposing tenant data to adversaries.
For more information see the [Intel article on TDX architecture](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-trust-domain-extensions.html).

This tech preview of TDX 1.0 on Ubuntu 23.10  provides host and guest functionalities. Follow these instructions
to setup the TDX host, create a TD guest, and boot it.

## Supported Hardware

	4th Generation Intel® Xeon® Scalable Processors or newer with Intel® TDX.

## Setup TDX Host

In this section, you will install a generic Ubuntu 23.10 server, install necessary packages to turn the host
into a TDX host, and enable TDX settings in the BIOS.

1. Download and install [Ubuntu 23.10 server](https://releases.ubuntu.com/23.10/ubuntu-23.10-live-server-amd64.iso) on the host machine.

NOTE: Although rare, the installer may hang during its bootup on some systems, which is caused by a kernel graphics driver issue.  The workaround is to add the `nomodeset` parameter to the kernel command-line.  Follow these steps:
* At the `GRUB` boot menu, press `e`
* Add `nomodeset` to linux line, like the example below:
```bash
linux	/casper/vmlinuz nomodeset ---
```
* Press `Ctrl-x` to continue the boot process
* After installation is complete, reboot, use `nomodeset` again, like the example below:
```bash
linux	/boot/vmlinuz-6.5.0-10-generic nomodeset root=UUID=c5605a23-05ae-4d9d-b65f-e47ba48b7560 ro
```
* Step #3 below will automatically add `nomodeset` to the GRUB config so that no additional intervention is needed

2. Clone this repo to get scripts that will be used throughout this README.

```bash
git clone https://github.com/canonical/tdx.git
```

3. Run the script.

```bash
cd tdx
sudo ./setup-tdx-host.sh
```

4. Reboot.

### Enable TDX Settings in the Host's BIOS

1. Go into the host's BIOS.

NOTE: The following is a sample BIOS configuration.  It may vary slightly from one manufacturer to another.

2. Go to `Socket Configuration > Processor Configuration > TME, TME-MT, TDX`.

		* Set `Memory Encryption (TME)` to `Enabled`
		* Set `Total Memory Encryption Bypass` to `Enabled` (Optional: for best host and non-TDVM performance.)
		* Set `Total Memory Encryption Multi-Tenant (TME-MT)` to `Enabled`
		* Set `TME-MT memory integrity` to `Disabled`
		* Set `Trust Domain Extension (TDX)` to `Enabled`
		* Set `TDX Secure Arbitration Mode Loader (SEAM Loader)` to `Enabled`. (NOTE: This allows loading SEAMLDR and TDX module from the ESP or BIOS.)
		* Set `TME-MT/TDX key split` to a non-zero value

3. Go to `Socket Configuration > Processor Configuration > Software Guard Extension (SGX)`.

		* Set `SW Guard Extensions (SGX)` to `Enabled`

4. Save the BIOS settings and boot up.

### Verify TDX is Enabled on Host

1. Verify that TDX is enabled using the `dmesg` command.

```bash
sudo dmesg | grep -i tdx
```

Example output:

```bash
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
...
```

## Setup TDX Guest

In this section, you will create an Ubuntu 23.10-based TD guest from scratch or convert an existing non-TD guest into one. This can be performed on any Ubuntu 22.04 or newer system and a TDX-specific environment is not required.

### Create a New TD Guest Image

The base image is an Ubuntu 23.10 cloud image [`ubuntu-23.10-server-cloudimg-amd64.img`](https://cloud-images.ubuntu.com/releases/mantic/release/). You can be customized your preferences by setting these two environment variables before running the script:

```bash
export OFFICIAL_UBUNTU_IMAGE="https://cloud-images.ubuntu.com/releases/mantic/release/"
export CLOUD_IMG="ubuntu-23.10-server-cloudimg-amd64.img"
```

1. Generate a TD guest image.

```bash
cd tdx/guest-tools/image/
sudo ./create-td-image.sh
```

The produced TD guest image is `tdx-guest-ubuntu-23.10.qcow2`.

The root password is set to `123456`.

### Convert a Non-TD Guest into a TD Guest

If you have an existing Ubuntu 23.10 non-TD guest, you can enable the TDX feature by following these steps.

1. Boot up your guest.

2. Clone this repo.

```bash
git clone https://github.com/canonical/tdx.git
```

3. Run the script.

```bash
cd tdx
sudo ./setup-tdx-guest.sh
```
4. Shutdown the guest.

## Boot TD Guest

Now that you have a TD guest image, let’s boot it.  There are two ways to boot it:
* Boot using QEMU
* Boot using virsh

### Boot TD Guest with QEMU

1. Boot TD Guest with the provided script.

NOTE: It is recommended that you run the script as a non-root user. To do this, add the current user to the `kvm` group:

```bash
sudo usermod -aG kvm $USER
```
Close the current shell and open a new one to apply this group settings.

```bash
cd tdx/guest-tools
TD_IMG=<path_to_td_qcow2_image> ./run_td.sh
```

### Boot TD Guest with virsh (Libvirt)

1. Configure the libvirt.

NOTE: It is recommended that you run virsh as a non-root user. To do that, please apply these settings to `/etc/libvirt/qemu.conf`.

```bash
user = <your_user_name>
group = <your_group>
dynamic_ownership = 0
```

* Restart the `libvirtd` service

```bash
systemctl restart libvirtd
```

2. Boot TD guest with libvirt

```bash
cd tdx/guest-tools
TD_IMG=<path_to_td_qcow2_image> ./run_td_virsh.sh
```

## Verify TD Guest

1. Log into the guest.

NOTE: The example below uses the credentials for a TD guest created from scratch.
If you converted your own guest, please use your original credentials.

```bash
ssh -p 10022 root@localhost
```

2. Verify TDX is enabled in the guest.

```bash
sudo dmesg | grep -i tdx
```

Example output:

```bash
[    0.000000] tdx: Guest detected
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 2023.05-2+tdx1.0~ubuntu23.10.1 10/17/2023
[    0.395218] process: using TDX aware idle routine
[    0.395218] Memory Encryption Features active: Intel TDX
```

2. Verify the `tdx_guest` device exists.

```bash
ls /dev/tdx_guest
```

Example output:

```bash
/dev/tdx_guest
```

## Additional Sanity and Functional Test Cases

If you're interested in doing additional sanity and functional testing of TDX, see this [wiki](https://github.com/intel/tdx/wiki/Tests).
