#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

HOST = os.environ.get("GX430T_HOST_BIND", "0.0.0.0")
PORT = int(os.environ.get("GX430T_HOST_PORT", "43043"))
CLI = os.environ.get("GX430T_CLI", "/usr/local/bin/gx430tctl")
CONFIG = Path.home() / "Library" / "Application Support" / "GX430T" / "host.json"
LOG_DIR = Path.home() / "Library" / "Logs" / "GX430T"
LOG_FILE = LOG_DIR / "host-jobs.jsonl"

ALLOWED_KINDS = {
    "text": "print-text",
    "code128": "print-code128",
    "code39": "print-code39",
    "qr": "print-qr",
}


def read_config() -> dict[str, Any]:
    try:
        return json.loads(CONFIG.read_text())
    except Exception:
        return {}


def run_cli(arguments: list[str], timeout: int = 30) -> tuple[int, str]:
    try:
        result = subprocess.run(
            [CLI, *arguments],
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        output = (result.stdout + result.stderr).strip()
        return result.returncode, output
    except Exception as exc:
        return 1, str(exc)


def append_job(record: dict[str, Any]) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, separators=(",", ":")) + "\n")


class Handler(BaseHTTPRequestHandler):
    server_version = "GX430THost/1.0"

    def log_message(self, format: str, *args: Any) -> None:
        return

    def send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def authenticated(self) -> bool:
        config = read_config()
        expected = str(config.get("token", ""))
        supplied = self.headers.get("Authorization", "")
        if supplied.startswith("Bearer "):
            supplied = supplied[7:]
        return bool(expected) and supplied == expected

    def read_body(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length < 1 or length > 65536:
            raise ValueError("invalid content length")
        raw = self.rfile.read(length)
        payload = json.loads(raw.decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("JSON object required")
        return payload

    def do_GET(self) -> None:
        if self.path == "/v1/health":
            self.send_json(
                200,
                {
                    "service": "GX430T Print Host",
                    "protocol": 1,
                    "status": "ok",
                },
            )
            return

        if self.path == "/v1/status":
            code, output = run_cli(["status"])
            self.send_json(
                200 if code == 0 else 503,
                {
                    "service": "GX430T Print Host",
                    "protocol": 1,
                    "printerOnline": code == 0,
                    "statusOutput": output,
                },
            )
            return

        if self.path == "/v1/info":
            config = read_config()
            self.send_json(
                200,
                {
                    "service": "GX430T Print Host",
                    "protocol": 1,
                    "hostName": config.get("hostName", "GX430T Host"),
                    "port": PORT,
                    "authentication": "bearer-token",
                },
            )
            return

        self.send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path != "/v1/print":
            self.send_json(404, {"error": "not_found"})
            return

        if not self.authenticated():
            self.send_json(401, {"error": "unauthorized"})
            return

        try:
            payload = self.read_body()
            kind = str(payload.get("kind", "")).lower()
            value = str(payload.get("value", "")).strip()
            copies = int(payload.get("copies", 1))

            if kind not in ALLOWED_KINDS:
                raise ValueError("unsupported print kind")
            if not value:
                raise ValueError("value is required")
            if len(value) > 4096:
                raise ValueError("value is too long")
            if copies < 1 or copies > 999:
                raise ValueError("copies must be between 1 and 999")

            job_id = str(uuid.uuid4())
            started = time.time()
            payload_hash = hashlib.sha256(
                f"{kind}\0{value}\0{copies}".encode("utf-8")
            ).hexdigest()

            code, output = run_cli(
                [ALLOWED_KINDS[kind], value, str(copies)],
                timeout=60,
            )

            record = {
                "jobId": job_id,
                "kind": kind,
                "copies": copies,
                "payloadHash": payload_hash,
                "success": code == 0,
                "result": output,
                "durationMs": int((time.time() - started) * 1000),
                "timestamp": int(time.time()),
                "remoteAddress": self.client_address[0],
            }
            append_job(record)

            self.send_json(
                200 if code == 0 else 503,
                {
                    "jobId": job_id,
                    "accepted": code == 0,
                    "result": output,
                },
            )
        except (ValueError, TypeError, json.JSONDecodeError) as exc:
            self.send_json(400, {"error": "invalid_request", "detail": str(exc)})
        except Exception as exc:
            self.send_json(500, {"error": "internal_error", "detail": str(exc)})


def main() -> int:
    if not Path(CLI).is_file():
        print("GX430T_HOST_CLI_NOT_FOUND=true", file=sys.stderr)
        return 70

    config = read_config()
    if not config.get("token"):
        print("GX430T_HOST_TOKEN_NOT_CONFIGURED=true", file=sys.stderr)
        return 78

    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"GX430T_HOST_LISTENING=http://{HOST}:{PORT}", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
