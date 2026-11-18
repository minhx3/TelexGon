#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

bundle=TelexGon.app
source="$PWD/$bundle"
target="$HOME/Library/Input Methods"
destination="$target/$bundle"
executable="Contents/MacOS/TelexGon"
lock="$target/.telexgon-install"
stage=""

if [[ "$(/usr/bin/uname -m)" != arm64 ]]; then
    printf '%s\n' 'Telex Gọn cần macOS trên Apple Silicon (ARM64).'
    exit 1
fi

/usr/bin/codesign --verify --strict "$source"
mkdir -p "$target"

if ! mkdir "$lock"; then
    printf '%s\n' 'Đang có một phiên cài Telex Gọn khác.'
    exit 1
fi

cleanup() {
    if [[ -n "$stage" ]]; then
        if [[ -d "$stage/previous.app" && ! -e "$destination" ]]; then
            if ! mv "$stage/previous.app" "$destination"; then
                printf 'Bản trước được giữ tại %s\n' "$stage/previous.app" >&2
                rmdir "$lock"
                return
            fi
        fi
        /bin/rm -rf "$stage"
    fi
    rmdir "$lock"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ -L "$destination" ]] || [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
        "$destination/Contents/Info.plist" 2>/dev/null)" != vn.codex.inputmethod.telexgon ]]; then
        printf 'Trùng đường dẫn với một ứng dụng khác tại %s\n' "$destination" >&2
        exit 1
    fi
fi

if ! /usr/bin/cmp -s "$source/$executable" "$destination/$executable" ||
    ! /usr/bin/codesign --verify --strict "$destination" 2>/dev/null; then
    stage="$(mktemp -d "$target/.telexgon.XXXXXXXX")"
    /usr/bin/ditto "$source" "$stage/$bundle"
    /usr/bin/codesign --verify --strict "$stage/$bundle"
    if [[ -d "$destination" ]]; then
        "$destination/$executable" --stop
        mv "$destination" "$stage/previous.app"
    fi
    mv "$stage/$bundle" "$destination"
fi

"$destination/$executable" --register || true
if "$destination/$executable" --status >/dev/null; then
    printf '%s\n' 'Telex Gọn đã có trong menu nguồn nhập trên thanh menu.'
else
    printf '%s\n' 'Đã cài Telex Gọn vào Library/Input Methods của người dùng.' \
        'Để bật, mở System Settings → Keyboard → Text Input → Edit → +.' \
        'Tìm Telex Gọn trong Vietnamese, bấm Add rồi Done.' \
        'Nếu chưa thấy, mở lại System Settings. Nếu cần, đăng xuất rồi đăng nhập lại.'
fi
