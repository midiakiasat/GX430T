#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import html
import io
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.parse
import uuid
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from xml.etree import ElementTree as ET

VERSION = "0.3.0"
DEFAULT_PORT = int(os.environ.get("GX430T_PORT", "9430"))
BASE = Path(os.environ.get("GX430T_HOME", str(Path.home() / ".gx430t"))).expanduser()
DB = BASE / "queue.sqlite3"
UPLOADS = BASE / "uploads"
NS = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

BARCODE_KEYS = [
    "barcode", "bar code", "codice", "codice a barre", "ean", "ean13",
    "code128", "sku", "style", "style code", "article", "articolo",
    "item", "item code", "product code", "codice articolo"
]
TITLE_KEYS = ["title", "name", "nome", "product name", "descrizione", "description", "brand", "marchio"]
QTY_KEYS = ["qty", "quantity", "qta", "quantita", "quantità", "copies", "copie"]
ORDER_KEYS = ["order", "ordine", "row", "riga", "sequence", "seq", "priority"]

def ensure() -> None:
    BASE.mkdir(parents=True, exist_ok=True)
    UPLOADS.mkdir(parents=True, exist_ok=True)

def db() -> sqlite3.Connection:
    ensure()
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS jobs (
          id TEXT PRIMARY KEY,
          created INTEGER,
          position INTEGER,
          source_file TEXT,
          source_row INTEGER,
          barcode TEXT,
          title TEXT,
          status TEXT,
          printed INTEGER,
          last_error TEXT,
          zpl TEXT
        )
        """
    )
    c.commit()
    return c

def key(s: object) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(s or "").strip().lower()).strip()

def choose(headers, candidates):
    by_key = {key(h): h for h in headers}
    for c in candidates:
        if key(c) in by_key:
            return by_key[key(c)]
    for h in headers:
        hk = key(h)
        for c in candidates:
            ck = key(c)
            if ck and (ck in hk or hk in ck):
                return h
    return None

def to_qty(v: object) -> int:
    try:
        return max(1, min(999, int(float(str(v).replace(",", ".").strip()))))
    except Exception:
        return 1

def make_zpl(barcode: str, title: str = "") -> str:
    b = str(barcode or "").replace("^", " ").replace("~", " ").replace("\\", "/").strip()
    t = str(title or "GX430T LABEL").replace("^", " ").replace("~", " ").replace("\\", "/").strip()[:44]
    return (
        "^XA\n"
        "^CI28\n"
        "^PW609\n"
        "^LL203\n"
        f"^FO30,18^A0N,28,28^FD{t}^FS\n"
        f"^FO30,58^BY2,2.6,82^BCN,82,Y,N,N^FD{b}^FS\n"
        f"^FO30,168^A0N,22,22^FD{b}^FS\n"
        "^XZ\n"
    )

def normalize(rows, source_file: str):
    if not rows:
        return []
    headers = list(rows[0].keys())
    barcode_key = choose(headers, BARCODE_KEYS)
    title_key = choose(headers, TITLE_KEYS)
    qty_key = choose(headers, QTY_KEYS)
    order_key = choose(headers, ORDER_KEYS)

    if not barcode_key:
        for h in headers:
            if any(str(r.get(h, "")).strip() for r in rows):
                barcode_key = h
                break

    output = []
    for row_index, row in enumerate(rows, 1):
        code = str(row.get(barcode_key or "", "")).strip()
        if not code:
            continue

        q = to_qty(row.get(qty_key, "1")) if qty_key else 1

        try:
            order = int(float(str(row.get(order_key, row_index)).replace(",", ".").strip())) if order_key else row_index
        except Exception:
            order = row_index

        title = str(row.get(title_key or "", "")).strip() if title_key else ""

        for _ in range(q):
            output.append({
                "order": order,
                "source_row": row_index,
                "barcode": code,
                "title": title,
                "source_file": source_file,
            })

    output.sort(key=lambda r: (r["order"], r["source_row"], r["barcode"]))
    return output

def parse_csv(data: bytes, name: str):
    text = data.decode("utf-8-sig", errors="replace")
    try:
        dialect = csv.Sniffer().sniff(text[:4096], delimiters=",;\t|")
    except Exception:
        dialect = csv.excel
    reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    rows = []
    for r in reader:
        rows.append({str(k or "").strip(): str(v or "").strip() for k, v in r.items()})
    return normalize(rows, name)

def xlsx_cell(c, shared):
    v = c.find("a:v", NS)
    if v is None:
        t = c.find("a:is/a:t", NS)
        return t.text if t is not None and t.text else ""
    raw = v.text or ""
    if c.attrib.get("t") == "s":
        try:
            return shared[int(raw)]
        except Exception:
            return raw
    return raw

def parse_xlsx(data: bytes, name: str):
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            root = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in root.findall("a:si", NS):
                shared.append("".join((t.text or "") for t in si.findall(".//a:t", NS)))

        sheets = sorted(n for n in z.namelist() if n.startswith("xl/worksheets/sheet") and n.endswith(".xml"))
        if not sheets:
            return []

        root = ET.fromstring(z.read(sheets[0]))
        table = []
        for row in root.findall(".//a:sheetData/a:row", NS):
            values = []
            for c in row.findall("a:c", NS):
                ref = c.attrib.get("r", "")
                letters = "".join(ch for ch in ref if ch.isalpha())
                col = 0
                for ch in letters:
                    col = col * 26 + ord(ch.upper()) - 64
                while len(values) < max(col - 1, 0):
                    values.append("")
                values.append(xlsx_cell(c, shared))
            table.append(values)

    table = [r for r in table if any(str(x).strip() for x in r)]
    if not table:
        return []

    headers = [str(x).strip() or f"Column {i+1}" for i, x in enumerate(table[0])]
    rows = []
    for r in table[1:]:
        rows.append({h: (str(r[i]).strip() if i < len(r) else "") for i, h in enumerate(headers)})
    return normalize(rows, name)

def parse_file(data: bytes, name: str):
    if name.lower().endswith(".xlsx") or data[:2] == b"PK":
        return parse_xlsx(data, name)
    return parse_csv(data, name)

def next_position(c):
    row = c.execute("SELECT COALESCE(MAX(position), 0) + 1 AS p FROM jobs").fetchone()
    return int(row["p"])

def enqueue(rows):
    c = db()
    pos = next_position(c)
    added = 0
    for r in rows:
        c.execute(
            "INSERT INTO jobs VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (
                uuid.uuid4().hex,
                int(time.time()),
                pos,
                r["source_file"],
                r["source_row"],
                r["barcode"],
                r["title"],
                "queued",
                0,
                "",
                make_zpl(r["barcode"], r["title"]),
            ),
        )
        pos += 1
        added += 1
    c.commit()
    c.close()
    return added

def all_jobs(status=None, limit=1000):
    c = db()
    if status:
        rows = c.execute("SELECT * FROM jobs WHERE status=? ORDER BY position LIMIT ?", (status, limit)).fetchall()
    else:
        rows = c.execute("SELECT * FROM jobs ORDER BY position LIMIT ?", (limit,)).fetchall()
    c.close()
    return [dict(r) for r in rows]

def counts():
    c = db()
    out = {}
    for s in ("queued", "printed", "failed"):
        out[s] = int(c.execute("SELECT COUNT(*) AS c FROM jobs WHERE status=?", (s,)).fetchone()["c"])
    out["total"] = int(c.execute("SELECT COUNT(*) AS c FROM jobs").fetchone()["c"])
    c.close()
    return out

def printer_name():
    env = os.environ.get("GX430T_PRINTER", "").strip()
    if env:
        return env
    try:
        out = subprocess.check_output(["lpstat", "-p"], text=True, stderr=subprocess.DEVNULL)
        names = [line.split()[1] for line in out.splitlines() if line.startswith("printer ") and len(line.split()) > 1]
        for n in names:
            if "GX430" in n.upper() or "ZEBRA" in n.upper():
                return n
        return names[0] if names else "GX430T"
    except Exception:
        return "GX430T"

def send_to_printer(row):
    ensure()
    zpl_path = BASE / "last-label.zpl"
    zpl_path.write_text(row["zpl"])
    pr = printer_name()
    last_error = "no lp/lpr command found"
    for cmd in (["lp", "-d", pr, "-o", "raw", str(zpl_path)], ["lpr", "-P", pr, "-l", str(zpl_path)]):
        if shutil.which(cmd[0]):
            try:
                subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
                return True, "sent"
            except Exception as e:
                last_error = repr(e)
    return False, last_error

def print_ids(ids):
    c = db()
    ok = 0
    failed = 0
    for jid in ids:
        row = c.execute("SELECT * FROM jobs WHERE id=?", (jid,)).fetchone()
        if not row:
            continue
        good, msg = send_to_printer(dict(row))
        if good:
            c.execute("UPDATE jobs SET status='printed', printed=?, last_error='' WHERE id=?", (int(time.time()), jid))
            ok += 1
        else:
            c.execute("UPDATE jobs SET status='failed', last_error=? WHERE id=?", (msg, jid))
            failed += 1
    c.commit()
    c.close()
    return {"ok": ok, "failed": failed}

PAGE = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>GX430T Upload Queue</title>
<style>
body{margin:0;background:#111;color:#f6f6f6;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Arial;padding:24px}
h1{font-size:42px;margin:0 0 18px}.grid{display:grid;grid-template-columns:360px 1fr;gap:18px}
.card{background:#181818;border:1px solid #333;border-radius:22px;padding:18px}
button,input{border:0;border-radius:12px;padding:12px;font-weight:800}button{background:#fff;color:#000}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:16px}
.kpis div{background:#181818;border:1px solid #333;border-radius:18px;padding:14px;text-transform:uppercase;letter-spacing:.12em;color:#aaa}
.kpis b{display:block;color:#fff;font-size:34px;letter-spacing:0}
table{width:100%;border-collapse:collapse}td,th{border-bottom:1px solid #333;padding:10px;text-align:left}th{color:#aaa;letter-spacing:.12em}
small{color:#aaa}
</style>
</head>
<body>
<h1>GX430T Upload Queue</h1>
<div class="grid">
  <div class="card">
    <h2>Upload Excel / CSV</h2>
    <form id="f"><input type="file" name="file" accept=".csv,.xlsx" required><p><button>UPLOAD TO QUEUE</button></p></form>
    <small>Secondary batch tool. Native GX430T app remains primary.</small>
    <h2>Print</h2>
    <p><button onclick="printNext()">Print next</button> <button onclick="printAll()">Print all</button></p>
    <p><button onclick="clearQ()">Clear queued</button></p>
  </div>
  <main>
    <div class="kpis">
      <div>Queued<b id="q">0</b></div><div>Printed<b id="p">0</b></div><div>Failed<b id="fa">0</b></div><div>Total<b id="t">0</b></div>
    </div>
    <div class="card">
      <table><thead><tr><th>#</th><th>Status</th><th>Barcode</th><th>Title</th><th>Source</th></tr></thead><tbody id="rows"></tbody></table>
    </div>
  </main>
</div>
<script>
async function api(u,o){let r=await fetch(u,o||{}); if(!r.ok) throw Error(await r.text()); return r.json()}
async function load(){let s=await api('/api/state'); q.textContent=s.counts.queued;p.textContent=s.counts.printed;fa.textContent=s.counts.failed;t.textContent=s.counts.total;rows.innerHTML=s.jobs.map(j=>`<tr><td>${j.position}</td><td>${j.status}</td><td><b>${escapeHtml(j.barcode)}</b></td><td>${escapeHtml(j.title||'')}</td><td>${escapeHtml(j.source_file||'')} #${j.source_row||''}</td></tr>`).join('')}
function escapeHtml(s){return String(s).replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
f.onsubmit=async e=>{e.preventDefault(); await fetch('/api/upload',{method:'POST',body:new FormData(f)}); f.reset(); load()}
async function printNext(){await api('/api/print-next',{method:'POST'});load()}
async function printAll(){await api('/api/print-all',{method:'POST'});load()}
async function clearQ(){await api('/api/clear',{method:'POST'});load()}
load(); setInterval(load,3000)
</script>
</body>
</html>"""

def multipart(ctype, data):
    m = re.search(r"boundary=(.+)", ctype or "")
    if not m:
        return "upload.csv", data
    boundary = ("--" + m.group(1).strip().strip('"')).encode()
    for part in data.split(boundary):
        if b"Content-Disposition" not in part:
            continue
        head, _, body = part.partition(b"\r\n\r\n")
        disp = head.decode(errors="replace")
        fn = re.search(r'filename="([^"]+)"', disp)
        name = fn.group(1) if fn else "upload.csv"
        return name, body.rstrip(b"\r\n-")
    return "upload.csv", data

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def send_json(self, obj, code=200):
        data = json.dumps(obj, ensure_ascii=False, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_body(self):
        return self.rfile.read(int(self.headers.get("Content-Length", "0") or "0"))

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            data = PAGE.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif path == "/api/health":
            self.send_json({"ok": True, "version": VERSION, "printer": printer_name()})
        elif path == "/api/state":
            self.send_json({"version": VERSION, "printer": printer_name(), "counts": counts(), "jobs": all_jobs()})
        else:
            self.send_error(404)

    def do_POST(self):
        try:
            path = urllib.parse.urlparse(self.path).path
            if path == "/api/upload":
                name, data = multipart(self.headers.get("Content-Type", ""), self.read_body())
                safe_name = Path(name).name or "upload.csv"
                saved = UPLOADS / (time.strftime("%Y%m%d-%H%M%S") + "-" + safe_name)
                ensure()
                saved.write_bytes(data)
                rows = parse_file(data, safe_name)
                labels = enqueue(rows)
                self.send_json({"ok": True, "rows": len(rows), "labels": labels})
                return

            if path == "/api/print-next":
                queued = all_jobs("queued", 1)
                self.send_json(print_ids([queued[0]["id"]]) if queued else {"ok": 0, "failed": 0})
                return

            if path == "/api/print-all":
                queued = all_jobs("queued", 5000)
                self.send_json(print_ids([x["id"] for x in queued]))
                return

            if path == "/api/clear":
                c = db()
                cur = c.execute("DELETE FROM jobs WHERE status='queued'")
                c.commit()
                deleted = cur.rowcount
                c.close()
                self.send_json({"deleted": deleted})
                return

            self.send_error(404)
        except Exception as e:
            self.send_json({"ok": False, "error": repr(e)}, 500)

def serve(port: int, open_ui: bool = False):
    ensure()
    db().close()
    print("GX430T_UPLOAD_QUEUE_READY=true", flush=True)
    print("VERSION=" + VERSION, flush=True)
    print(f"URL=http://127.0.0.1:{port}", flush=True)
    if open_ui:
        subprocess.Popen(["open", f"http://127.0.0.1:{port}"])
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()

def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd")
    sv = sub.add_parser("serve")
    sv.add_argument("--port", type=int, default=DEFAULT_PORT)
    sv.add_argument("--open", action="store_true")
    up = sub.add_parser("upload")
    up.add_argument("file")
    sub.add_parser("status")
    sub.add_parser("print-next")
    sub.add_parser("print-all")
    sub.add_parser("clear")
    args = ap.parse_args(argv)

    if args.cmd in (None, "serve"):
        serve(args.port if args.cmd else DEFAULT_PORT, getattr(args, "open", False))
        return 0

    if args.cmd == "upload":
        p = Path(args.file)
        rows = parse_file(p.read_bytes(), p.name)
        print(json.dumps({"rows": len(rows), "labels": enqueue(rows)}, indent=2))
        return 0

    if args.cmd == "status":
        print(json.dumps({"version": VERSION, "counts": counts(), "jobs": all_jobs(limit=50)}, indent=2))
        return 0

    if args.cmd == "print-next":
        queued = all_jobs("queued", 1)
        print(json.dumps(print_ids([queued[0]["id"]]) if queued else {"ok": 0, "failed": 0}, indent=2))
        return 0

    if args.cmd == "print-all":
        queued = all_jobs("queued", 5000)
        print(json.dumps(print_ids([x["id"] for x in queued]), indent=2))
        return 0

    if args.cmd == "clear":
        c = db()
        cur = c.execute("DELETE FROM jobs WHERE status='queued'")
        c.commit()
        print(json.dumps({"deleted": cur.rowcount}, indent=2))
        c.close()
        return 0

    return 2

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
