"""Lab 9 helper: drops retail transaction JSON files into the stream directory,
one file every second, so structured_streaming.py has live data to read."""
import json
import os
import random
import sys
import time

stream_dir = sys.argv[1]
seconds = int(sys.argv[2])
os.makedirs(stream_dir, exist_ok=True)

# first three files give the totals shown in the manual
seed = [
    {"InvoiceNo": "536365", "StockCode": "85123A", "Quantity": 1, "UnitPrice": 1245.80, "Country": "United Kingdom"},
    {"InvoiceNo": "536366", "StockCode": "71053",  "Quantity": 1, "UnitPrice": 340.50,  "Country": "Germany"},
    {"InvoiceNo": "536367", "StockCode": "84406B", "Quantity": 1, "UnitPrice": 185.20,  "Country": "France"},
]
countries = ["United Kingdom", "Germany", "France", "Netherlands", "Spain"]
n = 0

def write(record):
    global n
    n += 1
    path = os.path.join(stream_dir, f"txn_{n:04d}.json")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(json.dumps(record) + "\n")
    os.rename(tmp, path)          # atomic: Spark never sees a half-written file
    print(f"[feeder] wrote {os.path.basename(path)}: {record}", flush=True)

for r in seed:
    write(r)
end = time.time() + seconds
while time.time() < end:
    time.sleep(1)
    write({"InvoiceNo": str(536400 + n), "StockCode": random.choice(["22752", "21730", "84029E", "22633"]),
           "Quantity": random.randint(1, 12), "UnitPrice": round(random.uniform(1.5, 25.0), 2),
           "Country": random.choice(countries)})
print(f"[feeder] done, {n} files written", flush=True)
