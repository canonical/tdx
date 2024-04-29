#!/bin/bash

cleanup() {
    # test results
    # if root : /var/lib/phoronix-test-suite/test-results
    # normal user : ~/.phoronix-test-suite/test-results
    PTS_FOLDER=$HOME/.phoronix-test-suite/
    if [ "$EUID" -eq 0 ]; then
	PTS_FOLDER=/var/lib/phoronix-test-suite/
    fi
    rm -rf $PTS_FOLDER/test-results/
}

setup() {
    # installation
    sudo DEBIAN_FRONTEND=noninteractive apt install -y php-cli php-xml build-essential unzip

    wget https://phoronix-test-suite.com/releases/repo/pts.debian/files/phoronix-test-suite_10.8.4_all.deb
    sudo DEBIAN_FRONTEND=noninteractive apt install -y ./phoronix-test-suite_10.8.4_all.deb

    # phoronix configuration
    phoronix-test-suite user-config-set \
            UploadResults=FALSE \
            PromptForTestIdentifier=FALSE \
            PromptForTestDescription=FALSE \
            PromptSaveName=FALSE \
            RunAllTestCombinations=TRUE \
            Configured=TRUE \
            DropNoisyResults=TRUE
}

echo " start setup $(date +%s)"

setup &> /dev/null

echo " end start setup $(date +%s)"

cleanup

export TEST_RESULTS_IDENTIFIER=tdx-memory-benchmark-id
export TEST_RESULTS_NAME=memory-benchmark
export TEST_RESULTS_DESCRIPTION='PTS memory benchmarking for TDX'

# run

#phoronix-test-suite batch-install stream
#phoronix-test-suite batch-run stream

phoronix-test-suite batch-benchmark memory

phoronix-test-suite result-file-raw-to-csv $TEST_RESULTS_NAME

# if root user, the output result will be /root/$TEST_RESULTS_NAME-raw.csv

echo " end test $(date +%s)"
