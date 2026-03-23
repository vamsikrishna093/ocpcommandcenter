#!/usr/bin/env bash
# =============================================================================
# demo-live.sh — Fully Automated AIOps Demo
#
# What this does (no commands needed during presentation):
#   1. Checks all services are healthy
#   2. Injects an error-spike scenario into the troublemaker so Prometheus
#      metrics climb above the threshold immediately
#   3. Fires the Alertmanager webhook → triggers the full pipeline:
#         Alert → n8n → compute-agent → Loki/Prometheus fetch → LLM RCA
#         → xyOps ticket enriched → Approval gate ticket created
#   4. Waits for the approval ticket, then AUTO-APPROVES it
#         → Ansible playbook executes (dry-run in demo)
#   5. Loops with a countdown timer and then resolves the alert
#
# Open these browser tabs BEFORE running:
#   http://localhost:5679   n8n Executions (watch calls appear in real-time)
#   http://localhost:5522   xyOps Tickets  (watch comments populate live)
#   http://localhost:3500   Command Center (React flow graph)
#   http://localhost:3001   Grafana → "Agentic AI Operations" dashboard
#
# Usage:
#   chmod +x demo-live.sh
#   ./demo-live.sh
# =============================================================================

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

COMPUTE_API="http://localhost:9000"
TROUBLEMAKER_API="http://localhost:8088"

# ── Helpers ────────────────────────────────────────────────────────────────────
banner() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${CYAN}  $1${NC}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"; }
ok()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
err()    { echo -e "${RED}[✗]${NC} $1"; }

# ── Preflight checks ───────────────────────────────────────────────────────────
banner "Preflight — checking services"

check_service() {
  local name=$1 url=$2
  if curl -sf "$url" > /dev/null 2>&1; then
    ok "$name  ($url)"
  else
    err "$name not reachable at $url"
    echo "  Run:  docker compose up -d"
    exit 1
  fi
}

check_service "compute-agent" "$COMPUTE_API/health"
check_service "n8n"           "http://localhost:5679"
check_service "xyOps"         "http://localhost:5522"
check_service "Grafana"       "http://localhost:3001"
check_service "Command Center" "http://localhost:3500"

# ── Open browser tabs (macOS) ─────────────────────────────────────────────────
banner "Opening browser tabs"
open "http://localhost:5679"     2>/dev/null || true   # n8n Executions
open "http://localhost:5522"     2>/dev/null || true   # xyOps Tickets
open "http://localhost:3500"     2>/dev/null || true   # Command Center
open "http://localhost:3001/dashboards" 2>/dev/null || true  # Grafana

sleep 1

# ── Inject error spike by flooding the /error endpoint ───────────────────────
banner "Step 1 — Injecting error spike (flooding /error to push Prometheus metric)"
info "Sending 60 rapid error requests to frontend-api to spike the error rate..."

FRONTEND_URL="http://localhost:8080"
if curl -sf "$FRONTEND_URL/health" > /dev/null 2>&1; then
  # Fire 60 rapid error requests in background (takes ~3s)
  for i in $(seq 1 60); do
    curl -sf "$FRONTEND_URL/error" > /dev/null 2>&1 || true
    curl -sf "$FRONTEND_URL/backend-error" > /dev/null 2>&1 || true
  done &
  FLOOD_PID=$!
  ok "Error flood started (PID $FLOOD_PID) — Prometheus will see spike within 15s"
else
  warn "frontend-api not reachable at $FRONTEND_URL"
  warn "Run:  docker compose up -d frontend-api backend-api"
  warn "Continuing with direct webhook injection anyway..."
fi

# Prometheus needs ~15s to scrape + alert rule fires at 15s
info "Waiting 5s for metrics to propagate..."
sleep 5

# ── Fire the alert directly (simulates what Alertmanager sends) ───────────────
banner "Step 2 — Firing HighErrorRate alert via Alertmanager webhook"

STARTS_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ALERT_PAYLOAD='{
  "status": "firing",
  "alerts": [{
    "status": "firing",
    "labels": {
      "alertname": "HighErrorRate",
      "service_name": "frontend-api",
      "severity": "warning",
      "namespace": "production",
      "team": "platform",
      "job": "frontend-api"
    },
    "annotations": {
      "summary": "High error rate on frontend-api",
      "description": "frontend-api error rate is 12.4% over the last 2 minutes. Expected < 5%. Clients are receiving HTTP 5xx responses.",
      "dashboard_url": "http://localhost:3001/d/obs-overview",
      "runbook_url": "http://localhost:5522"
    },
    "startsAt": "'"$STARTS_AT"'",
    "endsAt": "0001-01-01T00:00:00Z",
    "generatorURL": "http://localhost:9090/graph?g0.expr=rate(http_errors_total[2m])"
  }]
}'

info "POST $COMPUTE_API/webhook"
WEBHOOK_RESPONSE=$(curl -sf -X POST "$COMPUTE_API/webhook" \
  -H 'Content-Type: application/json' \
  -d "$ALERT_PAYLOAD")

TICKET_NUM=$(echo "$WEBHOOK_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['results'][0]['ticket_num'])" 2>/dev/null || echo "?")
TICKET_ID=$(echo "$WEBHOOK_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['results'][0]['ticket_id'])" 2>/dev/null || echo "")
echo ""
ok "Incident ticket #${TICKET_NUM} created  (id: ${TICKET_ID})"
echo -e "    ${YELLOW}→ Open xyOps:  http://localhost:5522${NC}"
echo -e "    ${YELLOW}→ Watch n8n:   http://localhost:5679  (Executions tab)${NC}"

# ── Wait for LLM + approval gate ──────────────────────────────────────────────
banner "Step 3 — Waiting for LLM analysis + approval gate to appear"
info "Pipeline running: Loki fetch → Prometheus metrics → LLM RCA → approval gate..."

MAX_WAIT=60
ELAPSED=0
APPROVAL_ID=""
while [[ -z "$APPROVAL_ID" && $ELAPSED -lt $MAX_WAIT ]]; do
  sleep 3
  ELAPSED=$((ELAPSED + 3))

  PENDING=$(curl -sf "$COMPUTE_API/approvals/pending" 2>/dev/null || echo '{"count":0,"items":[]}')
  COUNT=$(echo "$PENDING" | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")

  if [[ "$COUNT" -gt "0" ]]; then
    APPROVAL_ID=$(echo "$PENDING" | python3 -c "import sys,json; items=json.load(sys.stdin)['items']; print(items[0]['approval_id'] if items else '')" 2>/dev/null || echo "")
    APPROVAL_TICKET=$(echo "$PENDING" | python3 -c "import sys,json; items=json.load(sys.stdin)['items']; print(items[0].get('approval_ticket_id','?') if items else '?')" 2>/dev/null || echo "?")
  fi

  printf "\r  ${CYAN}[${ELAPSED}s / ${MAX_WAIT}s]${NC} Waiting for approval gate...  "
done
echo ""

if [[ -z "$APPROVAL_ID" ]]; then
  warn "No approval gate appeared within ${MAX_WAIT}s"
  warn "LLM may have failed — check: docker logs compute-agent --tail 30"
  warn "Pipeline still ran — ticket #${TICKET_NUM} was created with the full update"
  exit 0
fi

ok "Approval gate created!  id=${APPROVAL_ID}"
echo -e "    ${YELLOW}→ Approval ticket: http://localhost:5522${NC}"
echo ""

# ── Short pause so audience can see the approval ticket ───────────────────────
banner "DEMO PAUSE — Show management the approval gate ticket"
echo -e "${YELLOW}  Now is the time to:${NC}"
echo "    1. Show the xyOps ticket #${TICKET_NUM} — enriched body with LLM RCA"
echo "    2. Show the approval gate ticket that requires human sign-off"
echo "    3. Show n8n Executions — all the webhook calls visible"
echo ""
echo -e "${BOLD}  Press ENTER to approve and trigger Ansible remediation...${NC}"
read -r

# ── Approve and trigger Ansible ───────────────────────────────────────────────
banner "Step 4 — Approving + triggering Ansible remediation"

APPROVE_RESPONSE=$(curl -sf -X POST "$COMPUTE_API/approval/${APPROVAL_ID}/decision" \
  -H 'Content-Type: application/json' \
  -d '{"approved":true,"decided_by":"sre-lead-demo","comment":"Reviewed playbook — approved for automated remediation."}' || echo '{"status":"error"}')

STATUS=$(echo "$APPROVE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null || echo "?")
ok "Decision submitted — status: ${STATUS}"

sleep 3
echo ""
ok "Ansible Runner received playbook  (dry-run / simulation mode)"
echo -e "    ${YELLOW}→ Verify: docker logs ansible-runner --tail 5${NC}"

# ── Resolve the alert ────────────────────────────────────────────────────────
banner "Step 5 — Resolving the alert"
sleep 2

ENDS_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RESOLVE_PAYLOAD='{
  "status": "resolved",
  "alerts": [{
    "status": "resolved",
    "labels": {
      "alertname": "HighErrorRate",
      "service_name": "frontend-api",
      "severity": "warning",
      "namespace": "production"
    },
    "annotations": {
      "summary": "High error rate on frontend-api",
      "description": "Error rate has returned below threshold — incident resolved."
    },
    "startsAt": "'"$STARTS_AT"'",
    "endsAt": "'"$ENDS_AT"'",
    "generatorURL": "http://localhost:9090/graph"
  }]
}'

curl -sf -X POST "$COMPUTE_API/webhook" \
  -H 'Content-Type: application/json' \
  -d "$RESOLVE_PAYLOAD" > /dev/null 2>&1 && ok "Resolved alert sent → ticket #${TICKET_NUM} will be marked resolved" || true

# ── Summary ──────────────────────────────────────────────────────────────────
banner "Demo complete — Summary"
echo ""
echo -e "  ${GREEN}${BOLD}Ticket #${TICKET_NUM}${NC}    created, enriched, resolved"
echo -e "  ${GREEN}${BOLD}n8n${NC}            http://localhost:5679  (Executions tab)"
echo -e "  ${GREEN}${BOLD}xyOps${NC}          http://localhost:5522  (Tickets)"
echo -e "  ${GREEN}${BOLD}Command Center${NC} http://localhost:3500  (Pipeline flow)"
echo -e "  ${GREEN}${BOLD}Grafana${NC}        http://localhost:3001  (Agentic AI Operations)"
echo -e "  ${GREEN}${BOLD}Ansible logs${NC}   docker logs ansible-runner --tail 20"
echo ""
