# 🧪 N8N Testing Guide — Complete Workflow Setup & Validation

---

## 📊 Overview

This guide walks you through testing the N8N integration with xyOps. You'll:

1. **Access N8N UI** (port 5679)
2. **Import 3 pre-built workflows** from `/Volumes/Data/Codehub/xyopsver2/N8N/`
3. **Configure webhook URLs** for each workflow
4. **Test each workflow** with sample data
5. **Verify end-to-end flow** with test alerts

**Testing Timeline:** ~30 minutes total

---

## 🎯 Part 1: Access N8N & Verify Service

### 1.1 Check N8N Service

```bash
# Verify N8N is running
docker ps | grep n8n

# Expected output:
# n8n          Up 2 hours    5679/tcp

# If not running, start it
docker-compose up -d n8n

# Check logs
docker logs n8n | tail -20
```

### 1.2 Open N8N UI

**URL:** http://localhost:5679

You should see:
- N8N dashboard
- "Workflows" tab on the left
- "Create new" button
- Empty workflow list (first time)

**Note:** N8N doesn't have login/password in development mode.

---

## ✅ Part 2: Import Workflows

### 2.1 Workflow Files Location

All 3 workflows are pre-built and ready to import:

```bash
ls -lh /Volumes/Data/Codehub/xyopsver2/N8N/
```

**Files:**
- `n8n_workflows_01_pre_enrichment_agent.json` (4.4 KB)
- `n8n_workflows_02_post_approval_agent.json` (1.4 KB)
- `n8n_workflows_03_smart_router_agent.json` (3.5 KB)

### 2.2 Import Workflow #1: Pre-Enrichment Agent

**Purpose:** Enrich alerts with CMDB context before AI analysis

**Steps:**

1. **Open N8N:** http://localhost:5679
2. **Click:** "Workflows" → "+" (New)
3. **Click:** "Choose a workflow"
4. **Select:** "Import from file"
5. **Browse:** `/Volumes/Data/Codehub/xyopsver2/N8N/n8n_workflows_01_pre_enrichment_agent.json`
6. **Click:** "Import"

**Expected result:**
```
Workflow loaded with nodes:
  ├─ Webhook (trigger)
  ├─ Enrich: Extract Metadata
  ├─ CMDB: Lookup Service
  ├─ Merge: CMDB Enrichment
  ├─ Send: To AIOps Bridge
  └─ Respond: Success
```

**Status:** Workflow appears in UI (not yet activated)

### 2.3 Import Workflow #2: Post-Approval Agent

**Purpose:** Slack-based human approval before remediation

**Steps:**

1. **Click:** "Workflows" tab
2. **Click:** "+" (New)
3. **Select:** "Import from file"
4. **Browse:** `/Volumes/Data/Codehub/xyopsver2/N8N/n8n_workflows_02_post_approval_agent.json`
5. **Click:** "Import"

**Expected result:**
```
Workflow loaded with nodes:
  ├─ Webhook (trigger)
  ├─ Slack: Send Approval Message
  │  └─ Interactive buttons (Approve/Reject/Info)
  ├─ Decision: Branch on response
  ├─ Bridge: Create Ticket
  └─ Respond: Decision Result
```

**Status:** Workflow appears in UI

### 2.4 Import Workflow #3: Smart Router

**Purpose:** Choose optimal LLM model based on system state

**Steps:**

1. **Click:** "Workflows" tab
2. **Click:** "+" (New)
3. **Select:** "Import from file"
4. **Browse:** `/Volumes/Data/Codehub/xyopsver2/N8N/n8n_workflows_03_smart_router_agent.json`
5. **Click:** "Import"

**Expected result:**
```
Workflow loaded with nodes:
  ├─ Webhook (trigger)
  ├─ Prometheus: Check System CPU
  ├─ Prometheus: Check System Memory
  ├─ Ollama: Check Available Models
  ├─ Code: Smart Routing Decision
  ├─ Bridge: Analyze with Selected Model
  └─ Respond: Routing Result
```

**Status:** Workflow appears in UI

---

## 🔧 Part 3: Configure Webhooks

### 3.1 Webhook Configuration (Pre-Enrichment)

**What is a webhook?**
A webhook is a URL that N8N exposes for incoming requests. When AIOps Bridge sends data to the webhook, the workflow triggers.

**Steps to make Pre-Enrichment active:**

1. **Open Workflow #1:** "Pre-Enrichment Agent"
2. **Click:** Webhook node (first node)
3. **Copy:** Webhook URL shown in the node details
   - Format: `http://n8n:5678/webhook/...`
4. **Update .env** with this URL:
   ```bash
   nano /Volumes/Data/Codehub/xyopsver2/.env
   
   # Find or add:
   N8N_PATTERN=pre-enrichment
   N8N_PRE_ENRICHMENT_WEBHOOK=<paste webhook URL>
   ```
5. **Save file**
6. **Restart AIOps Bridge:**
   ```bash
   docker restart aiops-bridge
   ```

**Verify:**
```bash
# Check logs for webhook URL
docker logs aiops-bridge | grep -i "pre-enrichment\|webhook"

# Should see: "Triggering n8n pre-enrichment agent"
```

### 3.2 Webhook Configuration (Post-Approval)

**Steps:**

1. **Open Workflow #2:** "Post-Approval Agent"
2. **Click:** Webhook node
3. **Copy:** Webhook URL
4. **Update .env:**
   ```bash
   N8N_POST_APPROVAL_WEBHOOK=<paste webhook URL>
   ```
5. **Save & restart AIOps Bridge**

### 3.3 Webhook Configuration (Smart Router)

**Steps:**

1. **Open Workflow #3:** "Smart Router"
2. **Click:** Webhook node
3. **Copy:** Webhook URL
4. **Update .env:**
   ```bash
   N8N_PATTERN=smart-router
   N8N_SMART_ROUTER_WEBHOOK=<paste webhook URL>
   ```
5. **Save & restart AIOps Bridge**

### 3.4 Final .env Configuration

```bash
# After configuring all three:

# Enable N8N integration
ENABLE_N8N=true

# Choose primary pattern
N8N_PATTERN=pre-enrichment  # or post-approval or smart-router

# Webhook URLs (copy from N8N UI)
N8N_PRE_ENRICHMENT_WEBHOOK=http://n8n:5678/webhook/aiops/pre-enrichment
N8N_POST_APPROVAL_WEBHOOK=http://n8n:5678/webhook/aiops/approval
N8N_SMART_ROUTER_WEBHOOK=http://n8n:5678/webhook/aiops/router

# Security
N8N_WEBHOOK_TOKEN=your-secret-token
N8N_HMAC_SECRET=your-hmac-secret
```

---

## 🚀 Part 4: Activate Workflows

### 4.1 Activate Pre-Enrichment

**In N8N UI:**

1. **Open:** Workflow #1 (Pre-Enrichment Agent)
2. **Top right:** Toggle switch → **ON** (green)
3. **Wait:** "Webhook is now listening"
4. **Status:** Workflow shows as "Active"

### 4.2 Activate Post-Approval

**In N8N UI:**

1. **Open:** Workflow #2 (Post-Approval Agent)
2. **Top right:** Toggle switch → **ON**
3. **Status:** Workflow shows as "Active"

### 4.3 Activate Smart Router

**In N8N UI:**

1. **Open:** Workflow #3 (Smart Router)
2. **Top right:** Toggle switch → **ON**
3. **Status:** Workflow shows as "Active"

### 4.4 Verify All Active

**Command:**
```bash
# Check N8N API for active workflows
curl -s http://localhost:5679/api/v1/workflows | jq '.data[] | {id, name, active}'

# Expected output:
# {
#   "id": "1",
#   "name": "Pre-Enrichment Agent",
#   "active": true
# }
# {
#   "id": "2",
#   "name": "Post-Approval Agent",
#   "active": true
# }
# {
#   "id": "3",
#   "name": "Smart Router",
#   "active": true
# }
```

---

## 🧪 Part 5: Test Each Workflow

### 5.1 Test Workflow #1: Pre-Enrichment

**What it does:**
1. Receives alert data
2. Extracts metadata (service name, severity)
3. Queries CMDB for service information
4. Enriches data with context
5. Sends enriched data back to AIOps Bridge

**Test command:**
```bash
# Send test data to pre-enrichment webhook
curl -X POST http://localhost:5679/webhook/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "HighErrorRate",
    "service_name": "frontend-api",
    "severity": "warning",
    "summary": "High error rate detected",
    "description": "Error rate > 5% detected on frontend-api service",
    "dashboard_url": "http://localhost:3001"
  }'
```

**Expected response:**
```json
{
  "status": "success",
  "enriched_data": {
    "alert_name": "HighErrorRate",
    "service_name": "frontend-api",
    "cmdb_context": {
      "service_owner": "backend-team",
      "sla": "99.9%",
      "dependencies": ["postgres", "redis"]
    }
  }
}
```

**In N8N UI:**
1. **Open:** Workflow #1
2. **Click:** Executions tab
3. **Should show:** Recent execution with status "completed"

### 5.2 Test Workflow #2: Post-Approval

**What it does:**
1. Receives analysis result from AIOps
2. Sends interactive Slack message with approve/reject buttons
3. Waits for user decision
4. Creates ticket based on decision
5. Returns result

**Test via Slack (if integrated):**
```bash
# This requires Slack webhook integration
# For testing without Slack, use the N8N test function

# In N8N UI:
# 1. Click Workflow #2
# 2. Click "Test Workflow" button
# 3. N8N will prompt for input
# 4. Enter sample decision data
# 5. Watch execution flow
```

**Alternative: Use manual webhook test:**
```bash
curl -X POST http://localhost:5679/webhook/aiops/approval \
  -H "Content-Type: application/json" \
  -d '{
    "analysis_result": {
      "rca": "Database connection pool exhausted",
      "risk_score": 0.85,
      "recommendation": "Increase pool size from 10 to 25"
    },
    "approval_required": true
  }'
```

### 5.3 Test Workflow #3: Smart Router

**What it does:**
1. Checks Prometheus for CPU/memory metrics
2. Queries Ollama for available models
3. Decides which model to use based on:
   - If CPU > 80% → Use fast model (Mistral)
   - If memory low → Use lightweight model (Llama 3.2)
   - If context large → Use reasoning model
   - Default → Qwen2:7b (balanced)
4. Returns routing decision

**Test command:**
```bash
curl -X POST http://localhost:5679/webhook/aiops/router \
  -H "Content-Type: application/json" \
  -d '{
    "alert_data": {
      "alert_name": "ComplexErrorPattern",
      "severity": "critical",
      "context_length": 8000
    },
    "system_state": {
      "cpu_usage": 45,
      "memory_usage": 62,
      "available_models": ["qwen2:7b", "mistral:latest", "llama2:13b"]
    }
  }'
```

**Expected response:**
```json
{
  "selected_model": "qwen2:7b",
  "reason": "Balanced model for moderate CPU/memory and medium context",
  "routing_decision": {
    "model": "qwen2:7b",
    "temperature": 0.7,
    "max_tokens": 2048
  }
}
```

---

## 🔗 Part 6: Full End-to-End Test

### 6.1 Complete Flow: Alert → Enrichment → AIOps → xyOps

**Step 1: Send test alert**
```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "HighErrorRate",
        "service_name": "frontend-api",
        "severity": "warning"
      },
      "annotations": {
        "summary": "High error rate detected",
        "description": "Error rate exceeded 5% threshold for 1 minute",
        "dashboard_url": "http://localhost:3001/d/frontend"
      },
      "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }]
  }'
```

**Step 2: Monitor N8N execution**

In N8N UI, watch the Pre-Enrichment workflow execute:
- Webhook receives alert
- Metadata extracted
- CMDB queried
- Data enriched
- Sent back to AIOps Bridge

Button to watch: Click workflow → "Executions" tab

**Step 3: Monitor AIOps Bridge**

```bash
# Watch logs in real-time
docker logs -f aiops-bridge | grep -E "n8n|enrichment|webhook|ticket"

# Should see:
# - "Triggering n8n pre-enrichment agent"
# - "N8N response received"
# - "Creating ticket in xyOps"
```

**Step 4: Verify Ticket in xyOps**

```bash
# Check xyOps UI
open http://localhost:5522
# Login: admin / admin
# Click: Tickets tab
# Should see: New ticket with enriched data
```

**Step 5: Monitor Traces in Tempo**

```bash
# Open Grafana
open http://localhost:3001

# Navigate: Explore → Tempo
# Search: Service: aiops-bridge
# Click: Trace from the alert webhook call
# Should see child spans for:
#   - N8N pre-enrichment call
#   - CMDB query
#   - xyOps ticket creation
```

---

## 📈 Part 7: Testing Scenarios

### Scenario 1: High CPU Load (Smart Router Test)

**Expected behavior:** Smart Router chooses fast model (Mistral)

```bash
# Simulate high CPU alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "labels": {
        "alertname": "HighCPU",
        "service_name": "backend-api",
        "severity": "critical"
      },
      "annotations": {
        "summary": "CPU usage critical (95%)",
        "description": "CPU on backend-api node exceeded 95%"
      }
    }]
  }'
```

**In N8N:**
- Watch Smart Router execute
- See CPU check → results in "Mistral" model selection
- Verify routing decision logged

### Scenario 2: Complex Issue (Reasoning Model Test)

**Expected behavior:** Smart Router chooses reasoning model

```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "labels": {
        "alertname": "ComplexErrorPattern",
        "service_name": "compute-agent",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Multi-service issue detected",
        "description": "Database errors + API timeouts + rate limiting all triggered simultaneously. This appears to be a cascading failure starting from..."
      }
    }]
  }'
```

**In N8N:**
- Watch Smart Router detect large context
- See model selection → Reasoning model
- Verify AIOps uses selected model

### Scenario 3: Low Memory (Lightweight Model Test)

**Expected behavior:** Smart Router chooses lightweight model

```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "labels": {
        "alertname": "LowMemory",
        "service_name": "storage-agent",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Memory pressure detected (88%)",
        "description": "Available memory dropped below 12%"
      }
    }]
  }'
```

**In N8N:**
- Watch Smart Router check memory
- See model selection → Llama 3.2 (lightweight)
- Verify execution completes without issues

---

## 🔍 Part 8: Monitoring & Debugging

### 8.1 View N8N Workflow Executions

**In N8N UI:**
1. **Click:** Workflow (any)
2. **Click:** "Executions" tab (bottom)
3. **Shows:** All recent runs with status

**Color codes:**
- 🟢 Green: Successful execution
- 🔴 Red: Failed execution
- 🟡 Yellow: Running/pending

### 8.2 Check N8N Logs

```bash
# View N8N container logs
docker logs n8n | tail -50

# Watch logs in real-time
docker logs -f n8n | grep -i "error\|webhook\|execution"
```

### 8.3 Monitor API Responses

```bash
# Check N8N health
curl -s http://localhost:5679/health | jq

# Expected:
{
  "status": "ok",
  "uptime": 12345.67
}

# List all workflows
curl -s http://localhost:5679/api/v1/workflows | jq '.data | length'
# Shows: 3 (if all imported)
```

### 8.4 Debug Failed Executions

**If workflow fails:**

1. **In N8N UI:**
   - Open workflow
   - Click "Executions"
   - Click failed execution
   - See error message in "Output" panel

2. **Common issues:**
   - Webhook not triggered → Check webhook URL in .env
   - Connection error → Check if service (xyOps, Ollama) is running
   - Timeout → Increase timeout in workflow settings

### 8.5 Trace Full Request

```bash
# Using trace ID from alert response
TRACE_ID="abc123xyz"

# Search in Tempo
curl -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode "query={trace_id=\"$TRACE_ID\"}" | jq
```

---

## ✅ Part 9: Validation Checklist

### N8N Service

```bash
□ Container running
  docker ps | grep n8n

□ UI accessible
  open http://localhost:5679

□ Webhook available
  curl http://localhost:5679/health

□ Can access workflows list
  curl http://localhost:5679/api/v1/workflows
```

### Workflows

```bash
□ Workflow #1 (Pre-Enrichment)
  ├─ Imported ✅
  ├─ Active (toggle ON) ✅
  └─ Webhook URL copied to .env ✅

□ Workflow #2 (Post-Approval)
  ├─ Imported ✅
  ├─ Active (toggle ON) ✅
  └─ Webhook URL copied to .env ✅

□ Workflow #3 (Smart Router)
  ├─ Imported ✅
  ├─ Active (toggle ON) ✅
  └─ Webhook URL copied to .env ✅
```

### Integration

```bash
□ .env updated with webhook URLs
  grep N8N_PRE_ENRICHMENT_WEBHOOK /Volumes/Data/Codehub/xyopsver2/.env

□ AIOps Bridge restarted
  docker restart aiops-bridge

□ N8N pattern selected
  grep N8N_PATTERN /Volumes/Data/Codehub/xyopsver2/.env

□ N8N integration enabled
  grep ENABLE_N8N /Volumes/Data/Codehub/xyopsver2/.env
```

### Testing

```bash
□ Test alert sent successfully
□ N8N workflow executed
□ Ticket created in xyOps
□ Trace ID visible in Tempo
□ Logs show workflow progression
□ No errors in any logs
```

---

## 📊 Expected Output Timeline

```
T=0s:   Alert sent to http://localhost:9000/webhook
        └─ Response: {"status": "processed"}

T=0-1s: AIOps Bridge processes alert
        └─ Creates OTel span

T=1s:   N8N pre-enrichment triggered
        └─ POST http://n8n:5678/webhook/aiops/pre-enrichment

T=2-3s: Pre-enrichment workflow executes
        ├─ Extract metadata
        ├─ Query CMDB
        ├─ Merge enrichment
        └─ Return enriched data

T=3s:   AIOps Bridge receives enriched data
        └─ Calls Ollama for AI analysis

T=4-5s: Ollama generates RCA + playbook
        └─ AIOps creates xyOps ticket

T=5s:   Ticket visible in xyOps UI
        ├─ Status: open
        ├─ Body: enriched data + AI analysis
        └─ Tags: alert name, service, severity

TOTAL:  ~5 seconds from alert to ticket
```

---

## 🎯 Summary

| Component | Status | Expected |
|-----------|--------|----------|
| **N8N Service** | Running | Port 5679 active |
| **3 Workflows** | Imported | All show in dashboard |
| **Webhooks** | Configured | URLs in .env |
| **Activations** | On | All green toggles |
| **First Alert** | Sent | N8N executes |
| **Ticket** | Created | xyOps shows ticket #1 |
| **Traces** | Recorded | Tempo shows spans |

---

## 🚀 Next Steps

1. **Open N8N:** http://localhost:5679
2. **Import 3 workflows** from `/Volumes/Data/Codehub/xyopsver2/N8N/`
3. **Copy webhook URLs** to .env
4. **Activate all workflows** (green toggles)
5. **Restart AIOps:** `docker restart aiops-bridge`
6. **Send test alert:** See curl command above
7. **Verify:** Check xyOps, Tempo, N8N logs

---

**Status:** 🟢 **READY FOR TESTING**  
**Duration:** 30 minutes start-to-finish  
**Next:** Follow Part 2.1 to start importing workflows

✨ Ready to test with N8N? Open http://localhost:5679 now! ✨
