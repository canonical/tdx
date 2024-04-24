#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

on_exit() {
    rc=$?
    if [ ${rc} -ne 0 ]; then
        echo "====================================="
        echo "ERROR : The script failed..."
        echo "====================================="
    fi
    return ${rc}
}

_error() {
  echo "Error : $1"
  exit 1
}

trap "on_exit" EXIT

source ${SCRIPT_DIR}/setup-tdx-common

KERNEL_RELEASE=6.8.0-1001-intel

# add the login user to kvm group
# the idea is that the login user will be the one who will run the guest (qemu)
# so skip adding root
add_user_to_kvm() {
    LOG_USER=$(logname)
    if [ -n "$LOG_USER" ] && [ "$LOG_USER" != "root" ]; then
        usermod -aG kvm $LOG_USER
    fi
}

# grub: switch to kernel version
grub_switch_kernel() {
    KERNELVER=$1
    MID=$(awk '/Advanced options for Ubuntu/{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2)
    KID=$(awk "/with Linux $KERNELVER/"'{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2 | head -n1)
    cat > /etc/default/grub.d/99-tdx-kernel.cfg <<EOF
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
EOF
    grub-editenv /boot/grub/grubenv set saved_entry="${MID}>${KID}"
    update-grub
}

grub_cmdline_kvm() {
  # update cmdline to add tdx=1 to kvm_intel
  if ! grep -q -E "GRUB_CMDLINE_LINUX.*=.*\".*kvm_intel.tdx( )*=1.*\"" /etc/default/grub; then
    sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 kvm_intel.tdx=1\"/g" /etc/default/grub
    update-grub
    grub-install
  fi
}

grub_cmdline_nohibernate() {
  # nohibernate
  # TDX cannot survive from S3 and deeper states.  The hardware resets and
  # disables TDX completely when platform goes to S3 and deeper.  Both TDX
  # guests and the TDX module get destroyed permanently.
  # The kernel uses S3 for suspend-to-ram, and use S4 and deeper states for
  # hibernation.  Currently, for simplicity, the kernel chooses to make TDX
  # mutually exclusive with S3 and hibernation.
  if ! grep -q -E "GRUB_CMDLINE_LINUX.*=.*\".*nohibernate.*\"" /etc/default/grub; then
    sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 nohibernate\"/g" /etc/default/grub
    update-grub
    grub-install
  fi
}

# preparation
apt update
apt install --yes software-properties-common gawk &> /dev/null

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

# stop at error
set -e

add_kobuk_ppa

apt install --yes --allow-downgrades \
    linux-image-unsigned-${KERNEL_RELEASE} \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    ovmf \
    tdx-tools-host

grub_switch_kernel ${KERNEL_RELEASE}

grub_cmdline_kvm || true
grub_cmdline_nohibernate || true
add_user_to_kvm || true

# setup attestation
"${SCRIPT_DIR}"/attestation/setup-host.sh

echo "========================================================================"
echo "The setup has been done successfully. Please enable now TDX in the BIOS."
echo "========================================================================"
