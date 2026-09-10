# This file is sourced by build.sh.

toolchain_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LLVM_VERSION="23.1.1"
LLVM_ROOT="${LLVM_ROOT:-$toolchain_dir/llvm-$LLVM_VERSION}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-nightly-2026-09-08}"

for llvm_tool in clang clang++ llvm-ar llvm-cov llvm-nm llvm-profdata llvm-ranlib; do
    if [ ! -x "$LLVM_ROOT/bin/$llvm_tool" ]; then
        echo "LLVM $LLVM_VERSION is incomplete or missing at $LLVM_ROOT"
        echo "Run ./build.sh --bootstrap-toolchain first."
        return 1
    fi
done

clang_version="$($LLVM_ROOT/bin/clang --version | sed -n '1p')"
case "$clang_version" in
    *"clang version $LLVM_VERSION"*) ;;
    *)
        echo "Expected Clang $LLVM_VERSION, found: $clang_version"
        return 1
        ;;
esac

resource_dir="$($LLVM_ROOT/bin/clang -print-resource-dir)"
for runtime in asan ubsan_standalone fuzzer_no_main profile; do
    if [ -z "$(find "$resource_dir/lib" -type f -name "libclang_rt.$runtime*.a" -print -quit)" ]; then
        echo "LLVM $LLVM_VERSION is missing the $runtime runtime."
        return 1
    fi
done

export LLVM_ROOT RUST_TOOLCHAIN
export PATH="$LLVM_ROOT/bin:$PATH"
export CC="$LLVM_ROOT/bin/clang"
export CXX="$LLVM_ROOT/bin/clang++"
export AR="$LLVM_ROOT/bin/llvm-ar"
export NM="$LLVM_ROOT/bin/llvm-nm"
export RANLIB="$LLVM_ROOT/bin/llvm-ranlib"
export RUSTUP_TOOLCHAIN="$RUST_TOOLCHAIN"

verify_rust_llvm() {
    local rust_llvm_version
    rust_llvm_version="$(rustc -vV | sed -n 's/^LLVM version: //p')"
    if [ "$rust_llvm_version" != "$LLVM_VERSION" ]; then
        echo "Expected Rust to use LLVM $LLVM_VERSION, found $rust_llvm_version"
        return 1
    fi
}
