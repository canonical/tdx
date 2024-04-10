# Intel® Trust Domain Extensions (TDX) on Ubuntu

### Table of Contents:
* [1. Introduction](#introduction)
* [2. Report an Issue](#report-an-issue)
* [3. Supported Hardware](#supported-hardware)
* [4. Setup TDX Host](#setup-tdx-host)
* [5. Setup TD Guest](#setup-td-guest)
* [6. Boot TD Guest](#boot-td-guest)
* [7. Verify TD Guest](#verify-td-guest)
* [8. Verify attestation setup](#setup-remote-attestation)
* [9. Perform Attestation](#attest)
* [10. Build Packages From Source](#build-packages-from-source)
* [11. Additional Sanity and Functional Test Cases](#sanity-functional-tests)

<!-- headings -->
<a id="introduction"></a>
## 1. Introduction
Intel® TDX is a confidential computing technology which deploys hardware-isolated,
Virtual Machines (VMs) called Trust Domains (TDs). It protects TD VMs from a broad range of software attacks by
isolating them from the Virtual-Machine Manager (VMM), hypervisor and other non-TD software on the host platform.
As a result, it enhances a platform user’s control of data security and IP protection. Also, it enhances the
Cloud Service Providers’ (CSP) ability to provide managed cloud services without exposing tenant data to adversaries.
For more information, see the [Intel TDX overview](https://www.intel.com/content/www/us/en/developer/tools/trust-domain-extensions/overview.html).

This tech preview of TDX on Ubuntu 24.04 provides base host and guest functionalities. Follow these instructions
to setup the TDX host, create a TD guest, and boot it.

<a id="report-an-issue"></a>
## 2. Report an Issue
Please submit an issue [here](https://github.com/canonical/tdx/issues) and we'll get back to you ASAP.

<a id="supported-hardware"></a>
## 3. Supported Hardware
This release supports 4th Generation Intel® Xeon® Scalable Processors with Intel® TDX and all 5th Generation Intel®  Xeon® Scalable Processors.

<a id="setup-tdx-host"></a>
## 4. Setup TDX Host
In this section, you will install a generic Ubuntu 24.04 server, install necessary packages to turn 
the host into a TDX host, and enable TDX settings in the BIOS.

1. Download and install [Ubuntu 24.04 server](https://cdimage.ubuntu.com/ubuntu-server/daily-live/pending/noble-live-server-amd64.iso) on the host machine.

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

2. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning it at the appropriate tag.

3. Run the script. <br>

NOTE: If you're behind a proxy, use `sudo -E` to preserve user environment.

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

An example output:

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
...
```
<a id="setup-td-guest"></a>
## 5. Setup TD Guest

In this section, you will create an Ubuntu 24.04-based TD guest from scratch or convert an existing non-TD guest into one. This can be performed on any Ubuntu 22.04 or newer system and a TDX-specific environment is not required.

### Create a New TD Guest Image

The base image is an Ubuntu 24.04 cloud image [`ubuntu-24.04-server-cloudimg-amd64.img`](https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img). You can be customized your preferences by setting these two environment variables before running the script:

```bash
export OFFICIAL_UBUNTU_IMAGE="https://cloud-images.ubuntu.com/releases/mantic/release/"
export CLOUD_IMG="ubuntu-23.10-server-cloudimg-amd64.img"
```

1. Generate a TD guest image. <br>
NOTE: If you're behind a proxy, use `sudo -E` to preserve user environment.

```bash
cd tdx/guest-tools/image/
sudo ./create-td-image.sh
```

The produced TD guest image is `tdx-guest-ubuntu-24.04.qcow2`.

The root password is set to `123456`.

### Convert a Non-TD Guest into a TD Guest

If you have an existing Ubuntu 24.04 non-TD guest, you can enable the TDX feature by following these steps.

1. Boot up your guest.

2. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning it at the appropriate tag.

3. Run the script. 

```bash
cd tdx
sudo ./setup-tdx-guest.sh
```
4. Shutdown the guest.

<a id="boot-td-guest"></a>
## 6. Boot TD Guest

Now that you have a TD guest image, let’s boot it. There are two ways to boot it:
* Boot using QEMU
* Boot using virsh

NOTE: the virsh method supports running multiple TDs simultaneously, while the QEMU method
supports running only a single instance.

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

An example output:

```bash
TD VM, PID: 111924, SSH : ssh -p 10022 root@localhost
```

### Boot TD Guest with virsh (libvirt)

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
./td_virsh_tool.sh
```

If you are running the script outside the `tdx/guest-tools` directory, you should set the
shell variables TD_IMG and/or XML_TEMPLATE to specifiy the paths to the base .qcow2 image
and the libvirt guest XML template file, respectively. For example:

```bash
TD_IMG=/tmp/myimage.qcow2 XML_TEMPLATE=../myguest.xml ./td_virsh_tool.sh
```

Note that `td_virsh_tool.sh` also supports running multiple TDs simultaneously. This can
be accomplished either by running the script multiple times or by passing the `-n N` command
line option (where N is the number of instances you wish to launch). `td_virsh_tool.sh`
also accepts a `-c D` option (where D is either the domain name or "all" for all domains)
for destroying and cleaning up unwanted TDs.

```bash
# launch two TDs
./td_virsh_tool.sh -n 2
# clean/destroy td_guest-1 domain
./td_virsh_tool.sh -c td_guest-1
# clean/destroy all domains containing "td_guest" in name
./td_virsh_tool.sh -c all
```

<a id="verify-td-guest"></a>
## 7. Verify TD Guest

1. Log into the guest.

NOTE: The example below uses the credentials for a TD guest created from scratch.
If you converted your own guest, please use your original credentials.

Also note that if you booted your guest with `td_virsh_tool.sh` that you will likely need
a different port number from the one below. The tool will print the appropriate port to use
after it has successfully booted the TD.

```bash
# From localhost
ssh -p 10022 root@localhost

# From remote host
ssh -p 10022 root@<host_ip>
```

3. Verify TDX is enabled in the guest.

```bash
dmesg | grep -i tdx
```

An example output:

```
[    0.000000] tdx: Guest detected
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 2023.05-2+tdx1.0~ubuntu23.10.1 10/17/2023
[    0.395218] process: using TDX aware idle routine
[    0.395218] Memory Encryption Features active: Intel TDX
```

2. Verify the `tdx_guest` device exists.

```bash
ls /dev/tdx_guest
```

An example output:

```
/dev/tdx_guest
```

<a id="setup-remote-attestation"></a>
## 8. Setup Remote Attestation on Host and TD Guest
Attestation is a process in which the attester requests the verifier (Intel Trust Authority Service) to confirm that it is operating in a secure and trusted environment.  This process involves the attester generating a "quote", which contains trusted execution environment (TEE) measurements and other cryptographic evidence.  The quote is sent to the verifier who then confirms its validity against reference values and policies.  If confirmed, the verifier returns an attestation token.  The attester can then send the token to a reply party who will validate it.  For more on the basics of attestation, see [Attestation overview](https://docs.trustauthority.intel.com/main/articles/concept-attestation-overview.html).

For attestation to work, you need _Production_ hardware. Run this script to verify.

```bash
cd tdx/attestation
sudo ./check-production.sh
```

1. Verify that sgx devices have proper user and group.

```bash
$ ls -l /dev/sgx_*
crw-rw-rw- 1 root sgx     10, 125 Apr  3 21:14 /dev/sgx_enclave
crw-rw---- 1 root sgx_prv 10, 126 Apr  3 21:14 /dev/sgx_provision
crw-rw---- 1 root sgx     10, 124 Apr  3 21:14 /dev/sgx_vepc
```

2. Verify the QGS service is running properly.

```bash
sudo systemctl status qgsd
```

3. Verify the PCCS service is running properly.
```bash
sudo systemctl status pccs
```

4. Obtain an [Intel PCS API key](https://api.portal.trustedservices.intel.com/provisioning-certification).  This is needed to configure the PCCS service in the next step.  Specifically, you should subscribe to the Provisioning Certification Service.

5. Configure the PCCS service.  

```bash
sudo /usr/bin/pccs-configure
```

An example configuration you can use:

```
Checking nodejs version ...
nodejs is installed, continue...
Checking cracklib-runtime ...
Set HTTPS listening port [8081] (1024-65535) :
Set the PCCS service to accept local connections only? [Y] (Y/N) :
Set your Intel PCS API key (Press ENTER to skip) : <Enter your Intel PCS API key here>
You didn't set Intel PCS API key. You can set it later in config/default.json.  
Choose caching fill method : [LAZY] (LAZY/OFFLINE/REQ) :
Set PCCS server administrator password: <PCCS-ADMIN-PASSWORD>
Re-enter administrator password: <PCCS-ADMIN-PASSWORD>
Set PCCS server user password: <PCCS-SERVER-USER-PASSWORD>
Re-enter user password: <PCCS-SERVER-USER-PASSWORD>
Do you want to generate insecure HTTPS key and cert for PCCS service? [Y] (Y/N) :N
```

6. Restart the PCCS service.

```bash
sudo systemctl restart pccs
```

7. Verify the PCCS service is running properly.

```bash
sudo systemctl status pccs
```
8. Platform registration.

The platformation registration is done with `mpa_registration_tool`, the service is run on system start up,
registers the platform and gets desactivated. Please check the service does not output any error message:

```bash
sudo systemctl status mpa_registration_tool
```

```bash
○ mpa_registration_tool.service - Intel MPA Registration
     Loaded: loaded (/usr/lib/systemd/system/mpa_registration_tool.service; enabled; preset: enabled)
     Active: inactive (dead) since Tue 2024-04-09 22:54:50 UTC; 11h ago
   Duration: 46ms
   Main PID: 3409 (code=exited, status=0/SUCCESS)
        CPU: 21ms

Apr 09 22:54:50 right-glider-515046 systemd[1]: Started mpa_registration_tool.service - Intel MPA Registratio>
Apr 09 22:54:50 right-glider-515046 systemd[1]: mpa_registration_tool.service: Deactivated successfully.
```

If the failure occurred, you might want to boot into the BIOS and perform `SGX Factory Reset` (go to `Socket Configuration > Processor Configuration`).

### Setup [Intel Trust Authority (ITA) Client](https://github.com/intel/trustauthority-client-for-go) on Guest 
1. [Boot a TD guest](#boot-td-guest) and connect to it.

2. Clone this repo.

```bash
git clone https://github.com/canonical/tdx.git
```

2. Install the ITA client. <br>

```bash
cd tdx/attestation
./setup-attestation-guest.sh
```

3. Verify the ITA client version.

```bash
trustauthority-cli version
```

An example output:

```
Intel® Trust Authority CLI for TDX
Version: 1.0.1-
Build Date: 2023-10-20T09:45:41+00:00
```

<a id="attest"></a>
## 9. Perform Attestation
1. Inside the TD guest, generate a sample TD quote to prove the quote generation service is working properly.

```bash
cd /usr/share/doc/libtdx-attest-dev/examples/
./test_tdx_attest
```

An example output of a successful quote generation:

```
		TDX report data

00000000: 1a d0 79 02 45 df 7e 77 2b 9f a2 43 8c 69 4f 8a
00000010: f3 0b 53 44 01 87 15 e1 44 1b 27 f1 c0 eb 14 da
00000020: bb 8d dd 00 6c 5b 78 97 fa 1a da 86 83 2a 10 76
00000030: 35 63 bb 36 ea d0 17 2f eb 3e 20 ab 2a 34 86 e5
		
		TDX report

00000000: 81 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00000010: 06 06 16 18 03 ff 00 04 00 00 00 00 00 00 00 00
00000020: ae ef a8 61 f5 b5 f0 4f b5 ad 95 8c 1b ae f7 5f
00000030: 2c 05 e0 e1 5e cd 5f 87 96 85 0a 10 cf ca a7 58
 ....
 ....
 
Successfully get the TD Quote
Wrote TD Quote to quote.dat
Failed to extend rtmr[2]
Failed to extend rtmr[3]
```

NOTE: You can ignore the `Failed to extend rtmr` messages.

You should also find a `quote.dat` file generated.

2. Next step is to attest with the [Intel Trust Authority](https://www.intel.com/content/www/us/en/security/trust-authority.html) service.  For this, you will need to subscribe and obtain an API key. See this [tutorial](https://docs.trustauthority.intel.com/main/articles/tutorial-api-key.html?tabs=attestation-api-key-portal%2Cattestation-sgx-client) for how to create a key.

3. Once you have an API key, create a config.json like the example below:

```
{
    "trustauthority_url": "https://portal.trustauthority.intel.com"
    "trustauthority_api_url": "https://api.trustauthority.intel.com",
    "trustauthority_api_key": "djE6ZWQ1ZDU2MGEtZDcyMi00ODBmLWJkMGYtMTc3OTNjNjM2ZGY5Onc0cHM3QXV4RDE3U0dHOFZUcjNLQzYyTXpkQXhVNDlVNWtDN3JwVzI="
}
```

4. Finally, attest with the Intel Trust Authority service.

```bash
trustauthority-cli token -c config.json
```

An example of a successful attestation:

```
2024/03/19 23:59:09 [DEBUG] GET https://api.trustauthority.intel.com/appraisal/v1/nonce

Get the vsock port number [4050]

Reply message body is 5030 bytes
2024/03/19 23:59:13 [DEBUG] POST https://api.trustauthority.intel.com/appraisal/v1/attest
Trace Id: U5sA2GNVoAMEPkQ=
eyJhbGciOiJQUzM4NCIsImprdSI6Imh0dHBzOi8vYW1iZXItdGVzdDEtdXNlcjEucHJvamVjdC1hbWJlci1zbWFzLmN
.....
.....
.....
DRctLIeN4MioXztymyK7qsT1p7n7Dh56-HmDQH47MVgrEL_S-wRYDQioEkUvtuA_3pGk

```

<a id="build-packages-from-source"></a>
## 10. Build Packages From Source

Despite the fact that TDX components live in a separate PPA from the rest of the Ubuntu packages,
they follow the Ubuntu standards and offer users the same facilities for code source access and building.

You can find generic instructions on how to build a package from source here: https://wiki.debian.org/BuildingTutorial

Here are the example intructions for building qemu (for normal user with sudo rights):

1. Install Ubuntu 24.04

You can install Ubuntu 24.04 or use an existing Ubuntu 24.04 system.

2. Install components for build:

```bash
sudo apt update
sudo apt install --no-install-recommends --yes software-properties-common \
		build-essential \
		fakeroot \
		devscripts \
		wget \
		git \
		equivs \
		liblz4-tool \
		sudo \
		unzip \
		curl \
		xz-utils \
		cpio \
		gawk
```

3. Download package's source

```bash
sudo add-apt-repository -s ppa:kobuk-team/tdx-release
apt source qemu
```

This command will create several files and a folder, the folder is the qemu source code.

4. Rebuild

```bash
cd <qemu-source-code>
sudo apt build-dep ./
debuild -us -uc -b
```

The resulting debian packages are available in the parent folder.

5. Install the packages

You can refer to https://wiki.debian.org/BuildingTutorial#Installing_and_testing_the_modified_package

### Modify source code

The core idea of building a package from source code is to be able to edit the source code. The instructions can be found at https://wiki.debian.org/BuildingTutorial#Edit_the_source_code

<a id="sanity-functional-tests"></a>
## 11. Additional Sanity and Functional Test Cases

If you're interested in doing additional sanity and functional testing of TDX, see this [wiki](https://github.com/intel/tdx/wiki/Tests).
