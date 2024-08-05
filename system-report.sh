#!/bin/bash
#
# This file is part of Canonical's TDX repository which includes tools
# to setup and configure a confidential computing environment
# based on Intel TDX technology.
# See the LICENSE file in the repository for the license text.

# Copyright 2024 Canonical Ltd.
# SPDX-License-Identifier: GPL-3.0-only

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3,
# as published by the Free Software Foundation.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranties
# of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

#
# This script outputs relevant system information for
# reporting TDX issues at:
#
# https://github.com/canonical/tdx/issues
#

print_section() {
  if [ $# -ne 2 ]; then
    >&2 echo "$0 <header> <command output>"
    exit 1
  fi
  header=$1
  cmdout=$2
  printf "### ${header}\n\n"
  printf "\`\`\`\n"
  printf "${cmdout}"
  printf "\n\`\`\`\n\n"
}

set_pkg_result_string() {
  if [ $# -ne 1 ]; then
    >&2 echo "$0 <package>"
    exit 1
  fi
  package=$1
  result=$( \
  if dpkg -s ${package} &> /dev/null; then \
    echo "Status: Installed"; \
  else echo "Status: Not Installed"; \
  fi)
  result="$result\n$(apt info ${package} 2>/dev/null | grep -E 'Package|Version|APT-Sources')"
}

printf "If you are running this for reporting an issue on GitHub,\n"
printf "copy all output between the markers below.\n\n"

printf "<======== COPY BELOW HERE ========>\n\n"

result=$(lsb_release -a)
print_section "Operating system details" "${result}"

result=$(uname -rvpio) # show everything but hostname
print_section "Kernel version" "${result}"

result=$(sudo dmesg | grep -i tdx)
print_section "TDX kernel logs" "${result}"

result=$( \
if grep -q tdx /proc/cpuinfo; then \
  echo "CPU supports TDX according to /proc/cpuinfo"; \
else echo "No TDX support in CPU according to /proc/cpuinfo"; \
fi)
print_section "TDX CPU instruction support" "${result}"

result=$(grep -m1 "model name" /proc/cpuinfo | cut -f2 -d":")
print_section "CPU details" "${result}"

result=$(find . -name check-production.sh -exec \
  sh -c 'cd "$(dirname "$0")" && sudo ./check-production.sh' {} \;)
print_section "Production system check" "${result}"

set_pkg_result_string "qemu-system-x86"
print_section "QEMU package details" "${result}"

set_pkg_result_string "libvirt-clients"
print_section "Libvirt package details" "${result}"

set_pkg_result_string "ovmf"
print_section "OVMF package details" "${result}"

set_pkg_result_string "sgx-dcap-pccs"
print_section "sgx-dcap-pccs package details" "${result}"

set_pkg_result_string "tdx-qgs"
print_section "tdx-qgs package details" "${result}"

set_pkg_result_string "sgx-ra-service"
print_section "sgx-ra-service package details" "${result}"

set_pkg_result_string "sgx-pck-id-retrieval-tool"
print_section "sgx-pck-id-retrieval-tool package details" "${result}"

printf "<======== COPY ABOVE HERE ========>\n"
