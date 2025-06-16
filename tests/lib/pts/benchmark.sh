#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TEST_PROFILE="default"

export http_proxy=http://proxy-dmz.intel.com:911/ && export https_proxy=http://proxy-dmz.intel.com:912/
if ! grep -q "sslverify=False" /etc/dnf/dnf.conf; then
    echo "Adding 'sslverify=False' to /etc/dnf/dnf.conf"
    echo "sslverify=False" >> /etc/dnf/dnf.conf
fi
echo "RAM memory = $(free -h | grep Mem | awk '{print $2}')"
echo "Kernel version = $(uname -r)"
sed -i 's|http_proxy=http://proxy-dmz.intel.com:912|http_proxy=http://proxy-dmz.intel.com:911|' /etc/environment
sed -i 's|fedora-epel|fedora/epel|' /etc/yum.repos.d/Intel-Epel.repo
sed -i 's|enabled=1|enabled=0|' /etc/yum.repos.d/bkc-cs9-common.repo
sed -i 's|enabled=1|enabled=0|' /etc/yum.repos.d/bkc-cs9-emr.repo
sed -i 's|enabled=1|enabled=0|' /etc/yum.repos.d/bkc-cs9-emr-internal.repo
sudo dnf install -y make gcc

# test results
# if root : /var/lib/phoronix-test-suite/test-results
# normal user : ~/.phoronix-test-suite/test-results
PTS_FOLDER=$HOME/.phoronix-test-suite/
if [ "$EUID" -eq 0 ]; then
  PTS_FOLDER=/var/lib/phoronix-test-suite/
fi

cleanup() {
    rm -rf $PTS_FOLDER/test-results/
}

setup() {
    # installation
    sudo yum install -y phoronix-test-suite

    # phoronix configuration
    phoronix-test-suite user-config-set \
            UploadResults=FALSE \
            PromptForTestIdentifier=FALSE \
            PromptForTestDescription=FALSE \
            PromptSaveName=FALSE \
            RunAllTestCombinations=TRUE \
            Configured=TRUE \
            DropNoisyResults=TRUE

    rm -rf $PTS_FOLDER/test-suites/local/*
    cp -r ${SCRIPT_DIR}/phoronix-custom-suites/* $PTS_FOLDER/test-suites/local/
}

echo " start setup $(date +%s)"

setup &> /dev/null

echo " end start setup $(date +%s)"

cleanup

# sed -i 's|<StandardDeviationThreshold>2.5|<StandardDeviationThreshold>3.5|' /etc/phoronix-test-suite.xml
# sed -i 's|<ProxyAddress>.*|<ProxyAddress>proxy-dmz.intel.com</ProxyAddress>|' /etc/phoronix-test-suite.xml
# sed -i 's|<ProxyPort>.*|<ProxyPort>912</ProxyPort>|' /etc/phoronix-test-suite.xml

export TEST_RESULTS_IDENTIFIER=tdx-memory-benchmark-id
export TEST_RESULTS_NAME=memory-benchmark
export TEST_RESULTS_DESCRIPTION='PTS memory benchmarking for TDX'

if [ ! -z "$1" ]; then
    TEST_PROFILE=$1
fi

# run

#phoronix-test-suite batch-install stream
#phoronix-test-suite batch-run stream

PTS_SILENT_MODE=1 phoronix-test-suite batch-benchmark $TEST_PROFILE

# OUTPUT_FILE only affects result-file-to-* and not result-file-raw-to-csv
# so we cannot use it here, we wil have to copy the file ourself to benchmark.csv
phoronix-test-suite result-file-raw-to-csv $TEST_RESULTS_NAME
phoronix-test-suite result-file-to-html $TEST_RESULTS_NAME

cp ${HOME}/memory-benchmark-raw.csv ${SCRIPT_DIR}/benchmark.csv
cp ${HOME}/memory-benchmark.html ${SCRIPT_DIR}/benchmark.html

echo " end test $(date +%s)"
