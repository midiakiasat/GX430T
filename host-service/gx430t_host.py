#!/usr/bin/env python3
from __future__ import annotations
import argparse
import hashlib
import secrets
import uuid
import csv
import html
import io
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.parse
import webbrowser
import zipfile
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from decimal import Decimal, InvalidOperation

VERSION = os.environ.get("GX430T_VERSION", "0.3.3")
HOST = os.environ.get("GX430T_HOST_BIND", "0.0.0.0")
PORT = int(
    os.environ.get(
        "GX430T_HOST_PORT",
        os.environ.get("GX430T_PORT", "43043"),
    )
)
CLI = os.environ.get("GX430T_CLI", "/usr/local/bin/gx430tctl")

CONFIG = (
    Path.home()
    / "Library"
    / "Application Support"
    / "GX430T"
    / "host.json"
)

LOG_DIR = Path.home() / "Library" / "Logs" / "GX430T"
LOG_FILE = LOG_DIR / "host-jobs.jsonl"

PROTOCOL_VERSION = 1
MAX_JSON_BODY = 65536
MAX_UPLOAD_BODY = 50 * 1024 * 1024

BARCODE_KEYS = [
    "barcode", "bar code", "codice", "code", "ean", "gtin", "sku",
    "style code", "style", "item code", "product code", "article",
    "articolo", "ref", "reference", "id"
]
TITLE_KEYS = ["title", "name", "description", "descrizione", "brand", "label", "product"]
QTY_KEYS = ["quantity", "qty", "qta", "quantita", "quantità", "copies", "copy"]
ORDER_KEYS = ["order", "ordine", "sequence", "seq", "priority", "row", "riga", "position"]

def gx_home():
    return Path(os.environ.get("GX430T_HOME", str(Path.home() / ".gx430t")))

def db_path():
    h = gx_home()
    h.mkdir(parents=True, exist_ok=True)
    (h / "uploads").mkdir(parents=True, exist_ok=True)
    return h / "queue.sqlite3"

def create_jobs_table(con):
    con.execute("""
    CREATE TABLE IF NOT EXISTS jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created REAL NOT NULL,
      position REAL NOT NULL,
      source_file TEXT,
      source_row INTEGER,
      barcode TEXT NOT NULL,
      title TEXT,
      status TEXT NOT NULL DEFAULT 'queued',
      printed REAL,
      last_error TEXT,
      zpl TEXT NOT NULL
    )
    """)


def safe_float(value, fallback):
    try:
        return float(value)
    except (TypeError, ValueError):
        return float(fallback)


def safe_int(value, fallback=None):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return fallback


def ensure_queue_schema(con):
    information = con.execute(
        "PRAGMA table_info(jobs)"
    ).fetchall()

    if not information:
        create_jobs_table(con)
        con.commit()
        return

    columns = {
        str(row["name"]): row
        for row in information
    }

    id_column = columns.get("id")

    canonical = (
        id_column is not None
        and int(id_column["pk"] or 0) == 1
        and "INT" in str(id_column["type"] or "").upper()
        and {
            "created",
            "position",
            "source_file",
            "source_row",
            "barcode",
            "title",
            "status",
            "printed",
            "last_error",
            "zpl",
        }.issubset(columns)
    )

    if canonical:
        return

    legacy_name = (
        "jobs_legacy_"
        + str(int(time.time() * 1000))
    )

    con.execute("BEGIN IMMEDIATE")

    try:
        con.execute(
            f'ALTER TABLE jobs RENAME TO "{legacy_name}"'
        )

        create_jobs_table(con)

        legacy_rows = con.execute(
            f'SELECT * FROM "{legacy_name}"'
        ).fetchall()

        for index, row in enumerate(legacy_rows, start=1):
            available = set(row.keys())

            def value(*names):
                for name in names:
                    if name in available:
                        candidate = row[name]

                        if candidate is not None:
                            return candidate

                return None

            barcode = nonempty(
                value(
                    "barcode",
                    "code",
                    "ean",
                    "sku",
                    "value",
                )
            )

            if not barcode:
                continue

            title = nonempty(
                value(
                    "title",
                    "name",
                    "description",
                    "label",
                )
            ) or barcode

            created = safe_float(
                value("created", "created_at", "timestamp"),
                time.time(),
            )

            base_position = safe_float(
                value(
                    "position",
                    "order",
                    "sequence",
                    "priority",
                ),
                index,
            )

            source_file = nonempty(
                value(
                    "source_file",
                    "source",
                    "filename",
                    "file",
                )
            ) or None

            source_row = safe_int(
                value(
                    "source_row",
                    "row",
                    "row_number",
                )
            )

            status = nonempty(
                value("status")
            ).lower() or "queued"

            if status not in {
                "queued",
                "printed",
                "error",
            }:
                status = "queued"

            printed_value = value(
                "printed",
                "printed_at",
            )

            printed = None

            if printed_value not in {
                None,
                "",
                0,
                0.0,
                "0",
                "0.0",
            }:
                printed = safe_float(
                    printed_value,
                    time.time(),
                )

            last_error = nonempty(
                value(
                    "last_error",
                    "error",
                )
            ) or None

            existing_zpl = nonempty(
                value("zpl")
            )

            quantity = safe_int(
                value(
                    "qty",
                    "quantity",
                    "copies",
                ),
                1,
            )

            quantity = max(
                1,
                min(quantity or 1, 999),
            )

            for copy_index in range(quantity):
                position = (
                    base_position
                    + copy_index * 0.0001
                )

                con.execute(
                    """
                    INSERT INTO jobs(
                      created,
                      position,
                      source_file,
                      source_row,
                      barcode,
                      title,
                      status,
                      printed,
                      last_error,
                      zpl
                    )
                    VALUES(?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        created,
                        position,
                        source_file,
                        source_row,
                        barcode,
                        title,
                        status,
                        printed,
                        last_error,
                        existing_zpl
                        or zpl_for(barcode, title),
                    ),
                )

        con.execute(
            f'DROP TABLE "{legacy_name}"'
        )

        con.commit()
    except Exception:
        con.rollback()
        raise


def connect():
    con = sqlite3.connect(str(db_path()))
    con.row_factory = sqlite3.Row
    ensure_queue_schema(con)
    return con

def clean_key(x):
    return re.sub(r"\s+", " ", str(x or "").strip().lower())

def nonempty(v):
    return str(v or "").strip()

def numeric_like(v):
    s = nonempty(v)
    return bool(re.fullmatch(r"[0-9A-Za-z._\-]+", s)) and not any(c.isspace() for c in s)

def is_header_row(row):
    vals = [clean_key(x) for x in row if nonempty(x)]
    if not vals:
        return False
    joined = " ".join(vals)
    known = BARCODE_KEYS + TITLE_KEYS + QTY_KEYS + ORDER_KEYS
    if any(k in joined for k in known):
        return True
    if len(vals) == 1 and numeric_like(vals[0]):
        return False
    if len(vals) <= 2 and all(numeric_like(v) for v in vals):
        return False
    return False

def matrix_to_dict_rows(matrix):
    rows = []
    for r in matrix:
        vals = [nonempty(x) for x in r]
        if any(vals):
            rows.append(vals)
    if not rows:
        return []
    if is_header_row(rows[0]):
        headers = [clean_key(x) or f"column_{i+1}" for i, x in enumerate(rows[0])]
        out = []
        for i, row in enumerate(rows[1:], start=2):
            d = {}
            for j, val in enumerate(row):
                key = headers[j] if j < len(headers) else f"column_{j+1}"
                d[key] = val
            d["_source_row"] = i
            out.append(d)
        return out
    out = []
    for i, row in enumerate(rows, start=1):
        d = {"barcode": row[0], "_source_row": i}
        if len(row) > 1:
            d["title"] = row[1]
        if len(row) > 2:
            d["quantity"] = row[2]
        if len(row) > 3:
            d["order"] = row[3]
        out.append(d)
    return out

def read_delimited(path):
    text = Path(path).read_text(encoding="utf-8-sig", errors="replace")
    ext = Path(path).suffix.lower()
    sample = text[:4096]
    if ext == ".tsv":
        delim = "\t"
    else:
        try:
            delim = csv.Sniffer().sniff(sample, delimiters=",;\t|").delimiter
        except Exception:
            if "\t" in sample:
                delim = "\t"
            elif ";" in sample:
                delim = ";"
            else:
                delim = ","
    reader = csv.reader(io.StringIO(text), delimiter=delim)
    return matrix_to_dict_rows(list(reader))

def xlsx_shared_strings(z):
    names = z.namelist()
    if "xl/sharedStrings.xml" not in names:
        return []
    root = ET.fromstring(z.read("xl/sharedStrings.xml"))
    ns = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    out = []
    for si in root.findall(".//a:si", ns):
        texts = [t.text or "" for t in si.findall(".//a:t", ns)]
        out.append("".join(texts))
    return out

def xlsx_cell_value(cell, shared):
    t = cell.attrib.get("t")
    v = cell.find("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}v")
    if v is None:
        inline = cell.find(".//{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")
        return inline.text if inline is not None and inline.text is not None else ""
    raw = v.text or ""
    if t == "s":
        try:
            return shared[int(raw)]
        except Exception:
            return raw
    return raw

def col_index(cell_ref):
    letters = "".join(ch for ch in cell_ref if ch.isalpha()).upper()
    n = 0
    for ch in letters:
        n = n * 26 + (ord(ch) - 64)
    return max(0, n - 1)

def read_xlsx(path):
    with zipfile.ZipFile(path) as z:
        shared = xlsx_shared_strings(z)
        sheet = "xl/worksheets/sheet1.xml"
        if sheet not in z.namelist():
            sheets = [n for n in z.namelist() if n.startswith("xl/worksheets/sheet") and n.endswith(".xml")]
            if not sheets:
                return []
            sheet = sorted(sheets)[0]
        root = ET.fromstring(z.read(sheet))
        ns = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
        matrix = []
        for row in root.findall(".//a:sheetData/a:row", ns):
            vals = []
            for c in row.findall("a:c", ns):
                idx = col_index(c.attrib.get("r", "A1"))
                while len(vals) <= idx:
                    vals.append("")
                vals[idx] = xlsx_cell_value(c, shared)
            matrix.append(vals)
        return matrix_to_dict_rows(matrix)

def ods_cell_text(cell):
    texts = []
    for elem in cell.iter():
        if elem.text:
            texts.append(elem.text)
    return " ".join(t.strip() for t in texts if t.strip())

def read_ods(path):
    matrix = []
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("content.xml"))
        ns_table = "{urn:oasis:names:tc:opendocument:xmlns:table:1.0}"
        for table in root.iter(ns_table + "table"):
            for row in table.iter(ns_table + "table-row"):
                repeat_row = int(row.attrib.get(ns_table + "number-rows-repeated", "1"))
                vals = []
                for cell in list(row):
                    if not cell.tag.endswith("table-cell"):
                        continue
                    repeat = int(cell.attrib.get(ns_table + "number-columns-repeated", "1"))
                    val = ods_cell_text(cell)
                    if repeat > 50 and not val:
                        repeat = 1
                    for _ in range(repeat):
                        vals.append(val)
                if any(nonempty(x) for x in vals):
                    for _ in range(min(repeat_row, 20)):
                        matrix.append(vals)
            if matrix:
                break
    return matrix_to_dict_rows(matrix)

def read_rows(path):
    ext = Path(path).suffix.lower()
    if ext == ".xlsx":
        return read_xlsx(path)
    if ext == ".ods":
        return read_ods(path)
    if ext in [".csv", ".tsv", ".txt"]:
        return read_delimited(path)
    return read_delimited(path)

def first_value(d, keys):
    lower = {clean_key(k): v for k, v in d.items()}
    for k in keys:
        ck = clean_key(k)
        if ck in lower and nonempty(lower[ck]):
            return nonempty(lower[ck])
    return ""

def qty_value(d):
    raw = first_value(d, QTY_KEYS)
    if not raw:
        return 1
    try:
        return max(1, int(float(str(raw).replace(",", "."))))
    except Exception:
        return 1

def order_value(d, fallback):
    raw = first_value(d, ORDER_KEYS)
    if not raw:
        return float(fallback)
    try:
        return float(str(raw).replace(",", "."))
    except Exception:
        return float(fallback)


def normalize_barcode_value(v):
    s = nonempty(v)
    if not s:
        return ""
    s = s.strip()
    # Excel/Google Sheets may expose barcode-looking numeric cells as 9.87654321E8.
    # Convert integer-valued scientific/float notation back to plain digits.
    if re.fullmatch(r"[+-]?\d+(\.\d+)?[eE][+-]?\d+", s) or re.fullmatch(r"[+-]?\d+\.0+", s):
        try:
            d = Decimal(s)
            if d == d.to_integral_value():
                return format(d.quantize(Decimal(1)), "f")
        except (InvalidOperation, ValueError):
            pass
    if re.fullmatch(r"\d+\.0+", s):
        return s.split(".", 1)[0]
    return s

def fallback_barcode(d):
    for k, v in d.items():
        if str(k).startswith("_"):
            continue
        val = normalize_barcode_value(v)
        if val:
            return val
    return ""

def zpl_for(barcode, title=""):
    safe = str(barcode).replace("^", " ").replace("~", " ")
    label = str(title or barcode).replace("^", " ").replace("~", " ")
    return f"^XA\n^CI28\n^FO35,42^BY2,2.7,92^BCN,92,Y,N,N^FD{safe}^FS\n^FO35,164^A0N,26,26^FD{label}^FS\n^XZ\n"

def expand_jobs(rows, source_file):
    jobs = []
    seq = 0
    for idx, d in enumerate(rows, start=1):
        source_row = int(d.get("_source_row", idx) or idx)
        barcode = first_value(d, BARCODE_KEYS) or fallback_barcode(d)
        barcode = normalize_barcode_value(barcode)
        if not barcode:
            continue
        title = first_value(d, TITLE_KEYS) or barcode
        qty = qty_value(d)
        order = order_value(d, idx)
        for copy in range(qty):
            seq += 1
            jobs.append({
                "position": order + copy * 0.0001 + seq * 0.0000001,
                "source_file": Path(source_file).name,
                "source_row": source_row,
                "barcode": barcode,
                "title": title,
                "zpl": zpl_for(barcode, title)
            })
    jobs.sort(key=lambda x: (x["position"], x["source_row"]))
    return jobs

def enqueue_file(path):
    rows = read_rows(path)
    jobs = expand_jobs(rows, path)
    con = connect()
    with con:
        for j in jobs:
            con.execute(
                "INSERT INTO jobs(created, position, source_file, source_row, barcode, title, status, zpl) VALUES(?,?,?,?,?,?,?,?)",
                (time.time(), j["position"], j["source_file"], j["source_row"], j["barcode"], j["title"], "queued", j["zpl"])
            )
    return {"ok": True, "file": Path(path).name, "rows": len(jobs), "labels": len(jobs)}

def counts(con):
    out = {"queued": 0, "printed": 0, "error": 0}
    for r in con.execute("SELECT status, COUNT(*) c FROM jobs GROUP BY status"):
        out[r["status"]] = r["c"]
    return out

def state(limit=100):
    con = connect()
    jobs = []
    for r in con.execute("SELECT * FROM jobs ORDER BY CASE status WHEN 'queued' THEN 0 WHEN 'error' THEN 1 ELSE 2 END, position, id LIMIT ?", (limit,)):
        jobs.append({k: r[k] for k in r.keys() if k != "zpl"})
    return {"ok": True, "version": VERSION, "counts": counts(con), "jobs": jobs}

def clear():
    con = connect()
    with con:
        con.execute("DELETE FROM jobs")
    return {"ok": True, "cleared": True}

def printer_cmd(zpl):
    tmp = tempfile.NamedTemporaryFile("w", delete=False, suffix=".zpl")
    try:
        tmp.write(zpl)
        tmp.close()
        p = subprocess.run(["/usr/bin/lp", "-o", "raw", tmp.name], capture_output=True, text=True, timeout=20)
        if p.returncode != 0:
            return False, (p.stderr or p.stdout or "lp failed").strip()
        return True, (p.stdout or "printed").strip()
    except Exception as e:
        return False, str(e)
    finally:
        try:
            os.unlink(tmp.name)
        except Exception:
            pass

def print_next():
    con = connect()
    r = con.execute("SELECT * FROM jobs WHERE status='queued' ORDER BY position, id LIMIT 1").fetchone()
    if not r:
        return {"ok": True, "printed": 0, "message": "queue empty"}
    ok, msg = printer_cmd(r["zpl"])
    with con:
        if ok:
            con.execute("UPDATE jobs SET status='printed', printed=?, last_error=NULL WHERE id=?", (time.time(), r["id"]))
            return {"ok": True, "printed": 1, "id": r["id"], "barcode": r["barcode"], "message": msg}
        con.execute("UPDATE jobs SET status='error', last_error=? WHERE id=?", (msg, r["id"]))
        return {"ok": False, "printed": 0, "id": r["id"], "barcode": r["barcode"], "error": msg}

def print_all():
    printed = 0
    errors = []
    while True:
        con = connect()
        remaining = con.execute("SELECT COUNT(*) c FROM jobs WHERE status='queued'").fetchone()["c"]
        if remaining <= 0:
            break
        res = print_next()
        if res.get("printed"):
            printed += 1
        else:
            errors.append(res)
            break
    return {"ok": len(errors) == 0, "printed": printed, "errors": errors, "state": state(20)}

def save_upload_bytes(filename, data):
    filename = Path(filename or "upload.csv").name
    upload_dir = gx_home() / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)
    dest = upload_dir / f"{int(time.time())}-{filename}"
    dest.write_bytes(data)
    return enqueue_file(dest)

def parse_multipart_file(headers, rfile):
    ctype = headers.get("Content-Type", "")
    m = re.search(r'boundary=(?:"([^"]+)"|([^;]+))', ctype)
    if not m:
        raise ValueError("missing multipart boundary")
    boundary = (m.group(1) or m.group(2) or "").strip().encode("utf-8")
    if not boundary:
        raise ValueError("empty multipart boundary")

    length = int(headers.get("Content-Length", "0") or "0")
    if length <= 0:
        raise ValueError("empty upload")

    body = rfile.read(length)
    delimiter = b"--" + boundary
    close_delimiter = delimiter + b"--"

    pos = 0
    while True:
        start = body.find(delimiter, pos)
        if start < 0:
            break

        part_start = start + len(delimiter)

        if body[part_start:part_start + 2] == b"--":
            break

        if body[part_start:part_start + 2] == b"\r\n":
            part_start += 2
        elif body[part_start:part_start + 1] == b"\n":
            part_start += 1

        header_end = body.find(b"\r\n\r\n", part_start)
        sep_len = 4
        if header_end < 0:
            header_end = body.find(b"\n\n", part_start)
            sep_len = 2
        if header_end < 0:
            pos = part_start
            continue

        header_bytes = body[part_start:header_end]
        header_text = header_bytes.decode("utf-8", errors="replace")
        data_start = header_end + sep_len

        next_marker = body.find(b"\r\n" + delimiter, data_start)
        marker_prefix_len = 2
        if next_marker < 0:
            next_marker = body.find(b"\n" + delimiter, data_start)
            marker_prefix_len = 1
        if next_marker < 0:
            next_marker = body.find(close_delimiter, data_start)
            marker_prefix_len = 0
        if next_marker < 0:
            raise ValueError("multipart closing boundary not found")

        data_end = next_marker
        data = body[data_start:data_end]

        if "Content-Disposition" in header_text and 'name="file"' in header_text:
            fm = re.search(r'filename="([^"]*)"', header_text)
            filename = Path(fm.group(1) if fm else "upload.csv").name or "upload.csv"
            if not data:
                raise ValueError("uploaded file is empty")
            return filename, data

        pos = next_marker + marker_prefix_len + len(delimiter)

    raise ValueError("missing file field")

def json_bytes(obj):
    return json.dumps(obj, indent=2, ensure_ascii=False).encode("utf-8")

def read_config() -> dict[str, Any]:
    try:
        payload = json.loads(CONFIG.read_text())
        return payload if isinstance(payload, dict) else {}
    except Exception:
        return {}


def write_config(config: dict[str, Any]) -> None:
    CONFIG.parent.mkdir(parents=True, exist_ok=True)

    temporary = CONFIG.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(config, indent=2, ensure_ascii=False) + "\n"
    )
    temporary.chmod(0o600)
    temporary.replace(CONFIG)


def generate_pairing_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def ensure_config() -> dict[str, Any]:
    config = read_config()
    changed = False

    host_name = (
        os.environ.get("GX430T_HOST_NAME", "").strip()
        or os.uname().nodename
        or "GX430T Host"
    )

    defaults: dict[str, Any] = {
        "schema": "gx430t.print_host_config.v1",
        "hostName": host_name,
        "port": PORT,
        "protocol": PROTOCOL_VERSION,
        "pairingEnabled": True,
    }

    for key, value in defaults.items():
        if config.get(key) != value:
            config[key] = value
            changed = True

    token = str(config.get("token", ""))

    if len(token) != 64:
        config["token"] = secrets.token_hex(32)
        changed = True

    pairing_code = str(config.get("pairingCode", ""))

    if len(pairing_code) != 6 or not pairing_code.isdigit():
        config["pairingCode"] = generate_pairing_code()
        changed = True

    if changed or not CONFIG.exists():
        write_config(config)

    return config


def run_cli(
    arguments: list[str],
    timeout: int = 30,
) -> tuple[int, str]:
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
        handle.write(
            json.dumps(
                record,
                separators=(",", ":"),
                ensure_ascii=False,
            )
            + "\n"
        )


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


def job_summary(
    records: list[dict[str, Any]],
) -> dict[str, Any]:
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

    return {
        "totalJobs": len(print_jobs),
        "successfulJobs": successful,
        "failedJobs": failed,
        "totalCopies": copies,
        "latestJob": print_jobs[0] if print_jobs else None,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "GX430THost/1.0"

    def log_message(
        self,
        format: str,
        *args: Any,
    ) -> None:
        sys.stderr.write(
            "GX430T "
            + (format % args)
            + "\n"
        )

    def send_json(
        self,
        status: int,
        payload: dict[str, Any],
    ) -> None:
        body = json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ).encode("utf-8")

        self.send_response(status)
        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )
        self.send_header(
            "Content-Length",
            str(len(body)),
        )
        self.send_header(
            "Cache-Control",
            "no-store",
        )
        self.end_headers()
        self.wfile.write(body)

    def send_html(
        self,
        status: int,
        body: str,
    ) -> None:
        data = body.encode("utf-8")

        self.send_response(status)
        self.send_header(
            "Content-Type",
            "text/html; charset=utf-8",
        )
        self.send_header(
            "Content-Length",
            str(len(data)),
        )
        self.send_header(
            "Cache-Control",
            "no-store",
        )
        self.end_headers()
        self.wfile.write(data)

    def authenticated(self) -> bool:
        config = read_config()
        expected = str(config.get("token", ""))
        supplied = self.headers.get("Authorization", "")

        if supplied.startswith("Bearer "):
            supplied = supplied[7:]

        return (
            bool(expected)
            and secrets.compare_digest(supplied, expected)
        )

    def require_authentication(self) -> bool:
        if self.authenticated():
            return True

        self.send_json(
            401,
            {
                "error": "unauthorized",
                "protocol": PROTOCOL_VERSION,
            },
        )
        return False

    def read_body(
        self,
        maximum: int = MAX_JSON_BODY,
    ) -> dict[str, Any]:
        length = int(
            self.headers.get("Content-Length", "0")
        )

        if length < 1 or length > maximum:
            raise ValueError("invalid content length")

        raw = self.rfile.read(length)
        payload = json.loads(raw.decode("utf-8"))

        if not isinstance(payload, dict):
            raise ValueError("JSON object required")

        return payload

    def request_path(self) -> str:
        return urllib.parse.urlparse(self.path).path

    def do_GET(self) -> None:
        path = self.request_path()

        if path in {"/v1/health", "/api/health"}:
            self.send_json(
                200,
                {
                    "service": "GX430T Print Host",
                    "protocol": PROTOCOL_VERSION,
                    "status": "ok",
                    "version": VERSION,
                    "formats": [
                        "csv",
                        "tsv",
                        "xlsx",
                        "ods",
                    ],
                    "headerless": True,
                },
            )
            return

        if path == "/v1/info":
            config = ensure_config()

            self.send_json(
                200,
                {
                    "service": "GX430T Print Host",
                    "protocol": PROTOCOL_VERSION,
                    "hostName": config.get(
                        "hostName",
                        "GX430T Host",
                    ),
                    "port": PORT,
                    "authentication":
                        "pairing-code-and-bearer-token",
                    "pairingEnabled": bool(
                        config.get(
                            "pairingEnabled",
                            False,
                        )
                    ),
                    "queueFormats": [
                        "csv",
                        "tsv",
                        "xlsx",
                        "ods",
                    ],
                },
            )
            return

        if path == "/v1/status":
            code, output = run_cli(["status"])

            self.send_json(
                200 if code == 0 else 503,
                {
                    "service": "GX430T Print Host",
                    "protocol": PROTOCOL_VERSION,
                    "printerOnline": code == 0,
                    "statusOutput": output,
                },
            )
            return

        if path.startswith("/v1/jobs"):
            if not self.require_authentication():
                return

            query = urllib.parse.parse_qs(
                urllib.parse.urlparse(
                    self.path
                ).query
            )

            try:
                limit = int(
                    query.get("limit", ["100"])[0]
                )
            except ValueError:
                limit = 100

            records = read_jobs(limit)

            if path == "/v1/jobs/summary":
                self.send_json(
                    200,
                    {
                        "service":
                            "GX430T Print Host",
                        "protocol":
                            PROTOCOL_VERSION,
                        "summary":
                            job_summary(records),
                    },
                )
                return

            self.send_json(
                200,
                {
                    "service": "GX430T Print Host",
                    "protocol": PROTOCOL_VERSION,
                    "jobs": records,
                },
            )
            return

        if path == "/api/state":
            if not self.require_authentication():
                return

            self.send_json(
                200,
                state(),
            )
            return

        if path == "/":
            self.send_html(
                200,
                """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>GX430T Print Host</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#111;color:#eee;padding:32px">
<h1>GX430T Print Host</h1>
<p>The native Mac application, menu bar, and paired iPhone application are the product control surfaces.</p>
<p>Secure print and queue transport is active on protocol 1.</p>
<p>Queue formats: CSV, TSV, XLSX, and ODS.</p>
</body>
</html>""",
            )
            return

        self.send_json(
            404,
            {"error": "not_found"},
        )

    def do_POST(self) -> None:
        path = self.request_path()

        if path == "/v1/pair":
            try:
                payload = self.read_body()

                supplied_code = str(
                    payload.get(
                        "pairingCode",
                        "",
                    )
                ).strip()

                client_name = str(
                    payload.get(
                        "clientName",
                        "GX430T Client",
                    )
                ).strip()[:120]

                config = ensure_config()
                expected_code = str(
                    config.get(
                        "pairingCode",
                        "",
                    )
                )

                pairing_enabled = bool(
                    config.get(
                        "pairingEnabled",
                        False,
                    )
                )

                if (
                    not pairing_enabled
                    or not expected_code
                ):
                    self.send_json(
                        403,
                        {"error": "pairing_disabled"},
                    )
                    return

                if not secrets.compare_digest(
                    supplied_code,
                    expected_code,
                ):
                    time.sleep(0.35)

                    self.send_json(
                        401,
                        {
                            "error":
                                "invalid_pairing_code"
                        },
                    )
                    return

                token = str(
                    config.get("token", "")
                )

                if not token:
                    self.send_json(
                        503,
                        {
                            "error":
                                "host_token_unavailable"
                        },
                    )
                    return

                config["pairingCode"] = (
                    generate_pairing_code()
                )
                config["pairingEnabled"] = True
                config["lastPairedClient"] = (
                    client_name
                )
                config["lastPairedAddress"] = (
                    self.client_address[0]
                )
                config["lastPairedTimestamp"] = int(
                    time.time()
                )

                write_config(config)

                append_job(
                    {
                        "event":
                            "client_paired",
                        "clientName":
                            client_name,
                        "remoteAddress":
                            self.client_address[0],
                        "timestamp":
                            int(time.time()),
                    }
                )

                self.send_json(
                    200,
                    {
                        "paired": True,
                        "protocol":
                            PROTOCOL_VERSION,
                        "hostName":
                            config.get(
                                "hostName",
                                "GX430T Host",
                            ),
                        "token": token,
                    },
                )
                return
            except (
                ValueError,
                TypeError,
                json.JSONDecodeError,
            ) as exc:
                self.send_json(
                    400,
                    {
                        "error":
                            "invalid_request",
                        "detail":
                            str(exc),
                    },
                )
                return
            except Exception as exc:
                self.send_json(
                    500,
                    {
                        "error":
                            "internal_error",
                        "detail":
                            str(exc),
                    },
                )
                return

        if path == "/v1/print":
            if not self.require_authentication():
                return

            try:
                payload = self.read_body()

                kind = str(
                    payload.get("kind", "")
                ).lower()

                value = str(
                    payload.get("value", "")
                ).strip()

                copies = int(
                    payload.get("copies", 1)
                )

                allowed_kinds = {
                    "text": "print-text",
                    "code128":
                        "print-code128",
                    "code39":
                        "print-code39",
                    "qr": "print-qr",
                }

                if kind not in allowed_kinds:
                    raise ValueError(
                        "unsupported print kind"
                    )

                if not value:
                    raise ValueError(
                        "value is required"
                    )

                if len(value) > 4096:
                    raise ValueError(
                        "value is too long"
                    )

                if copies < 1 or copies > 999:
                    raise ValueError(
                        "copies must be between 1 and 999"
                    )

                job_id = str(uuid.uuid4())
                started = time.time()

                payload_hash = hashlib.sha256(
                    (
                        f"{kind}\0"
                        f"{value}\0"
                        f"{copies}"
                    ).encode("utf-8")
                ).hexdigest()

                code, output = run_cli(
                    [
                        allowed_kinds[kind],
                        value,
                        str(copies),
                    ],
                    timeout=60,
                )

                record = {
                    "jobId": job_id,
                    "kind": kind,
                    "copies": copies,
                    "payloadHash":
                        payload_hash,
                    "accepted": code == 0,
                    "success": code == 0,
                    "deliveryState": (
                        "SUBMITTED_TO_CUPS"
                        if code == 0
                        else "SUBMISSION_FAILED"
                    ),
                    "physicalDeliveryVerified":
                        False,
                    "result": output,
                    "durationMs": int(
                        (
                            time.time()
                            - started
                        )
                        * 1000
                    ),
                    "timestamp":
                        int(time.time()),
                    "remoteAddress":
                        self.client_address[0],
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
                return
            except (
                ValueError,
                TypeError,
                json.JSONDecodeError,
            ) as exc:
                self.send_json(
                    400,
                    {
                        "error":
                            "invalid_request",
                        "detail":
                            str(exc),
                    },
                )
                return
            except Exception as exc:
                self.send_json(
                    500,
                    {
                        "error":
                            "internal_error",
                        "detail":
                            str(exc),
                    },
                )
                return

        if path.startswith("/api/"):
            if not self.require_authentication():
                return

            if path == "/api/upload":
                try:
                    length = int(
                        self.headers.get(
                            "Content-Length",
                            "0",
                        )
                    )

                    if (
                        length < 1
                        or length > MAX_UPLOAD_BODY
                    ):
                        raise ValueError(
                            "invalid upload length"
                        )

                    filename, data = (
                        parse_multipart_file(
                            self.headers,
                            self.rfile,
                        )
                    )

                    self.send_json(
                        200,
                        save_upload_bytes(
                            filename,
                            data,
                        ),
                    )
                except Exception as exc:
                    self.send_json(
                        400,
                        {
                            "ok": False,
                            "error": str(exc),
                            "type":
                                exc.__class__.__name__,
                        },
                    )
                return

            if path == "/api/print-next":
                self.send_json(
                    200,
                    print_next(),
                )
                return

            if path == "/api/print-all":
                self.send_json(
                    200,
                    print_all(),
                )
                return

            if path == "/api/clear":
                self.send_json(
                    200,
                    clear(),
                )
                return

        self.send_json(
            404,
            {"error": "not_found"},
        )


def main() -> int:
    global HOST
    global PORT

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(
        dest="cmd"
    )

    serve_parser = subparsers.add_parser(
        "serve"
    )
    serve_parser.add_argument(
        "--port",
        type=int,
        default=PORT,
    )
    serve_parser.add_argument(
        "--bind",
        default=HOST,
    )
    serve_parser.add_argument(
        "--open",
        action="store_true",
    )

    subparsers.add_parser("init-config")

    upload_parser = subparsers.add_parser(
        "upload"
    )
    upload_parser.add_argument("file")

    subparsers.add_parser("status")
    subparsers.add_parser("print-next")
    subparsers.add_parser("print-all")
    subparsers.add_parser("clear")

    args = parser.parse_args()

    if args.cmd == "serve":
        HOST = args.bind
        PORT = args.port

        config = ensure_config()

        if not Path(CLI).is_file():
            print(
                "GX430T_HOST_CLI_NOT_FOUND=true",
                file=sys.stderr,
            )
            return 70

        if not config.get("token"):
            print(
                "GX430T_HOST_TOKEN_NOT_CONFIGURED=true",
                file=sys.stderr,
            )
            return 78

        server = ThreadingHTTPServer(
            (HOST, PORT),
            Handler,
        )

        if args.open:
            webbrowser.open(
                f"http://127.0.0.1:{PORT}"
            )

        print(
            json.dumps(
                {
                    "service":
                        "GX430T Print Host",
                    "protocol":
                        PROTOCOL_VERSION,
                    "version":
                        VERSION,
                    "url":
                        f"http://127.0.0.1:{PORT}",
                    "securePrint":
                        True,
                    "secureQueue":
                        True,
                }
            ),
            flush=True,
        )

        server.serve_forever()
        return 0

    if args.cmd == "init-config":
        config = ensure_config()

        print(
            json.dumps(
                {
                    "hostName":
                        config.get(
                            "hostName",
                            "GX430T Host",
                        ),
                    "port":
                        config.get(
                            "port",
                            PORT,
                        ),
                    "protocol":
                        config.get(
                            "protocol",
                            PROTOCOL_VERSION,
                        ),
                    "pairingCode":
                        config.get(
                            "pairingCode",
                            "",
                        ),
                    "pairingEnabled":
                        bool(
                            config.get(
                                "pairingEnabled",
                                False,
                            )
                        ),
                    "tokenConfigured":
                        len(
                            str(
                                config.get(
                                    "token",
                                    "",
                                )
                            )
                        )
                        == 64,
                },
                indent=2,
            )
        )
        return 0

    if args.cmd == "upload":
        print(
            json.dumps(
                enqueue_file(args.file),
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0

    if args.cmd == "status":
        print(
            json.dumps(
                state(),
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0

    if args.cmd == "print-next":
        print(
            json.dumps(
                print_next(),
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0

    if args.cmd == "print-all":
        print(
            json.dumps(
                print_all(),
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0

    if args.cmd == "clear":
        print(
            json.dumps(
                clear(),
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0

    parser.print_help()
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
