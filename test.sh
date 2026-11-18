#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
temp="$(mktemp -d)"
trap '/bin/rm -rf "$temp"' EXIT

xcrun clang -arch arm64 -std=c17 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -Wno-unused-parameter -framework AppKit -framework Carbon -framework InputMethodKit \
    -fsanitize=address,undefined -fno-sanitize-recover=all \
    tests/TelexTests.m src/TelexController.m src/Telex.c -o "$temp/TelexTests"
"$temp/TelexTests"
