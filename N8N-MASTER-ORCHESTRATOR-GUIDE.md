# 🤖 N8N Master Orchestrator — Complete Autonomous Workflow

## For Your Manager: "Here's How the Agents Talk"

When you run this workflow, your manager will see:

```
Alert comes in
    ↓
  [Agent #1] Pre-Enrichment
    ├─ CMDB lookup (Adds context)
    ├─ Service details
    └─ Historical data
    ↓
  [Agent #2] Smart Router (Parallel)
    ├─ Prometheus checks
    ├─ Model selection
    └─ Route decision
    ↓
  [Agent #3] AI Analysis
    ├─ Ollama processing
    ├─ Root cause analysis
    ├─ Recommendations
    └─ Auto-approval
    ↓
  [Decision Engine]
    ├─ Autonomous decision: "CREATE_TICKET"
    ├─ No human needed!
    └─ Full reasoning logged
    ↓
  [Ticket Created in xyOps]
    ├─ With enrichment data
    ├─ With AI analysis
    ├─ With trace ID
    └─ Ready for remediation
```

**All in ONE N8N diagram your manager can click through and see the agents working together.**

---

## Setup: Import & Connect (10 Minutes)

### Step 1: Import Master Orchestrator Workflow

```bash
open http://localhost:5679
```

**In N8N UI:**

1. Click: **Workflows** (left sidebar)
2. Click: **"+" button** (New workflow)
3. Click: **Manage workflows**
4. Click: **Import from file**
5. Select: `/Volumes/Data/Codehub/xyopsver2/N8N/n8n_workflows_00_master_orchestrator.json`
6. Click: **Import**

**Result:** You'll see a new workflow named:
- `🤖 AIOps Master Orchestrator - Complete Autonomous Workflow`

---

### Step 2: Verify All 4 Existing Workflows

The Master Orchestrator calls these 3 agents internally. Make sure they're still there:

1. Click: **Workflows** tab
2. You should see:
   - ✅ `n8n_workflows_00_master_orchestrator` (just imported)
   - ✅ `n8n_workflows_01_pre_enrichment_agent`
   - ✅ `n8n_workflows_02_post_approval_agent`
   - ✅ `n8n_workflows_03_smart_router_agent`

If any are missing, import them first (using N8N-QUICK-START.md Steps 2-4).

---

### Step 3: Activate ONLY the Master Orchestrator

**⚠️ IMPORTANT:** Only activate the Master workflow. The other 3 stay inactive (they're called from the Master).

1. Click: `🤖 AIOps Master Orchestrator` workflow
2. Top right: Find **toggle switch**
3. Click to turn **ON** (green)
4. Wait for: **"Webhook is now listening"**

You should see webhook URL:
```
http://localhost:5679/webhook/aiops/master
```

---

### Step 4: Copy Master Webhook URL to .env

```bash
nano /Volumes/Data/Codehub/xyopsver2/.env
```

Find the N8N section and add/update:

```bash
# Line ~70

ENABLE_N8N=true
N8N_PATTERN=master-orchestrator
N8N_MASTER_ORCHESTRATOR_WEBHOOK=http://n8n:5678/webhook/aiops/master

# Keep these if they exist (for manual testing):
N8N_PRE_ENRICHMENT_WEBHOOK=http://n8n:5678/webhook/aiops/pre-enrichment
N8N_POST_APPROVAL_WEBHOOK=http://n8n:5678/webhook/aiops/post-approval
N8N_SMART_ROUTER_WEBHOOK=http://n8n:5678/webhook/aiops/router

# Restart AIOps Bridge to pick up changes
```

**Save:** Ctrl+O → Enter → Ctrl+X

---

### Step 5: Update AIOps Bridge (Optional)

If you want all alerts to ONLY go through the Master Orchestrator:

Edit: `aiops-bridge/app/pipeline.py`

Find: `N8N webhook URL routing`

Add route for master orchestrator (usually the bridge already handles generic webhook patterns).

**Or restart to reload .env:**

```bash
docker restart aiops-bridge
docker logs aiops-bridge | grep -i "n8n"
```

---

## 🎬 DEMO TIME: Test for Your Manager

### Test 1: Show Single Alert → Complete Workflow

```bash
curl -X POST http://localhost:5679/webhook/aiops/master \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "DemoAlert_For_Manager",
        "service_name": "frontend-api",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Demonstrating autonomous multi-agent orchestration",
        "description": "Alert processed by 4 coordinated AI agents without human intervention",
        "dashboard_url": "http://localhost:3001"
      },
      "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }]
  }'
```

**Expected Response:**

```json
{
  "status": "orchestration_complete",
  "trace_id": "abc123def456",
  "alert": "DemoAlert_For_Manager",
  "service": "frontend-api",
  "agents_involved": [
    "Pre-Enrichment Agent",
    "Smart Router Agent",
    "AI Analysis Agent",
    "Autonomous Decision Agent"
  ],
  "decision": "CREATE_TICKET",
  "ticket_created": true,
  "workflow_duration_ms": 3250,
  "message": "Autonomous AIOps workflow completed - all agents executed successfully"
}
```

---

### Test 2: Show the Visual Workflow in N8N

1. Open N8N: `http://localhost:5679`
2. Click: `🤖 AIOps Master Orchestrator` workflow
3. **SHOW YOUR MANAGER:**
   - **Top to bottom flow:** Webhook → Alert Parse → Agents → Decision → Ticket
   - **Agent nodes (boxes):** 
     - 🔍 Pre-Enrichment (pulls CMDB)
     - 🎯 Smart Router (chooses LLM)
     - 🧠 AI Analysis (Ollama processes)
     - ⚡ Decision Logic (autonomous call)
   - **Data flow (arrows):** Shows data passing between agents
   - **Bottom node:** Creates ticket in xyOps

4. Click: **Executions** tab (bottom)
5. Should see: Recent execution logs with GREEN ✅ on all nodes

---

### Test 3: Show Ticket in xyOps (with AI Analysis)

```bash
open http://localhost:5522
# Login: admin / admin
# Click: Tickets
```

**Your manager sees:**
- New ticket created
- Subject: `[CRITICAL] DemoAlert_For_Manager on frontend-api`
- Body contains:
  - ✅ AI Generated Root Cause Analysis
  - ✅ CMDB enrichment (from Agent #1)
  - ✅ Model Selection decision (from Agent #2)
  - ✅ Trace ID linking back to N8N execution
  - ✅ No manual approval needed → Fully autonomous

---

### Test 4: Show Execution Details (Agent Communication)

In N8N, click exec → click individual nodes to see:

1. **Webhook: Alert Received**
   - Shows: Raw alerts coming in
   
2. **Parse Alert Data**
   - Shows: Extracted fields (service, severity, trace_id)

3. **Agent #1: Pre-Enrichment**
   - Shows: HTTP call to enrichment agent
   - Response: CMDB data returned

4. **Agent #2: Smart Router**
   - Shows: Routing decision (which LLM model)
   - Response: `"selected_model": "mistral"`

5. **Agent #3: AI Analysis**
   - Shows: LLM prompt sent to Ollama
   - Response: AI-generated root cause + recommendations

6. **Autonomous Decision Logic**
   - Shows: Decision reasoning
   - Output: `"decision": "CREATE_TICKET"`, `"approved_by": "AI_AGENTS"`

7. **Create Ticket in xyOps**
   - Shows: Ticket creation call
   - Response: Ticket #XXX created successfully

---

## 📊 What Your Manager Sees (Visual)

```
WORKFLOW DIAGRAM (N8N Browser)

                    ┌─────────────────────────────────────────────┐
                    │  1️⃣ WEBHOOK: Alert Received                │
                    │  (Alert fires from monitoring system)        │
                    └────────────────┬────────────────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  Parse Alert Data               │
                    │  (Extract: service, severity)   │
                    └────┬─────────────────────┬──────┘
                         │                     │
          ┌──────────────▼────┐      ┌────────▼──────────────┐
          │  🔍 AGENT #1      │      │  🎯 AGENT #2         │
          │ Pre-Enrichment    │      │  Smart Router         │
          │ (CMDB lookup)     │      │  (Choose LLM model)   │
          │ Returns: Context  │      │  Returns: Model name  │
          └──────────────┬────┘      └────────┬──────────────┘
                         │                    │
                         └────────┬─────────────┘
                                  │
                    ┌─────────────▼────────────┐
                    │  🧠 AGENT #3              │
                    │  AI Analysis (Ollama)     │
                    │  Input: Alert + Context   │
                    │  Output: RCA + Actions    │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  ⚡ AUTONOMOUS DECISION    │
                    │  Decision: CREATE_TICKET  │
                    │  Status: APPROVED         │
                    │  By: AI_AGENTS (No human) │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  📋 FINAL PROCESSING      │
                    │  Package all agent data   │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  🎫 CREATE TICKET        │
                    │  in xyOps (#123)          │
                    │  With enrichment + AI     │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  ✅ COMPLETE              │
                    │  Response to requester    │
                    └──────────────────────────┘


TIME: ~3-5 seconds from alert to ticket created
ALL AGENTS: 4 coordinated agents, no human intervention
VISIBILITY: Every step logged and traceable
```

---

## 🎤 What to Tell Your Manager

**"Here's what's happening:**

1. Alert comes in from monitoring system
2. **Agent #1** (pre-enrichment): Auto-enriches with CMDB context
3. **Agent #2** (smart router): Decides which AI model is best
4. **Agent #3** (AI analysis): Analyzes root cause and generates recommendations
5. **Decision engine**: Autonomously decides to create a ticket
6. **Ticket created** in xyOps with all agent work included
7. **Total time**: 3-5 seconds, fully autonomous, no human needed

**All visible in this one diagram.** Each node=one agent. The arrows show data flowing between them. This is the agents talking to each other and generating autonomous workflows."

---

## 🔍 Advanced: Understanding the Data Flow

### Alert enters:
```json
{
  "status": "firing",
  "labels": {
    "alertname": "TestAlert",
    "service_name": "frontend-api",
    "severity": "warning"
  }
}
```

### Pre-Enrichment Agent adds:
```json
{
  "cmdb_data": {
    "owner": "platform-team",
    "business_unit": "core-services",
    "runbook_url": "https://runbooks.internal/frontend-api"
  }
}
```

### Smart Router Agent adds:
```json
{
  "selected_model": "mistral",
  "reason": "Context < 4k tokens, fast inference needed"
}
```

### AI Analysis Agent adds:
```json
{
  "ai_root_cause": "Frontend service timeout due to backend DB connection pool exhaustion",
  "recommendations": [
    "Check database connection limits",
    "Review recent deployment",
    "Scale backend service horizontally"
  ]
}
```

### Autonomous Decision adds:
```json
{
  "decision": "CREATE_TICKET",
  "approved_by": "AI_AGENTS",
  "confidence": 0.92
}
```

### Final result in xyOps ticket:
```
Subject: [WARNING] TestAlert on frontend-api

Body:
- AI Analysis: Frontend timeout due to DB connections
- CMDB Owner: platform-team
- Recommendations: Scale DB, check limits
- Model used: mistral
- Trace ID: abc123 (links to N8N execution)
```

---

## ⚙️ Customization: Change the Flow

**Want to add Slack approval before ticket creation?**

Replace `📋 Final Processing` with a Slack node that sends approval requests.

**Want different routing logic?**

Edit `⚡ Autonomous Decision Logic` code node to add custom rules.

**Want more agents?**

Add new HTTP request nodes in the flow and wire them up with arrows.

---

## ✅ Verification Checklist

- [ ] Master Orchestrator workflow imported
- [ ] All 3 agent workflows still exist
- [ ] Only Master Orchestrator is ACTIVATED (green toggle)
- [ ] Webhook URL copied to .env
- [ ] AIOps Bridge restarted
- [ ] Test alert sent successfully
- [ ] Ticket created in xyOps
- [ ] N8N shows all nodes executed (green ✅)
- [ ] Manager can see complete flow in one diagram

---

## 📞 Support

**"The agents aren't talking"**
- Check: All 4 workflows in Workflows list
- Check: Only Master Orchestrator activated
- Check: Webhook URLs in .env are correct
- Fix: `docker restart aiops-bridge && docker restart n8n`

**"Ticket didn't create"**
- Check: xyOps running: `docker ps | grep xyops`
- Check: AIOps Bridge logs: `docker logs aiops-bridge | tail -20`
- Fix: Send alert again to test

**"Nodes show errors"**
- Check: Individual agent workflows can be called
- Check: N8N logs: `docker logs n8n | grep -i error`
- Fix: `docker restart n8n && sleep 10`

