#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if ! which sqlite3 &> /dev/null; then
    echo "install sqlite3"
    apt install sqlite3
fi

CACHE_DB="/opt/intel/sgx-dcap-pccs/pckcache.db"
TABLES="appraisal_policies pck_certchain platforms crl_cache pck_crl platforms_registered
enclave_identities pcs_certificates umzug fmspc_tcbs pcs_version pck_cert platform_tcbs"

for table in $TABLES; do
    echo "Dump table $table"
    echo "==="
    sqlite3 -header -csv $CACHE_DB "select * from $table;"
done

