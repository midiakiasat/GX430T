#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

CONFIG_DIR = Path.home() / "Library" / "Application Support" / "GX430T"
CONFIG_FILE = CONFIG_DIR / "client.json"
PROTOCOL = 1
TIMEOUT = 10


def normalize_url(value: str) -> str:
    value = value.strip().rstrip("/")
    if not value:
        raise ValueError("host URL is required")
    if not value.startswith(("http://", "https://")):
        value = f"http://{value}"
    return value


def request_json(
    method: str,
    url: str,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
) -> tuple[int, dict[str, Any]]:
    data = None
    headers = {
        "Accept": "application/json",
        "User-Agent": "GX430T-Mac-Client/1",
    }

    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(
        url=url,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            body = response.read().decode("utf-8")
            parsed = json.loads(body) if body else {}
            return response.status, parsed
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body)
        except Exception:
            parsed = {"error": body or str(exc)}
        return exc.code, parsed
    except urllib.error.URLError as exc:
        raise RuntimeError(f"host unavailable: {exc.reason}") from exc


def load_config() -> dict[str, Any]:
    if not CONFIG_FILE.exists():
        raise RuntimeError("GX430T client is not paired")
    try:
        config = json.loads(CONFIG_FILE.read_text())
    except Exception as exc:
        raise RuntimeError("GX430T client configuration is invalid") from exc

    if not config.get("hostURL") or not config.get("token"):
        raise RuntimeError("GX430T client configuration is incomplete")

    return config


def save_config(config: dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    temporary = CONFIG_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(config, indent=2) + "\n")
    temporary.chmod(0o600)
    temporary.replace(CONFIG_FILE)


def pair(host: str, pairing_code: str, client_name: str) -> int:
    host_url = normalize_url(host)
    status, payload = request_json(
        "POST",
        f"{host_url}/v1/pair",
        {
            "pairingCode": pairing_code.strip(),
            "clientName": client_name.strip() or socket.gethostname(),
        },
    )

    if status != 200 or payload.get("paired") is not True:
        print(json.dumps(payload, indent=2), file=sys.stderr)
        return 1

    if int(payload.get("protocol", 0)) != PROTOCOL:
        print("GX430T_CLIENT_PROTOCOL_MISMATCH=true", file=sys.stderr)
        return 1

    token = str(payload.get("token", ""))
    if len(token) != 64:
        print("GX430T_CLIENT_INVALID_HOST_TOKEN=true", file=sys.stderr)
        return 1

    config = {
        "schema": "gx430t.client_config.v1",
        "hostURL": host_url,
        "hostName": payload.get("hostName", "GX430T Host"),
        "token": token,
        "protocol": PROTOCOL,
        "clientName": client_name.strip() or socket.gethostname(),
    }
    save_config(config)

    print("GX430T_CLIENT_PAIRED=true")
    print(f"GX430T_CLIENT_HOST={config['hostName']}")
    print(f"GX430T_CLIENT_URL={host_url}")
    return 0


def status() -> int:
    config = load_config()
    code, payload = request_json(
        "GET",
        f"{config['hostURL']}/v1/status",
        token=config["token"],
    )

    print(json.dumps(payload, indent=2))

    if code == 200 and payload.get("printerOnline") is True:
        print("GX430T_REMOTE_STATUS=ONLINE")
        return 0

    print("GX430T_REMOTE_STATUS=OFFLINE")
    return 1


def info() -> int:
    config = load_config()
    print(f"GX430T_CLIENT_HOST_NAME={config.get('hostName', '')}")
    print(f"GX430T_CLIENT_HOST_URL={config.get('hostURL', '')}")
    print(f"GX430T_CLIENT_NAME={config.get('clientName', '')}")
    print(f"GX430T_CLIENT_PROTOCOL={config.get('protocol', '')}")
    print(f"GX430T_CLIENT_CONFIG={CONFIG_FILE}")
    return 0


def print_job(kind: str, value: str, copies: int) -> int:
    config = load_config()

    if kind not in {"text", "code128", "code39", "qr"}:
        raise ValueError("unsupported print kind")
    if not value.strip():
        raise ValueError("print value is required")
    if copies < 1 or copies > 999:
        raise ValueError("copies must be between 1 and 999")

    code, payload = request_json(
        "POST",
        f"{config['hostURL']}/v1/print",
        {
            "kind": kind,
            "value": value,
            "copies": copies,
        },
        token=config["token"],
    )

    print(json.dumps(payload, indent=2))

    if code == 200 and payload.get("accepted") is True:
        print("GX430T_REMOTE_PRINT_ACCEPTED=true")
        return 0

    print("GX430T_REMOTE_PRINT_ACCEPTED=false", file=sys.stderr)
    return 1


def remove() -> int:
    if CONFIG_FILE.exists():
        CONFIG_FILE.unlink()
    print("GX430T_CLIENT_PAIRING_REMOVED=true")
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="gx430t-client")
    sub = root.add_subparsers(dest="command", required=True)

    pair_parser = sub.add_parser("pair")
    pair_parser.add_argument("host")
    pair_parser.add_argument("pairing_code")
    pair_parser.add_argument(
        "--name",
        default=os.environ.get("GX430T_CLIENT_NAME", socket.gethostname()),
    )

    sub.add_parser("status")
    sub.add_parser("info")
    sub.add_parser("remove")

    print_parser = sub.add_parser("print")
    print_parser.add_argument("kind", choices=["text", "code128", "code39", "qr"])
    print_parser.add_argument("value")
    print_parser.add_argument("copies", nargs="?", type=int, default=1)

    return root


def main() -> int:
    args = parser().parse_args()

    try:
        if args.command == "pair":
            return pair(args.host, args.pairing_code, args.name)
        if args.command == "status":
            return status()
        if args.command == "info":
            return info()
        if args.command == "print":
            return print_job(args.kind, args.value, args.copies)
        if args.command == "remove":
            return remove()
    except (RuntimeError, ValueError) as exc:
        print(f"GX430T_CLIENT_ERROR={exc}", file=sys.stderr)
        return 1

    return 64


if __name__ == "__main__":
    raise SystemExit(main())
