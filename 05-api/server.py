"""Accounts receivable REST API (stage 5).

Runs in PASE on the IBM i with Python 3.9 and the standard library, plus
itoolkit (XMLSERVICE), both from the IBM i open-source packages. itoolkit's
DirectTransport runs inside this job, so it needs no user or password, and it
lets Python do two things that matter for a modernization:

  * run SQL on the stage 2 tables, and
  * call the SAME RPG code the batch uses: the procedures of service program
    ARSRV (validation, aging) and the posting program ARR240.

No business rule is written twice. The API is a new door to the old house.

Endpoints
  GET  /api/health
  GET  /api/customers/{id}              customer, balance, open invoices with age bucket
  GET  /api/aging?asof=YYYY-MM-DD       aged trial balance per customer, as JSON
  POST /api/payments                    {"customer": 100100, "amount": 1500.00,
                                         "date": "2026-10-25"}
       201 posted (body: payment status, unapplied credit, new balance)
       404 unknown customer, 422 invalid amount or date, 400 bad JSON

Start (batch job or SSH session on the IBM i):
  AR_LIB=DODIKIBMI1 AR_DATA=DODIKIBMI2 PORT=48410 python3.9 server.py
"""
import datetime
import json
import os
import re
import warnings
from decimal import Decimal, InvalidOperation
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

warnings.simplefilter("ignore")          # itoolkit 1.7 warns that iSql* is deprecated
from itoolkit import iCmd, iData, iPgm, iSqlFetch, iSqlFree, iSqlQuery, iSrvPgm, iToolKit  # noqa: E402
from itoolkit.transport import DirectTransport  # noqa: E402

PGM_LIB = os.environ.get("AR_LIB", "DODIKIBMI1").upper()
DATA_LIB = os.environ.get("AR_DATA", "DODIKIBMI2").upper()
PORT = int(os.environ.get("PORT", "48410"))
HOST = os.environ.get("HOST", "127.0.0.1")
API_BATCH = 2                             # payments received through the API
BUCKETS = {1: "current", 2: "days_1_30", 3: "days_31_60", 4: "days_61_90", 5: "over_90"}
NAME = re.compile(r"^[A-Z0-9_]{1,10}$")
assert NAME.match(PGM_LIB) and NAME.match(DATA_LIB)

transport = DirectTransport()


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


# ---------------------------------------------------------------- IBM i access
def run(*items, may_fail=()):
    tk = iToolKit()
    for item in items:
        tk.add(item)
    tk.call(transport)
    out = tk.dict_out()
    for key, value in out.items():
        if isinstance(value, dict) and "error" in value and key not in may_fail:
            raise ApiError(500, f"IBM i call {key} failed")
    return out


def sql(statement):
    """Run one statement; return the rows of a SELECT as a list of dicts.
    Only numbers that were parsed by this module are ever put into a statement."""
    out = run(iSqlQuery("q", statement), iSqlFetch("f"), iSqlFree("x"), may_fail=("f",))
    fetch = out.get("f", {})
    if "error" in fetch:
        if "02000" in str(fetch.get("xmlhint", "")):      # SQLSTATE 02000: no rows
            return []
        raise ApiError(500, "IBM i call f failed")
    rows = fetch.get("row", [])
    return [rows] if isinstance(rows, dict) else rows


def execute(statement):
    run(iSqlQuery("q", statement), iSqlFree("x"))


def arsrv(proc, parms, ret):
    """Call one exported procedure of service program ARSRV."""
    call = iSrvPgm("p", "ARSRV", proc, {"lib": PGM_LIB})
    for name, typ, value in parms:
        call.addParm(iData(name, typ, str(value)))
    call.addRet(iData("ret", ret[0], "", ret[1] if len(ret) > 1 else {}))
    return run(call)["p"]["ret"]


def age_buckets(days_list):
    """Age bucket for many invoices: one XMLSERVICE request, one call of the
    ARSRV procedure AR_ageBucket per invoice - the same rule as the report.
    (Days past due come from SQL: calling AR_daysPastDue through XMLSERVICE
    failed whenever the result was negative, i.e. for invoices not yet due,
    although the same procedure passes its RPGUnit test for that case.)"""
    if not days_list:
        return []
    calls = [iSrvPgm(f"b{i}", "ARSRV", "AR_ageBucket", {"lib": PGM_LIB})
             .addParm(iData("days", "10i0", str(d)))
             .addRet(iData("bucket", "10i0", "")) for i, d in enumerate(days_list)]
    out = run(*calls)
    return [BUCKETS[int(out[f"b{i}"]["bucket"])] for i in range(len(days_list))]


def days_sql(as_of, column):
    """SQL expression: days from a YYYYMMDD numeric date column to the as-of date."""
    return (f"days(date('{as_of.isoformat()}')) - "
            f"days(date(to_date(digits({column}), 'YYYYMMDD')))")


# ---------------------------------------------------------------- helpers
def ymd(value):
    """'2026-10-25' -> 20261025 (numeric date column), validated."""
    try:
        return int(datetime.date.fromisoformat(str(value)).strftime("%Y%m%d"))
    except ValueError:
        raise ApiError(422, "date must be YYYY-MM-DD")


def iso(n):
    s = str(n)
    return f"{s[0:4]}-{s[4:6]}-{s[6:8]}" if len(s) == 8 else None


def money(value):
    return float(Decimal(value))


def customer_id(value):
    if not re.fullmatch(r"\d{1,6}", str(value)):
        raise ApiError(404, "customer not found")
    return int(value)


# ---------------------------------------------------------------- endpoints
def get_health(_q):
    sql(f"select 1 as ok from {DATA_LIB}.AR_CUSTOMER fetch first 1 row only")
    return 200, {"status": "ok", "programs": PGM_LIB, "data": DATA_LIB}


def get_customer(q, cust):
    cust = customer_id(cust)
    rows = sql(f"select CUSTOMER_ID, CUSTOMER_NAME, CREDIT_LIMIT, BALANCE, CUSTOMER_STATUS "
               f"from {DATA_LIB}.AR_CUSTOMER where CUSTOMER_ID = {cust}")
    if not rows:
        raise ApiError(404, "customer not found")
    c = rows[0]
    as_of = as_of_date(q)
    inv = sql(f"select INVOICE_NO, INVOICE_DATE, DUE_DATE, AMOUNT, PAID, "
              f"{days_sql(as_of, 'DUE_DATE')} as DAYS_PAST_DUE "
              f"from {DATA_LIB}.AR_INVOICES where CUSTOMER_ID = {cust} and INVOICE_STATUS = 'O' "
              f"order by DUE_DATE, INVOICE_NO")
    days = [int(r["DAYS_PAST_DUE"]) for r in inv]
    ages = list(zip(days, age_buckets(days)))
    return 200, {
        "customer": int(c["CUSTOMER_ID"]), "name": c["CUSTOMER_NAME"].rstrip(),
        "status": c["CUSTOMER_STATUS"], "credit_limit": money(c["CREDIT_LIMIT"]),
        "balance": money(c["BALANCE"]), "as_of": as_of.isoformat(),
        "open_invoices": [{
            "invoice": int(r["INVOICE_NO"]), "invoice_date": iso(r["INVOICE_DATE"]),
            "due_date": iso(r["DUE_DATE"]), "open_amount": money(Decimal(r["AMOUNT"]) - Decimal(r["PAID"])),
            "days_past_due": d, "bucket": b} for r, (d, b) in zip(inv, ages)],
    }


def as_of_date(q):
    value = q.get("asof", [datetime.date.today().isoformat()])[0]
    try:
        return datetime.date.fromisoformat(value)
    except ValueError:
        raise ApiError(422, "asof must be YYYY-MM-DD")


def get_aging(q):
    as_of = as_of_date(q)
    inv = sql(f"select i.CUSTOMER_ID, c.CUSTOMER_NAME, i.AMOUNT - i.PAID as OPEN_AMOUNT, "
              f"{days_sql(as_of, 'i.DUE_DATE')} as DAYS_PAST_DUE "
              f"from {DATA_LIB}.AR_INVOICES i left join {DATA_LIB}.AR_CUSTOMER c "
              f"on c.CUSTOMER_ID = i.CUSTOMER_ID where i.INVOICE_STATUS = 'O' "
              f"order by i.CUSTOMER_ID, i.DUE_DATE, i.INVOICE_NO")
    ages = age_buckets([int(r["DAYS_PAST_DUE"]) for r in inv])
    customers, total = {}, {b: Decimal(0) for b in BUCKETS.values()}
    for r, bucket in zip(inv, ages):
        cid = int(r["CUSTOMER_ID"])
        name = (r.get("CUSTOMER_NAME") or "").rstrip() or "*UNKNOWN*"
        c = customers.setdefault(cid, {"customer": cid, "name": name,
                                       **{b: Decimal(0) for b in BUCKETS.values()}})
        amount = Decimal(r["OPEN_AMOUNT"])
        c[bucket] += amount
        total[bucket] += amount
    for c in customers.values():
        c["open_amount"] = sum(c[b] for b in BUCKETS.values())
    total["open_amount"] = sum(total.values())
    return 200, {"as_of": as_of.isoformat(), "customers": list(customers.values()), "total": total}


def post_payment(body):
    try:
        data = json.loads(body or b"{}")
        if not isinstance(data, dict):
            raise ValueError
    except ValueError:
        raise ApiError(400, "body must be a JSON object")
    try:
        amount = Decimal(str(data.get("amount"))).quantize(Decimal("0.01"))
    except InvalidOperation:
        raise ApiError(422, "amount must be a number")
    if abs(amount) >= Decimal("10000000"):
        raise ApiError(422, "amount too large")
    cust = customer_id(data.get("customer", ""))
    pay_date = ymd(data.get("date", datetime.date.today().isoformat()))

    found = bool(sql(f"select 1 as ok from {DATA_LIB}.AR_CUSTOMER where CUSTOMER_ID = {cust}"))
    # the same validation as the batch: ARSRV AR_validatePayment
    error = arsrv("AR_validatePayment", [("amount", "9p2", amount), ("found", "1a", "1" if found else "0")],
                  ("30a", {"varying": "on"})).strip()
    if error:
        raise ApiError(404 if error == "CUSTOMER NOT FOUND" else 422, error.lower())

    seq = int(sql(f"select coalesce(max(SEQUENCE_NO), 0) + 1 as NEXT from {DATA_LIB}.AR_PAYMENTS "
                  f"where BATCH_NO = {API_BATCH}")[0]["NEXT"])
    execute(f"insert into {DATA_LIB}.AR_PAYMENTS (BATCH_NO, SEQUENCE_NO, CUSTOMER_ID, PAY_DATE, AMOUNT, "
            f"PAY_STATUS, MESSAGE) values ({API_BATCH}, {seq}, {cust}, {pay_date}, {amount}, ' ', ' ')")
    execute("commit")                     # ARR240 runs in its own commitment definition
    # post it with the batch program itself (one transaction per payment)
    run(iPgm("post", "ARR240", {"lib": PGM_LIB}))

    p = sql(f"select PAY_STATUS, MESSAGE from {DATA_LIB}.AR_PAYMENTS "
            f"where BATCH_NO = {API_BATCH} and SEQUENCE_NO = {seq}")[0]
    c = sql(f"select BALANCE, CUSTOMER_STATUS from {DATA_LIB}.AR_CUSTOMER where CUSTOMER_ID = {cust}")[0]
    if p["PAY_STATUS"] != "P":
        raise ApiError(500, "payment stored but not posted: " + p["MESSAGE"].strip())
    return 201, {"batch": API_BATCH, "sequence": seq, "customer": cust, "amount": float(amount),
                 "status": "posted", "message": p["MESSAGE"].strip() or None,
                 "customer_balance": money(c["BALANCE"]), "customer_status": c["CUSTOMER_STATUS"]}


ROUTES = [
    ("GET", re.compile(r"^/api/health$"), get_health),
    ("GET", re.compile(r"^/api/customers/([^/]+)$"), get_customer),
    ("GET", re.compile(r"^/api/aging$"), get_aging),
]


class Handler(BaseHTTPRequestHandler):
    server_version = "ar-api/1.0"

    def _send(self, status, payload):
        body = json.dumps(payload, default=lambda v: float(v) if isinstance(v, Decimal) else str(v),
                          indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _dispatch(self, method):
        url = urlparse(self.path)
        try:
            if method == "POST" and url.path == "/api/payments":
                length = int(self.headers.get("Content-Length") or 0)
                return self._send(*post_payment(self.rfile.read(length)))
            for m, pattern, func in ROUTES:
                hit = pattern.match(url.path)
                if m == method and hit:
                    return self._send(*func(parse_qs(url.query), *hit.groups()))
            raise ApiError(404, "no such endpoint")
        except ApiError as e:
            self._send(e.status, {"error": e.message})
        except Exception as e:            # never leak a stack trace to the caller
            self.log_error("unexpected: %r", e)
            self._send(500, {"error": "internal error"})

    def do_GET(self):  # noqa: N802
        self._dispatch("GET")

    def do_POST(self):  # noqa: N802
        self._dispatch("POST")


if __name__ == "__main__":
    # ARR240 names its tables without a library: put both libraries in this job's library list
    for lib in (DATA_LIB, PGM_LIB):
        run(iCmd("libl", f"ADDLIBLE LIB({lib}) POSITION(*LAST)"), may_fail=("libl",))
    print(f"AR API on http://{HOST}:{PORT}/api  (programs {PGM_LIB}, data {DATA_LIB})", flush=True)
    HTTPServer((HOST, PORT), Handler).serve_forever()
