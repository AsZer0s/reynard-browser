#!/bin/sh

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
FIREFOX_DIR="$ROOT_DIR/engine/firefox"

TARGET="aarch64-apple-ios"

cd "$ROOT_DIR"

if [ ! -d "$FIREFOX_DIR" ]; then
	echo "Missing firefox source at $FIREFOX_DIR"
	echo "Add the submodule, then run tools/development/update-gecko.sh."
	exit 1
fi

rm -f "$FIREFOX_DIR/.mozconfig"

{
	echo "ac_add_options --enable-application=mobile/ios"
	echo "ac_add_options --target=$TARGET"
	echo "ac_add_options --enable-ios-target=13.0"
	# Force Apple ld64 for iOS. Newer clang defaults try lld first, which
	# fails configure on GitHub macOS runners for the apple-ios target.
	echo "ac_add_options --enable-linker=ld64"
	echo "ac_add_options --enable-webrtc"
	echo "ac_add_options --enable-optimize"
	echo "ac_add_options --disable-debug"
	echo "ac_add_options --disable-tests"
} > "$FIREFOX_DIR/.mozconfig"

# Firefox 151's linker probe only recognizes ld64 when LD_PRINT_OPTIONS emits
# "Logging ld64 options" for -Wl,--version. Xcode 26's ld64 no longer emits
# that exact string on GitHub runners, so configure rejects the valid iOS
# linker before the build starts. Since this script explicitly requests ld64
# for the apple-ios target above, teach the probe to accept any non-zero
# --version response from that explicit linker as ld64.
python3 - "$FIREFOX_DIR" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1]) / "build/moz.configure/toolchain.configure"
text = path.read_text()
old = 'if retcode == 1 and "Logging ld64 options" in stderr:\n                kind = "ld64"'
new = 'if linker in (None, "ld64") and target.kernel == "Darwin" and retcode != 0:\n                kind = "ld64"\n\n            elif retcode == 1 and "Logging ld64 options" in stderr:\n                kind = "ld64"'
if old not in text:
    raise SystemExit("ld64 linker probe pattern not found")
path.write_text(text.replace(old, new, 1))
PY

if ! rustup target list | grep -q "^$TARGET (installed)"; then
	rustup target add "$TARGET"
fi

cd "$FIREFOX_DIR"
./mach build
