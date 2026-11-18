#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app=TelexGon.app
mkdir -p "$app/Contents/MacOS"
cp src/Info.plist "$app/Contents/Info.plist"
/usr/bin/ditto src/Resources "$app/Contents/Resources"

xcrun clang -arch arm64 -mmacosx-version-min=13.0 -std=c17 \
    -fobjc-arc -Oz -flto -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wl,-dead_strip -framework AppKit -framework Carbon -framework InputMethodKit \
    -framework UniformTypeIdentifiers \
    src/main.m src/TelexController.m src/TelexAppExclusions.m src/Telex.c \
    -o "$app/Contents/MacOS/TelexGon"
xcrun strip -x "$app/Contents/MacOS/TelexGon"

if [[ "${TELEXGON_SIGN_IDENTITY:--}" != "-" ]]; then
    /usr/bin/codesign --force --sign "$TELEXGON_SIGN_IDENTITY" --options runtime --timestamp "$app"
else
    /usr/bin/codesign --force --sign - --timestamp=none "$app"
fi
/usr/bin/codesign --verify --strict "$app"
