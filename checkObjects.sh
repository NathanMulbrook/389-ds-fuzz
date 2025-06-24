#!/bin/bash

# Directory to search (current directory by default)
DIR="./build/build_1"

# Output directory for the report (change as needed)
OUTDIR="./logs"
REPORT_FILE="${OUTDIR}/symbolReport.txt"

# Symbols to check for (edit as needed)
REQUIRED_SYMBOLS=("asan" "sancov" "sanitizer_cov" "covrec" "ubsan")

# Exclude patterns (files or directories, edit as needed)
EXCLUDES=("debug/incremental" "exclude_file.o")

# Temporary files for report
FAILED_REPORT=$(mktemp)
PASSED_REPORT=$(mktemp)
MISSING_SYMBOL_COUNTS_FILE=$(mktemp)

# Count totals for summary
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0

# Remove old report file if it exists
rm -f "$REPORT_FILE"

# Initialize counters for each symbol
declare -A MISSING_SYMBOL_COUNTS
for sym in "${REQUIRED_SYMBOLS[@]}"; do
    MISSING_SYMBOL_COUNTS[$sym]=0
done

# Build find exclude arguments
FIND_EXCLUDES=()
EXCLUDED_LIST=()
for pattern in "${EXCLUDES[@]}"; do
    FIND_EXCLUDES+=(-not -path "*/$pattern/*" -not -wholename "*/$pattern")
    EXCLUDED_LIST+=("$pattern")
done

FILES_LIST=()
while IFS= read -r objfile; do
    FILES_LIST+=("$objfile")
done < <(find "$DIR" -type f -regextype posix-extended -regex ".*\.(o|a)$" "${FIND_EXCLUDES[@]}")

TOTAL_FILES=${#FILES_LIST[@]}
PASSED_FILES=0
FAILED_FILES=0

# Find all .o and .a files recursively, excluding specified patterns
for objfile in "${FILES_LIST[@]}"; do
    missing=0
    declare -A FILE_MISSING
    for sym in "${REQUIRED_SYMBOLS[@]}"; do
        if ! nm "$objfile" 2>/dev/null | grep -qE "(_)?$sym"; then
            echo "$objfile: missing symbol $sym" >>"$FAILED_REPORT"
            missing=1
            FILE_MISSING[$sym]=1
        fi
    done
    for sym in "${REQUIRED_SYMBOLS[@]}"; do
        if [[ ${FILE_MISSING[$sym]} ]]; then
            echo "$sym" >>"$MISSING_SYMBOL_COUNTS_FILE"
        fi
    done
    if [ $missing -eq 0 ]; then
        echo "$objfile" >>"$PASSED_REPORT"
        PASSED_FILES=$((PASSED_FILES + 1))
    else
        total_syms=$(nm "$objfile" 2>/dev/null | wc -l)
        echo "$objfile: total symbols: $total_syms" >>"$FAILED_REPORT"
        FAILED_FILES=$((FAILED_FILES + 1))
    fi
    unset FILE_MISSING
done

# After processing all files, print missing symbol counts to console and report
for sym in "${REQUIRED_SYMBOLS[@]}"; do
    MISSING_SYMBOL_COUNTS[$sym]=$(grep -c "^$sym$" "$MISSING_SYMBOL_COUNTS_FILE")
done
rm -f "$MISSING_SYMBOL_COUNTS_FILE"

# Print summary at the top of the report and to console
EXCLUDED_COUNT=${#EXCLUDED_LIST[@]}
echo "==== Symbol Check Summary ====" | tee "$REPORT_FILE"
echo "Total files checked: $TOTAL_FILES" | tee -a "$REPORT_FILE"
echo "Files passed: $PASSED_FILES" | tee -a "$REPORT_FILE"
echo "Files failed: $FAILED_FILES" | tee -a "$REPORT_FILE"
echo "Files/directories excluded: $EXCLUDED_COUNT" | tee -a "$REPORT_FILE"
echo >>"$REPORT_FILE"

echo "== Missing Symbol Counts =="
for sym in "${REQUIRED_SYMBOLS[@]}"; do
    echo "$sym: ${MISSING_SYMBOL_COUNTS[$sym]} files missing"
done

echo "==== Symbol Check Report ====" >>"$REPORT_FILE"
echo >>"$REPORT_FILE"
echo "== Missing Symbol Counts ==" >>"$REPORT_FILE"
for sym in "${REQUIRED_SYMBOLS[@]}"; do
    echo "$sym: ${MISSING_SYMBOL_COUNTS[$sym]} files missing" >>"$REPORT_FILE"
done
echo >>"$REPORT_FILE"
echo "== Files Missing Required Symbols ==" >>"$REPORT_FILE"
if [ -s "$FAILED_REPORT" ]; then
    cat "$FAILED_REPORT" >>"$REPORT_FILE"
else
    echo "None" >>"$REPORT_FILE"
fi
echo >>"$REPORT_FILE"
echo "== Files Passing All Checks ==" >>"$REPORT_FILE"
if [ -s "$PASSED_REPORT" ]; then
    cat "$PASSED_REPORT" >>"$REPORT_FILE"
else
    echo "None" >>"$REPORT_FILE"
fi
echo >>"$REPORT_FILE"
echo "== Excluded Files/Directories ==" >>"$REPORT_FILE"
for excl in "${EXCLUDED_LIST[@]}"; do
    echo "$excl" >>"$REPORT_FILE"
done
echo >>"$REPORT_FILE"

# Cleanup
rm -f "$FAILED_REPORT" "$PASSED_REPORT"
