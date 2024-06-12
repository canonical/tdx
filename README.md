# Intel® Trust Domain Extensions (TDX) on Ubuntu 24.04

### Table of Contents:
* [1. Introduction](#introduction)
* [2. Report an Issue](#report-an-issue)
* [3. Supported Hardware](#supported-hardware)
* [4. Setup Host OS](#setup-host-os)
* [5. Create TD Image](#create-td-image)
* [6. Boot TD](#boot-td)
* [7. Verify TD](#verify-td)
* [8. Setup Remote Attestation on Host OS and inside TD](#setup-remote-attestation)
* [9. Build Packages From Source](#build-packages-from-source)
* [10. Run Tests](#sanity-functional-tests)

<!-- headings -->
<a id="introduction"></a>
## 1. Introduction
Intel® TDX is a Confidential Computing technology which deploys hardware-isolated,
Virtual Machines (VMs) called Trust Domains (TDs). It protects TDs from a broad range of software attacks by
isolating them from the Virtual-Machine Manager (VMM), hypervisor, and other non-TD software on the host platform.
As a result, Intel TDX enhances a platform user’s control of data security and IP protection. Also, it enhances the
Cloud Service Providers’ (CSP) ability to provide managed cloud services without exposing tenant data to adversaries.
For more information, see the [Intel TDX overview](https://www.intel.com/content/www/us/en/developer/tools/trust-domain-extensions/overview.html).

This tech preview of Intel TDX on Ubuntu 24.04 provides base host OS, guest OS, and remote attestation functionalities.
Follow these instructions to setup the Intel TDX host, create a TD, boot the TD, and attest the integrity of the TD's execution environment.

The setup can be customized by editing the global configuration file: `setup-tdx-config`

<a id="report-an-issue"></a>
## 2. Report an Issue
Please submit an issue [here](https://github.com/canonical/tdx/issues) and we'll get back to you ASAP.

<a id="supported-hardware"></a>
## 3. Supported Hardware
This release supports 4th Generation Intel® Xeon® Scalable Processors with activated Intel® TDX and all 5th Generation Intel® Xeon® Scalable Processors.

<a id="setup-host-os"></a>
## 4. Setup Host OS
In this section, you will install a generic Ubuntu 24.04 server image, install necessary packages to turn
the host OS into an Intel TDX-enabled host OS, optionally install remote attestation components, and enable Intel TDX settings in the BIOS.

### 4.1 Install Ubuntu 24.04 Server Image

Download and install [Ubuntu 24.04 server](https://cdimage.ubuntu.com/ubuntu-server/daily-live/pending/noble-live-server-amd64.iso) on the host machine.

### 4.2 Enable Intel TDX in Host OS

1. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning the repository (at the appropriate tag/branch).

2. Run the following script.<a id="step-4-2-2"></a>

    NOTE: If you're behind a proxy, use `sudo -E` to preserve user environment.

    ```bash
	cd tdx
	sudo ./setup-tdx-host.sh
	```

3. Reboot.

### 4.3 Enable Intel TDX in the Host's BIOS

1. Go into the host's BIOS.

    NOTE: The following is a sample BIOS configuration.
    The necessary BIOS settings or the menus might differ based on the platform that is used.
    Please reach out to your OEM/ODM or independent BIOS vendor for instructions dedicated for your BIOS.

2. Go to `Socket Configuration > Processor Configuration > TME, TME-MT, TDX`.

	* Set `Memory Encryption (TME)` to `Enabled`
	* Set `Total Memory Encryption Bypass` to `Enabled` (Optional setting for best host OS and regular VM performance.)
	* Set `Total Memory Encryption Multi-Tenant (TME-MT)` to `Enabled`
	* Set `TME-MT memory integrity` to `Disabled`
	* Set `Trust Domain Extension (TDX)` to `Enabled`
	* Set `TDX Secure Arbitration Mode Loader (SEAM Loader)` to `Enabled`. (NOTE: This allows loading Intel TDX Loader and Intel TDX Module from the ESP or BIOS.)
	* Set `TME-MT/TDX key split` to a non-zero value

3. Go to `Socket Configuration > Processor Configuration > Software Guard Extension (SGX)`.

	* Set `SW Guard Extensions (SGX)` to `Enabled`

4. Save the BIOS settings and boot up.

### 4.4 Verify Intel TDX is Enabled on Host OS

Verify that Intel TDX is enabled using the `dmesg` command:

```bash
sudo dmesg | grep -i tdx
```

The message `virt/tdx: module initialized` proves that the tdx has been properly initialized. Here is an example output:

```
...
[    5.205693] virt/tdx: BIOS enabled: private KeyID range [64, 128)
[   29.884504] virt/tdx: 1050644 KB allocated for PAMT
[   29.884513] virt/tdx: module initialized
...
```

<a id="create-td-image"></a>
## 5. Create TD Image

In this section, you will create an Ubuntu 24.04-based TD image from scratch or convert an existing VM image into a TD image. This can be performed on any Ubuntu 22.04 or newer system - an Intel TDX-specific environment is not required.

* The base image is an Ubuntu 24.04 cloud image.

* By default, the generic kernel is used for the guest. The Intel kernel can be selected by changing the variable `TDX_SETUP_INTEL_KERNEL` in the configuration file `setup-tdx-config`.

### 5.1 Create a New TD Image

A TD image can be generated with the following commands.
The resulting image will be based on an Ubuntu 24.04 cloud image ([`ubuntu-24.04-server-cloudimg-amd64.img`](https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img)), the default root password is `123456`, and other default settings are used.
Please note the most important options described after the commands and have a look at the `create-td-image.sh` script for more available options.

```bash
cd tdx/guest-tools/image/
# create tdx-guest-ubuntu-24.04-generic.qcow2
sudo ./create-td-image.sh
```

Important options for TD image creation:
* If you're behind a proxy, use `sudo -E` to preserve user environment.
* To adjust the base image, set the following two environment variables before running the script:

	```bash
	export OFFICIAL_UBUNTU_IMAGE="https://cloud-images.ubuntu.com/noble/current/"
	export CLOUD_IMG="noble-server-cloudimg-amd64.img"
	```
* The used kernel type (`generic` or `intel`) will be reflected in the name of the resulting image so it is easy to distinguish.

### 5.2 Convert a Regular VM Image into a TD Image

If you have an existing Ubuntu 24.04 VM image, you can enable the Intel TDX feature using the following steps:

1. Boot up your guest, i.e., your regular VM.

2. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning the repository (at the appropriate tag/branch).

3. Run the following script.

	```bash
	cd tdx
	sudo ./setup-tdx-guest.sh
	```

4. Shutdown the guest.


<a id="boot-td"></a>
## 6. Boot TD

Now that you have a TD image, let’s boot it using one of the following two ways:
* Boot using QEMU
* Boot using virsh

NOTE: The script provided for the virsh method supports running multiple TDs simultaneously.
The script provided for the QEMU method supports running only a single instance.

### 6.1 Boot TD with QEMU

Boot TD with the provided script.
By default, the script will use an image with a generic kernel located at
`./image/tdx-guest-ubuntu-24.04-generic.qcow2`. A different qcow2
image (e.g., one with an intel kernel) can be used by setting the `TD_IMG`
command-line variable.

NOTE: It is recommended that you run the script as a non-root user.

```bash
cd tdx/guest-tools
./run_td.sh
```

An example output:

```bash
TD, PID: 111924, SSH : ssh -p 10022 root@localhost
```

### 6.2 Boot TD with virsh (libvirt)

1. [Recommended] Configure libvirt to be usable as non-root user.
	* Apply the following settings to the file `/etc/libvirt/qemu.conf`.

		```bash
		user = <your_user_name>
		group = <your_group>
		dynamic_ownership = 0
		```
	* Restart the `libvirtd` service

		```bash
		systemctl restart libvirtd
		```

2. Boot TD using the following commands.

	```bash
	cd tdx/guest-tools
	./tdvirsh new
	```

Details about `tdvirsh`:
* To manage the lifecycle of TDs, we developed a wrapper around the `virsh` tool.
This new `tdvirsh` tool extends `virsh` with new capabilities to create/remove TDs.
* By default, the `tdvirsh` will use an image located at `./image/tdx-guest-ubuntu-24.04-generic.qcow2` with the `generic` Ubuntu kernel.
A different qcow2 image (e.g., one with an `intel` kernel) can be used by setting the `TD_IMG` command-line variable.
* All VMs can be listed with the following command:
	```
	./tdvirsh list --all
	```

	Example of output:

        ```
        $ ./tdvirsh list --all
        Id   Name                                                        State
        ---------------------------------------------------------------------------
        1    tdvirsh-trust_domain-f7210c2b-2657-4f30-adf3-639b573ea39f   running (ssh:32855, cid:3)
        ```

        `ssh:32855` displays the port user can use to connect to the VM via `ssh`.
* A TD can be removed with the following command:
	```
	./tdvirsh delete [domain]
	```
* All available options can be displayed with the following command:
	```
	./tdvirsh -h
	```


<a id="verify-td"></a>
## 7. Verify TD

1. Log into the TD using one of the following commands.

	NOTE: If you booted your TD with `td_virsh_tool.sh`, you will likely need
	a different port number from the one below. The tool will print the appropriate port to use
	after it has successfully booted the TD.

	```bash
	# From localhost
	ssh -p 10022 root@localhost

	# From remote host
	ssh -p 10022 root@<host_ip>
	```

2. Verify Intel TDX is enabled in the guest using the following command:

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

3. Verify the `tdx_guest` device exists:

	```bash
	ls /dev/tdx_guest
	```

	An example output:

	```
	/dev/tdx_guest
	```

<a id="setup-remote-attestation"></a>
## 8. Setup Remote Attestation on Host OS and inside TD
Attestation is a process in which the attester requests the verifier (e.g., Intel Tiber Trust Services) to confirm that a TD is operating in a secure and trusted environment.
This process involves the attester generating a "TD Quote", which contains measurements of the Trusted Execution Environment (TEE) and other cryptographic evidence.
The TD Quote is sent to the verifier who then confirms its validity against reference values and policies.
If confirmed, the verifier returns an attestation token.  The attester can then send the token to a relying party who will validate it.
For more on the basics of attestation, see [Attestation overview](https://docs.trustauthority.intel.com/main/articles/concept-attestation-overview.html).

### 8.1 Check Hardware Status

For attestation to work, you need _Production_ hardware. Run the following commands to verify.

```bash
cd tdx/attestation
sudo ./check-production.sh
```

### 8.2 Setup Intel® SGX Data Center Attestation Primitives (Intel® SGX DCAP) inside the Host OS

1. Install the required DCAP packages inside the host OS.

	NOTE 1:  If you have already installed Canoncial's attestation components as part of the host OS setup (see [step 2 in section 4.2](#step-4-2-2)), you can continue with [step 3](#verify-sgx-devices).

	NOTE 2: If you're behind a proxy, use `sudo -E` to preserve user environment.

	```bash
	cd tdx/attestation
	sudo ./setup-attestation-host.sh
	```

2. Reboot the system.

3. Verify that The Intel SGX devices have proper user and group.<a id="verify-sgx-devices"></a>

	NOTE: These devices are needed as Intel TDX's attestation flow is based on the Intel SGX attestation flow.

	```bash
	$ ls -l /dev/sgx_*
	crw-rw-rw- 1 root sgx     10, 125 Apr  3 21:14 /dev/sgx_enclave
	crw-rw---- 1 root sgx_prv 10, 126 Apr  3 21:14 /dev/sgx_provision
	crw-rw---- 1 root sgx     10, 124 Apr  3 21:14 /dev/sgx_vepc
	```

3. Verify the QGS service is running properly:
	```bash
	sudo systemctl status qgsd
	```

4. Verify the PCCS service is running properly:
	```bash
	sudo systemctl status pccs
	```

5. To setup the PCCS in the next step, you need a subscription key for the [Intel PCS](https://api.portal.trustedservices.intel.com/provisioning-certification).
	* If you did not request such a subscription key before, [subscribe](https://api.portal.trustedservices.intel.com/products#product=liv-intel-software-guard-extensions-provisioning-certification-service) to Intel PCS, which requires to log in (or create an account).
	Two subscription keys are generated (for key rotation) and both can be used for the following step.
	* If you did request such a subscription key before, [retrieve](https://api.portal.trustedservices.intel.com/manage-subscriptions) one of your keys, which requires to log in.
	You have two subscription keys (for key rotation) and both can be used for the following step.

6. Configure the PCCS service:

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
	Set your Intel PCS API key (Press ENTER to skip) : <Enter your Intel PCS subscription key here>
	You didn't set Intel PCS API key. You can set it later in config/default.json.
	Choose caching fill method : [LAZY] (LAZY/OFFLINE/REQ) :
	Set PCCS server administrator password: <PCCS-ADMIN-PASSWORD>
	Re-enter administrator password: <PCCS-ADMIN-PASSWORD>
	Set PCCS server user password: <PCCS-SERVER-USER-PASSWORD>
	Re-enter user password: <PCCS-SERVER-USER-PASSWORD>
	Do you want to generate insecure HTTPS key and cert for PCCS service? [Y] (Y/N) :N
	```

7. Restart the PCCS service:

	```bash
	sudo systemctl restart pccs
	```

8. Verify the PCCS service is running properly:

	```bash
	sudo systemctl status pccs
	```

9. Platform registration.

	The platform registration is done with the `mpa_registration_tool` tool.
	This service is executed on system start up, registers the platform, and gets deactivated.
	Please check the following two logs to confirm successful registration:

	1. Check service logs with following command:

		```bash
		sudo systemctl status mpa_registration_tool
		```

		A successful example output:

		```bash
		mpa_registration_tool.service - Intel MPA Registration
			Loaded: loaded (/usr/lib/systemd/system/mpa_registration_tool.service; enabled; preset: enabled)
			Active: inactive (dead) since Tue 2024-04-09 22:54:50 UTC; 11h ago
		Duration: 46ms
		Main PID: 3409 (code=exited, status=0/SUCCESS)
				CPU: 21ms

		Apr 09 22:54:50 right-glider-515046 systemd[1]: Started mpa_registration_tool.service - Intel MPA Registratio>
		Apr 09 22:54:50 right-glider-515046 systemd[1]: mpa_registration_tool.service: Deactivated successfully.
		```
	2. Check plateform registration logs with following command:
		```bash
		cat /var/log/mpa_registration.log
		```

		An example output:

		```bash
		[04-06-2024 03:05:53] INFO: SGX Registration Agent version: 1.20.100.2
		[04-06-2024 03:05:53] INFO: Starts Registration Agent Flow.
		[04-06-2024 03:05:54] INFO: Registration Flow - PLATFORM_ESTABLISHMENT or TCB_RECOVERY passed successfully.
		[04-06-2024 03:05:54] INFO: Finished Registration Agent Flow.
		```

	If an error is reported in one of the logs, boot into the BIOS, go to 
	`Socket Configuration > Processor Configuration > Software Guard Extension (SGX)`, and set
	- `SGX Factory Reset` to `Enabled`
	- `SGX Auto MP Registration` to `Enabled`

### 8.3 Setup [Intel Tiber Trust Services CLI](https://github.com/intel/trustauthority-client-for-go) inside TD

NOTE: If you have already installed the attestation components as part of the TD image creation,
you proceed to [step 4](#verify-itts-client-version).

1. [Boot a TD](#boot-td) and connect to it.

2. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning the repository (at the appropriate tag/branch).

3. Install the Intel Tiber Trust Service CLI.

	```bash
	cd tdx/attestation
	./setup-attestation-guest.sh
	```

4. Verify presence of Intel Tiber Trust Service CLI by printing its version.<a id="verify-itts-client-version"></a>

	```bash
	trustauthority-cli version
	```

	An example output:

	```
	Intel® Trust Authority CLI for TDX
	Version: 1.2.0-
	Build Date: 2024-03-07T17:35:34+00:00
	```

### 8.4 Perform Attestation using Intel Tiber Trust Services CLI

1. [Boot a TD](#boot-td) and connect to it.

2. Inside the TD, generate a sample TD Quote to prove the Quote Generation Service is working properly.

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

3. Attest with the [Intel Tiber Trust Service](https://www.intel.com/content/www/us/en/security/trust-authority.html).
	* Obtain an API key following the [tutorial](https://docs.trustauthority.intel.com/main/articles/tutorial-api-key.html?tabs=attestation-api-key-portal%2Cattestation-sgx-client).
	* Create a `config.json` file like the example below:

		```
		{
			"trustauthority_url": "https://portal.trustauthority.intel.com",
			"trustauthority_api_url": "https://api.trustauthority.intel.com",
			"trustauthority_api_key": "<Your Intel Tiber Trust Service API key>"
		}
		```

	* Use the Intel Tiber Trust Service CLI to generation an attestation token.
		Under the hood, the CLI will generate a TD Quote using the CPU, send the TD Quote to the external Intel Tiber Trust Service for TD Quote verification, and receive an attestation token on success.

		```bash
		trustauthority-cli token -c config.json
		```

		An example of a successful attestation token generation:

		```
		2024/04/30 22:55:17 [DEBUG] GET https://api.trustauthority.intel.com/appraisal/v1/nonce
		2024/04/30 22:55:18 [DEBUG] POST https://api.trustauthority.intel.com/appraisal/v1/attest
		Trace Id: U5sA2GNVoAMEPkQ=
		eyJhbGciOiJQUzM4NCIsImprdSI6Imh0dHBzOi8vYW1iZXItdGVzdDEtdXNlcjEucHJvamVjdC1hbWJlci1zbWFzLmN
		.....
		.....
		.....
		DRctLIeN4MioXztymyK7qsT1p7n7Dh56-HmDQH47MVgrEL_S-wRYDQioEkUvtuA_3pGk

		```

<a id="build-packages-from-source"></a>
## 9. Build Packages from Source

Even though the Intel TDX components live in a separate PPA from the rest of the Ubuntu packages,
they follow the Ubuntu standards and offer users the same facilities for code source access and building.

You can find generic instructions on how to build a package from source here: https://wiki.debian.org/BuildingTutorial.
The core idea of building a package from source code is to be able to edit the source code (see https://wiki.debian.org/BuildingTutorial#Edit_the_source_code).

Here are example instructions for building QEMU (for normal user with sudo rights):

1. Install Ubuntu 24.04 (or use an existing Ubuntu 24.04 system).

2. Install build dependencies:

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

3. Download package's source:

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

5. Install the packages.

	For details, you can refer to https://wiki.debian.org/BuildingTutorial#Installing_and_testing_the_modified_package


<a id="sanity-functional-tests"></a>
## 10. Running Tests

Please follow [tests/README](tests/README.md) to run Intel TDX tests.
