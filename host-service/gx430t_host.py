#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import html
import io
import json
import os
import plistlib
import re
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.parse
import uuid
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from xml.etree import ElementTree as ET

APP = "GX430T Mac Control"
VERSION = "0.2.9"
DEFAULT_PORT = int(os.environ.get("GX430T_PORT", "9430"))
BASE = Path(os.environ.get("GX430T_HOME", str(Path.home() / ".gx430t"))).expanduser()
DB = BASE / "queue.sqlite3"
UPLOADS = BASE / "uploads"
PRINTED = BASE / "printed"
NS = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

BARCODE_KEYS = [
    "barcode", "bar code", "codice", "codice a barre", "ean", "ean13",
    "code128", "sku", "style", "style code", "article", "articolo",
    "item", "item code", "product", "product code", "codice articolo"
]
TITLE_KEYS = ["title", "name", "nome", "product name", "descrizione", "description", "brand", "marchio"]
QTY_KEYS = ["qty", "quantity", "qta", "q.tà", "quantita", "quantità", "copies", "copie"]
ORDER_KEYS = ["order", "ordine", "row", "riga", "sequence", "seq", "priority"]

def now() -> int:
    return int(time.time())

def ensure_dirs() -> None:
    BASE.mkdir(parents=True, exist_ok=True)
    UPLOADS.mkdir(parents=True, exist_ok=True)
    PRINTED.mkdir(parents=True, exist_ok=True)

def db() -> sqlite3.Connection:
    ensure_dirs()
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    con.execute("""
        create table if not exists jobs (
            id text primary key,
            created integer not null,
            position integer not null,
            source_file text,
            source_row integer,
            barcode text not null,
            title text,
            qty integer not null default 1,
            status text not null default 'queued',
            printed integer not null default 0,
            last_error text,
            zpl text not null
        )
    """)
    con.execute("create index if not exists jobs_status_pos on jobs(status, position)")
    con.commit()
    return con

def clean_key(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(s).strip().lower()).strip()

def best_key(headers: List[str], candidates: List[str]) -> Optional[str]:
    norm = {clean_key(h): h for h in headers}
    for c in candidates:
        if clean_key(c) in norm:
            return norm[clean_key(c)]
    for h in headers:
        hk = clean_key(h)
        for c in candidates:
            ck = clean_key(c)
            if ck and (ck in hk or hk in ck):
                return h
    return None

def safe_qty(v) -> int:
    try:
        q = int(float(str(v).strip().replace(",", ".")))
        return max(1, min(q, 999))
    except Exception:
        return 1

def normalize_rows(rows: List[Dict[str, str]], source_file: str) -> List[Dict[str, object]]:
    if not rows:
        return []
    headers = list(rows[0].keys())
    barcode_key = best_key(headers, BARCODE_KEYS)
    title_key = best_key(headers, TITLE_KEYS)
    qty_key = best_key(headers, QTY_KEYS)
    order_key = best_key(headers, ORDER_KEYS)

    if not barcode_key:
        # fallback: first non-empty column
        for h in headers:
            if any(str(r.get(h, "")).strip() for r in rows):
                barcode_key = h
                break

    out = []
    for idx, r in enumerate(rows, start=1):
        barcode = str(r.get(barcode_key or "", "")).strip()
        if not barcode:
            continue
        title = str(r.get(title_key or "", "")).strip() if title_key else ""
        qty = safe_qty(r.get(qty_key, "1")) if qty_key else 1
        try:
            order = int(float(str(r.get(order_key, idx)).strip().replace(",", "."))) if order_key else idx
        except Exception:
            order = idx
        out.append({
            "source_file": source_file,
            "source_row": idx,
            "order": order,
            "barcode": barcode,
            "title": title,
            "qty": qty,
        })
    out.sort(key=lambda x: (int(x["order"]), int(x["source_row"])))
    return out

def parse_csv_bytes(data: bytes, filename: str) -> List[Dict[str, object]]:
    text = data.decode("utf-8-sig", errors="replace")
    sample = text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t|")
    except Exception:
        dialect = csv.excel
    reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    rows = [{str(k or "").strip(): str(v or "").strip() for k, v in row.items()} for row in reader]
    return normalize_rows(rows, filename)

def xlsx_cell_value(cell, shared: List[str]) -> str:
    t = cell.attrib.get("t")
    v = cell.find("a:v", NS)
    if v is None:
        is_node = cell.find("a:is/a:t", NS)
        return is_node.text if is_node is not None and is_node.text else ""
    raw = v.text or ""
    if t == "s":
        try:
            return shared[int(raw)]
        except Exception:
            return raw
    return raw

def parse_xlsx_bytes(data: bytes, filename: str) -> List[Dict[str, object]]:
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            root = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in root.findall("a:si", NS):
                texts = [t.text or "" for t in si.findall(".//a:t", NS)]
                shared.append("".join(texts))

        sheet_name = "xl/worksheets/sheet1.xml"
        if sheet_name not in z.namelist():
            candidates = [n for n in z.namelist() if n.startswith("xl/worksheets/sheet") and n.endswith(".xml")]
            if not candidates:
                return []
            sheet_name = sorted(candidates)[0]

        root = ET.fromstring(z.read(sheet_name))
        table = []
        for row in root.findall(".//a:sheetData/a:row", NS):
            values = []
            for c in row.findall("a:c", NS):
                ref = c.attrib.get("r", "")
                col_letters = "".join(ch for ch in ref if ch.isalpha())
                col = 0
                for ch in col_letters:
                    col = col * 26 + (ord(ch.upper()) - 64)
                while len(values) < max(col - 1, 0):
                    values.append("")
                values.append(xlsx_cell_value(c, shared))
            table.append(values)

    table = [r for r in table if any(str(x).strip() for x in r)]
    if not table:
        return []
    headers = [str(x).strip() or f"Column {i+1}" for i, x in enumerate(table[0])]
    dicts = []
    for row in table[1:]:
        d = {}
        for i, h in enumerate(headers):
            d[h] = str(row[i]).strip() if i < len(row) else ""
        dicts.append(d)
    return normalize_rows(dicts, filename)

def parse_upload(data: bytes, filename: str) -> List[Dict[str, object]]:
    low = filename.lower()
    if low.endswith(".xlsx"):
        return parse_xlsx_bytes(data, filename)
    if low.endswith(".csv") or low.endswith(".txt"):
        return parse_csv_bytes(data, filename)
    # try xlsx first if it is a zip, otherwise csv
    if data[:2] == b"PK":
        return parse_xlsx_bytes(data, filename)
    return parse_csv_bytes(data, filename)

def zpl_for(barcode: str, title: str = "") -> str:
    b = re.sub(r"[\r\n]+", " ", str(barcode)).strip()
    title = re.sub(r"[\r\n]+", " ", str(title or "")).strip()
    if len(title) > 42:
        title = title[:39] + "..."
    # 3x1 inch-ish direct thermal scanner-safe Code128
    return f"""^XA
^CI28
^PW609
^LL203
^LH0,0
^FO30,18^A0N,28,28^FD{escape_zpl(title or "GX430T LABEL")}^FS
^FO30,58^BY2,2.6,82^BCN,82,Y,N,N^FD{escape_zpl(b)}^FS
^FO30,168^A0N,22,22^FD{escape_zpl(b)}^FS
^XZ
"""

def escape_zpl(s: str) -> str:
    return str(s).replace("^", " ").replace("~", " ").replace("\\", "/")

def next_position(con: sqlite3.Connection) -> int:
    row = con.execute("select coalesce(max(position),0)+1 as p from jobs").fetchone()
    return int(row["p"])

def enqueue(rows: List[Dict[str, object]]) -> int:
    con = db()
    pos = next_position(con)
    count = 0
    for r in rows:
        qty = int(r["qty"])
        for copy_idx in range(qty):
            barcode = str(r["barcode"])
            title = str(r.get("title") or "")
            con.execute("""
                insert into jobs(id, created, position, source_file, source_row, barcode, title, qty, status, printed, last_error, zpl)
                values(?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                uuid.uuid4().hex,
                now(),
                pos,
                str(r.get("source_file") or ""),
                int(r.get("source_row") or 0),
                barcode,
                title,
                1,
                "queued",
                0,
                "",
                zpl_for(barcode, title),
            ))
            pos += 1
            count += 1
    con.commit()
    con.close()
    return count

def list_jobs(status: Optional[str] = None, limit: int = 500) -> List[Dict[str, object]]:
    con = db()
    if status:
        rows = con.execute("select * from jobs where status=? order by position limit ?", (status, limit)).fetchall()
    else:
        rows = con.execute("select * from jobs order by position limit ?", (limit,)).fetchall()
    con.close()
    return [dict(r) for r in rows]

def counts() -> Dict[str, int]:
    con = db()
    out = {}
    for st in ("queued", "printed", "failed"):
        out[st] = int(con.execute("select count(*) c from jobs where status=?", (st,)).fetchone()["c"])
    out["total"] = int(con.execute("select count(*) c from jobs").fetchone()["c"])
    con.close()
    return out

def find_printer() -> str:
    explicit = os.environ.get("GX430T_PRINTER", "").strip()
    if explicit:
        return explicit
    try:
        out = subprocess.check_output(["lpstat", "-p"], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[0] == "printer":
                name = parts[1]
                if "GX430" in name.upper() or "ZEBRA" in name.upper():
                    return name
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[0] == "printer":
                return parts[1]
    except Exception:
        pass
    return "GX430T"

def send_zpl(zpl: str, printer: Optional[str] = None) -> Tuple[bool, str]:
    printer = printer or find_printer()
    spool = BASE / "last-label.zpl"
    spool.write_text(zpl, encoding="utf-8")
    commands = [
        ["lp", "-d", printer, "-o", "raw", str(spool)],
        ["lpr", "-P", printer, "-l", str(spool)],
    ]
    errors = []
    for cmd in commands:
        if shutil.which(cmd[0]):
            try:
                out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
                return True, out.strip() or "sent"
            except subprocess.CalledProcessError as e:
                errors.append(e.output.strip())
            except Exception as e:
                errors.append(repr(e))
    return False, "; ".join(errors) or "No lp/lpr command available"

def print_jobs(ids: List[str]) -> Dict[str, object]:
    con = db()
    ok = 0
    failed = 0
    details = []
    for jid in ids:
        row = con.execute("select * from jobs where id=?", (jid,)).fetchone()
        if not row:
            continue
        success, msg = send_zpl(row["zpl"])
        if success:
            con.execute("update jobs set status='printed', printed=?, last_error='' where id=?", (now(), jid))
            ok += 1
        else:
            con.execute("update jobs set status='failed', last_error=? where id=?", (msg, jid))
            failed += 1
        details.append({"id": jid, "ok": success, "message": msg})
    con.commit()
    con.close()
    return {"ok": ok, "failed": failed, "details": details}

def clear_queue(status: str = "queued") -> int:
    con = db()
    cur = con.execute("delete from jobs where status=?", (status,))
    con.commit()
    n = cur.rowcount
    con.close()
    return n

def reorder(ids: List[str]) -> int:
    con = db()
    pos = 1
    for jid in ids:
        con.execute("update jobs set position=? where id=?", (pos, jid))
        pos += 1
    con.commit()
    con.close()
    return pos - 1

def parse_multipart(content_type: str, data: bytes) -> Tuple[str, bytes]:
    m = re.search(r"boundary=(.+)", content_type)
    if not m:
        return "upload.csv", data
    boundary = ("--" + m.group(1).strip().strip('"')).encode()
    parts = data.split(boundary)
    for part in parts:
        if b"Content-Disposition" not in part:
            continue
        head, _, body = part.partition(b"\r\n\r\n")
        disp = head.decode("utf-8", errors="replace")
        fn = re.search(r'filename="([^"]+)"', disp)
        filename = fn.group(1) if fn else "upload.csv"
        body = body.rstrip(b"\r\n-")
        return filename, body
    return "upload.csv", data

HTML_PAGE = r"""<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>GX430T Upload Queue Print OS</title>
<style>
:root{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Inter,Arial,sans-serif;background:#050505;color:#f7f7f7}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(circle at top left,#1f2937,#050505 44%,#000)}
main{max-width:1600px;margin:0 auto;padding:18px}
header{display:flex;justify-content:space-between;gap:16px;align-items:end;border-bottom:1px solid #303030;padding-bottom:14px}
h1{font-size:42px;margin:0;line-height:.95}
p.kicker{letter-spacing:.22em;text-transform:uppercase;color:#aaa;font-size:12px;margin:0 0 8px}
.badge{background:#111;border:1px solid #333;border-radius:18px;padding:12px;text-align:right}
.badge b{display:block;font-size:24px}
.grid{display:grid;grid-template-columns:380px 1fr;gap:14px;margin-top:14px}
.card{background:#101010;border:1px solid #292929;border-radius:24px;padding:16px}
.upload{border:2px dashed #444;border-radius:22px;padding:22px;text-align:center;background:#0b0b0b}
input,button,select{border:0;border-radius:14px;padding:12px;font-size:15px}
input[type=file]{width:100%;border:1px solid #333;background:#050505;color:#fff}
button{background:#fff;color:#000;font-weight:900;cursor:pointer}
button.dark{background:#171717;color:#fff;border:1px solid #333}
button.red{background:#fee2e2;color:#991b1b}
.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:14px}
.kpis article{background:#111;border:1px solid #292929;border-radius:20px;padding:14px}
.kpis p{letter-spacing:.16em;color:#aaa;font-size:11px;margin:0;text-transform:uppercase}
.kpis b{font-size:34px}
.tableWrap{height:68vh;overflow:auto;border:1px solid #292929;border-radius:22px}
table{width:100%;border-collapse:collapse}
th{position:sticky;top:0;background:#171717;text-align:left;color:#aaa;letter-spacing:.12em;text-transform:uppercase;font-size:11px}
th,td{border-bottom:1px solid #242424;padding:10px;vertical-align:top}
td.code{font-weight:900;font-size:16px}
.status{border-radius:999px;padding:4px 8px;font-size:11px;font-weight:900}
.queued{background:#dbeafe;color:#1e3a8a}.printed{background:#dcfce7;color:#14532d}.failed{background:#fee2e2;color:#991b1b}
.preview{white-space:pre-wrap;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:#050505;border:1px solid #333;border-radius:18px;padding:12px;max-height:240px;overflow:auto}
small{color:#999}
footer{text-align:center;color:#777;margin-top:18px}
@media(max-width:1000px){.grid{grid-template-columns:1fr}.kpis{grid-template-columns:repeat(2,1fr)}header{display:block}.badge{text-align:left;margin-top:12px}}
</style>
</head>
<body>
<main>
<header>
  <div>
    <p class="kicker">GX430T Upload Queue Print OS</p>
    <h1>Excel / CSV → Ordered Print Queue</h1>
  </div>
  <aside class="badge"><b>v0.2.9</b><span id="printer">GX430T</span></aside>
</header>

<section class="grid">
  <aside class="card">
    <h2>1. Upload file</h2>
    <form id="uploadForm" class="upload">
      <input type="file" name="file" accept=".csv,.txt,.xlsx" required />
      <div class="actions"><button>UPLOAD TO QUEUE</button></div>
      <p><small>Accepted headers: barcode, sku, style code, item code, codice, EAN, quantity, qty, description, brand.</small></p>
    </form>

    <h2>2. Print</h2>
    <div class="actions">
      <button id="printNext">Print next</button>
      <button id="printAll">Print all queued</button>
      <button class="dark" id="refresh">Refresh</button>
      <button class="red" id="clear">Clear queued</button>
    </div>

    <h2>Preview</h2>
    <pre class="preview" id="preview">Select a row…</pre>
  </aside>

  <section>
    <div class="kpis">
      <article><p>Queued</p><b id="queued">0</b></article>
      <article><p>Printed</p><b id="printed">0</b></article>
      <article><p>Failed</p><b id="failed">0</b></article>
      <article><p>Total</p><b id="total">0</b></article>
    </div>
    <div class="tableWrap">
      <table>
        <thead><tr><th>#</th><th>Status</th><th>Barcode</th><th>Title</th><th>Source</th><th>Action</th></tr></thead>
        <tbody id="rows"></tbody>
      </table>
    </div>
  </section>
</section>

<footer>Powered by Midia Kiasat · GX430T local print system · All rights reserved</footer>
</main>
<script>
const $ = (id)=>document.getElementById(id);
let jobs = [];

async function api(path, opts={}) {
  const r = await fetch(path, {cache:"no-store", ...opts});
  if (!r.ok) throw new Error(await r.text());
  return await r.json();
}
function render(s) {
  $("queued").textContent=s.counts.queued;
  $("printed").textContent=s.counts.printed;
  $("failed").textContent=s.counts.failed;
  $("total").textContent=s.counts.total;
  $("printer").textContent=s.printer;
  jobs=s.jobs;
  $("rows").innerHTML = jobs.map(j => `
    <tr onclick="preview('${j.id}')">
      <td>${j.position}</td>
      <td><span class="status ${j.status}">${j.status}</span></td>
      <td class="code">${escapeHtml(j.barcode)}</td>
      <td>${escapeHtml(j.title||"")}</td>
      <td><small>${escapeHtml(j.source_file||"")} #${j.source_row||""}</small></td>
      <td><button onclick="event.stopPropagation(); printOne('${j.id}')">Print</button></td>
    </tr>`).join("");
}
function escapeHtml(x){return String(x??"").replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));}
async function load(){render(await api("/api/state"));}
function preview(id){const j=jobs.find(x=>x.id===id); $("preview").textContent=j ? j.zpl : "Select a row…";}
async function printOne(id){await api("/api/print", {method:"POST", body:JSON.stringify({ids:[id]})}); await load();}
$("uploadForm").addEventListener("submit", async e => {
  e.preventDefault();
  const fd = new FormData(e.currentTarget);
  await fetch("/api/upload", {method:"POST", body:fd}).then(async r=>{if(!r.ok) throw new Error(await r.text())});
  e.currentTarget.reset();
  await load();
});
$("printNext").onclick=async()=>{await api("/api/print-next",{method:"POST"}); await load();};
$("printAll").onclick=async()=>{if(confirm("Print all queued labels in order?")){await api("/api/print-all",{method:"POST"}); await load();}};
$("clear").onclick=async()=>{if(confirm("Clear queued labels?")){await api("/api/clear",{method:"POST"}); await load();}};
$("refresh").onclick=load;
load();
setInterval(load, 5000);
</script>
</body>
</html>
"""

class Handler(BaseHTTPRequestHandler):
    server_version = f"GX430THost/{VERSION}"

    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (time.strftime("%H:%M:%S"), fmt % args))

    def send_json(self, obj, status=200):
        data = json.dumps(obj, ensure_ascii=False, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0") or "0")
        return self.rfile.read(length)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            data = HTML_PAGE.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if path == "/api/state":
            self.send_json({"version": VERSION, "printer": find_printer(), "counts": counts(), "jobs": list_jobs(limit=800)})
            return
        if path == "/api/health":
            self.send_json({"ok": True, "version": VERSION, "printer": find_printer(), "base": str(BASE)})
            return
        self.send_error(404)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        try:
            if path == "/api/upload":
                data = self.read_body()
                filename, body = parse_multipart(self.headers.get("Content-Type", ""), data)
                stamp = time.strftime("%Y%m%d-%H%M%S")
                saved = UPLOADS / f"{stamp}-{Path(filename).name}"
                saved.write_bytes(body)
                rows = parse_upload(body, filename)
                n = enqueue(rows)
                self.send_json({"ok": True, "file": filename, "rows": len(rows), "labels": n})
                return
            if path == "/api/print":
                payload = json.loads(self.read_body().decode() or "{}")
                ids = payload.get("ids") or []
                self.send_json(print_jobs(ids))
                return
            if path == "/api/print-next":
                q = list_jobs("queued", limit=1)
                self.send_json(print_jobs([q[0]["id"]]) if q else {"ok": 0, "failed": 0, "details": []})
                return
            if path == "/api/print-all":
                q = list_jobs("queued", limit=5000)
                self.send_json(print_jobs([x["id"] for x in q]))
                return
            if path == "/api/clear":
                self.send_json({"deleted": clear_queue("queued")})
                return
            self.send_error(404)
        except Exception as e:
            self.send_json({"ok": False, "error": repr(e)}, status=500)

def open_browser(port: int):
    url = f"http://127.0.0.1:{port}"
    if sys.platform == "darwin":
        subprocess.Popen(["open", url])
    else:
        print(url)

def run(port: int, open_ui: bool):
    ensure_dirs()
    db().close()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"GX430T_UPLOAD_QUEUE_PRINT_OS_READY=true")
    print(f"VERSION={VERSION}")
    print(f"URL=http://127.0.0.1:{port}")
    print(f"PRINTER={find_printer()}")
    print(f"QUEUE={BASE}")
    if open_ui:
        open_browser(port)
    server.serve_forever()

def cli(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(prog="gx430t_host.py")
    sub = ap.add_subparsers(dest="cmd")
    serve = sub.add_parser("serve")
    serve.add_argument("--port", type=int, default=DEFAULT_PORT)
    serve.add_argument("--open", action="store_true")
    up = sub.add_parser("upload")
    up.add_argument("file")
    st = sub.add_parser("status")
    sub.add_parser("print-next")
    sub.add_parser("print-all")
    sub.add_parser("clear")
    args = ap.parse_args(argv)

    if args.cmd in (None, "serve"):
        run(args.port if args.cmd == "serve" else DEFAULT_PORT, getattr(args, "open", False))
        return 0
    if args.cmd == "upload":
        p = Path(args.file)
        rows = parse_upload(p.read_bytes(), p.name)
        n = enqueue(rows)
        print(json.dumps({"rows": len(rows), "labels": n}, indent=2))
        return 0
    if args.cmd == "status":
        print(json.dumps({"version": VERSION, "printer": find_printer(), "counts": counts(), "jobs": list_jobs(limit=50)}, indent=2))
        return 0
    if args.cmd == "print-next":
        q = list_jobs("queued", limit=1)
        print(json.dumps(print_jobs([q[0]["id"]]) if q else {"ok": 0, "failed": 0}, indent=2))
        return 0
    if args.cmd == "print-all":
        q = list_jobs("queued", limit=5000)
        print(json.dumps(print_jobs([x["id"] for x in q]), indent=2))
        return 0
    if args.cmd == "clear":
        print(json.dumps({"deleted": clear_queue("queued")}, indent=2))
        return 0
    return 2

if __name__ == "__main__":
    raise SystemExit(cli(sys.argv[1:]))
