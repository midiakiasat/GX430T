#!/usr/bin/env python3
import argparse
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
from decimal import Decimal, InvalidOperation

VERSION = "0.3.3"
PORT = int(os.environ.get("GX430T_PORT", "9430"))

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

def connect():
    con = sqlite3.connect(str(db_path()))
    con.row_factory = sqlite3.Row
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
    con.commit()
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

class Handler(BaseHTTPRequestHandler):
    def send_json(self, obj, status=200):
        data = json_bytes(obj)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/health":
            self.send_json({"ok": True, "version": VERSION, "formats": ["csv", "tsv", "xlsx", "ods"], "headerless": True})
            return
        if path == "/api/state":
            self.send_json(state())
            return
        body = f"""<!doctype html><html><head><meta charset="utf-8"><title>GX430T Upload Queue</title></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#111;color:#eee;padding:32px">
<h1>GX430T Upload Queue</h1>
<p>Secondary browser surface. Native Mac app, Mac menu bar, and iPhone are primary surfaces.</p>
<p>Supports CSV, TSV, XLSX, ODS, headerless one-column barcode sheets, quantity expansion, and ordered queue.</p>
<form method="post" action="/api/upload" enctype="multipart/form-data">
<input type="file" name="file" accept=".csv,.tsv,.xlsx,.ods,.txt"/>
<button>Upload</button>
</form>
<p><button onclick="fetch('/api/print-next',{{method:'POST'}}).then(r=>r.text()).then(alert)">Print Next</button>
<button onclick="fetch('/api/print-all',{{method:'POST'}}).then(r=>r.text()).then(alert)">Print All</button>
<button onclick="fetch('/api/clear',{{method:'POST'}}).then(r=>r.text()).then(alert)">Clear</button></p>
<pre id="s"></pre>
<script>async function load(){{s.textContent=await fetch('/api/state').then(r=>r.text())}}; setInterval(load,2000); load();</script>
</body></html>"""
        data = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/upload":
            try:
                filename, data = parse_multipart_file(self.headers, self.rfile)
                self.send_json(save_upload_bytes(filename, data))
            except Exception as e:
                import traceback
                traceback.print_exc()
                self.send_json({"ok": False, "error": str(e), "type": e.__class__.__name__}, 500)
            return
        if path == "/api/print-next":
            self.send_json(print_next())
            return
        if path == "/api/print-all":
            self.send_json(print_all())
            return
        if path == "/api/clear":
            self.send_json(clear())
            return
        self.send_json({"ok": False, "error": "not found"}, 404)

    def log_message(self, fmt, *args):
        sys.stderr.write("GX430T " + (fmt % args) + "\n")

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd")
    s = sub.add_parser("serve")
    s.add_argument("--port", type=int, default=PORT)
    s.add_argument("--open", action="store_true")
    u = sub.add_parser("upload")
    u.add_argument("file")
    sub.add_parser("status")
    sub.add_parser("print-next")
    sub.add_parser("print-all")
    sub.add_parser("clear")
    args = ap.parse_args()

    if args.cmd == "serve":
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
        if args.open:
            webbrowser.open(f"http://127.0.0.1:{args.port}")
        print(json.dumps({"ok": True, "version": VERSION, "url": f"http://127.0.0.1:{args.port}"}), flush=True)
        server.serve_forever()
    elif args.cmd == "upload":
        print(json.dumps(enqueue_file(args.file), indent=2))
    elif args.cmd == "status":
        print(json.dumps(state(), indent=2))
    elif args.cmd == "print-next":
        print(json.dumps(print_next(), indent=2))
    elif args.cmd == "print-all":
        print(json.dumps(print_all(), indent=2))
    elif args.cmd == "clear":
        print(json.dumps(clear(), indent=2))
    else:
        ap.print_help()

if __name__ == "__main__":
    main()
