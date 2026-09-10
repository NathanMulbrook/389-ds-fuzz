# Rust instrumentation baseline

The baseline was captured on 2026-09-10 before the Rust build changes. It uses
389-ds-fuzz `708a631`, 389-ds-patches `33b0e87`, 389-ds-private `f423a48`, and
389-ds-base 3.3.1 at `59009c84`.

Before the change, the five top-level Rust libraries had ASan and LLVM source
coverage evidence, but no useful libFuzzer guidance. Each installed Rust plugin
DSO had one edge counter from its C stub. The Rust `slapd` and
`slapi_r_plugin` runtime dependencies had no sanitizer, guidance, or source
coverage evidence.

After the change, isolated debug and release builds produced all five Rust
archives and linked `libslapd`, `ns-slapd`, and the three Rust plugin DSOs.
Every top-level Rust archive contains evidence for ASan, edge counters,
comparison tracing, PC tables, LLVM profiles, and source coverage. The generated
Makefile build also confirmed that the flags reach runtime dependencies while
host build scripts and procedural macros remain uninstrumented.

| Plugin DSO | Before | Debug after | Release after |
| --- | ---: | ---: | ---: |
| entryuuid | 1 | 15,491 | 15,730 |
| entryuuid syntax | 1 | 15,164 | 15,845 |
| pwdchan | 1 | 55,116 | 47,689 |

The table counts inline 8-bit coverage counters in the final linked DSOs. Each
after-build PC table had exactly one 16-byte entry per counter.

The standard library is still prebuilt and uninstrumented. A member-by-member
scan of a Rust static library therefore reports expected failures for bundled
standard-library and compiler-builtins objects. Missing markers in an individual
crate object can mean that it emits no eligible operation. Read member results
alongside Cargo command lines and final linked-DSO evidence; no single aggregate
marker proves that every member is covered.

The local raw baseline is
`logs/baselines/rust-instrumentation-20260910T133423Z/`. It contains the full
pre-change artifact report, before/after build settings, artifact hashes,
isolated debug and release reports, and 58 existing `.profraw` files. The
profiles were copied without running or modifying any fuzzer. They measure
pre-change execution and are separate from this instrumentation comparison.

Release optimization remains enabled with LTO off. Rust nightly
`1.100.0-nightly (2026-09-08)` crashed in LLVM ThinLTO while compiling the
instrumented dependency graph; the same release builds completed at the normal
optimization level with `lto = "off"`.
