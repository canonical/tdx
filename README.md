# Intel® Trust Domain Extensions (TDX) on Ubuntu

### Table of Contents:
* [1. Introduction](#introduction)
* [2. Report an Issue](#report-an-issue)
* [3. Supported Hardware](#supported-hardware)
* [4. Setup Host OS](#setup-host-os)
* [5. Create TD Image](#create-td-image)
* [6. Boot TD](#boot-td)
* [7. Verify TD](#verify-td)
* [8. Setup Remote Attestation on Host OS and Inside TD](#setup-remote-attestation)
* [9. Perform Remote Attestation Using Intel Tiber Trust Services CLI](#perform-remote-attestation)
* [10. Build Packages From Source](#build-packages-from-source)
* [11. Build Kernel From Source](#build-kernel-from-source)
* [12. Run Tests](#sanity-functional-tests)
* [13. Troubleshooting Tips](#troubleshooting-tips)

<!-- headings -->
<a id="introduction"></a>
## 1. Introduction
Intel® TDX is a Confidential Computing technology which deploys hardware-isolated,
Virtual Machines (VMs) called Trust Domains (TDs). It protects TDs from a broad range of software attacks by
isolating them from the Virtual-Machine Manager (VMM), hypervisor, and other non-TD software on the host platform.
As a result, Intel TDX enhances a platform user’s control of data security and IP protection. Also, it enhances the
Cloud Service Providers’ (CSP) ability to provide managed cloud services without exposing tenant data to adversaries.
For more information, see the [Intel TDX overview](https://www.intel.com/content/www/us/en/developer/tools/trust-domain-extensions/overview.html).

This tech preview of Intel TDX on Ubuntu provides base host OS, guest OS, and remote attestation functionalities.
Two Ubuntu releases are currently supported for base host OS and guest OS:
* Ubuntu Noble 24.04 LTS
* Ubuntu Oracular 24.10

Follow these instructions to set up the Intel TDX host, create a TD, boot the TD, and attest the integrity of the TD's execution environment.

The host OS and TD setup can be customized by editing the global configuration file: `setup-tdx-config`.

<a id="report-an-issue"></a>
## 2. Report an Issue
First, check the [Troubleshooting Tips](#troubleshooting-tips) section. 

If your issue can't be resolved, then submit an issue [here](https://github.com/canonical/tdx/issues) and we'll get back to you ASAP.

To help us with the debugging process, run the `system-report.sh`
tool and attach the report.  

<a id="supported-hardware"></a>
## 3. Supported Hardware
This release works with these Intel® Xeon® Processors:
| Processor | Code Name | TDX Module Version |
| - | - | - |
| 4th Gen Intel® Xeon® Scalable Processors (select SKUs with Intel® TDX) | Sapphire Rapids | 1.5.x |
| 5th Gen Intel® Xeon® Scalable Processors | Emerald Rapids | 1.5.x |
| Intel® Xeon® 6 Processors with P-Cores | Granite Rapids | 2.0.x |

To help identify which processor you have, please visit [ark.intel.com](https://www.intel.com/content/www/us/en/ark.html) and search for the part number. Then, look for "Code Name" and "Intel® Trust Domain Extensions (Intel® TDX)".

<a id="setup-host-os"></a>
## 4. Setup Host OS
In this section, you will install a generic Ubuntu 24.04 server image, install necessary packages to turn
the host OS into an Intel TDX-enabled host OS, optionally install remote attestation components, and enable Intel TDX settings in the BIOS.

### 4.1 Install Ubuntu Server Image

Download and install appropriate Ubuntu Server on the host machine:
* [Ubuntu 24.04 server](https://releases.ubuntu.com/24.04/)
* [Ubuntu 24.10 server](https://releases.ubuntu.com/24.10/)

### 4.2 Enable Intel TDX in Host OS

1. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning the repository (at the appropriate tag/branch).
   
   For example: 

   ```bash
   git clone -b noble-24.04 https://github.com/canonical/tdx.git
   ```

2. Customize the setup of the host and TD by editing the configuration file `setup-tdx-config`.  
    By default, remote attestation components are not installed on the host and inside the TD.  
    You can choose to automatically install remote attestation packages provided by Canonical by setting `TDX_SETUP_ATTESTATION=1`.  
   In this case, you can skip [step 8.2.1](#step-8-2-1) and [step 8.3.3](#step-8-3-3).  

3. Run the `setup-tdx-host.sh` script.<a id="step-4-2-3"></a>

    NOTE: If you're behind a proxy, use `sudo -E` to preserve user environment.

   ```bash
   cd tdx
   sudo ./setup-tdx-host.sh
   ```

4. Reboot.

### 4.3 Enable Intel TDX in the Host's BIOS<a id="step-4-3"></a>

1. Go into the host's BIOS.

    NOTE: The following is a sample BIOS configuration.
    The necessary BIOS settings or the menus might differ based on the platform that is used.
    Please reach out to your OEM/ODM or independent BIOS vendor for instructions dedicated for your BIOS.

2. Go to `Socket Configuration > Processor Configuration > TME, TME-MT, TDX`.

	* Set `Memory Encryption (TME)` to `Enable`
	* Set `Total Memory Encryption Bypass` to `Enable` (Optional setting for best host OS and regular VM performance.)
	* Set `Total Memory Encryption Multi-Tenant (TME-MT)` to `Enable`
	* Set `TME-MT memory integrity` to `Disable`
	* Set `Trust Domain Extension (TDX)` to `Enable`
	* Set `TDX Secure Arbitration Mode Loader (SEAM Loader)` to `Enable`. (NOTE: This allows loading Intel TDX Loader and Intel TDX Module from the ESP or BIOS.)
	* Set `TME-MT/TDX key split` to a non-zero value

3. Go to `Socket Configuration > Processor Configuration > Software Guard Extension (SGX)`.

	* Set `SW Guard Extensions (SGX)` to `Enable`

4. Save the BIOS settings and boot up.

### 4.4 Verify Intel TDX is Enabled on Host OS

Verify that Intel TDX is enabled using the `dmesg` command:

```bash
sudo dmesg | grep -i tdx
```

The message `virt/tdx: module initialized` proves that Intel TDX has initialized properly. Here is an example output:

```console
...
[    5.205693] virt/tdx: BIOS enabled: private KeyID range [64, 128)
[   29.884504] virt/tdx: 1050644 KB allocated for PAMT
[   29.884513] virt/tdx: module initialized
...
```

<a id="create-td-image"></a>
## 5. Create TD Image

In this section, you will create an Ubuntu-based TD image from scratch or convert an existing VM image into a TD image. 
This can be performed on any Ubuntu 22.04 or newer system - an Intel TDX-specific environment is not required.

* The base image is an Ubuntu cloud image.
* By default, the Ubuntu generic kernel is used for the TD guest. The `-intel` kernel, which may have non-upstreamed and/or under-development features,
  can be selected by setting the variable `TDX_SETUP_INTEL_KERNEL=1` in the `setup-tdx-config` configuration file.

### 5.1 Create a New TD Image

A TD image based on Ubuntu 24.10 can be generated with the following commands:

```bash
cd tdx/guest-tools/image/
sudo ./create-td-image.sh -v 24.10
```

You can pass `24.04` to the `-v` to generate a TD image based on Ubuntu 24.04. 

The resulting image will be based on an ([`Ubuntu cloud image`](https://cloud-images.ubuntu.com/)),
the default root password is `123456`, and other default settings are used.
Please note the most important options described after the commands and take a look at the `create-td-image.sh` script for more available options.

Important options for TD image creation:
* If you're behind a proxy, use `sudo -E` to preserve user environment.
* The used kernel type (`generic` or `intel`) will be reflected in the name of the resulting image so it is easy to distinguish.

### 5.2 Convert a Regular VM Image into a TD Image

If you have an existing Ubuntu (`24.04` or `24.10`) VM image, you can enable the Intel TDX feature using the following steps:

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
`./image/tdx-guest-ubuntu-<24.04|24.10>-generic.qcow2`. A different qcow2
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
   1. Apply the following settings to the file `/etc/libvirt/qemu.conf`.

	    ```console
	    user = <your_user_name>
	    group = <your_group>
	    dynamic_ownership = 0
	    ```

   2. Restart the `libvirtd` service

	    ```bash
	    sudo systemctl restart libvirtd
	    ```

2. Boot TD using the following commands.

	```bash
	cd tdx/guest-tools
	./tdvirsh new
	```

   Details about `tdvirsh`:
   * To manage the lifecycle of TDs, we developed a wrapper around the `virsh` tool.
   This new `tdvirsh` tool extends `virsh` with new capabilities to create/remove TDs.
   * By default, `tdvirsh` will use an image located at `./image/tdx-guest-ubuntu-<24.04|24.10>-generic.qcow2` with the `generic` Ubuntu kernel.
   A different qcow2 image (e.g., one with an `intel` kernel) can be used by using the command-line option `-i IMAGE_PATH`.
   * By default, `tdvirsh` will use a XML libvirt template located at `./trust_domain.xml.template`.
   A different XML libvirt template can be used by using the command-line option `-t XML_PATH`.
   * All VMs can be listed with the following command:

        ```bash
        ./tdvirsh list --all
        ```

        Example output:

        ```console
        Id   Name                                                        State
        ---------------------------------------------------------------------------
        1    tdvirsh-trust_domain-f7210c2b-2657-4f30-adf3-639b573ea39f   running (ip:192.168.122.212, hostfwd:32855, cid:3)
        ```

        NOTE: `32855` in `hostfwd:32855` is the port number a user can use to connect to the TD via `ssh -p 32855 root@localhost`.
              You can also connect to the guest using its IP address : `ssh root@192.168.122.212`.

   * A TD can be removed with the following command:

        ```bash
        ./tdvirsh delete [domain]
        ```

   * All available options can be displayed with the following command:

        ```bash
        ./tdvirsh -h
        ```

### 6.3 Secure Boot TD

We provide a libvirt template (`trust_domain-sb.xml.template`) that shows how a TD can be booted with secure boot.
As a result, you can easily boot a TD with secure boot enabled using the following commands:

```bash
cd tdx/guest-tools
./tdvirsh new -t trust_domain-sb.xml.template
```

<a id="verify-td"></a>
## 7. Verify TD

1. Log into the TD using one of the following commands.

   NOTE: If you booted your TD with `td_virsh_tool.sh`, you will likely need
   a different port number from the one below. The tool will print the appropriate port to use
   after it has successfully booted the TD.

   * From localhost
   ```bash
   ssh -p 10022 root@localhost
   ```

   * From remote host
   ```bash
   ssh -p 10022 root@<host_ip>
   ```

2. Verify Intel TDX is enabled in the TD:

	```bash
	dmesg | grep -i tdx
	```

	An example output:

	```console
	[    0.000000] tdx: Guest detected
	[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 2023.05-2+tdx1.0~ubuntu23.10.1 10/17/2023
	[    0.395218] process: using TDX aware idle routine
	[    0.395218] Memory Encryption Features active: Intel TDX
	```

3. Verify quote generation provider:

	```bash
	mkdir -p /sys/kernel/config/tsm/report/testreport0
	cat /sys/kernel/config/tsm/report/testreport0/provider
	```

	Should give the following output:

	```console
	tdx_guest
	```

<a id="setup-remote-attestation"></a>
## 8. Setup Remote Attestation on Host OS and Inside TD
Attestation is a process in which the attester requests the verifier (e.g., Intel Tiber Trust Services) to confirm that a TD is operating in a secure and trusted environment.
This process involves the attester generating a "TD Quote", which contains measurements of the Trusted Execution Environment (TEE) and other cryptographic evidence.
The TD Quote is sent to the verifier who then confirms its validity against reference values and policies.
If confirmed, the verifier returns an attestation token.  The attester can then send the token to a relying party who will validate it.
For more on the basics of attestation, see [Attestation overview](https://docs.trustauthority.intel.com/main/articles/concept-attestation-overview.html).

### 8.1 Check Hardware Status

For attestation to work, you need _Production_ hardware. Run the `check-production.sh` script to verify.

```bash
cd tdx/attestation
sudo ./check-production.sh
```

### 8.2 Setup Intel® SGX Data Center Attestation Primitives (Intel® SGX DCAP) on the Host OS

1. Install the required DCAP packages from Canonical's PPA on the host OS.<a id="step-8-2-1"></a>

	NOTE 1: If you have already installed the attestation components as part of the host OS setup (see [step 2 in section 4.2](#step-4-2-3)), you can continue with [step 3](#verify-sgx-devices).

	NOTE 2: If you're behind a proxy, use `sudo -E` to preserve user environment.

	```bash
	cd tdx/attestation
	sudo ./setup-attestation-host.sh
	```

2. Reboot the system.

3. Verify the Intel SGX devices belong to these groups and have proper permissions.<a id="verify-sgx-devices"></a>

   NOTE: These devices are needed as Intel TDX's attestation flow is based on the Intel SGX attestation flow.

   ```bash
   ls -l /dev/sgx_*
   ```

   Expected result:

   ```console
   crw-rw---- 1 root sgx     10, 125 Apr  3 21:14 /dev/sgx_enclave
   crw-rw---- 1 root sgx_prv 10, 126 Apr  3 21:14 /dev/sgx_provision
   crw-rw---- 1 root sgx     10, 124 Apr  3 21:14 /dev/sgx_vepc
   ```

4. Verify the QGS service is running properly:
	```bash
	sudo systemctl status qgsd
	```

5. Verify the PCCS service is running properly:
	```bash
	sudo systemctl status pccs
	```
6. To set up the PCCS in the next step, you need a subscription key for the [Intel PCS](https://api.portal.trustedservices.intel.com/provisioning-certification).
   1. If you did not request such a subscription key before, [subscribe](https://api.portal.trustedservices.intel.com/products#product=liv-intel-software-guard-extensions-provisioning-certification-service) 
      to Intel PCS, which requires to log in (or create an account). Two subscription keys are generated (for key rotation) and both can be used for the following step.
   2. If you did request such a subscription key before, [retrieve](https://api.portal.trustedservices.intel.com/manage-subscriptions) one of your keys, 
      which requires to log in. You have two subscription keys (for key rotation) and both can be used for the following step.

7. Configure the PCCS service:

   ```bash
   sudo /usr/bin/pccs-configure
   ```

   An example configuration:

   ```console
   Checking nodejs version ...
   nodejs is installed, continue...
   Checking cracklib-runtime ...
   Set HTTPS listening port [8081] (1024-65535) :
   Set the PCCS service to accept local connections only? [Y] (Y/N) :
   Set your Intel PCS API key (Press ENTER to skip) : <Enter your Intel PCS subscription key here>
   Choose caching fill method : [LAZY] (LAZY/OFFLINE/REQ) :
   Set PCCS server administrator password: <pccs-admin-password>
   Re-enter administrator password: <pccs-admin-password>
   Set PCCS server user password: <pccs-server-user-password>
   Re-enter user password: <pccs-server-user-password>
   Do you want to generate insecure HTTPS key and cert for PCCS service? [Y] (Y/N) :N
   ```

   NOTE 1: The resulting config file is located at `/opt/intel/sgx-dcap-pccs/config/default.json`.

   NOTE 2: If you're behind a proxy, add your proxy URL in the `default.json` file.

8. Restart the PCCS service:

	```bash
	sudo systemctl restart pccs
	```

9. Verify the PCCS service is running properly:

	```bash
	sudo systemctl status pccs
	```

10. Register the platform.

    NOTE 1: There are multiple alternatives to perform platform registration with different trade-offs and they are 
    explained in detail in 
    [Intel's Intel TDX Enabling Guide](https://cc-enabling.trustedservices.intel.com/intel-tdx-enabling-guide/02/infrastructure_setup/#platform-registration).

    NOTE 2: If you're behind a proxy, add your proxy URL in `/etc/mpa_registration.conf` like the following example:

    ```console
    proxy type  = manual
    proxy url   = http://<proxy-url>:<port>
    ```

    In the following, we focus on the direct registration variant that uses the Multi-package Registration Agent (MPA).
    This agent is executed on system start up, registers the platform (if necessary), and gets deactivated.
    Please check the following two logs to confirm successful registration:

    1. Check the log of the MPA service:

       ```bash
       sudo systemctl status mpa_registration_tool
       ```

       Example output:

       ```console
       mpa_registration_tool.service - Intel MPA Registration
           Loaded: loaded (/usr/lib/systemd/system/mpa_registration_tool.service; enabled; preset: enabled)
           Active: inactive (dead) since Tue 2024-04-09 22:54:50 UTC; 11h ago
       Duration: 46ms
       Main PID: 3409 (code=exited, status=0/SUCCESS)
				CPU: 21ms

       Apr 09 22:54:50 right-glider-515046 systemd[1]: Started mpa_registration_tool.service - Intel MPA Registratio>
       Apr 09 22:54:50 right-glider-515046 systemd[1]: mpa_registration_tool.service: Deactivated successfully.
       ```

    2. Check the log file of the MPA:
       
       ```bash 
       cat /var/log/mpa_registration.log 
       ``` 

       An example output of successful registration:

       ```console
       [04-06-2024 03:05:53] INFO: SGX Registration Agent version: 1.20.100.2
       [04-06-2024 03:05:53] INFO: Starts Registration Agent Flow.
       [04-06-2024 03:05:54] INFO: Registration Flow - PLATFORM_ESTABLISHMENT or TCB_RECOVERY passed successfully.
       [04-06-2024 03:05:54] INFO: Finished Registration Agent Flow.
       ```

       If an error is reported, re-do the registration from scratch with these steps:

       1. Remove the MPA log file:  `sudo rm /var/log/mpa_registration.log`.
       2. Reboot.
       3. Go into the BIOS.
       4. Navigate to `Socket Configuration > Processor Configuration > Software Guard Extension (SGX)`.
       5. Set these:
          - `SGX Factory Reset` to `Enable`
          - `SGX Auto MP Registration` to `Enable`

### 8.3 Setup [Intel Tiber Trust Services CLI](https://github.com/intel/trustauthority-client-for-go) Inside TD

NOTE: If you have already installed the attestation components as part of the TD image creation,
you proceed to [step 4](#verify-itts-client-version).

1. [Boot a TD](#boot-td) and connect to it.

2. Download this repository by downloading an asset file from the [releases page on GitHub](https://github.com/canonical/tdx/releases) or by cloning the repository (at the appropriate tag/branch).

3. Install the Intel Tiber Trust Service CLI.<a id="step-8-3-3"></a>

	```bash
	cd tdx/attestation
	./setup-attestation-guest.sh
	```

4. Verify presence of Intel Tiber Trust Service CLI by printing its version.<a id="verify-itts-client-version"></a>

	```bash
	trustauthority-cli version
	```

	An example output:

	```console
	Intel® Trust Authority CLI for TDX
	Version: 1.5.0-
	Build Date: 2024-07-08T09:53:15+00:00
	```

<a id="perform-remote-attestation"></a>
### 9. Perform Remote Attestation Using Intel Tiber Trust Services CLI

1. [Boot a TD](#boot-td) and connect to it.

2. Inside the TD, generate a sample TD Quote to prove the Quote Generation Service is working properly.

	```bash
	trustauthority-cli quote
	```

	An example output of a successful quote generation:

	```console
        [4 0 2 0 129 0 0 0 0 0 0 0 147 154 114 51 247 156 76 169 148 10 13 179 149 127 6 7 153 37 33 
         114 143 8 198 185 144 222 132 242 244 129 151 76 0 0 0 0 5 1 2 0 0 0 0 0 0 0 0 0 0 0 0 0 28 
         198 161 122 183 153 233 166 147 250 199 83 107 230 28 18 238 30 15 171 173 168 45 12 153 15 
         8 204 238 42 168 109 231 123 8 112 245 88 197 112 231 255 229 93 109 71 250 4 0 0 0 0 0 0 0
         0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
         0 0 0 0 0 0 16 0 0 0 0 231 2 6 0 0 0 0 0 71 161 204 7 75 145 77 248 89 107 173 14 209 61 80
         213 97 173 30 255 199 247 204 83 10 184 109 167 234 73 255 192 62 87 231 218 130 159 140 18
         156 98 156 57 112 80 83 35 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
	                                       ....
	                                       ....
	                                       ....
         15 43 88 111 53 111 47 115 88 54 79 57 81 87 120 72 82 65 118 90 85 71 79 100 82 81 55 99 
         118 113 82 88 97 113 73 61 10 45 45 45 45 45 69 78 68 32 67 69 82 84 73 70 73 67 65 84 69 
         45 45 45 45 45 10 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
         0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]

	```

3. Attest with the [Intel Tiber Trust Service](https://www.intel.com/content/www/us/en/security/trust-authority.html).
   1. Subscribe to the Intel Tiber Trust Service [free trial](https://plan.seek.intel.com/2023_ITATrialForm).
   2. Obtain an Attestation API key following this [tutorial](https://docs.trustauthority.intel.com/main/articles/tutorial-api-key.html?tabs=attestation-api-key-portal%2Cattestation-sgx-client).

   3. Create a `config.json` file like the example below:

		```console
		{
			"trustauthority_url": "https://portal.trustauthority.intel.com",
			"trustauthority_api_url": "https://api.trustauthority.intel.com",
			"trustauthority_api_key": "<Your Intel Tiber Trust Service Attestation API key>"
		}
		```

   4. Use the Intel Tiber Trust Service CLI to generation an attestation token.
      Under the hood, the CLI will generate a TD Quote using the CPU, send the TD Quote to the external Intel Tiber Trust Service for TD Quote verification, and receive an attestation token on success.  

		```bash
		trustauthority-cli token -c config.json
		```

		An example of a successful attestation token generation:

		```console
		2024/04/30 22:55:17 [DEBUG] GET https://api.trustauthority.intel.com/appraisal/v1/nonce
		2024/04/30 22:55:18 [DEBUG] POST https://api.trustauthority.intel.com/appraisal/v1/attest
		Trace Id: U5sA2GNVoAMEPkQ=
		eyJhbGciOiJQUzM4NCIsImprdSI6Imh0dHBzOi8vYW1iZXItdGVzdDEtdXNlcjEucHJvamVjdC1hbWJlci1zbWFzLmN
		.....
		.....
		.....
		DRctLIeN4MioXztymyK7qsT1p7n7Dh56-HmDQH47MVgrEL_S-wRYDQioEkUvtuA_3pGk

		```

#### 9.1. Event log and measurements

One of the key components the remote attestation is the runtime measurement. The runtime measurement values
are stored in the RTMRs registers for each TD by the TDX module. During the system boot, each component
of the boot process (binary or conf) is measured into a digest. This digest value is extended to the RTMR's
current value. The digest of the result value becomes the new value of the RTMR.

If you want to inspect the event log and RTMR values, you can use the program `tdeventlog` available in the guest.
And furthermore, to see how the boot chain can impact the contents and the size of the boot event log, please take a look at
the [boot methods section](guest-tools/direct-boot/README.md).

<a id="build-packages-from-source"></a>
## 10. Build Packages from Source

Even though the Intel TDX components live in a separate PPA from the rest of the Ubuntu packages,
they follow the Ubuntu standards and offer users the same facilities for code source access and building.

You can find generic instructions on how to build a package from source here: https://wiki.debian.org/BuildingTutorial.
The core idea of building a package from source code is to be able to edit the source code (see https://wiki.debian.org/BuildingTutorial#Edit_the_source_code).

Here are example instructions for building QEMU (for normal user with sudo rights):

1. Install Ubuntu 24.04 or 24.10 (or use an existing Ubuntu system).

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
 	sudo apt install -y ubuntu-dev-tools
	pull-ppa-source --ppa ppa:kobuk-team/tdx-release qemu
	```

	This command will create several files and a folder, the folder is the qemu source code.

4. Rebuild

	```bash
	cd <qemu-source-code>
	sudo apt build-dep ./
	dpkg-buildpackage -us -uc -b
	```

	The resulting debian packages are available in the parent folder.

5. Install the packages.

	For details, you can refer to https://wiki.debian.org/BuildingTutorial#Installing_and_testing_the_modified_package


<a id="build-kernel-from-source"></a>
## 11. Build Kernel from Source

1. Initialize a matching build environment.

	```bash
	git clone https://kernel.ubuntu.com/gitea/kernel/kteam-tools.git
	sudo apt install schroot devscripts ubuntu-dev-tools
	# Some additional package might be installed in next step
	# A session restart might be required at next step to take permission changes into account
	kteam-tools/cranky/cranky chroot create-base "noble"
	kteam-tools/cranky/cranky chroot create-session noble:linux
	```

2. Clone the kernel source.

	```bash
	kteam-tools/cranky/cranky checkout noble:linux-intel
	```

3. Build the kernel.

	```bash
	cd <kernel repository>
	<path-to-kteam-tools>/cranky/cranky fdr clean binary
	```

4. Install the kernel.

	Example of kernel installation:

	```bash
	sudo dpkg -i ../linux-image-unsigned-6.8.0-1011-intel_6.8.0-1011.18_amd64.deb ../linux-modules-6.8.0-1011-intel_6.8.0-1011.18_amd64.deb
	```

<a id="sanity-functional-tests"></a>
## 12. Run Tests

Please follow [tests/README](tests/README.md) to run Intel TDX tests.

<a id="troubleshooting-tips"></a>
## 13. Troubleshooting Tips

| Issue # | Description | Suggestions |
| - | - | - |
| 1 | Performance is poor | Ensure you're using the latest TDX module. You can check the current version with `dmesg` (the version line looks like: `virt/tdx: TDX module: attributes 0x0, vendor_id 0x8086, major_version 1, minor_version 5, build_date 20240129, build_num 698`). See [link](https://cc-enabling.trustedservices.intel.com/intel-tdx-enabling-guide/04/hardware_setup/#deploy-specific-intel-tdx-module-version) on ways to update your TDX module. <br> NOTE: If you chose to "Update Intel TDX Module via Binary Deployment", make sure you're using the correct TDX module version for your hardware. See the [Supported Hardware](#supported-hardware) table. |
| 2 | TDX is not enabled on the host | 1. Ensure your installation of the TDX host components using `setup-tdx-host.sh` did not have any errors. <br> 2. Ensure BIOS settings are correct. See [step 4.3](#step-4.3) |
| 3 | Installation seems to hang | 1. Verify you can get out to the Internet. <br> 2. If you're behind a proxy, make sure you have proper proxy settings. <br> 3. If you're behind a proxy, use `sudo -E` to preserve user environment. |
