#!/usr/bin/env bash
set -euo pipefail

directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$directory/toolchain/use-llvm.sh"

if [ "$#" -ne 2 ]; then
    echo "Usage: ./genreport.sh PROFILE_SESSION BUILD_CONFIG"
    echo "Example: ./genreport.sh logs/profiles/20260910T190000Z-1234 15"
    exit 1
fi

profile_session="$(realpath "$1")"
build_config="$2"
profile_dir="$profile_session/run_$build_config"
run_dir="$directory/run/run_$build_config"
binary="$run_dir/sbin/ns-slapd"
report_dir="$directory/logs/coverage/$(basename "$profile_session")/run_$build_config"

if [ ! -x "$binary" ]; then
    echo "Missing fuzzer binary: $binary"
    exit 1
fi

mapfile -t profiles < <(find "$profile_dir" -type f -name '*.profraw' -size +0c | sort)
if [ "${#profiles[@]}" -eq 0 ]; then
    echo "No profiles found in $profile_dir"
    exit 1
fi

mapfile -t objects < <(
    find "$run_dir" -type f | while IFS= read -r file; do
        if readelf -SW "$file" 2>/dev/null | grep -q '__llvm_covmap'; then
            printf '%s\n' "$file"
        fi
    done | sort -u
)

object_args=()
for object in "${objects[@]}"; do
    if [ "$object" != "$binary" ]; then
        object_args+=(-object "$object")
    fi
done

mkdir -p "$report_dir"
llvm-profdata merge -sparse "${profiles[@]}" -o "$report_dir/coverage.profdata"
llvm-cov report "$binary" "${object_args[@]}" \
    -instr-profile="$report_dir/coverage.profdata" >"$report_dir/coverage.txt"
llvm-cov show "$binary" "${object_args[@]}" -format=html \
    -instr-profile="$report_dir/coverage.profdata" >"$report_dir/coverage.html"

echo "Coverage report: $report_dir/coverage.txt"
