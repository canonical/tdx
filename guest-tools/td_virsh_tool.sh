#!/bin/bash
#
# Run TD VMs managed by libvirt.
#
# Note this script supports running multiple VMs simultaneously,
# either by passing the -n flag or by running the script multiple times.
#

##
# Global constants
#
DOMAIN_PREFIX="td_guest"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
BASE_IMG=${TD_IMG:-${SCRIPT_DIR}/image/tdx-guest-ubuntu-24.04.qcow2}
XML_TEMPLATE=${XML_TEMPLATE:-${SCRIPT_DIR}/td_guest.xml.template}
MAX_DOMAINS=${MAX_DOMAINS:-"20"}

##
# Global variables
#
n_instances=1
overlay_image_path=/tmp/overlay.${domain}.qcow2
domain=""
base_img_path=""
xml_template_path=""
domain_to_clean=""

main() {
    parse_params "$@"

    if [ "${domain_to_clean}" = "all" ]; then
        clean_all
    elif [ ! -z "${domain_to_clean}" ]; then
        clean_one
    fi

    set_input_paths

    set -e
    trap "on_exit" EXIT

    for ((i = 0; i < ${n_instances}; i++)); do
        check_domain_count
        create_overlay_image
        create_domain_xml
        boot_vm
        echo_ssh_cmd
    done
}

usage() {
    cat <<EOM
Usage: ./$(basename "${BASH_SOURCE[0]}") [-h] [-c D] [-n N]

Run TD VMs managed by libvirt.

Available options:

-h,   --help            Print this help and exit
-c D, --clean D         Clean domain with name D (use "all" to clean all)
-n N, --n_instances N   Launch N instances

Environment variables:

TD_IMG         TDX image path (default: ./image/tdx-guest-ubuntu-24.04.qcow2)
XML_TEMPLATE   Path to virsh guest XML template (default: ./td_guest.xml.template)
MAX_DOMAINS    Maximum allowed domains running (default: 20)
EOM
}

parse_params() {
    while :; do
        case "${1-}" in
        -h | --help)
            usage
            exit 0
            ;;
        -n | --n_instances)
            n_instances="${2-}"
            if [ -z ${n_instances} ]; then
                echo "Please pass instance count after -n"
                exit 1
            fi
            shift
            ;;
        -c | --clean)
            domain_to_clean="${2-}"
            if [ -z ${domain_to_clean} ]; then
                echo "Please pass name of domain to destroy (or \"all\" to destroy all)"
                exit 1
            fi
            shift
            ;;
        -?*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *) break ;;
        esac
        shift
    done
}

set_input_paths() {
    base_img_path=$(realpath ${BASE_IMG})
    if [ $? -ne 0 ] || [ ! -f ${base_img_path} ]; then
        echo "Set base TD qcow2 image path with TD_IMG"
        exit 1
    fi
    xml_template_path=$(realpath ${XML_TEMPLATE})
    if [ $? -ne 0 ] || [ ! -f ${xml_template_path} ]; then
        echo "Set libvirt guest XML template path with XML_TEMPLATE"
        exit 1
    fi
}

check_domain_count() {
    local n_domains_running=$(virsh list --state-running |
        grep -c ${DOMAIN_PREFIX})
    if [ ${n_domains_running} -ge ${MAX_DOMAINS} ]; then
        echo "Error: exceeded max allowed guests."
        domain="" # avoid destroying latest domain on_exit
        exit 1
    fi
}

create_overlay_image() {
    local rand_str=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c15)
    overlay_image_path=/tmp/overlay.${rand_str}.qcow2
    qemu-img create \
        -f qcow2 \
        -F qcow2 \
        -b ${base_img_path} \
        ${overlay_image_path} >/dev/null
}

create_domain_xml() {
    awk -v img_path=${base_img_path} \
        -v domain=${DOMAIN_PREFIX} \
        -v overlay_path=${overlay_image_path} '
        {
	gsub("BASE_IMG_PATH", img_path, $0); 
	gsub("DOMAIN", domain, $0); 
	gsub("OVERLAY_IMG_PATH", overlay_path, $0); 
	print;
        }
	' ${xml_template_path} >/tmp/${DOMAIN_PREFIX}.xml
}

boot_vm() {
    virsh define /tmp/${DOMAIN_PREFIX}.xml >/dev/null
    domain=${DOMAIN_PREFIX}-$(virsh domuuid ${DOMAIN_PREFIX})
    mv /tmp/{${DOMAIN_PREFIX}.xml,${domain}.xml} &>/dev/null || true
    virsh domrename ${DOMAIN_PREFIX} ${domain} >/dev/null
    virsh start ${domain} >/dev/null
}

echo_ssh_cmd() {
    local host_port=$(
        virsh \
            qemu-monitor-command ${domain} \
            --hmp info usernet |
            awk '/HOST_FORWARD/ {print $4}'
    )
    local guest_cid=$(
        virsh \
            qemu-monitor-command ${domain} \
            --hmp info qtree |
            awk '/guest-cid/ {print $3}'
    )
    echo "Domain ${domain} running with vsock CID: ${guest_cid}," \
        "ssh -p ${host_port} root@localhost"
}

destroy() {
    local domain_to_destroy="${1}"
    local qcow2_overlay_path=$(virsh dumpxml ${domain_to_destroy} |
        grep -o "\/tmp\/overlay\.[A-Za-z0-9]*\.qcow2")

    echo "Destroying domain ${domain_to_destroy}."

    virsh shutdown ${domain_to_destroy} &>/dev/null
    virsh shutdown --domain ${domain_to_destroy} &>/dev/null

    echo "Waiting for VM to shutdown ..."
    sleep 5

    virsh destroy ${domain_to_destroy} &>/dev/null
    virsh destroy --domain ${domain_to_destroy} &>/dev/null
    virsh undefine ${domain_to_destroy} &>/dev/null

    rm -f ${qcow2_overlay_path} /tmp/${domain_to_destroy}.xml
}

clean_one() {
    domains_all=$(virsh list --all --name)
    if echo ${domains_all} | tr " " "\n" | grep -Fxq ${domain_to_clean}; then
        destroy ${domain_to_clean}
    else
        echo "Unknown domain ${domain_to_clean}"
        echo "Existing domains: $(echo ${domains_all} | tr -d "\n")"
        exit 1
    fi
    exit 0
}

clean_all() {
    for domain_to_clean in $(virsh list --all --name | grep ${DOMAIN_PREFIX}); do
        destroy ${domain_to_clean}
    done
    exit 0
}

on_exit() {
    rc=$?
    if [ ${rc} -ne 0 ]; then
        echo "The script failed..."
        if [ ! -z ${domain} ]; then
            destroy ${domain}
        fi
    fi
    return ${rc}
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
