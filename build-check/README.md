# Build artifact checker

A standalone Python script for inspecting Linux ELF object files, static archives
(including Rust `.rlib` files), executables, and shared libraries. It reads
artifacts with GNU `readelf` and never runs them. Requires Python 3.9+ and GNU
binutils; no Python packages.

From the repository root:

```sh
./checkObjects.sh
./checkObjects.sh /path/to/my-build.ini
# Equivalent standalone entry point:
python3 build-check/check_build.py build-check/check-build.ini
```

Edit `check-build.ini` to select the builds. The project config covers variants
1, 2, 3, 4, 9, 10, 11, 12, 18, and 19, which have built server binaries. It checks
their objects, linked outputs under `.libs`, and installed `bin`, `sbin`, and `lib`
directories. It writes one Markdown report, `logs/symbolReport.md`, with the
summary first and file-by-file evidence at the end. Incomplete variants are omitted.
The config expects stack protection, ASan/UBSan, and coverage evidence, with
Fortify, TSan, and MSan absent. These expectations follow the project's C/C++
flags. Small objects, Rust code, mixed dependencies, and helper programs can
differ; use the path rules below to express their expectations. The shipped
config ignores UBSan and Fortify for `*.rlib`, `*.rcgu.o`, and `*.a(*.rcgu.o)`.
These Rust path rules retain every other baseline expectation, including stack
protection, ASan, and coverage. The libFuzzer driver check is ignored in this
broad scan because objects and libraries do not need a driver.
Empty archives remain visible as inspection errors.
The checker overwrites only its configured report; it does not change the build.
Move this directory into another repository when needed; the launcher is optional.

For a scan while fuzzers are running, lower the checker's CPU and I/O priority:

```sh
nice -n 19 ionice -c 3 ./checkObjects.sh
```

## Config

Paths are relative to the config file. Use one literal path per line, without
quotes; spaces are allowed. Absolute paths also work. Root path globs and shell
variable expansion are not supported.

- `object_dirs`: recursively discover relocatable ELF objects (`ET_REL`) and
  regular or thin archives by content, including hidden directories. This covers
  `.o`, `.obj`, ELF `.lo` and `.ko`, `.a`, `.rlib`, and extensionless or unusually
  named files. Text libtool `.lo` wrappers are skipped. LLVM bitcode is discovered
  by its magic bytes and reported as unsupported. Invalid `.o`, `.obj`, `.a`,
  `.rlib`, and `.bc` files remain inspection candidates so errors stay visible.
- `binary_paths`: individual ELF binaries, or directories searched recursively for
  ELF executables and shared libraries, regardless of filename or executable bit.
  Scripts and other files in these directories are skipped. Explicit non-ELF
  binary paths are errors.
- `exclude`: shell-style patterns matched against the config-relative path or
  basename. Excluded directories are pruned. For example, `*/debug/incremental`,
  `skip.o`, or `*/third_party/*`. Directory symlinks within scans are not followed;
  file symlinks are resolved and duplicate resolved paths are checked once.
- `[output] report`: basic Markdown report path. Its parent directory is created if
  needed. Defaults to `build-report.md` beside the config. It cannot overwrite
  input artifacts or the config.
  Artifact filenames (`.o`, `.obj`, `.lo`, `.ko`, `.a`, `.rlib`, `.bc`, `.so`,
  `.so.*`) and existing hardlinked outputs are rejected. Existing ELF, archive,
  and bitcode content is also protected, including excluded artifacts.

Older configs with `[output] summary` should remove that setting. The combined
report replaces both outputs; the checker rejects the old setting instead of
silently writing an unexpected file.

Set the expectation for each feature under `[checks]`:

- `present`: list items without evidence of this feature as failures.
- `absent`: list items with evidence of this feature as failures.
- `ignore`: do not enforce an expectation for this feature. Its evidence still
  appears under File details. This is the default for unlisted checks.

Inconclusive evidence fails both `present` and `absent` expectations. Each
standalone object, binary, and nonmetadata archive member is checked separately.
If every check is ignored, the summary says no expectations were configured for
the checked items. File details still include every check. Unknown
settings and values are errors.

Older values remain accepted: `require` means `present`, `forbid` means `absent`,
and `report` means `ignore` (detailed evidence without an enforced expectation).

Use `[checks:PATH_GLOB]` sections to override the baseline for selected paths.
For example, with a C/C++ baseline and a Rust archive containing a C shim:

```ini
[checks]
asan = present
ubsan = present
fortify = absent
libfuzzer = ignore

[checks:../build/rust/*.rlib]
ubsan = ignore
fortify = ignore

[checks:../build/rust/libbridge*.rlib(shim.o)]
ubsan = present
fortify = absent
```

Patterns match the full config-relative parent path shown in the report, or
`path(member)` for an archive member. Matching is case-sensitive, uses shell-style
wildcards, and has no basename-only fallback; `*` can span directory separators.
A parent-path match applies to all of its members. Start with `[checks]`, then
apply matching rule sections in file order: the last matching rule wins **per
option**. Unlisted options retain earlier values, and an explicit `ignore` clears
an expectation. Empty patterns and unknown check names are errors. Duplicate
member names share the same rules; occurrence numbers are only report labels.

Choose rules from the flags intended for each group. UBSan and glibc Fortify are
not generic requirements for Rust code. Separate target code from host build
tools and procedural macros, and account for dependencies and the standard
library having different instrumentation. Rust's
[sanitizer guidance](https://doc.rust-lang.org/unstable-book/compiler-flags/sanitizer.html)
describes its supported sanitizers and target/build considerations. Use a rule
for the fuzzer executable when expecting the libFuzzer driver to be present.

## Report

One report is generated from the scan; each parent artifact is inspected once.
File details retain evidence for every check, including ignored
checks. States are `FOUND`, `SYMBOL-ONLY`, `NOT-SEEN`, and `UNKNOWN`. Archives have
separate member results, errors, and metadata skips. Repeated member names remain
separate items; later occurrences have labels such as `[occurrence 2]`. Markdown
headings identify sections, files, and members; fenced text blocks preserve the
aligned evidence rows.

The report is basic Markdown that also reads cleanly as plain text, ordered as follows:

1. **Failed files** and **Failed items** for each check, including the expectation.
   Click the file count in Markdown preview to jump to that check's failure list.
   Zero counts link to the corresponding empty list; ignored checks have no link.
   **Expected** shows `varies` when checked items actually use different modes.
2. File counts for objects, binaries, and archives, with inspected/error totals,
   plus a separate archive-member row.
3. Failures grouped by check, followed by inspection errors.
4. Separate object, binary, and archive inventories.
5. The evidence key and totals for each check state.
6. **File details:** every file's results, followed by its archive members where applicable.

Search for `## ` to jump to headings, or use `^## ` in a regex search for major
sections and `^### ` for individual checks in the summary or files under File
details. Use `^#### ` for archive members. Failure-list
headings use only the check name, so their links remain stable when counts or
expectations change.

Inventory code blocks contain **one absolute path per line**, with no indentation,
bullets, type labels, status, or error annotations. Copy the lines between the
fences to use them from any working directory. Empty inventories have an empty
block. Inventories list parent artifacts, including archives, without appending
member names. Individual failures retain short inline reasons, expected modes,
and config-relative paths, including `archive(member)` for a single failing
member. Multiple failing members of the same archive have one summary line per
check: `archive: N member failures; see File details`. Every member's evidence
and failure remains at the end of the same report.

````markdown
## Failures

### stack_protector

Expected present: 3 failures

```text
objects/plain.o: not seen; expected present
objects/libmixed.a: 2 member failures; see File details
```

## Objects (2)

```text
/project/objects/plain.o
/project/objects/protected.o
```

## Binaries (1)

```text
/project/bin/program
```
````

`not seen` means no matching evidence in the available tables. `found` includes
one example of a strong undefined reference or a nonempty instrumentation
section; for `libfuzzer`, the driver definition also counts. `inconclusive` means
only definitions or optional weak references exist, or the symbol table is
unavailable. None of these prove exact compiler flags or runtime behavior.

Inventories and file `Checked` counts include every attempted parent artifact,
including unsupported files. An archive with an inspection error is counted as
an errored file while retaining results from members that were read successfully.
The archive-member row counts members read within archives, including recognized
metadata; it adds no physical files to the inventory. Discovery errors, such as
missing directories, appear in the error section without a file type.

**Failed files** counts unique failing parent artifacts per check and equals the
number of failure entries in that check's summary list. **Failed items** counts each
successfully inspected nonmetadata item once per check; this is also the total
shown beneath the check's failure-list heading. The header's
**files failing expectations** counts each parent artifact once across all checks
and members. **Check items** counts standalone objects,
binaries, and individual archive members with evidence; its failing count counts
each such item once. Metadata has a separate **metadata items skipped** count.
Unreadable or unsupported items produce errors instead of missing-feature
failures. Ignored checks show `-`.

Member errors identify the member when possible. GNU `readelf` diagnostics may
be shared or indicate it stopped early, particularly with missing thin-archive
members. These produce an additional parent-level `archive inspection incomplete`
error; successful member results remain useful, but the archive did not pass
inspection. Thin-member names include the paths reported by `readelf`.

Exit codes: **0** completed with no expectation failures, **1** expectation
failure, **2** configuration, discovery, inspection, or report-write error.
Other artifacts are still reported when an inspection fails. Missing paths and
any non-excluded root that finds no artifacts are errors. Configuration errors
leave any previous report untouched, so check the exit code before using it.

| Check | Evidence sought |
| --- | --- |
| `stack_protector` | Stack check failure/guard references |
| `fortify` | Known glibc fortified calls, including `__open*_2`; excludes stack checks |
| `asan`, `ubsan`, `tsan`, `msan` | Address, undefined behavior, thread, and memory sanitizer hooks; ASan global sections |
| `sancov` | SanitizerCoverage edge/PC callbacks, inline counters, guards, or boolean flags |
| `sancov_cmp` | SanitizerCoverage comparison/switch callbacks |
| `sancov_pc_table` | SanitizerCoverage PC table or initialization reference |
| `llvm_profile` | LLVM profile counter/bitmap sections |
| `source_coverage` | LLVM source coverage mapping sections |
| `libfuzzer` | `LLVMFuzzerRunDriver`; the test callback alone is insufficient |

[SanitizerCoverage](https://clang.llvm.org/docs/SanitizerCoverage.html) provides
coverage feedback used by libFuzzer. Comparison hooks provide additional
feedback. [Source coverage](https://clang.llvm.org/docs/SourceBasedCodeCoverage.html)
supports coverage reports and does not by itself demonstrate libFuzzer guidance.
Rust's [`-C instrument-coverage`](https://doc.rust-lang.org/rustc/instrument-coverage.html)
also emits LLVM counters and coverage mappings; finding those sections does not
show which code has executed.
Runtime callback definitions alone do not establish that code calls them.

This is evidence inspection, not proof of exact compiler flags or runtime behavior.
Small functions, optimization, inlining, and trap-only sanitizers can leave no
recognized hooks. [Fortification](https://sourceware.org/glibc/manual/latest/html_node/Source-Fortification.html)
may resolve at compile time without a fortified call. A missing symbol match
does not prove `_FORTIFY_SOURCE` was disabled, and matches do not identify its
level. Likewise, stack check symbols do not identify the stack protector mode.

A member's evidence establishes only that member's result. A binary's results
do not describe every function, its shared library dependencies, or whether
checks are enabled at runtime. Inspect the constituent objects too. Static
linking can leave only runtime definitions and produce `SYMBOL-ONLY`, even in an
unstripped binary. An existing `.symtab` does not prove symbol completeness:
partial stripping is not inferred, so `NOT-SEEN` remains limited evidence.

Rust support covers ELF objects and binaries, ELF `cdylib` outputs, and native
ELF members in `staticlib` and `.rlib` archives. Rust
[linkage formats](https://doc.rust-lang.org/reference/linkage.html) have different
purposes; `.rmeta` carries compiler metadata, not target code. The checker skips
an ELF relocatable item only when it has a nonempty `.rmeta` or `.rmeta-link`
section and no nonempty allocated or executable sections (`A`/`X` flags).
These identified metadata items are listed as `SKIPPED`. A filename alone is
insufficient. Objects containing only ordinary global data still receive checks;
there is no blanket skip for objects without executable code.

Native ELF objects containing an embedded `.llvmbc` section are inspected through
their ELF evidence. Pure LLVM bitcode, GCC LTO objects, unrecognized non-ELF
archive members, and empty archives produce inspection errors. Raw Rust metadata
inside an archive is not silently accepted as native code. PE/COFF, Mach-O, and
WebAssembly are not parsed.

## Inspection tools and possible additions

The current inspector runs GNU `readelf` once per artifact:

```sh
readelf --wide --file-header --section-headers --symbols -- /path/to/artifact
```

[GNU readelf](https://sourceware.org/binutils/docs/binutils/readelf.html) supports
ELF objects, linked binaries, and archives containing ELF members. Its headers,
sections, and symbol tables are a good fit for this small Linux-only checker.
The checker uses both regular and dynamic symbol tables when available, and
distinguishes references from definitions and optional weak references.

For a larger tool, [llvm-readobj](https://llvm.org/docs/CommandGuide/llvm-readobj.html)
offers JSON output for ELF, which would avoid parsing human-formatted tables.
[llvm-nm](https://llvm.org/docs/CommandGuide/llvm-nm.html) would be useful if LLVM
bitcode support is added. Changing tools alone would not prove that every function
is instrumented, or recover compiler flags that were not recorded.

Useful next additions, **not implemented**:

- **First, build records:** associate objects with
  [`compile_commands.json`](https://clang.llvm.org/docs/JSONCompilationDatabase.html)
  and recorded Cargo/rustc invocations to verify intended flags, including frame
  pointers, and distinguish project code, host tools, and dependencies.
- **Then, linkage records:** use link maps and dependency inventories to identify
  which objects and libraries contributed to each binary. Dynamic dependencies
  and RPATH/RUNPATH describe embedded requirements, not what a process loaded.
- **Optional deeper evidence:** attribute instrumentation evidence to functions
  where available, with explicit limits for optimization, inlining, and stripping.
- **Optional extra checks:** debug information and build IDs; PIE, nonexecutable
  stack (NX), writable/executable segments, and RELRO with immediate binding.
  Account for separate debug files and restrict expectations to applicable file
  types. See [GNU linker options](https://sourceware.org/binutils/docs/ld/Options.html).

## Verification

```sh
python3 -m unittest discover -s build-check -p 'test_*.py' -v
```

Tests compile tiny fixtures in a temporary directory with Clang and GNU binutils;
an available directly installed `rustc` also supplies a Rust `.rlib` fixture.
They do not rebuild or execute this project's binaries.
