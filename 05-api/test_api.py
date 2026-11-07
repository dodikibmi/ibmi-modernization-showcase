"""Smoke / regression test of the AR REST API (stage 5).

Sends the same seven payments as test/testdata.sql batch 1, one by one, through
POST /api/payments, then reads the aging. Run on the IBM i while server.py is
running, after the test data was loaded and its waiting payments removed:
    python3.9 test_api.py [base-url] > api-test.txt
"""
import json
import sys
import urllib.error
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:48410/api"


def call(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            status, text = r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read().decode()
    print(f"\n=== {method} {path}" + (f"  {json.dumps(body)}" if body is not None else ""))
    print(f"--- HTTP {status}")
    print(text)
    return status, json.loads(text)


call("GET", "/health")
call("GET", "/customers/100100?asof=2026-10-31")

payments = [
    (100100, 1500.00, "2026-10-25"),   # pays 2600101 in full, 300 into 2600102
    (100200, 3000.00, "2026-10-26"),   # pays everything, customer released from hold
    (100300, 2000.00, "2026-10-27"),   # 550 left over: unapplied credit
    (999999, 100.00, "2026-10-27"),    # unknown customer -> 404
    (100500, 0.00, "2026-10-28"),      # zero amount -> 422
    (100500, 400.00, "2026-10-28"),    # partial payment
    (100100, -50.00, "2026-10-29"),    # negative amount -> 422
]
expected = [201, 201, 201, 404, 422, 201, 422]
got = [call("POST", "/payments", {"customer": c, "amount": a, "date": d})[0] for c, a, d in payments]

call("POST", "/payments", {"customer": 100100})          # amount missing -> 422
call("GET", "/customers/100100?asof=2026-10-31")
status, aging = call("GET", "/aging?asof=2026-10-31")
call("GET", "/nothing")

print("\n=== summary")
print("payment statuses", got, "expected", expected, "OK" if got == expected else "MISMATCH")
print("aging total", json.dumps(aging.get("total")))
