#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

REPO="${GX430T_REPOSITORY:-midiakiasat/GX430T}"
OUT_JSON="${1:-evidence/release/global-release-readiness.json}"
OUT_MD="${2:-docs/GLOBAL_RELEASE_READINESS.md}"

mkdir -p "$(dirname "$OUT_JSON")" "$(dirname "$OUT_MD")"

exists_file() {
  [[ -f "$1" ]]
}

exists_dir() {
  [[ -d "$1" ]]
}

executable_file() {
  [[ -x "$1" ]]
}

find_first() {
  find "$1" -type f \( $2 \) 2>/dev/null | sort | head -1
}

MAC_APP_SOURCE=false
IPHONE_APP_SOURCE=false
MENUBAR_SOURCE=false
MAC_INSTALLER_SOURCE=false
SIGNED_RELEASE_PIPELINE=false
UPDATER_SOURCE=false
PAIRING_SOURCE=false
PRINT_HOST_SOURCE=false
CLI_SOURCE=false
LICENSE_SOURCE=false
README_SOURCE=false
QUICKSTART_SOURCE=false
DOWNLOADS_SOURCE=false
PRESENTATION_SOURCE=false
CI_SOURCE=false
PRODUCT_VERIFY=false
IPHONE_EVIDENCE=false

source_grep() {
  local pattern="$1"
  shift

  grep -RIlE "$pattern" \
    --include='*.swift' \
    --include='*.sh' \
    --include='*.yml' \
    --include='*.yaml' \
    --include='*.plist' \
    --include='*.json' \
    "$@" 2>/dev/null \
    | grep -vE '/\.git/|/DerivedData|/build/|/pkgroot/|/\.swiftpm/' \
    | grep -q .
}

if [[ -f app/GX430TMacControl/Sources/GX430TMacControl/main.swift ]] \
  && source_grep 'import AppKit|NSApplication|@main|WindowGroup' app/GX430TMacControl; then
  MAC_APP_SOURCE=true
fi

exists_dir ios/GX430TiPhone && IPHONE_APP_SOURCE=true

if source_grep \
  'MenuBarExtra|NSStatusItem|NSStatusBar|statusItem|menu bar|menubar' \
  app/GX430TMacControl; then
  MENUBAR_SOURCE=true
fi

if [[ -f installer/build-pkg.sh ]] \
  && [[ -f installer/scripts/preinstall ]] \
  && [[ -f installer/scripts/postinstall ]]; then
  MAC_INSTALLER_SOURCE=true
fi

if [[ -f release-tools/build-signed-notarized-macos.sh ]] \
  && [[ -f release-tools/audit-macos-distribution.sh ]] \
  && source_grep \
    'notarytool|notariz|codesign|productsign|stapler' \
    release-tools .github/workflows; then
  SIGNED_RELEASE_PIPELINE=true
fi

if [[ -s updater/run-update-check.sh ]] \
  && [[ -s install/install-updater-service.sh ]] \
  && [[ -s install/remove-updater-service.sh ]] \
  && [[ -s docs/AUTOMATIC_UPDATER.md ]] \
  && grep -Eiq \
    'release|version|update|download|checksum|sha256|pkg|github|curl|gh ' \
    updater/run-update-check.sh \
    install/install-updater-service.sh \
    install/remove-updater-service.sh \
    docs/AUTOMATIC_UPDATER.md; then
  UPDATER_SOURCE=true
fi

if [[ -f ios/GX430TiPhone/Sources/GX430TPairingView.swift ]] \
  && [[ -f ios/GX430TiPhone/Sources/GX430TiPhoneModel.swift ]] \
  && [[ -f shared/GX430TKit/Sources/GX430TKit/GX430TKit.swift ]] \
  && source_grep \
    'pairing|pairingCode|pairing code|six-digit|six digit|paired' \
    ios/GX430TiPhone shared/GX430TKit app/GX430TMacControl; then
  PAIRING_SOURCE=true
fi

if [[ -d host-service ]] \
  && [[ -f install/install-host-service.sh ]] \
  && [[ -f install/remove-host-service.sh ]] \
  && source_grep \
    'Print Host|print-host|print host|NWListener|HTTPServer|IPP|CUPS|lpr -P' \
    host-service install app/GX430TMacControl shared/GX430TKit; then
  PRINT_HOST_SOURCE=true
fi

executable_file bin/gx430tctl && CLI_SOURCE=true
exists_file LICENSE && LICENSE_SOURCE=true
exists_file README.md && README_SOURCE=true
exists_file docs/distribution/COLLEAGUE_QUICKSTART.md && QUICKSTART_SOURCE=true
exists_file docs/distribution/DOWNLOADS.md && DOWNLOADS_SOURCE=true
exists_file docs/presentation/GX430T_WORK_PRESENTATION.md && PRESENTATION_SOURCE=true
exists_dir .github/workflows && CI_SOURCE=true
exists_file evidence/builds/gx430t-iphone-branded-interface.png && IPHONE_EVIDENCE=true

if [[ -x scripts/verify-gx430t-control.sh ]]; then
  if bash scripts/verify-gx430t-control.sh >/tmp/gx430t-global-verify.log 2>&1; then
    PRODUCT_VERIFY=true
  fi
elif [[ -f scripts/verify-gx430t-control.sh ]]; then
  if bash scripts/verify-gx430t-control.sh >/tmp/gx430t-global-verify.log 2>&1; then
    PRODUCT_VERIFY=true
  fi
fi

LATEST_TAG="$(git tag --sort=-version:refname | head -1 || true)"
LATEST_RELEASE_URL=""
LATEST_RELEASE_NAME=""
LATEST_RELEASE_PUBLISHED=""

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  LATEST_RELEASE_URL="$(gh release view --repo "$REPO" --json url --jq '.url' 2>/dev/null || true)"
  LATEST_RELEASE_NAME="$(gh release view --repo "$REPO" --json name --jq '.name' 2>/dev/null || true)"
  LATEST_RELEASE_PUBLISHED="$(gh release view --repo "$REPO" --json publishedAt --jq '.publishedAt' 2>/dev/null || true)"
fi

RELEASE_PRESENT=false
[[ -n "$LATEST_RELEASE_URL" ]] && RELEASE_PRESENT=true

python3 - "$OUT_JSON" \
  "$REPO" \
  "$MAC_APP_SOURCE" \
  "$IPHONE_APP_SOURCE" \
  "$MENUBAR_SOURCE" \
  "$MAC_INSTALLER_SOURCE" \
  "$SIGNED_RELEASE_PIPELINE" \
  "$UPDATER_SOURCE" \
  "$PAIRING_SOURCE" \
  "$PRINT_HOST_SOURCE" \
  "$CLI_SOURCE" \
  "$LICENSE_SOURCE" \
  "$README_SOURCE" \
  "$QUICKSTART_SOURCE" \
  "$DOWNLOADS_SOURCE" \
  "$PRESENTATION_SOURCE" \
  "$CI_SOURCE" \
  "$PRODUCT_VERIFY" \
  "$IPHONE_EVIDENCE" \
  "$RELEASE_PRESENT" \
  "$LATEST_TAG" \
  "$LATEST_RELEASE_URL" \
  "$LATEST_RELEASE_NAME" \
  "$LATEST_RELEASE_PUBLISHED" <<'PY'
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

(
    output,
    repository,
    mac_app,
    iphone_app,
    menubar,
    mac_installer,
    signed_pipeline,
    updater,
    pairing,
    print_host,
    cli,
    license_file,
    readme,
    quickstart,
    downloads,
    presentation,
    ci,
    verification,
    iphone_evidence,
    release_present,
    latest_tag,
    latest_release_url,
    latest_release_name,
    latest_release_published,
) = sys.argv[1:]

def truth(value: str) -> bool:
    return value.lower() == "true"

checks = {
    "mac_app_source": truth(mac_app),
    "iphone_app_source": truth(iphone_app),
    "menu_bar_source": truth(menubar),
    "mac_installer_source": truth(mac_installer),
    "signed_release_pipeline": truth(signed_pipeline),
    "automatic_updater_source": truth(updater),
    "pairing_source": truth(pairing),
    "print_host_source": truth(print_host),
    "cli_source": truth(cli),
    "license_present": truth(license_file),
    "readme_present": truth(readme),
    "colleague_quickstart_present": truth(quickstart),
    "downloads_guide_present": truth(downloads),
    "work_presentation_present": truth(presentation),
    "ci_present": truth(ci),
    "product_verification_passed": truth(verification),
    "iphone_visual_evidence_present": truth(iphone_evidence),
    "github_release_present": truth(release_present),
}

required = [
    "mac_app_source",
    "iphone_app_source",
    "menu_bar_source",
    "mac_installer_source",
    "signed_release_pipeline",
    "automatic_updater_source",
    "pairing_source",
    "print_host_source",
    "cli_source",
    "license_present",
    "readme_present",
    "colleague_quickstart_present",
    "downloads_guide_present",
    "work_presentation_present",
    "ci_present",
    "product_verification_passed",
    "iphone_visual_evidence_present",
    "github_release_present",
]

passed = sum(1 for key in required if checks[key])
total = len(required)
missing = [key for key in required if not checks[key]]

commit = subprocess.check_output(
    ["git", "rev-parse", "HEAD"], text=True
).strip()

branch = subprocess.check_output(
    ["git", "branch", "--show-current"], text=True
).strip()

data = {
    "schema": "gx430t.global-release-readiness.v1",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "repository": repository,
    "branch": branch,
    "commit": commit,
    "score": {
        "passed": passed,
        "total": total,
        "percentage": round((passed / total) * 100, 2),
    },
    "checks": checks,
    "missing": missing,
    "release": {
        "latest_tag": latest_tag or None,
        "latest_release_url": latest_release_url or None,
        "latest_release_name": latest_release_name or None,
        "latest_release_published_at": latest_release_published or None,
    },
    "global_release_ready": len(missing) == 0,
}

path = pathlib.Path(output)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"GX430T_GLOBAL_READINESS_JSON={path}")
print(f"GX430T_GLOBAL_READINESS_SCORE={passed}/{total}")
print(f"GX430T_GLOBAL_RELEASE_READY={str(len(missing) == 0).lower()}")
PY

python3 - "$OUT_JSON" "$OUT_MD" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))

labels = {
    "mac_app_source": "Native macOS application source",
    "iphone_app_source": "Native iPhone application source",
    "menu_bar_source": "macOS menu-bar control source",
    "mac_installer_source": "macOS installer source",
    "signed_release_pipeline": "Signing and notarization pipeline",
    "automatic_updater_source": "Automatic updater source",
    "pairing_source": "Mac and iPhone pairing source",
    "print_host_source": "Mac print-host source",
    "cli_source": "Command-line control surface",
    "license_present": "Apache-2.0 licence",
    "readme_present": "Repository README",
    "colleague_quickstart_present": "Colleague quick-start guide",
    "downloads_guide_present": "Download guide",
    "work_presentation_present": "Work presentation",
    "ci_present": "Continuous integration",
    "product_verification_passed": "Product verification",
    "iphone_visual_evidence_present": "iPhone visual evidence",
    "github_release_present": "Published GitHub release",
}

rows = []
for key, value in data["checks"].items():
    rows.append(
        f"| {'PASS' if value else 'MISSING'} | {labels.get(key, key)} |"
    )

missing = data["missing"]
missing_text = "\n".join(f"- `{item}`" for item in missing) if missing else "- None"

release = data["release"]

body = f"""# GX430T Global Release Readiness

This document is generated from repository and GitHub release evidence.

## Authority

- Repository: `{data['repository']}`
- Branch: `{data['branch']}`
- Commit: `{data['commit']}`
- Readiness score: **{data['score']['passed']}/{data['score']['total']}**
- Percentage: **{data['score']['percentage']}%**
- Global release ready: **{'YES' if data['global_release_ready'] else 'NO'}**

## Product surfaces

| Result | Surface |
| --- | --- |
{chr(10).join(rows)}

## Missing release obligations

{missing_text}

## Current release

- Tag: `{release.get('latest_tag') or 'none'}`
- Release name: `{release.get('latest_release_name') or 'none'}`
- Published: `{release.get('latest_release_published_at') or 'none'}`
- Release URL: `{release.get('latest_release_url') or 'none'}`

## Closure rule

GX430T may be presented as globally downloadable only when every required
surface passes, a GitHub release is published, release files have checksums,
installation instructions are verified on a clean colleague Mac, pairing is
verified with a physical iPhone, and a real label is printed through the Mac
print host.

Repository presence, source presence, build success, or local installation
alone do not constitute global distribution readiness.
"""

target.write_text(body, encoding="utf-8")
print(f"GX430T_GLOBAL_READINESS_MARKDOWN={target}")
PY
