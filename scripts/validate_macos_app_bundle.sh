#!/usr/bin/env bash
set -u

compile_only=false

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

if [ "${1:-}" = "--compile-only" ]; then
  compile_only=true
  shift
fi

if [ "$#" -ne 1 ]; then
  fail "Usage: $0 [--compile-only] /path/to/App.app"
fi

bundle_path=${1%/}

if [ ! -d "$bundle_path" ]; then
  fail "App bundle does not exist: $bundle_path"
fi

info_plist="$bundle_path/Contents/Info.plist"
if [ ! -f "$info_plist" ]; then
  fail "Info.plist is missing: $info_plist"
fi
pass "Info.plist exists"

if ! executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist" 2>/dev/null); then
  fail "CFBundleExecutable is missing from Info.plist"
fi

if [ -z "$executable_name" ]; then
  fail "CFBundleExecutable is empty in Info.plist"
fi
pass "CFBundleExecutable is $executable_name"

executable_path="$bundle_path/Contents/MacOS/$executable_name"
if [ ! -f "$executable_path" ]; then
  fail "Bundle executable is missing: $executable_path"
fi

if [ ! -x "$executable_path" ]; then
  fail "Bundle executable is not executable: $executable_path"
fi
pass "Bundle executable exists and is executable"

if ! file_output=$(file "$executable_path" 2>&1); then
  fail "file command failed for executable: $file_output"
fi

case "$file_output" in
  *Mach-O*)
    pass "Bundle executable is Mach-O"
    ;;
  *)
    fail "Bundle executable is not Mach-O: $file_output"
    ;;
esac

if command -v codesign >/dev/null 2>&1; then
  if codesign_output=$(codesign --verify --deep --strict --verbose=4 "$bundle_path" 2>&1); then
    pass "codesign verification passed"
  elif $compile_only; then
    case "$codesign_output" in
      *CSSMERR_TP_NOT_TRUSTED*)
        pass "bundle is signed, but the local certificate chain is not trusted"
        ;;
      *"code object is not signed at all"*)
        pass "bundle is unsigned, as allowed for compile validation"
        ;;
      *)
        fail "codesign structure verification failed: $codesign_output"
        ;;
    esac
  else
    fail "codesign verification failed: $codesign_output"
  fi
else
  pass "codesign not available; skipped verification"
fi

pass "macOS app bundle validation passed"
