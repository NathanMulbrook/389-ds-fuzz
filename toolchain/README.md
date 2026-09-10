# LLVM toolchain

The fuzzer build uses a local LLVM 23.1.1 toolchain so Clang, compiler-rt,
libFuzzer, and the coverage tools match Rust's LLVM version. The source archive
is pinned by SHA-256 and comes from the official LLVM release.

Build the toolchain once:

```console
./build.sh --bootstrap-toolchain
```

The build needs at least 80 GB free and installs under
`toolchain/llvm-23.1.1`. Sources and intermediate files remain under
`toolchain/work` so an interrupted build can resume. That work directory can be
deleted after installation.

Normal `build.sh` runs require the local toolchain and select all LLVM tools by
absolute path. They also use the pinned `nightly-2026-09-08` Rust toolchain,
which is based on LLVM 23.1.1.

The bootstrap inherits the host Clang target and system configuration. On
Fedora, this keeps the local compiler on the native `x86_64-redhat-linux-gnu`
target and prevents an installed cross-compiler from supplying the C++ headers.

The following environment variables are optional:

- `LLVM_TOOLCHAIN_WORK_DIR` moves sources and intermediate build files.
- `LLVM_TOOLCHAIN_JOBS` controls parallel compilation.
- `LLVM_ROOT` selects another LLVM 23.1.1 installation.
- `RUST_TOOLCHAIN` selects another Rust toolchain; it must use LLVM 23.1.1.
- `LLVM_MIN_FREE_GB` changes the free-space safety check.
