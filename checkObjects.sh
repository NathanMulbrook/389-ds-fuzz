#!/bin/bash

# Directory to search (current directory by default)
DIR="./build/build_1"

# Symbols to check for (edit as needed)
REQUIRED_SYMBOLS=("asan" "sancov")

# Exclude patterns (files or directories, edit as needed)
EXCLUDES=("exclude_dir" "exclude_file.o")

# Temporary files for report
FAILED_REPORT=$(mktemp)
PASSED_REPORT=$(mktemp)

# Build find exclude arguments
FIND_EXCLUDES=()
EXCLUDED_LIST=()
for pattern in "${EXCLUDES[@]}"; do
    FIND_EXCLUDES+=(-not -path "*/$pattern/*" -not -name "$pattern")
    EXCLUDED_LIST+=("$pattern")
done

# Find all .o files recursively, excluding specified patterns
find "$DIR" -type f -name "*.o" "${FIND_EXCLUDES[@]}" | while read -r objfile; do
    missing=0
    for sym in "${REQUIRED_SYMBOLS[@]}"; do
        if ! nm "$objfile" 2>/dev/null | grep -qw "$sym"; then
            echo "$objfile: missing symbol $sym" >> "$FAILED_REPORT"
            echo "$objfile: missing symbol $sym"
            missing=1
        fi
    done
    if [ $missing -eq 0 ]; then
        echo "$objfile" >> "$PASSED_REPORT"
    fi
done

echo "==== Symbol Check Report ====" >> symbolReport.txt
echo >> symbolReport.txt
echo "== Files Missing Required Symbols ==" >> symbolReport.txt
if [ -s "$FAILED_REPORT" ]; then
    cat "$FAILED_REPORT" >> symbolReport.txt
else
    echo "None" >> symbolReport.txt
fi
echo >> symbolReport.txt
echo "== Files Passing All Checks ==" >> symbolReport.txt
if [ -s "$PASSED_REPORT" ]; then
    cat "$PASSED_REPORT" >> symbolReport.txt
else
    echo "None" >> symbolReport.txt
fi
echo >> symbolReport.txt
echo "== Excluded Files/Directories ==" >> symbolReport.txt
for excl in "${EXCLUDED_LIST[@]}"; do
    echo "$excl" >> symbolReport.txt
done

# Cleanup
rm -f "$FAILED_REPORT" "$PASSED_REPORT"