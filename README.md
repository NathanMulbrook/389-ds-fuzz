# 389-ds-fuzz

## Toolchain

Build the pinned LLVM 23.1.1 toolchain before building the fuzzers:

```console
./build.sh --bootstrap-toolchain
```

This keeps Clang, ASan, UBSan, libFuzzer, and the LLVM coverage tools aligned
with Rust's LLVM version. See [the toolchain documentation](toolchain/README.md)
for disk requirements and configuration.

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

Each `run.sh` invocation writes coverage profiles to its own directory under
`logs/profiles/`. Module and process identifiers in the filenames keep profiles
from separate binaries and runs from overwriting or corrupting each other.
After stopping the fuzzers, generate text and HTML coverage for one variant:

```console
./genreport.sh logs/profiles/SESSION_DIRECTORY 15
```

## Multipacket corpus

Prepare an existing corpus before the first multipacket run:

```console
./normalize-corpus-flags.py corpus
```

The script preserves the old bind behavior and adds two ordinary-packet seeds
plus four two-packet seeds. The multipacket seeds cover fixed-delay and
response-wait operation, with and without bind. The first byte contains the
controls: bit 0 requests bind, bit 1 enables multipacket input, and bit 2 waits
for a response between packets. Multipacket data is a repeated two-byte
big-endian length followed by the raw packet bytes. Invalid lengths are rejected
before connecting to the server.

## Fuzzing directory

When `build.sh` creates an instance with `--directory`, it first applies
`fuzz-directory-config.ldif` and restarts the instance so the enabled plugins
are active. It then applies `fuzz-directory.ldif`, which adds six unlocked
users, two nested groups, and a manager account in the sample permission
groups. This provides successful and denied bind/ACL paths and enough entries
for paged and sorted searches.

The configuration enables MemberOf, referential integrity, and UID uniqueness,
and adds approximate indexing for `cn`. Each build configuration uses a unique
instance name so its runtime statistics and semaphore are isolated.

## Replaying one LDAP packet

Start one instance without its embedded fuzzer:

```console
./run.sh --fuzz --config=1
```

`send-test-case.py` sends either a raw LDAP packet or one packet extracted from
a multipacket fuzzer input. With no bind arguments it tests anonymous access:

```console
./send-test-case.py crash-input --packet 6 --port 5601
./send-test-case.py crash-input --packet 6 --port 5601 \
    --bind-dn 'uid=fuzz-user,ou=people,dc=example,dc=com' \
    --password 'FuzzUser-pass-01'
```

The tool prints each LDAP response and then opens a new connection to report
whether the server is still reachable. It uses only the Python standard
library.
