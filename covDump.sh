#!/bin/bash
# extract_libfuzzer_coverage.sh
#
# Dumps LibFuzzer coverage from a running process via GDB injection
# Usage: ./extract_libfuzzer_coverage.sh <PID> [output_dir]

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <PID> [output_dir]"
    exit 1
fi

PID="$1"
OUTPUT_DIR="${2:-.}"

# Verify process exists
if ! ps -p "$PID" > /dev/null; then
    echo "Process $PID not found"
    exit 1
fi

# Get process metadata
BIN_PATH=$(readlink /proc/"$PID"/exe)
BIN_NAME=$(basename "$BIN_PATH")
WORKING_DIR=$(readlink /proc/"$PID"/cwd)
COVERAGE_NAME="${BIN_NAME}.${PID}.sancov"

echo "Bin Path: ${BIN_PATH}"
echo "Target: ${BIN_NAME} (PID $PID)"
echo "CWD:    ${WORKING_DIR}"
echo "Dumping coverage to: ${OUTPUT_DIR}/${COVERAGE_NAME}"

# Dump coverage via GDB injection
gdb -n -p "$PID" -batch 2>/dev/null \
    -ex "print (void)__sanitizer_cov_set_filename(\"${OUTPUT_DIR}/${COVERAGE_NAME}\")" \
    -ex "print (void)__sanitizer_cov_dump()" \
    -ex "detach" \
    -ex "quit"

# Verify results
if [ -f "${OUTPUT_DIR}/${COVERAGE_NAME}" ]; then
    echo "Success: Coverage data written to ${OUTPUT_DIR}/${COVERAGE_NAME}"
    echo "You can analyze it with:"
    echo "  sancov -symbolize ${OUTPUT_DIR}/${COVERAGE_NAME} ${BIN_PATH}"
else
    echo "Error: Coverage dump failed!"
    echo "Possible reasons:"
    echo "1. Process not compiled with -fsanitize-coverage"
    echo "2. Insufficient permissions for GDB attachment"
    echo "3. Temporary write failure"
    exit 1
fi