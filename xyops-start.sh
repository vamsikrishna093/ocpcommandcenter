#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  xyOps Platform — Start & End-to-End Test Script
#  Usage:
#    ./xyops-start.sh             # Start all services + run E2E test
#    ./xyops-start.sh --start     # Start services only (no E2E test)
#    ./xyops-start.sh --test      # Run E2E test only (services already up)
#    ./xyops-start.sh --stop      # Stop all services
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC}  $*"; }
fail() { echo -e "${RED}✗${NC}  $*"; }
info() { echo -e "${CYAN}→${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
step() { echo -e "\n${BOLD}${BLUE}▶ $*${NC}"; }
banner() {
  echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗"
  echo -e "║  $*"
  echo -e "╚══════════════════════════════════════════════════════╝${NC}\n"
}

# ── Parse arguments ────────────────────────────────────────────────────────────
MODE="full"          # full | start | test | stop
for arg in "$@"; do
  case $arg in
    --start) MODE="start" ;;
    --test)  MODE="test"  ;;
    --stop)  MODE="stop"  ;;
    --full)  MODE="full"  ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

# ── Service health check ───────────────────────────────────────────────────────
wait_for_http() {
  local name=$1 url=$2 max=${3:-60} delay=${4:-2}
  local i=0
  while [ $i -lt $max ]; do
    if curl -sf "$url" -o /dev/null --max-time 3 2>/dev/null; then
      ok "$name is ready"
      return 0
    fi
    sleep "$delay"
    i=$((i + 1))
    if (( i % 5 == 0 )); then
      info "  Waiting for $name... (${i}/${max} attempts)"
    fi
  done
  fail "$name did not become ready after $((max * delay))s"
  return 1
}

# ── STOP ───────────────────────────────────────────────────────────────────────
do_stop() {
  banner "Stopping xyOps Platform"
  docker compose down
  ok "All services stopped"
}

# ── START ──────────────────────────────────────────────────────────────────────
do_start() {
  banner "Starting xyOps Platform"

  # Check Docker is running
  if ! docker info &>/dev/null; then
    fail "Docker is not running. Please start Docker Desktop first."
    exit 1
  fi

  # Check Ollama is available on host
  step "Checking local Ollama..."
  if curl -sf http://localhost:11434/api/tags -o /dev/null 2>/dev/null; then
    ok "Ollama is running on :11434"
    MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; d=json.load(sys.stdin); [print(' ',m['name']) for m in d.get('models',[])]" 2>/dev/null)
    info "Available models:$MODELS"
  else
    warn "Ollama not detected on :11434 — LLM analysis will use deterministic fallback"
  fi

  # ── Core infrastructure first ───────────────────────────────────────────────
  step "Starting core infrastructure (databases, observability)..."
  docker compose up -d \
    prometheus loki tempo otel-collector grafana alertmanager \
    storage-simulator \
    2>&1 | grep -E "Started|Created|Running|Error" || true

  # ── Application services ────────────────────────────────────────────────────
  step "Starting application services..."
  docker compose up -d \
    xyops gitea knowledge-store \
    frontend-api backend-api \
    ansible-runner \
    2>&1 | grep -E "Started|Created|Running|Error" || true

  # ── AI/Agent services ───────────────────────────────────────────────────────
  step "Starting AI orchestration and agent services..."
  docker compose up -d \
    obs-intelligence storage-agent compute-agent \
    n8n \
    2>&1 | grep -E "Started|Created|Running|Error" || true

  # ── UI services ─────────────────────────────────────────────────────────────
  step "Starting UI services..."
  docker compose up -d \
    ui-backend ui-streamlit command-center \
    2>&1 | grep -E "Started|Created|Running|Error" || true

  # ── Traffic generator ───────────────────────────────────────────────────────
  step "Starting traffic generator (troublemaker)..."
  docker compose --profile troublemaker up -d troublemaker \
    2>&1 | grep -E "Started|Created|Running|Error" || true

  # ── Wait for critical services ───────────────────────────────────────────────
  step "Waiting for services to become healthy..."
  wait_for_http "xyOps"         "http://localhost:5522"         30 2
  wait_for_http "Prometheus"    "http://localhost:9090/-/ready" 30 2
  wait_for_http "Compute-Agent" "http://localhost:9000/health"  45 2
  wait_for_http "n8n"           "http://localhost:5679/healthz"  45 2
  wait_for_http "Grafana"       "http://localhost:3001/api/health" 30 2
  wait_for_http "Command Center" "http://localhost:3500"         30 2
  wait_for_http "Gitea"         "http://localhost:3002"         30 2
  wait_for_http "UI Backend"    "http://localhost:9005/health"  30 2
  wait_for_http "Streamlit"     "http://localhost:8501"         30 2

  # ── Summary ─────────────────────────────────────────────────────────────────
  banner "Platform is UP — Service URLs"
  echo -e "  ${BOLD}Command Center (React)${NC}   →  http://localhost:3500"
  echo -e "  ${BOLD}n8n Orchestrator${NC}         →  http://localhost:5679"
  echo -e "  ${BOLD}xyOps Tickets${NC}            →  http://localhost:5522"
  echo -e "  ${BOLD}Grafana Dashboards${NC}       →  http://localhost:3001"
  echo -e "  ${BOLD}Prometheus${NC}               →  http://localhost:9090"
  echo -e "  ${BOLD}Streamlit Dashboard${NC}      →  http://localhost:8501"
  echo -e "  ${BOLD}Gitea (PR review)${NC}        →  http://localhost:3002  (aiops / Aiops1234!)"
  echo -e "  ${BOLD}Alertmanager${NC}             →  http://localhost:9093"
  echo -e "  ${BOLD}Compute Agent API${NC}        →  http://localhost:9000"
}

# ── E2E TEST ──────────────────────────────────────────────────────────────────
do_e2e_test() {
  banner "Running End-to-End Pipeline Test"

  local WEBHOOK="http://localhost:9000/webhook"
  local AGENT_API="http://localhost:9000"
  local UI_API="http://localhost:9005"
  local PASS=0 FAIL=0

  # ── Helper ─────────────────────────────────────────────────────────────────
  assert() {
    local label=$1 result=$2
    if [ "$result" -eq 0 ] 2>/dev/null; then
      ok "$label"
      PASS=$((PASS + 1))
    else
      fail "$label"
      FAIL=$((FAIL + 1))
    fi
  }

  # ── Step 1: Health checks ──────────────────────────────────────────────────
  step "Step 1: Service health checks"
  for svc_url in \
      "Compute-Agent|http://localhost:9000/health" \
      "UI-Backend|http://localhost:9005/health" \
      "Prometheus|http://localhost:9090/-/ready" \
      "xyOps|http://localhost:5522" \
      "Grafana|http://localhost:3001/api/health"; do
    svc="${svc_url%%|*}"; url="${svc_url##*|}"
    if curl -sf "$url" -o /dev/null --max-time 5 2>/dev/null; then
      assert "$svc healthy" 0
    else
      assert "$svc healthy" 1
    fi
  done

  # ── Step 2: Fire test alert ────────────────────────────────────────────────
  step "Step 2: Fire HighErrorRate alert → compute-agent webhook"
  ALERT_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  WEBHOOK_RESP=$(curl -sf -X POST "$WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{\"status\":\"firing\",\"alerts\":[{\"status\":\"firing\",\"labels\":{\"alertname\":\"HighErrorRate\",\"service_name\":\"frontend-api\",\"severity\":\"warning\",\"namespace\":\"production\"},\"annotations\":{\"summary\":\"E2E test alert\",\"description\":\"frontend-api returning 5xx at 15% — E2E test\"},\"startsAt\":\"${ALERT_START}\",\"endsAt\":\"0001-01-01T00:00:00Z\",\"generatorURL\":\"http://prometheus:9090/graph\"}]}" \
    2>/dev/null || echo "ERROR")

  if [ "$WEBHOOK_RESP" = "ERROR" ]; then
    assert "Webhook accepted alert" 1
    echo "  FATAL: Cannot reach compute-agent. Aborting test."
    return 1
  fi

  TICKET_NUM=$(echo "$WEBHOOK_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0].get('ticket_num','?'))" 2>/dev/null || echo "?")
  TICKET_ID=$(echo "$WEBHOOK_RESP"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0].get('ticket_id','?'))"  2>/dev/null || echo "?")
  assert "Webhook accepted alert" 0
  info "  Created xyOps Ticket #${TICKET_NUM} (${TICKET_ID})"

  # ── Step 3: Wait for LLM + ticket enrichment ──────────────────────────────
  step "Step 3: Waiting for AI analysis (LLM reasoning)..."
  ANALYSIS_OK=1
  for i in $(seq 1 20); do
    sleep 2
    SESSION=$(curl -sf "${AGENT_API}/pipeline/session/default" 2>/dev/null || echo "{}")
    STAGE=$(echo "$SESSION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stage','?'))" 2>/dev/null)
    CONFIDENCE=$(echo "$SESSION" | python3 -c "import sys,json; a=json.load(sys.stdin).get('analysis',{}); print(a.get('confidence','?'))" 2>/dev/null)
    if [[ "$STAGE" == "awaiting_approval" || "$STAGE" == "complete" || "$STAGE" == "autonomous_executing" ]]; then
      ANALYSIS_OK=0
      break
    fi
    info "  Stage: $STAGE (${i}/20)..."
  done
  assert "AI analysis + ticket enrichment completed" $ANALYSIS_OK
  info "  Stage reached: ${STAGE} | LLM confidence: ${CONFIDENCE}"

  # ── Step 4: Verify pipeline session in UI backend ─────────────────────────
  step "Step 4: Verify Command Center session endpoint"
  UI_SESSION=$(curl -sf "${UI_API}/pipeline/session/default" 2>/dev/null || echo "{}")
  UI_STAGE=$(echo "$UI_SESSION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stage','?'))" 2>/dev/null)
  if [[ "$UI_STAGE" != "?" && "$UI_STAGE" != "" ]]; then
    assert "UI Backend returns live session" 0
    info "  UI stage: ${UI_STAGE}"
  else
    assert "UI Backend returns live session" 1
  fi

  # ── Step 5: Check approval gate ───────────────────────────────────────────
  step "Step 5: Check pending approval gate"
  # Get approval_id directly from the current session so we approve the right gate
  APPROVAL_ID=$(curl -sf "${AGENT_API}/pipeline/session/default" 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_id',''))" 2>/dev/null || echo "")

  if [ -z "$APPROVAL_ID" ]; then
    # Fallback to most recently created pending approval
    APPROVALS=$(curl -sf "${AGENT_API}/approvals/pending" 2>/dev/null || echo "{}")
    APPROVAL_ID=$(echo "$APPROVALS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
items = sorted(d.get('items', d) if isinstance(d, dict) else d, key=lambda x: x.get('created_at',''), reverse=True)
print(items[0]['approval_id'] if items else '')
" 2>/dev/null || echo "")
    APPROVAL_COUNT=$(echo "$APPROVALS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('count', len(d)) if isinstance(d,dict) else len(d))" 2>/dev/null || echo "0")
  else
    APPROVAL_COUNT="1 (from current session)"
  fi

  if [ -n "$APPROVAL_ID" ]; then
    assert "Approval gate created ($APPROVAL_COUNT pending)" 0
    info "  Approval ID: ${APPROVAL_ID}"
  else
    assert "Approval gate created" 1
    warn "  No pending approvals found — pipeline may be in autonomous mode"
    APPROVAL_ID=""
  fi

  # ── Step 6: Approve + verify Ansible playbook run ─────────────────────────
  if [ -n "$APPROVAL_ID" ]; then
    step "Step 6: Approving remediation..."
    APPROVE_RESP=$(curl -sf -X POST "${AGENT_API}/approval/${APPROVAL_ID}/decision" \
      -H 'Content-Type: application/json' \
      -d '{"approved":true,"decided_by":"e2e-test","comment":"Automated E2E approval"}' \
      2>/dev/null || echo "ERROR")

    if [ "$APPROVE_RESP" != "ERROR" ]; then
      APPROVED=$(echo "$APPROVE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approved','?'))" 2>/dev/null)
      assert "Approval decision accepted (approved=${APPROVED})" 0
    else
      assert "Approval decision accepted" 1
    fi

    # Wait for Ansible to complete
    info "  Waiting for Ansible playbook execution..."
    # Get the session_id of the session that owns this approval
    CURRENT_SESSION_ID=$(curl -sf "${AGENT_API}/pipeline/session/default" 2>/dev/null | \
      python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','default'))" 2>/dev/null || echo "default")
    ANSIBLE_OK=1
    for i in $(seq 1 15); do
      sleep 2
      FINAL_SESSION=$(curl -sf "${AGENT_API}/pipeline/session/${CURRENT_SESSION_ID}" 2>/dev/null || echo "{}")
      FINAL_STAGE=$(echo "$FINAL_SESSION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stage','?'))" 2>/dev/null)
      OUTCOME=$(echo "$FINAL_SESSION"     | python3 -c "import sys,json; print(json.load(sys.stdin).get('outcome','?'))" 2>/dev/null)
      if [[ "$FINAL_STAGE" == "complete" || "$OUTCOME" == "success" ]]; then
        ANSIBLE_OK=0
        break
      fi
      info "  Stage: $FINAL_STAGE (${i}/15)..."
    done
    assert "Ansible playbook executed → pipeline complete (outcome=${OUTCOME})" $ANSIBLE_OK
  else
    step "Step 6: Skipping approval (no pending gate)"
  fi

  # ── Step 7: Verify Gitea PR was created ───────────────────────────────────
  step "Step 7: Verify Gitea PR for remediation playbook"
  PR_COUNT=$(curl -sf "http://localhost:3002/api/v1/repos/aiops-org/ansible-playbooks/pulls?state=open&token=" \
    -u "aiops:Aiops1234!" --max-time 5 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [ "$PR_COUNT" -gt 0 ] 2>/dev/null; then
    assert "Gitea PR created for remediation (${PR_COUNT} open PRs)" 0
  else
    assert "Gitea PR created" 1
  fi

  # ── Step 8: Prometheus real metrics check ─────────────────────────────────
  step "Step 8: Verify Prometheus has real error metrics"
  ERR_RATE=$(curl -sf "http://localhost:9090/api/v1/query?query=sum(rate(http_server_duration_count%7Bservice_name%3D%22frontend-api%22%2Chttp_status_code%3D~%225..%22%7D%5B5m%5D))" \
    2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
rs=d['data']['result']
val=float(rs[0]['value'][1]) if rs else 0
print(f'{val:.3f} errors/sec')
" 2>/dev/null || echo "no data")
  info "  frontend-api 5xx rate: ${ERR_RATE}"
  if [[ "$ERR_RATE" != "no data" && "$ERR_RATE" != "0.000 errors/sec" ]]; then
    assert "Prometheus real traffic metrics present (${ERR_RATE})" 0
  else
    assert "Prometheus real traffic metrics present" 1
  fi

  # ── Summary ─────────────────────────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  E2E Test Results${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}Passed: ${PASS}${NC}"
  echo -e "  ${RED}Failed: ${FAIL}${NC}"
  TOTAL=$((PASS + FAIL))
  echo -e "  ${BOLD}Total:  ${TOTAL}${NC}"
  echo ""
  if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ ALL TESTS PASSED — Demo ready!${NC}"
  else
    echo -e "  ${YELLOW}${BOLD}⚠ ${FAIL} test(s) failed — review above${NC}"
  fi
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${BOLD}View live pipeline:${NC} http://localhost:3500"
  echo -e "  ${BOLD}n8n executions:${NC}     http://localhost:5679"
  echo -e "  ${BOLD}xyOps tickets:${NC}      http://localhost:5522"
  echo -e "  ${BOLD}Grafana:${NC}            http://localhost:3001"
  echo -e "  ${BOLD}Gitea PRs:${NC}          http://localhost:3002/aiops-org/ansible-playbooks/pulls"
  echo ""
  return $FAIL
}

# ── Entrypoint ────────────────────────────────────────────────────────────────
case $MODE in
  stop)
    do_stop
    ;;
  start)
    do_start
    ;;
  test)
    do_e2e_test
    ;;
  full)
    do_start
    echo ""
    info "Letting services stabilise for 15 seconds before running E2E test..."
    sleep 15
    do_e2e_test
    ;;
esac
