# 🚀 Docker Validation & N8N Onboarding Guide

Complete step-by-step guide to validate all containers and import N8N workflows.

---

## ✅ Docker Container Status Summary

**All containers are running and healthy:**

| Container | Status | Port | Purpose |
|-----------|--------|------|---------|
| ✅ aiops-bridge | Up 2h | 9000 | AIOps pipeline engine |
| ✅ n8n | Up 2h | 5679→5678 | Workflow orchestration |
| ✅ xyops | Up 2h | 5522-5523 | Ticketing system |
| ✅ compute-agent | Up 2h | - | AI computation agent |
| ✅ storage-agent | Up 2h | - | Data storage agent |
| ✅ ansible-runner | Up 2h | 8090 | Playbook execution |
| ✅ ollama | Up 2h | 11434 | Local LLM |
| ✅ prometheus | Up 2h | 9090 | Metrics DB |
| ✅ grafana | Up 2h | 3001 | Visualization |
| ✅ loki | Up 2h | 3100 | Log aggregation |
| ✅ tempo | Up 2h | 3200 | Trace storage |
| ✅ AlertManager | Up 2h | 9093 | Alert routing |
| ✅ gitea | Up 2h | 3002 | Git repository |
| ✅ otel-collector | Up 2h | 4317-4318 | Telemetry collection |

**Status:** 🟢 **ALL HEALTHY** — Ready for N8N workflow import

---

## 📁 N8N Workflows Located  

**Found at:** `/Volumes/Data/Codehub/xyopsver2/N8N/`

```
N8N/
├── n8n_workflows_01_pre_enrichment_agent.json      (✅ 220 lines)
├── n8n_workflows_02_post_approval_agent.json       (✅ 220 lines)
└── n8n_workflows_03_smart_router_agent.json        (✅ 220 lines)
```

**All workflows are:**
- ✅ Valid JSON (syntax checked)
- ✅ Ready to import
- ✅ Fully documented
- ✅ Contains webhook configurations

---

## 🎯 N8N Onboarding Steps (15 minutes)

### Step 1: Access N8N Web UI

```bash
open http://localhost:5679
# or
curl http://localhost:5679/health | jq '.'
```

**Expected response:**
```json
{
  "status": "ok",
  "database": "sqlite",
  "authRequired": false
}
```

---

### Step 2: Import Workflow 1 — Pre-Enrichment Agent

#### 2.1: Open N8N UI
- Go to: `http://localhost:5679`
- Click **"Workflows"** tab (left sidebar)
- Click **"Import"** button

#### 2.2: Select JSON File
- Click **"Select file"**
- Navigate to: `/Volumes/Data/Codehub/xyopsver2/N8N/`
- Select: **`n8n_workflows_01_pre_enrichment_agent.json`**
- Click **"Import"**

#### 2.3: Verify Nodes Loaded
N8N UI should show:
```
✓ Webhook Trigger node
✓ Code node (metadata extraction)
✓ HTTP node (CMDB lookup)
✓ HTTP node (Bridge API call)
✓ Response node
```

#### 2.4: Check Webhook Config
1. Double-click **Webhook** node
2. Verify:
   - **Path:** `/webhook/aiops/pre-enrichment`
   - **Method:** `POST`
   - **Response:** Send response
3. Click **"Save"** → **"Deploy"**

#### 2.5: Test the Workflow
```bash
curl -X POST http://localhost:5679/webhook/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "backend-api",
    "alert_name": "DiskSpaceHigh",
    "severity": "warning",
    "description": "Disk usage 85%"
  }'
```

**Expected:** Workflow executes successfully (visible in N8N UI → Executions tab)

---

### Step 3: Import Workflow 2 — Post-Approval Agent

#### 3.1: Import Workflow
- **Workflows** → **Import**
- Select: **`n8n_workflows_02_post_approval_agent.json`**
- Click **"Import"**

#### 3.2: Verify Webhook Config
1. Double-click **Webhook** node
2. Verify:
   - **Path:** `/webhook/aiops/post-approval`
   - **Method:** `POST`
3. Click **"Deploy"**

#### 3.3: Test Webhook
```bash
curl -X POST http://localhost:5679/webhook/aiops/post-approval \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_id": "TICKET-001",
    "alert_name": "MemoryLeak",
    "rca_summary": "Node.js memory growing unbounded",
    "confidence": "high"
  }'
```

**Expected:** Workflow triggers (watch N8N Executions tab for completion)

---

### Step 4: Import Workflow 3 — Smart-Router Agent

#### 4.1: Import Workflow
- **Workflows** → **Import**
- Select: **`n8n_workflows_03_smart_router_agent.json`**
- Click **"Import"**

#### 4.2: Verify Configuration
1. Check **Webhook** node:
   - **Path:** `/webhook/aiops/smart-router`
   - **Method:** `POST`
2. Check **Prometheus node** (if exists):
   - Should point to: `http://prometheus:9090`
3. Check **Ollama node** (if exists):
   - Should point to: `http://ollama:11434`
4. Click **"Deploy"**

#### 4.3: Test Webhook
```bash
curl -X POST http://localhost:5679/webhook/aiops/smart-router \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "HighCPU",
    "severity": "critical",
    "description": "CPU utilization at 95% for 10 minutes"
  }'
```

**Expected:** Workflow routes to appropriate LLM model (check Executions tab)

---

## 🔍 Validation Checklist

### Docker Container Health

```bash
# 1. Check all services running
docker ps | grep -E "aiops-bridge|n8n|xyops|ansible-runner"

# 2. Check N8N specific health
curl http://localhost:5679/health | jq '.status' 

# 3. Check AIOps Bridge health
curl http://localhost:9000/health | jq '.status'

# 4. Check xyOps health
curl http://localhost:5522/health | jq '.status'
```

### N8N Workflow Import Status

**After importing all 3 workflows, verify in N8N UI:**

1. **Workflows page shows 3 workflows:**
   - `Pre-Enrichment Agent` ✓
   - `Post-Approval Agent` ✓
   - `Smart-Router Agent` ✓

2. **Each workflow has green checkmark** (deployed)

3. **Click each workflow → Executions tab:** Should show recent test executions

---

## ⚙️ Configuration Files to Update

### .env File Requirements

Verify `.env` has N8N section:

```bash
# Extract N8N config from .env
grep -i "N8N\|enable" .env | head -10
```

**Expected output:**
```
ENABLE_N8N=true
N8N_WEBHOOK_URL=http://n8n:5679
N8N_PATTERN=pre-enrichment  # or post-approval or smart-router
N8N_PRE_ENRICHMENT_WEBHOOK=http://n8n:5679/webhook/aiops/pre-enrichment
N8N_POST_APPROVAL_WEBHOOK=http://n8n:5679/webhook/aiops/post-approval
N8N_SMART_ROUTER_WEBHOOK=http://n8n:5679/webhook/aiops/smart-router
```

If not present, update `.env`:
```bash
cat >> .env << 'EOF'

# N8N Integration
ENABLE_N8N=true
N8N_WEBHOOK_URL=http://n8n:5679
N8N_PATTERN=pre-enrichment
N8N_PRE_ENRICHMENT_WEBHOOK=http://n8n:5679/webhook/aiops/pre-enrichment
N8N_POST_APPROVAL_WEBHOOK=http://n8n:5679/webhook/aiops/post-approval
N8N_SMART_ROUTER_WEBHOOK=http://n8n:5679/webhook/aiops/smart-router
EOF
```

Then restart compute-agent:
```bash
docker restart aiops-bridge
```

---

## 🧪 Quick Test: End-to-End Flow

After importing workflows, test the complete integration:

### Test 1: Send Alert (2 min)

```bash
# Send alert to compute-agent
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
        "description": "Error rate is 8.5%"
      }
    }]
  }'
```

**Watch for:**
- compute-agent logs: `docker logs -f aiops-bridge | grep -i "alert\|n8n"`
- N8N Executions: Check if pre-enrichment workflow triggered

### Test 2: Monitor in N8N UI (3 min)

1. Open N8N: `http://localhost:5679`
2. Click **Pre-Enrichment Agent** workflow
3. Click **Executions** tab
4. Should see recent execution with:
   - Input: Your alert JSON
   - Output: Enriched data

### Test 3: Check xyOps Ticket (3 min)

1. Open xyOps: `http://localhost:5522`
2. Navigate to **Tickets** tab
3. Look for: `[AI] frontend-api — HighErrorRate`
4. Verify ticket has:
   - RCA in description
   - Ansible playbook
   - Test plan

### Test 4: Monitor Approval Flow (2 min)

1. Ticket should transition to `approving` status
2. Check N8N Post-Approval Executions:
   - If Slack configured, check for approval message
3. Approve in xyOps
4. Check N8N logs: `docker logs -f n8n`

---

## 🐛 Troubleshooting

### Issue: N8N Webhook Not Triggered by compute-agent

**Debug steps:**

```bash
# 1. Verify N8N is reachable
curl http://localhost:5679/health | jq '.status'

# 2. Check if workflow is DEPLOYED (not just saved)
# → N8N UI: Workflow should have green checkmark

# 3. Check compute-agent logs for N8N calls
docker logs aiops-bridge | grep -i "n8n\|webhook" | tail -20

# 4. Verify .env has N8N enabled
grep "ENABLE_N8N" .env

# 5. If not enabled, update and restart
echo "ENABLE_N8N=true" >> .env
docker restart aiops-bridge
```

### Issue: N8N Workflow Import Fails

**Solution:**

```bash
# 1. Verify JSON syntax is valid
python3 -m json.tool /Volumes/Data/Codehub/xyopsver2/N8N/n8n_workflows_01_pre_enrichment_agent.json > /dev/null && echo "✅ Valid JSON"

# 2. Check N8N logs for import errors
docker logs n8n | tail -50

# 3. Try manual workflow creation instead
# → See N8N-SETUP-GUIDE.md for step-by-step manual creation
```

### Issue: Webhook Path Mismatch

**Verify webhook paths match:**

```bash
# Expected paths:
# - /webhook/aiops/pre-enrichment
# - /webhook/aiops/post-approval
# - /webhook/aiops/smart-router

# Test each one:
for path in pre-enrichment post-approval smart-router; do
  echo "Testing: /webhook/aiops/$path"
  curl -X POST http://localhost:5679/webhook/aiops/$path \
    -H "Content-Type: application/json" \
    -d '{"test": "data"}' 2>&1 | head -5
done
```

---

## 📊 Monitoring Commands

### Watch N8N Executions Real-Time

```bash
# Stream N8N logs
docker logs -f n8n --tail=50 | grep -E "Webhook.*trigger|Execution|error"
```

### Check All Service Health

```bash
#!/bin/bash
echo "Service Health Check:"
echo "===================="

services=(
  "aiops-bridge:9000"
  "n8n:5679"
  "xyops:5522"
  "ansible-runner:8090"
)

for svc in "${services[@]}"; do
  name="${svc%:*}"
  port="${svc#*:}"
  status=$(curl -s http://localhost:$port/health | jq -r '.status // "error"' 2>/dev/null)
  if [ "$status" = "ok" ]; then
    echo "✅ $name ($port): $status"
  else
    echo "❌ $name ($port): $status"
  fi
done
```

### List All N8N Webhooks

```bash
curl http://localhost:5679/rest/webhooks | jq '.data[] | {path, method}'
```

---

## 📈 Next Steps After Onboarding

1. **Test each workflow individually** (see Quick Test section)
2. **Enable N8N in compute-agent** (set `ENABLE_N8N=true`)
3. **Choose a pattern** (pre-enrichment, post-approval, or smart-router) in `.env`
4. **Send test alert** to validate end-to-end flow
5. **Monitor in Streamlit dashboard** (`http://localhost:8501`)
6. **Review results in xyOps tickets** (`http://localhost:5522`)

---

## 📚 Reference URLs

| Service | URL | Purpose |
|---------|-----|---------|
| N8N Workflows | `http://localhost:5679` | Import/manage workflows |
| AIOps Bridge | `http://localhost:9000` | Incident pipeline |
| xyOps Tickets | `http://localhost:5522` | Ticketing system |
| Grafana | `http://localhost:3001` | Metrics/traces/logs |
| Prometheus | `http://localhost:9090` | Metrics DB |
| AlertManager | `http://localhost:9093` | Alert routing |
| Streamlit | `http://localhost:8501` | Real-time dashboard |

---

## ✅ Success Criteria

You've successfully completed the N8N onboarding when:

1. ✅ All 3 N8N workflows imported
2. ✅ Each workflow shows green checkmark (deployed)
3. ✅ Webhook paths correctly configured
4. ✅ Test curl commands execute without errors
5. ✅ Workflows appear in N8N Executions tab
6. ✅ compute-agent can call N8N webhooks
7. ✅ Tickets created in xyOps show evidence of N8N enrichment

---

**Ready to start? Begin with Step 1 above! 🚀**
