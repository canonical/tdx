# TD Boot Methods 

This folder contains scripts and instructions to boot a TD using the [direct
boot](https://qemu-project.gitlab.io/qemu/system/linuxboot.html) method.

The direct boot method is an alternative to the boot method that is being used by `tdvirsh`
to run TDs.
We will refer to the `tdvirsh` boot method as the `indirect boot` method.
With the `indirect boot` method, the boot chain involves following components:
- TDVF (virtual UEFI firmware)
- SHIM
- Grub
- Kernel + Initrd

The `direct boot` will skip `SHIM` and `Grub` in the boot chain by providing the `Kernel`
and `Initrd` directly to `qemu`. Per consequence, the boot chain involves these components:
- TDVF (virtual UEFI firmware)
- Kernel + Initrd

The boot chain structure is important for remote attestation since it impacts the size of
the event log journal. Indeed, each component in the boot chain generates a set of entries of the event
log journal. The more components we have in the boot chain, the more event logs we will have and the harder
is the verification of the correctness of the measurement values.

For `direct boot`, we would like to investigate 2 ways of passing `kernel` and `initrd` to `qemu`:
- Separately using `-kernel` and `-initrd` arguments
- Bundled together as part of an [Unified Kernel Image](https://uapi-group.org/specifications/specs/unified_kernel_image/)

### Prerequisites

To later perform direct boot with the two direct boot variants, we need to generate following files:

1. TD Guest Image

The boot scripts need a guest image as the final rootfs to boot into.

To generate this guest image, please refer to the section [Create TD Image](../../README.md#create-td-image).

NOTE: The credentials necessary for login into the TD guest can also be found in this section.

2. Kernel, initrd and UKI
 
NOTE: the provided instructions are for `24.04` guest.
    Please replace `24.04` by `24.10` if you want to work with `oracular` TD guest.

```
$ cd guest-tools/image
$ ./create-td-uki.sh tdx-guest-ubuntu-24.04-generic.qcow2
```

This script will generate 3 files:
- `vmlinuz-24.04` : the kernel of the guest image
- `initrd.img-24.04` : the initrd of the guest image
- `uki.efi-24.04` : the Unified Kernel Image that bundles together the kernel, the kernel's commandline and the initrd

### Direct boot

```
$ cd guest-tools/direct-boot
$ ./boot_direct.sh 24.04
```

Once you are in the guest console, you can see the event log journal by:

```
$ tdeventlog
```

Example output:

```
root@tdx-guest:~# tdeventlog
==== TDX Event Log Entry - 0 [0x7FBEF000] ====
RTMR              : 0
Type              : 3 (EV_NO_ACTION)
Length            : 65
Algorithms Number : 1
  Algorithms[0xC] Size: 384
RAW DATA: ----------------------------------------------
7FBEF000  01 00 00 00 03 00 00 00 00 00 00 00 00 00 00 00  ................
7FBEF010  00 00 00 00 00 00 00 00 00 00 00 00 21 00 00 00  ............!...
7FBEF020  53 70 65 63 20 49 44 20 45 76 65 6E 74 30 33 00  Spec ID Event03.
7FBEF030  00 00 00 00 00 02 00 02 01 00 00 00 0C 00 30 00  ..............0.
7FBEF040  00                                               .
RAW DATA: ----------------------------------------------

...
...

==== TDX Event Log Entry - 19 [0x7FBEF77F] ====
RTMR              : 1
Type              : 0x80000007 (EV_EFI_ACTION)
Length            : 95
Algorithms ID     : 12 (TPM_ALG_SHA384)
Digest[0] : 214b0bef1379756011344877743fdc2a5382bac6e70362d624ccf3f654407c1b4badf7d8f9295dd3dabdef65b27677e0
RAW DATA: ----------------------------------------------
7FBEF77F  02 00 00 00 07 00 00 80 01 00 00 00 0C 00 21 4B  ..............!K
7FBEF78F  0B EF 13 79 75 60 11 34 48 77 74 3F DC 2A 53 82  ...yu`.4Hwt?.*S.
7FBEF79F  BA C6 E7 03 62 D6 24 CC F3 F6 54 40 7C 1B 4B AD  ....b.$...T@|.K.
7FBEF7AF  F7 D8 F9 29 5D D3 DA BD EF 65 B2 76 77 E0 1D 00  ...)]....e.vw...
7FBEF7BF  00 00 45 78 69 74 20 42 6F 6F 74 20 53 65 72 76  ..Exit Boot Serv
7FBEF7CF  69 63 65 73 20 49 6E 76 6F 63 61 74 69 6F 6E     ices Invocation
RAW DATA: ----------------------------------------------

==== TDX Event Log Entry - 20 [0x7FBEF7DE] ====
RTMR              : 1
Type              : 0x80000007 (EV_EFI_ACTION)
Length            : 106
Algorithms ID     : 12 (TPM_ALG_SHA384)
Digest[0] : 0a2e01c85deae718a530ad8c6d20a84009babe6c8989269e950d8cf440c6e997695e64d455c4174a652cd080f6230b74
RAW DATA: ----------------------------------------------
7FBEF7DE  02 00 00 00 07 00 00 80 01 00 00 00 0C 00 0A 2E  ................
7FBEF7EE  01 C8 5D EA E7 18 A5 30 AD 8C 6D 20 A8 40 09 BA  ..]....0..m .@..
7FBEF7FE  BE 6C 89 89 26 9E 95 0D 8C F4 40 C6 E9 97 69 5E  .l..&.....@...i^
7FBEF80E  64 D4 55 C4 17 4A 65 2C D0 80 F6 23 0B 74 28 00  d.U..Je,...#.t(.
7FBEF81E  00 00 45 78 69 74 20 42 6F 6F 74 20 53 65 72 76  ..Exit Boot Serv
7FBEF82E  69 63 65 73 20 52 65 74 75 72 6E 65 64 20 77 69  ices Returned wi
7FBEF83E  74 68 20 53 75 63 63 65 73 73                    th Success
RAW DATA: ----------------------------------------------


==== Replayed RTMR values from event log ====
rtmr_0 : a40d9875d5a7477e2d14201a27fc2aef21d9e6243ffe483262d2212cf518fd249fb0956d5d3ba30e6dca6d839c8e6212
rtmr_1 : 8584f2ccb76201a023e8dc30ed918e40650fa96fc5c5802d78cda055a1ef8d65a0845d1ced5bb9601ed0060a5bcf8802
rtmr_2 : 82abbec34b50b6784bd9edc785fdbfd2e49d05acbb0f1ae58c011f057b64bb6532cac5b9146bdb245992118d55d90013
rtmr_3 : 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```

### Direct boot with UKI

Another way to do direct boot is to use the [Unified Kernel Image](https://uapi-group.org/specifications/specs/unified_kernel_image/).
UKI leads to better UEFI Secure Boot support, better supporting TPM measurements and confidential computing, and a more robust boot process.

```
$ cd guest-tools/direct-boot
$ ./boot_uki.sh 24.04
```

Once you are in the guest console, you can see the event log journal by using `tdeventlog` as explained in the previous section.

