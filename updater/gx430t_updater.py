#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from typing import Any

REPOSITORY = "midiakiasat/GX430T"
API_URL = f"https://api.github.com/repos/{REPOSITORY}/releases/latest"
USER_AGENT = "GX430T-Mac-Control-Updater/1"
DEFAULT_APP = pathlib.Path("/Applications/GX430T Mac Control.app")
STATE_DIR = pathlib.Path.home() / "Library/Application Support/GX430T/Updater"
STATE_FILE = STATE_DIR / "state.json"
CACHE_DIR = pathlib.Path.home() / "Library/Caches/GX430T/Updater"


@dataclass(frozen=True)
class ReleaseAsset:
    name: str
    url: str
    size: int
    digest: str | None


@dataclass(frozen=True)
class Release:
    tag: str
    version: str
    html_url: str
    published_at: str
    package: ReleaseAsset
    checksum: ReleaseAsset


def fail(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def request_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": USER_AGENT,
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read()
    except urllib.error.HTTPError as exc:
        fail(f"GX430T_UPDATE_HTTP_ERROR={exc.code}")
    except urllib.error.URLError as exc:
        fail(f"GX430T_UPDATE_NETWORK_ERROR={exc.reason}")

    try:
        parsed = json.loads(payload)
    except json.JSONDecodeError:
        fail("GX430T_UPDATE_INVALID_RELEASE_RESPONSE=true")

    if not isinstance(parsed, dict):
        fail("GX430T_UPDATE_INVALID_RELEASE_RESPONSE=true")

    return parsed


def parse_version(value: str) -> tuple[int, ...]:
    cleaned = value.strip().lower()

    if cleaned.startswith("v"):
        cleaned = cleaned[1:]

    match = re.match(r"^(\d+(?:\.\d+)*)", cleaned)

    if not match:
        return (0,)

    return tuple(int(part) for part in match.group(1).split("."))


def installed_version(app_path: pathlib.Path) -> str:
    plist_path = app_path / "Contents/Info.plist"

    if not plist_path.is_file():
        return "0.0.0"

    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)

    value = plist.get("CFBundleShortVersionString") or plist.get(
        "CFBundleVersion"
    )

    if not value:
        return "0.0.0"

    return str(value)


def find_asset(
    assets: list[dict[str, Any]],
    predicate,
) -> ReleaseAsset:
    for asset in assets:
        name = str(asset.get("name", ""))

        if not predicate(name):
            continue

        url = str(asset.get("browser_download_url", ""))
        size = int(asset.get("size", 0))
        digest_value = asset.get("digest")
        digest = str(digest_value) if digest_value else None

        if not url:
            continue

        return ReleaseAsset(
            name=name,
            url=url,
            size=size,
            digest=digest,
        )

    fail("GX430T_UPDATE_REQUIRED_RELEASE_ASSET_MISSING=true")


def latest_release() -> Release:
    payload = request_json(API_URL)

    if payload.get("draft") is True:
        fail("GX430T_UPDATE_LATEST_RELEASE_IS_DRAFT=true")

    if payload.get("prerelease") is True:
        fail("GX430T_UPDATE_LATEST_RELEASE_IS_PRERELEASE=true")

    tag = str(payload.get("tag_name", "")).strip()

    if not tag:
        fail("GX430T_UPDATE_RELEASE_TAG_MISSING=true")

    version = tag[1:] if tag.lower().startswith("v") else tag
    assets_raw = payload.get("assets")

    if not isinstance(assets_raw, list):
        fail("GX430T_UPDATE_RELEASE_ASSETS_MISSING=true")

    assets = [
        asset for asset in assets_raw if isinstance(asset, dict)
    ]

    package = find_asset(
        assets,
        lambda name: (
            name.startswith("GX430T-Mac-Control-")
            and name.endswith(".pkg")
            and not name.endswith(".pkg.sha256")
        ),
    )

    checksum = find_asset(
        assets,
        lambda name: name == f"{package.name}.sha256",
    )

    return Release(
        tag=tag,
        version=version,
        html_url=str(payload.get("html_url", "")),
        published_at=str(payload.get("published_at", "")),
        package=package,
        checksum=checksum,
    )


def download(url: str, destination: pathlib.Path) -> None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT},
    )

    destination.parent.mkdir(parents=True, exist_ok=True)

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            with destination.open("wb") as output:
                shutil.copyfileobj(response, output)
    except urllib.error.HTTPError as exc:
        fail(f"GX430T_UPDATE_DOWNLOAD_HTTP_ERROR={exc.code}")
    except urllib.error.URLError as exc:
        fail(f"GX430T_UPDATE_DOWNLOAD_NETWORK_ERROR={exc.reason}")


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)

    return digest.hexdigest()


def parse_checksum_file(path: pathlib.Path, package_name: str) -> str:
    text = path.read_text(encoding="utf-8").strip()

    for line in text.splitlines():
        parts = line.strip().split()

        if not parts:
            continue

        candidate = parts[0].lower()

        if re.fullmatch(r"[0-9a-f]{64}", candidate):
            if len(parts) == 1:
                return candidate

            recorded_name = parts[-1].lstrip("*")

            if pathlib.Path(recorded_name).name == package_name:
                return candidate

    fail("GX430T_UPDATE_INVALID_CHECKSUM_FILE=true")


def verify_package(
    package: pathlib.Path,
    checksum_file: pathlib.Path,
    release: Release,
) -> str:
    actual = sha256(package)
    expected = parse_checksum_file(
        checksum_file,
        release.package.name,
    )

    if actual != expected:
        fail("GX430T_UPDATE_SHA256_MISMATCH=true")

    github_digest = release.package.digest

    if github_digest:
        normalized = github_digest.lower()

        if normalized.startswith("sha256:"):
            normalized = normalized.split(":", 1)[1]

        if normalized != actual:
            fail("GX430T_UPDATE_GITHUB_DIGEST_MISMATCH=true")

    package_check = subprocess.run(
        ["pkgutil", "--check-signature", str(package)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )

    signature_output = package_check.stdout.strip()

    if signature_output:
        print(signature_output)

    print(f"GX430T_UPDATE_PACKAGE_SHA256={actual}")

    return actual


def release_payload(release: Release, current: str) -> dict[str, Any]:
    available = parse_version(release.version) > parse_version(current)

    return {
        "repository": REPOSITORY,
        "currentVersion": current,
        "latestVersion": release.version,
        "tag": release.tag,
        "updateAvailable": available,
        "publishedAt": release.published_at,
        "releaseURL": release.html_url,
        "package": asdict(release.package),
        "checksum": asdict(release.checksum),
    }


def save_state(payload: dict[str, Any]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )
    os.chmod(temporary, 0o600)
    temporary.replace(STATE_FILE)


def command_check(args: argparse.Namespace) -> int:
    current = installed_version(pathlib.Path(args.app))
    release = latest_release()
    payload = release_payload(release, current)
    save_state(payload)

    print(json.dumps(payload, indent=2))

    if payload["updateAvailable"]:
        print("GX430T_UPDATE_AVAILABLE=true")
        return 10

    print("GX430T_UPDATE_AVAILABLE=false")
    return 0


def command_download(args: argparse.Namespace) -> int:
    current = installed_version(pathlib.Path(args.app))
    release = latest_release()
    payload = release_payload(release, current)

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    package_path = CACHE_DIR / release.package.name
    checksum_path = CACHE_DIR / release.checksum.name

    with tempfile.TemporaryDirectory(
        prefix="gx430t-update-",
        dir=str(CACHE_DIR),
    ) as temporary_directory:
        temporary = pathlib.Path(temporary_directory)
        temporary_package = temporary / release.package.name
        temporary_checksum = temporary / release.checksum.name

        download(release.package.url, temporary_package)
        download(release.checksum.url, temporary_checksum)

        digest = verify_package(
            temporary_package,
            temporary_checksum,
            release,
        )

        temporary_package.replace(package_path)
        temporary_checksum.replace(checksum_path)

    payload["downloadedPackage"] = str(package_path)
    payload["downloadedChecksum"] = str(checksum_path)
    payload["verifiedSHA256"] = digest
    save_state(payload)

    print(json.dumps(payload, indent=2))
    print(f"GX430T_UPDATE_DOWNLOADED={package_path}")
    print("GX430T_UPDATE_VERIFIED=true")

    return 0


def command_install(args: argparse.Namespace) -> int:
    current = installed_version(pathlib.Path(args.app))
    release = latest_release()
    package_path = CACHE_DIR / release.package.name
    checksum_path = CACHE_DIR / release.checksum.name

    if not package_path.is_file() or not checksum_path.is_file():
        fail("GX430T_UPDATE_NOT_DOWNLOADED=true")

    verify_package(package_path, checksum_path, release)

    command = [
        "/usr/sbin/installer",
        "-pkg",
        str(package_path),
        "-target",
        "/",
    ]

    if os.geteuid() == 0:
        subprocess.run(command, check=True)
    else:
        subprocess.run(
            ["/usr/bin/sudo", *command],
            check=True,
        )

    installed = installed_version(pathlib.Path(args.app))

    payload = release_payload(release, current)
    payload["installedVersionAfterUpdate"] = installed
    payload["installedPackage"] = str(package_path)
    payload["installationComplete"] = True
    save_state(payload)

    print(f"GX430T_UPDATE_INSTALLED_VERSION={installed}")
    print("GX430T_UPDATE_INSTALL_COMPLETE=true")

    return 0


def command_state(_: argparse.Namespace) -> int:
    if not STATE_FILE.is_file():
        print("GX430T_UPDATE_STATE=EMPTY")
        return 0

    print(STATE_FILE.read_text(encoding="utf-8"), end="")
    return 0


def command_clear(_: argparse.Namespace) -> int:
    if CACHE_DIR.exists():
        shutil.rmtree(CACHE_DIR)

    if STATE_FILE.exists():
        STATE_FILE.unlink()

    print("GX430T_UPDATE_CACHE_CLEARED=true")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gx430t-updater",
        description="GX430T secure GitHub release updater",
    )

    parser.add_argument(
        "--app",
        default=str(DEFAULT_APP),
        help="Installed GX430T application bundle",
    )

    subparsers = parser.add_subparsers(
        dest="command",
        required=True,
    )

    subparsers.add_parser("check")
    subparsers.add_parser("download")
    subparsers.add_parser("install")
    subparsers.add_parser("state")
    subparsers.add_parser("clear")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "check": command_check,
        "download": command_download,
        "install": command_install,
        "state": command_state,
        "clear": command_clear,
    }

    return commands[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
