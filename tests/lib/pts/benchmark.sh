#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TEST_PROFILE="default"

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

cp ${HOME}/memory-benchmark-raw.csv ${SCRIPT_DIR}/benchmark.csv

echo " end test $(date +%s)"
