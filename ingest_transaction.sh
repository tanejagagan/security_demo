#!/usr/bin/env bash
# Demo: HTTP push ingestion via Arrow IPC + curl
#
# Pushes new transaction rows into ducklake_catalog.main.transaction
# via the DazzleDuck complete server (port 8081).
#
# Prerequisites:
#   - docker-compose up (complete server on port 8081)
#   - python3 with pyarrow installed: pip3 install pyarrow
#
# Usage:
#   ./ingest_transaction.sh

set -euo pipefail

SERVER="http://localhost:8081"
ARROW_FILE="/tmp/new_transactions.arrows"

echo "==> Step 1: Get JWT token from $SERVER"
RESPONSE=$(curl -sf -X POST "$SERVER/v1/login" \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin"}')

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get JWT token. Is the server running on port 8081?"
  exit 1
fi
echo "    Token: ${TOKEN:0:40}..."

echo ""
echo "==> Step 2: Generate Arrow IPC data with Python/pyarrow"
python3 - <<'PYEOF'
import pyarrow as pa
import datetime

now = datetime.datetime.now()

schema = pa.schema([
    pa.field("transaction_id", pa.int32()),
    pa.field("tenant_id",      pa.int32()),
    pa.field("user_id",        pa.int32()),
    pa.field("method",         pa.string()),
    pa.field("path",           pa.string()),
    pa.field("status_code",    pa.int16()),
    pa.field("response_ms",    pa.int32()),
    pa.field("bytes_sent",     pa.int32()),
    pa.field("ip_address",     pa.string()),
    pa.field("user_agent",     pa.string()),
    pa.field("time",           pa.timestamp("us")),
])

import time
base_id = int(time.time())

batch = pa.record_batch({
    "transaction_id": pa.array([base_id, base_id + 1], type=pa.int32()),
    "tenant_id":      pa.array([1,       1           ], type=pa.int32()),
    "user_id":        pa.array([101,  102 ], type=pa.int32()),
    "method":         pa.array(["GET", "POST"]),
    "path":           pa.array(["/api/ingest-demo", "/api/ingest-demo"]),
    "status_code":    pa.array([200, 201], type=pa.int16()),
    "response_ms":    pa.array([42,  88 ], type=pa.int32()),
    "bytes_sent":     pa.array([1024, 512], type=pa.int32()),
    "ip_address":     pa.array(["10.0.1.99", "10.0.1.99"]),
    "user_agent":     pa.array(["curl/8.0", "curl/8.0"]),
    "time":           pa.array([now, now], type=pa.timestamp("us")),
}, schema=schema)

sink = pa.BufferOutputStream()
writer = pa.ipc.new_stream(sink, schema)
writer.write_batch(batch)
writer.close()

with open("/tmp/new_transactions.arrows", "wb") as f:
    f.write(sink.getvalue().to_pybytes())

print(f"    Written: /tmp/new_transactions.arrows ({len(sink.getvalue())} bytes)")
print(f"    Rows: {batch.num_rows}")
PYEOF

echo ""
echo "==> Step 3: Push Arrow data to ingestion queue 'transaction'"
HTTP_STATUS=$(curl -s -o /tmp/ingest_response.txt -w "%{http_code}" \
  -X POST "$SERVER/v1/ingest?ingestion_queue=transaction" \
  -H "Content-Type: application/vnd.apache.arrow.stream" \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary "@$ARROW_FILE")

echo "    HTTP status: $HTTP_STATUS"
if [ -s /tmp/ingest_response.txt ]; then
  echo "    Response: $(cat /tmp/ingest_response.txt)"
fi

if [ "$HTTP_STATUS" = "200" ]; then
  echo ""
  echo "==> Success! Data pushed to ducklake_catalog.main.transaction"
  echo ""
  echo "    To verify, query via DuckDB with dazzleduck extension:"
  echo "    SELECT transaction_id, method, path, time"
  echo "    FROM \"transaction\""
  echo "    WHERE transaction_id >= 9000;"
else
  echo "ERROR: Ingestion failed with HTTP $HTTP_STATUS"
  exit 1
fi
