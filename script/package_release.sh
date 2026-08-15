#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: $0 <semantic-version>" >&2
  exit 2
fi

APP_NAME="TopBuddy"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Sources/TopBuddy/Support/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Sources/TopBuddy/Support/TopBuddy.entitlements"
RELEASE_DIR="$ROOT_DIR/release"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/topbuddy-release.XXXXXX")"
APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
ZIP_NAME="$APP_NAME-v$VERSION-macOS-universal.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
SHA_PATH="$ZIP_PATH.sha256"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
if [[ "$PLIST_VERSION" != "$VERSION" ]]; then
  echo "Info.plist version is $PLIST_VERSION, but requested package version is $VERSION" >&2
  exit 1
fi

"$ROOT_DIR/script/privacy_audit.sh"
swift test --package-path "$ROOT_DIR" -Xswiftc -warnings-as-errors
swift build --package-path "$ROOT_DIR" -c release --arch arm64 --arch x86_64

BIN_DIR="$(swift build --package-path "$ROOT_DIR" -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP_BINARY="$BIN_DIR/$APP_NAME"
if [[ ! -x "$APP_BINARY" ]]; then
  echo "release binary not found: $APP_BINARY" >&2
  exit 1
fi

mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$RELEASE_DIR"
cp "$APP_BINARY" "$APP_MACOS/$APP_NAME"
cp "$INFO_PLIST" "$APP_CONTENTS/Info.plist"
chmod +x "$APP_MACOS/$APP_NAME"
/usr/bin/strip -S "$APP_MACOS/$APP_NAME"

scan_binary() {
  local label="$1"
  local pattern="$2"
  local matches

  matches="$(/usr/bin/strings "$APP_MACOS/$APP_NAME" | rg -n --pcre2 -- "$pattern" || true)"
  if [[ -n "$matches" ]]; then
    echo "packaged-binary privacy audit failed: $label" >&2
    echo "$matches" >&2
    exit 1
  fi
}

scan_binary "absolute macOS home path" '/''Users/[^/[:space:]"'\''`]+'
scan_binary "email address" '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.(?:com|org|net|edu|gov|io|dev|app|co)\b'
scan_binary "private workspace URL" '(?i)https?://(?:app\.notion\.com/(?:p/)?[0-9a-f]{20,}|[a-z0-9-]+\.chatgpt\.site)'
scan_binary "credential-like token" '(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})'

if [[ -n "${TOPBUDDY_SIGNING_IDENTITY:-}" ]]; then
  /usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    --sign "$TOPBUDDY_SIGNING_IDENTITY" \
    "$APP_BUNDLE"
  SIGNING_STATUS="Developer ID signed"
else
  /usr/bin/codesign --force --deep --entitlements "$ENTITLEMENTS" --sign - "$APP_BUNDLE"
  SIGNING_STATUS="ad-hoc signed"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
ARCHS="$(/usr/bin/lipo -archs "$APP_MACOS/$APP_NAME")"
for required_arch in arm64 x86_64; do
  if [[ " $ARCHS " != *" $required_arch "* ]]; then
    echo "missing required architecture: $required_arch (found: $ARCHS)" >&2
    exit 1
  fi
done

rm -f "$ZIP_PATH" "$SHA_PATH"
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k \
  --norsrc --noextattr --noqtn --noacl \
  --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [[ -n "${TOPBUDDY_NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${TOPBUDDY_SIGNING_IDENTITY:-}" ]]; then
    echo "notarization requires TOPBUDDY_SIGNING_IDENTITY" >&2
    exit 1
  fi
  /usr/bin/xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$TOPBUDDY_NOTARY_PROFILE" \
    --wait
  /usr/bin/xcrun stapler staple "$APP_BUNDLE"
  rm -f "$ZIP_PATH"
  COPYFILE_DISABLE=1 /usr/bin/ditto -c -k \
    --norsrc --noextattr --noqtn --noacl \
    --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  NOTARY_STATUS="notarized and stapled"
else
  NOTARY_STATUS="not notarized"
fi

(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 "$ZIP_NAME" > "$(basename "$SHA_PATH")"
)

echo "created $ZIP_PATH"
echo "architectures: $ARCHS"
echo "signing: $SIGNING_STATUS"
echo "notarization: $NOTARY_STATUS"
