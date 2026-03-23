# 🚀 Quick Test Commands Reference

Copy-paste commands to test each component step-by-step.

---

## 1️⃣ Health Check (30 seconds)

**Verify all services are running:**

```bash
# Check all services
echo "=== Service Status ===" && \
curl -s http://localhost:5522/api/app/get_system_info/v1 | jq '.status' && \
curl -s http://localhost:9000/health | jq '.status' && \
curl -s http://localhost:8501/ &>/dev/null && echo "Streamlit OK" || echo "Streamlit FAILED"

# Results:
# ✅ xyOps: 200 OK
# ✅ Compute-Agent: 200 OK  
# ✅ Streamlit: 200 OK
```

---

## 2️⃣ Send Test Alert (1 minute)

**Fire a test alert to the pipeline:**

```bash
# High Error Rate Alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "HighErrorRate",
        "service": "frontend-api",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Error rate above threshold",
        "description": "Error rate is 8.5% (threshold: 5%)"
      }
    }]
  }'

# Response:
# {"status": "accepted", "session_id": "abc123xyz"}
```

**Variations:**

```bash
# High Latency Alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "HighLatency",
        "service": "backend-api",
        "severity": "warning"
      },
      "annotations": {
        "summary": "P95 latency above threshold",
        "description": "P95 latency is 2.5 seconds (threshold: 1 second)"
      }
    }]
  }'

# Memory Pressure Alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "MemoryPressure",
        "service": "data-processor",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Memory usage critical",
        "description": "Memory usage 92% on node-3"
      }
    }]
  }'
```

---

## 3️⃣ Check Ticket Created (2 minutes)

**Verify ticket appeared in xyOps:**

```bash
# Get all tickets
curl -s 'http://localhost:5522/api/app/search/v1?q=AI&limit=10' | jq '.results[]'

# Or get the latest ticket:
curl -s 'http://localhost:5522/api/app/get_tickets/v1?limit=1&sort=created_desc' | jq '.tickets[0]'

# Expected fields in response:
# - title: "[AI] frontend-api — HighErrorRate (Severity: CRITICAL)"
# - description: (rich markdown with RCA + playbook)
# - status: "draft" or "approving"
```

**Grep for AI tickets:**

```bash
curl -s 'http://localhost:5522/api/app/get_tickets/v1?limit=100' | \
  jq '.tickets[] | select(.title | contains("AI")) | {id: .id, title: .title, status: .status}'

# Output:
# {
#   "id": "TICKET-2024-001",
#   "title": "[AI] frontend-api — HighErrorRate (Severity: CRITICAL)",
#   "status": "approving"
# }
```

---

## 4️⃣ Inspect Ticket Body (2 minutes)

**View what the AI generated:**

```bash
# Get ticket details
TICKET_ID="TICKET-2024-001"  # Replace with actual ID

curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq '.ticket | {title, description, status}' | head -50

# View full markdown body:
curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq -r '.ticket.description' | less
```

**Check for playbook section:**

```bash
curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq -r '.ticket.description' | grep -A 30 "Proposed Ansible"
```

---

## 5️⃣ Monitor Compute-Agent Logs (Real-Time)

**Watch the pipeline execute:**

```bash
# Follow logs
docker logs -f aiops-bridge 2>&1 | grep -E "Alert|step|Stage|confidence"

# In another terminal, send alert (step 2️⃣ above)

# Expected log output:
# 2026-03-22 10:15:30 Alert received | session=abc123
# 2026-03-22 10:15:32 Stage=logs_fetched | duration=2.1s
# 2026-03-22 10:15:35 Stage=metrics_fetched | duration=3.2s
# 2026-03-22 10:15:50 Stage=analyzed | confidence=HIGH | playbook_lines=32
# 2026-03-22 10:15:51 Stage=ticket_created | ticket_id=TICKET-2024-001
```

---

## 6️⃣ View Pipeline Session (Debug)

**Inspect all processing details:**

```bash
# Copy SESSION_ID from alert response (step 2️⃣)
SESSION_ID="abc123xyz"

# Get full session state
curl -s "http://localhost:9000/pipeline/session/$SESSION_ID" | jq '.'

# View specific fields:
curl -s "http://localhost:9000/pipeline/session/$SESSION_ID" | \
  jq '{session_id, stage, ticket_id, analysis: .analysis | {confidence, rca: .rca_summary, playbook_lines: (.ansible_playbook | length)}}'

# Output:
# {
#   "session_id": "abc123xyz",
#   "stage": "ticket_created",
#   "ticket_id": "TICKET-2024-001",
#   "analysis": {
#     "confidence": "HIGH",
#     "rca": "Backend connection pool exhaustion",
#     "playbook_lines": 32
#   }
# }
```

---

## 7️⃣ Check Ticket Comments with Step Updates

**View pipeline step feedback (auto-posted):**

```bash
TICKET_ID="TICKET-2024-001"

# Get all comments
curl -s "http://localhost:5522/api/app/get_ticket_comments/v1?id=$TICKET_ID" | jq '.comments[]'

# Get most recent comments (steps 1-5)
curl -s "http://localhost:5522/api/app/get_ticket_comments/v1?id=$TICKET_ID" | \
  jq '.comments[-5:] | .[] | {user: .user, created: .created, body: .body[:100]}'

# Expected output:
# {
#   "user": "aiops-bridge",
#   "created": "2026-03-22T10:15:32Z",
#   "body": "✅ Step 1: Logs fetched | 256 lines from Loki..."
# }
# {
#   "user": "aiops-bridge",
#   "created": "2026-03-22T10:15:35Z",
#   "body": "✅ Step 2: Metrics analyzed | 24h context fetched..."
# }
# ... etc
```

---

## 8️⃣ Streamlit Dashboard Access

**View real-time dashboard:**

```bash
# Start if not running
cd ui-streamlit && streamlit run app.py &

# Open browser
open http://localhost:8501

# Or from command line:
curl -s http://localhost:8501/_stcore/health | jq '.'
```

**Check dashboard sees data:**

```bash
# Dashboard page should show:
# - Compute: ✅ Healthy
# - Storage: ✅ Healthy  
# - Active Alerts: 1+
# - Risk Level: CRITICAL

# Pipeline View should show:
# - Session: abc123xyz
# - Steps: [✅ logs, ✅ metrics, ✅ analyze, ✅ ticket, ⏳ approval]

# Approvals page should show:
# - Pending: TICKET-2024-001 | frontend-api | HIGH
# - "View in xyOps" button
```

---

## 9️⃣ Approve Ticket & Trigger Playbook

**Simulate human approval:**

```bash
TICKET_ID="TICKET-2024-001"

# Get current status
curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq '.ticket.status'

# Expected: "approving"

# Approve via xyOps API:
curl -X POST "http://localhost:5522/api/app/approve_ticket/v1" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XYOPS_API_KEY" \
  -d "{
    \"id\": \"$TICKET_ID\",
    \"approved\": true,
    \"notes\": \"Approved by test suite\"
  }"

# Or manually in UI:
# 1. Open: http://localhost:5522 → Tickets
# 2. Find ticket with status "approving"
# 3. Click "Approve" button
# 4. Confirm
```

---

## 🔟 Monitor Ansible Execution

**Watch playbook run:**

```bash
# Follow ansible-runner logs
docker logs -f ansible-runner 2>&1 | grep -E "validate|run|PASSED|rc"

# Expected output:
# hostname=ansible-runner validate service=frontend-api alert=HighErrorRate
# hostname=ansible-runner run service=frontend-api
# TASK [Pre-validation: Assert baseline state]
# ok: [localhost] => {"assertion": "HTTP 200"}
# TASK [Remediate frontend-api]
# changed: [localhost] => {"msg": "Pool increased to 150"}
# TASK [Post-validation: Verify recovery]
# ok: [localhost] => {"assertion": "Error rate < 1%"}
# Return code: 0 (SUCCESS)
```

---

## 1️⃣1️⃣ Check Playbook Execution Results

**View final outcome in ticket:**

```bash
TICKET_ID="TICKET-2024-001"

# Get latest comments (execution results)
curl -s "http://localhost:5522/api/app/get_ticket_comments/v1?id=$TICKET_ID" | \
  jq '.comments[-2:] | .[] | {time: .created, body: .body[:200]}'

# Expected output:
# {
#   "time": "2026-03-22T10:16:15Z",
#   "body": "✅ Playbook execution result\nReturn code: 0\nPassed tests: 4/4\nDuration: 45 seconds"
# }
# {
#   "time": "2026-03-22T10:16:20Z",
#   "body": "✅ Incident resolved\nStatus: RESOLVED\nTotal time: 2m 45s"
# }
```

---

## 1️⃣2️⃣ View OpenTelemetry Trace (Optional)

**Deep-dive into execution timeline:**

```bash
# From session data, get trace ID
SESSION_ID="abc123xyz"
TRACE_ID=$(curl -s "http://localhost:9000/pipeline/session/$SESSION_ID" | jq -r '.bridge_trace_id')

# Click link to Grafana Tempo:
# http://localhost:3001/explore?orgId=1&left=%7B%22datasource%22:%22Tempo%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22queryType%22:%22search%22,%22serviceName%22:%22aiops-bridge%22,%22traceID%22:%22$TRACE_ID%22%7D%5D%7D

# Or open manually:
echo "Open in browser: http://localhost:3001"
echo "Then: Explore → Select Tempo datasource → Search for traceID: $TRACE_ID"
```

---

## 🧪 N8N Webhook Testing

**If N8N workflows enabled:**

```bash
# Test Pre-Enrichment Webhook
curl -X POST "http://localhost:5678/webhook/aiops/pre-enrichment" \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "frontend-api",
    "alert_name": "HighErrorRate",
    "severity": "critical"
  }'

# Test Post-Approval Webhook
curl -X POST "http://localhost:5678/webhook/aiops/post-approval" \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_id": "TICKET-2024-001",
    "alert_name": "HighErrorRate",
    "rca_summary": "Connection pool exhaustion",
    "confidence": "HIGH"
  }'

# Test Smart-Router Webhook
curl -X POST "http://localhost:5678/webhook/aiops/smart-router" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "HighCPU",
    "severity": "critical",
    "description": "CPU 95% for 5 minutes"
  }'

# Watch N8N execute
docker logs -f n8n | grep -E "webhook|execution|completed"
```

---

## 🔍 Common Issues & Quick Fixes

### Issue: Ticket Not Created

```bash
# Check compute-agent logs
docker logs aiops-bridge | tail -30 | grep -i "error\|exception"

# Verify xyOps reachable
curl -I "http://localhost:5522"

# Check API key in .env
grep XYOPS_API_KEY .env

# Restart if needed
docker restart aiops-bridge
```

### Issue: No Playbook Generated

```bash
# Check Ollama has models
curl http://localhost:11434/api/tags | jq '.models[]'

# If empty, pull a model
docker exec ollama ollama pull qwen2:7b

# Check LLM logs
docker logs aiops-bridge | grep -i "ollama\|llm"

# Restart
docker restart aiops-bridge
```

### Issue: Playbook Execution Failed

```bash
# Check ansible-runner logs
docker logs ansible-runner | tail -50

# Verify playbook YAML is valid
TICKET_ID="TICKET-2024-001"
curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq -r '.ticket.description' | grep -A 40 "Proposed Ansible" | \
  python3 -m yaml

# Check test case assertions
curl -s "http://localhost:5522/api/app/get_ticket_comments/v1?id=$TICKET_ID" | \
  jq '.comments[] | select(.body | contains("FAILED"))'
```

### Issue: Streamlit Can't Connect to Agents

```bash
# Check agents are running
docker ps | grep -E "compute|storage|obs"

# Check ports
netstat -tlnp | grep -E "9000|9001|9100"

# Test connectivity
curl http://localhost:9000/health
curl http://localhost:9001/health

# Check Streamlit .env
cat .env | grep -i "COMPUTE\|STORAGE\|OBS"

# Restart Streamlit
docker restart ui-streamlit
```

---

## 📊 Full Test Sequence Script

**Run complete flow end-to-end:**

```bash
#!/bin/bash
set -e

echo "🚀 Starting AIOps End-to-End Test"
echo ""

# 1. Health check
echo "1️⃣  Health check..."
curl -s http://localhost:9000/health | jq '.status' || echo "❌ Failed"
echo ""

# 2. Send alert
echo "2️⃣  Sending test alert..."
RESPONSE=$(curl -s -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "HighErrorRate",
        "service": "frontend-api",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Error rate above threshold",
        "description": "Error rate is 8.5%"
      }
    }]
  }')

SESSION_ID=$(echo "$RESPONSE" | jq -r '.session_id')
echo "Session ID: $SESSION_ID"
echo ""

# 3. Wait for ticket
echo "3️⃣  Waiting for ticket creation (30s)..."
sleep 30

# 4. Check ticket created
echo "4️⃣  Checking ticket..."
TICKET=$(curl -s 'http://localhost:5522/api/app/get_tickets/v1?limit=1&sort=created_desc' | jq '.tickets[0]')
TICKET_ID=$(echo "$TICKET" | jq -r '.id')
echo "Ticket ID: $TICKET_ID"
echo "Title: $(echo \"$TICKET\" | jq -r '.title')"
echo "Status: $(echo \"$TICKET\" | jq -r '.status')"
echo ""

# 5. Check Streamlit dashboard
echo "5️⃣  Dashboard accessible..."
curl -s http://localhost:8501/ &>/dev/null && echo "✅ Streamlit OK" || echo "❌ Failed"
echo ""

echo "✅ Test Complete!"
echo "Next steps:"
echo "1. Review ticket in xyOps: http://localhost:5522"
echo "2. Check dashboard: http://localhost:8501"
echo "3. Approve ticket manually"
echo "4. Monitor ansible execution in logs"
```

**Save and run:**

```bash
chmod +x test-flow.sh
./test-flow.sh
```

---

## 📋 Approval Workflow Test Script

**Test approval → execution flow:**

```bash
#!/bin/bash

TICKET_ID="${1:?Usage: $0 <TICKET_ID>}"

echo "Testing approval flow for $TICKET_ID..."
echo ""

# 1. Get current status
echo "1. Current status:"
curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq '.ticket.status'
echo ""

# 2. Approve
echo "2. Approving ticket..."
curl -X POST "http://localhost:5522/api/app/approve_ticket/v1" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"$TICKET_ID\", \"approved\": true}" | jq '.status'
echo ""

# 3. Monitor playbook execution
echo "3. Monitoring ansible execution (60s)..."
for i in {1..6}; do
  echo -n "."
  sleep 10
done
echo ""
echo ""

# 4. Check results
echo "4. Final ticket status:"
curl -s "http://localhost:5522/api/app/get_ticket/v1?id=$TICKET_ID" | \
  jq '.ticket | {status, resolved_at}'
echo ""

# 5. Show execution results
echo "5. Latest comments (execution results):"
curl -s "http://localhost:5522/api/app/get_ticket_comments/v1?id=$TICKET_ID" | \
  jq '.comments[-1] | {user, body: .body[:200]}'
```

**Usage:**

```bash
chmod +x approve-flow.sh
./approve-flow.sh TICKET-2024-001
```

---

**📌 Pro Tips:**
- Use `| jq '.'` to pretty-print JSON responses
- Use `| jq '.field'` to extract specific fields
- Use `| tail -N` to show last N lines
- Use `| grep pattern` to filter output
- Save TICKET_ID in env variable: `export TICKET_ID="TICKET-2024-001"`

