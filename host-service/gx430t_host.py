#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import secrets
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


def write_config(config: dict[str, Any]) -> None:
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    temporary = CONFIG.with_suffix(".tmp")
    temporary.write_text(json.dumps(config, indent=2) + "\n")
    temporary.chmod(0o600)
    temporary.replace(CONFIG)


def generate_pairing_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


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


def read_jobs(limit: int = 100) -> list[dict[str, Any]]:
    if not LOG_FILE.exists():
        return []

    records: list[dict[str, Any]] = []

    try:
        with LOG_FILE.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue

                try:
                    payload = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if isinstance(payload, dict):
                    records.append(payload)
    except OSError:
        return []

    records.reverse()
    return records[: max(1, min(limit, 500))]


def job_summary(records: list[dict[str, Any]]) -> dict[str, Any]:
    print_jobs = [
        record
        for record in records
        if "jobId" in record
    ]

    successful = sum(
        1
        for record in print_jobs
        if record.get("success") is True
    )

    failed = sum(
        1
        for record in print_jobs
        if record.get("success") is False
    )

    copies = sum(
        int(record.get("copies", 0) or 0)
        for record in print_jobs
    )

    latest = print_jobs[0] if print_jobs else None

    return {
        "totalJobs": len(print_jobs),
        "successfulJobs": successful,
        "failedJobs": failed,
        "totalCopies": copies,
        "latestJob": latest,
    }


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
                    "authentication": "pairing-code-and-bearer-token",
                    "pairingEnabled": bool(config.get("pairingEnabled", False)),
                },
            )
            return

        if self.path.startswith("/v1/jobs"):
            if not self.authenticated():
                self.send_json(401, {"error": "unauthorized"})
                return

            limit = 100

            if "?" in self.path:
                query = self.path.split("?", 1)[1]

                for field in query.split("&"):
                    if field.startswith("limit="):
                        try:
                            limit = int(field.split("=", 1)[1])
                        except ValueError:
                            limit = 100

            records = read_jobs(limit)

            if self.path.startswith("/v1/jobs/summary"):
                self.send_json(
                    200,
                    {
                        "service": "GX430T Print Host",
                        "protocol": 1,
                        "summary": job_summary(records),
                    },
                )
                return

            self.send_json(
                200,
                {
                    "service": "GX430T Print Host",
                    "protocol": 1,
                    "jobs": records,
                },
            )
            return

        self.send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path == "/v1/pair":
            try:
                payload = self.read_body()
                supplied_code = str(payload.get("pairingCode", "")).strip()
                client_name = str(payload.get("clientName", "GX430T Client")).strip()[:120]

                config = read_config()
                expected_code = str(config.get("pairingCode", ""))
                pairing_enabled = bool(config.get("pairingEnabled", False))

                if not pairing_enabled or not expected_code:
                    self.send_json(403, {"error": "pairing_disabled"})
                    return

                if not secrets.compare_digest(supplied_code, expected_code):
                    time.sleep(0.35)
                    self.send_json(401, {"error": "invalid_pairing_code"})
                    return

                token = str(config.get("token", ""))
                if not token:
                    self.send_json(503, {"error": "host_token_unavailable"})
                    return

                next_code = generate_pairing_code()
                config["pairingCode"] = next_code
                config["pairingEnabled"] = True
                config["lastPairedClient"] = client_name
                config["lastPairedAddress"] = self.client_address[0]
                config["lastPairedTimestamp"] = int(time.time())
                write_config(config)

                append_job(
                    {
                        "event": "client_paired",
                        "clientName": client_name,
                        "remoteAddress": self.client_address[0],
                        "timestamp": int(time.time()),
                    }
                )

                self.send_json(
                    200,
                    {
                        "paired": True,
                        "protocol": 1,
                        "hostName": config.get("hostName", "GX430T Host"),
                        "token": token,
                    },
                )
                return
            except (ValueError, TypeError, json.JSONDecodeError) as exc:
                self.send_json(400, {"error": "invalid_request", "detail": str(exc)})
                return
            except Exception as exc:
                self.send_json(500, {"error": "internal_error", "detail": str(exc)})
                return

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
