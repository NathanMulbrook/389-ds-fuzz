#!/usr/bin/env bash
basicTools=(
    test.c
    389-ds-private/tools/test2.c
)

fuzzerTools=(
    fuzzerBlackbox.c
    fuzzerBlackboxWindows.c
)

testToolsDir="testTools"

mkdir -p $testToolsDir

for tool in "${basicTools[@]}"; do
    gcc -O2 -lpcap $tool -o ${tool%.c}
    chmod +x $testToolsDir/${tool%.c}
done

for tool in "${fuzzerTools[@]}"; do
    clang -O2 -fsanitize=fuzzer $tool -o ${tool%.c}
    chmod +x $testToolsDir/${tool%.c}
done