# 🚀 N8N Testing — Quick Start (5 Minutes)

**Status:** ✅ All services running
- N8N: `http://localhost:5679` (port 5679)
- xyOps: `http://localhost:5522` (port 5522)
- AIOps Bridge: `http://localhost:9000` (port 9000)

---

## 📋 Quick Checklist — Do This in Order

### Step 1: Open N8N (30 seconds)
```bash
open http://localhost:5679
```

You should see N8N dashboard with "Workflows" tab on left.

---

### Step 2: Import Workflow #1 – Pre-Enrichment (2 minutes)

**In N8N UI:**

1. Click: **"Workflows"** tab (left sidebar)
2. Click: **"+" button** (New workflow)
3. Click: **"Manage workflows"** at top
4. Click: **"Import from file"**
5. Select: `/Volumes/Data/Codehub/xyopsver2/N8N/n8n_workflows_01_pre_enrichment_agent.json`
6. Click: **"Import"**
7. Result: Workflow #1 appears in list

**Then activate it:**
1. Click: Workflow name (Pre-Enrichment Agent)
2. Top right: Find **toggle switch** → Click to turn **ON** (green)
3. Wait: "Webhook is now listening"

---

### Step 3: Import Workflow #2 – Post-Approval (1 minute)

Repeat Step 2 for:
- File: `n8n_workflows_02_post_approval_agent.json`
- Then activate (green toggle)

---

### Step 4: Import Workflow #3 – Smart Router (1 minute)

Repeat Step 2 for:
- File: `n8n_workflows_03_smart_router_agent.json`
- Then activate (green toggle)

---

### Step 5: Copy Webhook URLs (1 minute)

For each workflow:

1. **Open** Workflow #1
2. **Click** first node (Webhook)
3. **Copy** the webhook URL shown (looks like: `http://n8n:5678/webhook/...`)
4. **Save** it somewhere

Do this for all 3 workflows.

---

### Step 6: Update .env with Webhook URLs

```bash
# Edit .env
nano /Volumes/Data/Codehub/xyopsver2/.env

# Find "N8N" section (around line 70)
# Add/update:

ENABLE_N8N=true
N8N_PATTERN=pre-enrichment

N8N_PRE_ENRICHMENT_WEBHOOK=<paste webhook #1 URL>
N8N_POST_APPROVAL_WEBHOOK=<paste webhook #2 URL>
N8N_SMART_ROUTER_WEBHOOK=<paste webhook #3 URL>

# Save: Ctrl+O → Enter → Ctrl+X
```

---

### Step 7: Restart AIOps Bridge

```bash
docker restart aiops-bridge

# Wait 5 seconds for restart

# Verify:
docker logs aiops-bridge | grep -i "n8n\|pattern"
# Should show: "N8N integration enabled" or similar
```

---

## ✅ Verify Everything Works

### Check All 3 Workflows Active

```bash
open http://localhost:5679
# Click: Workflows tab
# Should see: 3 workflows with green status indicators
```

### Send Test Alert

```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "service_name": "frontend-api",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Test alert from N8N testing",
        "description": "Verifying N8N workflow integration",
        "dashboard_url": "http://localhost:3001"
      },
      "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }]
  }'
```

### Watch N8N Execute

1. **Go to N8N:** `http://localhost:5679`
2. **Click:** Workflow #1 (Pre-Enrichment)
3. **Click:** "Executions" tab (bottom)
4. **Should see:** New execution with green status ✅

### Verify Ticket Created in xyOps

1. **Go to xyOps:** `http://localhost:5522`
2. **Login:** admin / admin
3. **Click:** "Tickets" tab
4. **Should see:** New ticket created with enriched data

---

## 📊 Full End-to-End Timeline

```
T=0s:   You send alert via curl to port 9000
        └─ Response: {"status": "processed"}

T=1s:   AIOps Bridge receives alert
        └─ Starting AI analysis

T=2s:   N8N pre-enrichment webhook triggered
        └─ N8N begins enrichment workflow

T=3s:   Pre-enrichment completes
        └─ Enriched data sent back to AIOps

T=4s:   AIOps gets AI response from Ollama
        └─ Ready to create ticket

T=5s:   xyOps ticket created
        ├─ Visible in UI immediately
        ├─ Contains: AI analysis + enrichment
        └─ Status: open

TOTAL:  ~5 seconds from alert to visible ticket!
```

---

## 🎯 3 Things to Try

### Test 1: Pre-Enrichment Workflow

**What it does:** Adds CMDB context to alert

```bash
curl -X POST http://localhost:5679/webhook/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "HighErrorRate",
    "service_name": "frontend-api",
    "severity": "warning"
  }'
```

**Result:** Returns enriched data with service details

### Test 2: Smart Router Workflow

**What it does:** Chooses optimal LLM model

```bash
curl -X POST http://localhost:5679/webhook/aiops/router \
  -H "Content-Type: application/json" \
  -d '{
    "alert_data": {
      "alert_name": "ComplexIssue",
      "severity": "critical",
      "context_length": 8000
    }
  }'
```

**Result:** Returns model routing decision (e.g., "mistral" or "qwen2:7b")

### Test 3: Full Alert Flow

(See "Send Test Alert" above)

**Result:** Ticket created in xyOps with full enrichment

---

## 🆘 Troubleshooting

### N8N not responding
```bash
# Check if running
docker ps | grep n8n

# If not running:
docker-compose up -d n8n

# Check logs:
docker logs n8n | tail -20
```

### Workflows won't activate
- ❌ "Webhook already in use" → Another workflow has same path
- ❌ "Permission denied" → Restart N8N container
- ✅ Solution: `docker restart n8n`

### Alert not triggering workflow
- ❌ Check webhook URL in .env matches N8N
- ❌ Check AIOps Bridge logs: `docker logs aiops-bridge | grep webhook`
- ❌ Verify AIOps restarted after .env change

### Ticket not appearing in xyOps
- ❌ Check xyOps is running: `docker ps | grep xyops`
- ❌ Check logs: `docker logs aiops-bridge | grep -i "xyops\|ticket"`
- ❌ Try accessing UI: `open http://localhost:5522`

---

## 📚 Full Documentation

For complete details, see: **[N8N-TESTING-GUIDE.md](N8N-TESTING-GUIDE.md)**

Contains:
- Detailed webhook configuration
- 3 complete test scenarios
- Debugging & monitoring
- Architecture diagrams
- Timeline breakdowns

---

## ✨ You're Ready!

**Next action:** Open http://localhost:5679 and start importing workflows

**Time to first test:** ~5 minutes

**Expected outcome:** Ticket created in xyOps with N8N enrichment applied

🚀 **Let's go!**
