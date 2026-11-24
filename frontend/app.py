"""TravelX front end. Only needs: pip install pymysql
Run:  set DB_USER/DB_PASSWORD (env) then  python app.py   ->  http://localhost:8000
Pages: / (menu), /hotel and /car (book, shows the trigger error), /views, /queries
Not tested against a live MySQL server by the author of this package. Test it on your machine.
"""
import os, re, html
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import pymysql

CFG = dict(host=os.getenv("DB_HOST", "localhost"), user=os.getenv("DB_USER", "root"),
           password=os.getenv("DB_PASSWORD", ""), database="travelx", autocommit=True)
QUERIES_FILE = os.path.join(os.path.dirname(__file__), "..", "sql", "travelx_queries.sql")
e = html.escape

def db(): return pymysql.connect(**CFG)

def table(cols, rows):
    h = "<table><tr>" + "".join(f"<th>{e(str(c))}</th>" for c in cols) + "</tr>"
    for r in rows: h += "<tr>" + "".join(f"<td>{e(str(v))}</td>" for v in r) + "</tr>"
    return h + "</table>"

def run(sql, args=None):
    with db() as c, c.cursor() as cur:
        cur.execute(sql, args)
        return [d[0] for d in cur.description], cur.fetchall()

def page(body):
    return f"""<!doctype html><meta charset=utf-8><title>TravelX</title><style>
body{{font-family:Arial;margin:0;background:#f4f6f9;color:#222}}header{{background:#122b4a;color:#fff;padding:16px 30px}}
header a{{color:#7fd6e6;margin-right:18px;text-decoration:none}}main{{padding:20px 30px}}
table{{border-collapse:collapse;background:#fff;margin:10px 0;font-size:13px}}td,th{{border:1px solid #ccd;padding:4px 8px}}th{{background:#1f8a9e;color:#fff}}
pre{{background:#fff;border-left:4px solid #1f8a9e;padding:8px;overflow:auto}}.err{{background:#fde8e8;border:1px solid #c33;padding:10px;font-weight:bold}}
.ok{{background:#e5f6e8;border:1px solid #3a3;padding:10px}}label{{display:block;margin:6px 0}}input,select{{padding:4px}}</style>
<header><b>TravelX</b> &nbsp; <a href="/">Home</a><a href="/hotel">Book hotel</a><a href="/car">Book car</a><a href="/views">Views</a><a href="/queries">Queries</a></header><main>{body}</main>"""

def form(kind):
    idf, d1, d2 = ("room_id", "check_in_date", "check_out_date") if kind == "hotel" else ("car_id", "pickup_date", "return_date")
    extra = '<label>Guests <input name="guests" value="1"></label>' if kind == "hotel" else ""
    return f"""<h2>Book a {kind} (trigger demo)</h2>
<p>The trigger <code>trg_{kind}_item_no_overlap</code> rejects a second confirmed booking of the same {idf[:-3]} on overlapping dates. Back-to-back stays (check-out day = next check-in) are allowed.</p>
<form method=post><label>Booking id <input name="booking_id" value="1"></label><label>Traveler (customer) id <input name="traveler_id" value="1"></label>
<label>{idf} <input name="item_id" value="1"></label><label>{d1} <input type=date name="d1" value="2026-11-28"></label>
<label>{d2} <input type=date name="d2" value="2026-12-01"></label><label>Price <input name="price" value="1000"></label>{extra}
<button>Book</button></form><p>Tip: room 1 already has a confirmed stay 2026-11-26 to 2026-12-05 in the sample data (see tests T1/T2). Try overlapping dates to see the trigger error.</p>"""

def book(kind, f):
    g = lambda k: f.get(k, [""])[0]
    with db() as c, c.cursor() as cur:
        cur.execute("INSERT INTO booking_item (booking_id, traveler_id, service_type, price) VALUES (%s,%s,%s,%s)",
                    (g("booking_id"), g("traveler_id"), kind.capitalize(), g("price")))
        bid = cur.lastrowid
        try:
            if kind == "hotel":
                cur.execute("INSERT INTO hotel_item (booking_item_id, room_id, check_in_date, check_out_date, guest_count) VALUES (%s,%s,%s,%s,%s)",
                            (bid, g("item_id"), g("d1"), g("d2"), g("guests") or 1))
            else:
                cur.execute("INSERT INTO car_item (booking_item_id, car_id, pickup_date, return_date) VALUES (%s,%s,%s,%s)",
                            (bid, g("item_id"), g("d1"), g("d2")))
            return f'<div class=ok>Booked. booking_item_id = {bid}. (Delete it later to keep the sample data clean.)</div>'
        except pymysql.MySQLError as ex:
            cur.execute("DELETE FROM booking_item WHERE booking_item_id=%s", (bid,))
            return f'<div class=err>Database refused the booking: {e(str(ex.args[-1]))}</div>'

def views():
    out = "<h2>External schemas (views)</h2>"
    for v in ("customer_trip_view", "visa_officer_view", "accountant_view"):
        cols, rows = run(f"SELECT * FROM {v} LIMIT 25")
        out += f"<h3>{v}</h3>" + table(cols, rows)
    return out

def queries():
    txt = open(QUERIES_FILE, encoding="utf-8").read()
    out = "<h2>Queries and results</h2>"
    for part in txt.split(";"):
        sql = part.strip()
        body = "\n".join(l for l in sql.splitlines() if not l.strip().startswith("--")).strip()
        if not body or body.upper().startswith("USE"): continue
        cm = [l for l in sql.splitlines() if l.startswith("-- Q")]
        out += f"<h3>{e(cm[0][3:] if cm else 'Query')}</h3><pre>{e(body)}</pre>"
        try: out += table(*run(body))
        except Exception as ex: out += f'<div class=err>{e(str(ex))}</div>'
    return out

class H(BaseHTTPRequestHandler):
    def send(self, body):
        b = page(body).encode(); self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        p = urlparse(self.path).path
        try:
            if p == "/hotel": self.send(form("hotel"))
            elif p == "/car": self.send(form("car"))
            elif p == "/views": self.send(views())
            elif p == "/queries": self.send(queries())
            else: self.send("<h2>TravelX</h2><p>Integrated Travel and Reservation Management System (COMP 207).</p><p>Use the menu to book a hotel room or car (triggers), or to browse the 3 views and 32 queries.</p>")
        except Exception as ex: self.send(f'<div class=err>{e(str(ex))}</div>')
    def do_POST(self):
        p = urlparse(self.path).path; n = int(self.headers.get("Content-Length", 0))
        f = parse_qs(self.rfile.read(n).decode())
        kind = "hotel" if p == "/hotel" else "car"
        try: self.send(form(kind) + book(kind, f))
        except Exception as ex: self.send(form(kind) + f'<div class=err>{e(str(ex))}</div>')

if __name__ == "__main__":
    print("TravelX front end on http://localhost:8000"); HTTPServer(("", 8000), H).serve_forever()
