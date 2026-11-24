#!/usr/bin/env bash
# Local test of the voicemail workflow with n8n installed via npm (no Telegram, no accounts needed).
# Usage: bash tests/run-local-test.sh /path/to/folder/containing/node_modules/n8n
# It swaps the Telegram node for a no-op and makes the webhook reply with the last node's output,
# so the formatted message can be checked. The real workflow file is not changed.
set -euo pipefail
N8N_DIR="${1:?path to a folder where 'npm install n8n' was run}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
export N8N_USER_FOLDER="$(mktemp -d)"
export N8N_LISTEN_ADDRESS=127.0.0.1 N8N_DIAGNOSTICS_ENABLED=false N8N_PERSONAL_PUBLICATION_ENABLED=false N8N_PORT=5690
TOKEN="Bearer local-test-token"
N8N="$N8N_DIR/node_modules/.bin/n8n"

python3 - "$HERE" "$N8N_USER_FOLDER" "$TOKEN" <<'PY'
import json, sys
here, out, token = sys.argv[1:4]
wf = json.load(open(f"{here}/workflows/voicemail-to-telegram.json"))
wf["id"] = "voicemaildemo01"
for n in wf["nodes"]:
    if n["type"] == "n8n-nodes-base.webhook":
        n["parameters"]["responseMode"] = "lastNode"
        n["credentials"] = {"httpHeaderAuth": {"id": "cred01", "name": "Local test token"}}
    if n["type"] in ("n8n-nodes-base.telegram", "n8n-nodes-base.httpRequest"):
        n["type"] = "n8n-nodes-base.noOp"; n["typeVersion"] = 1; n["parameters"] = {}
        n.pop("retryOnFail", None); n.pop("maxTries", None); n.pop("waitBetweenTries", None)
wf["active"] = False
json.dump([wf], open(f"{out}/wf.json", "w"))
json.dump([{"id": "cred01", "name": "Local test token", "type": "httpHeaderAuth",
            "data": {"name": "Authorization", "value": token}}], open(f"{out}/cred.json", "w"))
PY

wait_up() { for i in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$N8N_PORT/healthz" && return 0; sleep 2; done; return 1; }

# A first boot sets up the local database. Boot once, stop, then import and publish, then boot for the tests.
"$N8N" start >"$N8N_USER_FOLDER/boot1.log" 2>&1 & P1=$!
wait_up; sleep 3; kill $P1 2>/dev/null || true; wait $P1 2>/dev/null || true

"$N8N" import:credentials --input="$N8N_USER_FOLDER/cred.json" >/dev/null
"$N8N" import:workflow --input="$N8N_USER_FOLDER/wf.json" >/dev/null
"$N8N" publish:workflow --id=voicemaildemo01 >/dev/null 2>&1

"$N8N" start >"$N8N_USER_FOLDER/n8n.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
wait_up; sleep 3

post() { curl -s -w '\n[HTTP %{http_code}]\n' -X POST "http://localhost:$N8N_PORT/webhook/voicemail-demo" \
  -H "Content-Type: application/json" -H "Authorization: $1" --data @"$2"; }

echo "== 1. wrong token (expect 403) =="; post "Bearer wrong" "$HERE/sample-payloads/01-complete-voicemail.json"
echo "== 2. complete voicemail =="; post "$TOKEN" "$HERE/sample-payloads/01-complete-voicemail.json"
echo "== 3. same call again (expect 'No item' = dropped as a repeat; the HTTP 500 is only the test-mode reply) =="; post "$TOKEN" "$HERE/sample-payloads/01-complete-voicemail.json"
echo "== 4. incomplete voicemail with < and & in it =="; post "$TOKEN" "$HERE/sample-payloads/02-incomplete-voicemail.json"
echo "== 5. audio event (expect 'No item' = ignored; same test-mode reply) =="; post "$TOKEN" "$HERE/sample-payloads/03-audio-event-ignored.json"
echo "== 6. outbound call (expect 'No item' = ignored; same test-mode reply) =="; post "$TOKEN" "$HERE/sample-payloads/04-outbound-call-ignored.json"
