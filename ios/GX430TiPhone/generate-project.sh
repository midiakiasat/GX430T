#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "GX430T_XCODEGEN_AND_HOMEBREW_NOT_FOUND=true" >&2
    exit 69
  fi

  brew install xcodegen
fi

cd "$ROOT"
xcodegen generate

echo "GX430T_IPHONE_PROJECT_GENERATED=true"
echo "PROJECT=$ROOT/GX430TiPhone.xcodeproj"
