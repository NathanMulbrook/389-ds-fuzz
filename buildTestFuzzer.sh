#!/bin/bash
set -e

SRC="testFuzzer.c"
OBJ="testTools/testFuzzer.o"
OUT="testTools/testFuzzer"
FUZZER_NO_MAIN_A="/usr/lib/clang/17/lib/x86_64-redhat-linux-gnu/libclang_rt.fuzzer_no_main.a"  # Adjust path as needed

# Compile with fuzzer-no-link
clang   -DDEBUG -DMCC_DEBUG   -DRUST_ENABLE  -g3 -ggdb -gdwarf-5  -O2 -fsanitize=fuzzer-no-link,address,undefined  -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer   -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fno-common -g -pipe -Wall -O2 -fexceptions -fstack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4  -m64 -mtune=generic  -fsanitize-recover=all -c -g -O2  -Wno-implicit-function-declaration -fsanitize=fuzzer-no-link,address,undefined "$SRC" -o "$OBJ"

# Link against fuzzer-no-main .a file
clang++ -g3 -ggdb -gdwarf-5 -O2 -fsanitize=fuzzer-no-link,address,undefined -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fno-common -g -pipe -Wall -O2 -fexceptions -fstack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4 -m64 -mtune=generic -fsanitize-recover=all -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fuse-ld=lld -fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer -fno-common -g -pipe -Wall -O2 -fexceptions -fstack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4  -m64 -mtune=generic  -fsanitize-recover=all -lz -ljson-c -lcrack -ldl -lpthread -lc -lm -lrt -lutil -fsanitize=fuzzer-no-link,address,undefined  -g -O2  -fsanitize=address,undefined "$OBJ" "$FUZZER_NO_MAIN_A" -o "$OUT"