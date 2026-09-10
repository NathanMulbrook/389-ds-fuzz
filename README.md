# 389-ds-fuzz

## Rust instrumentation

Rust flags live in `389-ds-patches/patches/config.in.patch`. Configure generates
the build directory's `.cargo/config.toml`, which Cargo reads for all five Rust
libraries and their runtime dependencies. It enables ASan, source coverage, and
libFuzzer guidance (edge counters, comparison callbacks, and PC tables).

The Makefile passes the Rust host triple explicitly through `--target`. This
keeps host build scripts and procedural macros outside instrumentation. Rust
archives are therefore under `rs/<crate>/<target>/<debug|release>/`. Changes to
the generated Cargo config or Makefile cause the archive recipes to invoke Cargo
again. Cargo environment variables `RUSTFLAGS` and `CARGO_ENCODED_RUSTFLAGS` can
override config flags; leave them unset when using this setup.

The standard library remains prebuilt; `build-std` is not enabled. Release
optimization remains enabled, but Rust LTO is disabled: the current Rust nightly
crashes in its LTO processing with the instrumentation flags.

Use [the artifact checker](build-check/README.md) to verify objects and archive
members as well as final libraries. The initial comparison is recorded in the
[Rust instrumentation baseline](build-check/rust-instrumentation-baseline.md).
Local reports and execution profiles are saved under `logs/baselines/`; the
comparison measures instrumentation, not corpus execution coverage. Build
validation should use a separate directory while fuzzers run: `build.sh`
replaces installed outputs and stops matching server processes.
