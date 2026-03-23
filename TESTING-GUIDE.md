# 🧪 AIOps End-to-End Testing Guide

Complete walkthrough to test N8N orchestration, Streamlit dashboard, xyOps ticket creation, and Ansible playbook execution.

---

## 📋 Table of Contents

1. [Component Overview](#component-overview)
2. [N8N Workflows (3 JSON Files)](#n8n-workflows)
3. [Streamlit Dashboard](#streamlit-dashboard)
4. [xyOps Integration](#xyops-integration)
5. [Ansible Playbook Execution](#ansible-playbook-execution)
6. [Testing Sequence](#testing-sequence)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Component Overview

### Architecture Flow

```
Alert (Prometheus/AlertManager)
  ↓
Compute-Agent (AIOps Bridge)
  ├→ (Optional) N8N Pre-Enrichment
  ├→ Fetch Logs (Loki)
  ├→ Fetch Metrics (Prometheus)
  ├→ AI Analysis (Ollama)
  ├→ (Optional) N8N Post-Approval
  ↓
Create Ticket in xyOps
  ├→ Rich markdown description
  ├→ Ansible playbook embedded
  ├→ Test plan included
  ↓
Approval Workflow
  ├→ Human review (xyOps Tickets page)
  ├→ Approve/Reject decision
  ↓
Ansible Playbook Execution
  ├→ Pre-validation (test assertions)
  ├→ Remediation tasks
  ├→ Post-validation (verify recovery)
  ↓
Results posted back to xyOps ticket
  ├→ Execution status (✅/❌)
  ├→ Test results per phase
  ├→ Stdout/stderr output
  ↓
Streamlit Dashboard (Read-Only)
  ├→ Shows pipeline status
  ├→ Displays test results
  ├→ Links to xyOps for decisions
```

---

## 🎯 N8N Workflows (3 JSON Files)

### Status

> **⚠️ Important:** N8N workflow JSON files are **generated** not pre-existing.
> They live in the root directory after you run the generation script or import them manually into N8N.

### Workflow 1: Pre-Enrichment Agent
**File:** `n8n_workflows_01_pre_enrichment_agent.json` (if generated)

**Purpose:** Enriches incoming alerts with CMDB data before AI analysis

**Flow:**
```
Webhook Input (from compute-agent)
  ↓
Extract Alert Metadata
  ├→ service_name, alert_name, severity
  ├→ dashboard_url, trace_id
  ↓
CMDB API Lookup
  ├→ Fetch service ownership
  ├→ Get escalation policies
  ├→ Find related incidents
  ↓
Bridge API Call (POST /pipeline/agent/enrichment)
  ├→ Send enriched alert with CMDB context
  ↓
MongoDB Audit Log (optional)
  ├→ Record enrichment details
  ↓
Response to compute-agent
```

**Nodes:**
- Webhook receiver (input)
- Metadata extractor
- CMDB HTTP call
- Bridge API call
- Audit logger
- Response node

**Test:** Manually trigger webhook with sample alert JSON

```bash
curl -X POST http://localhost:5678/webhook/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "frontend-api",
    "alert_name": "HighErrorRate",
    "severity": "critical",
    "description": "Error rate > 5%"
  }'
```

---

### Workflow 2: Post-Approval Agent
**File:** `n8n_workflows_02_post_approval_agent.json` (if generated)

**Purpose:** Sends human approval request to Slack with interactive buttons

**Flow:**
```
Webhook Input (from compute-agent after AI analysis)
  ↓
Extract Analysis Context
  ├→ Best match playbook
  ├→ Confidence level
  ├→ RCA summary
  ↓
Send Slack Message
  ├→ Contains: Alert summary, RCA, estimated fix time
  ├→ Interactive buttons: [✅ Approve] [❌ Reject] [ℹ️ More Info]
  ↓
Wait for Button Click (webhook callback)
  ├→ Timeout: 30 minutes (configurable)
  ↓
Decision Logic
  ├→ If Approved → Create ticket in xyOps
  ├→ If Rejected → Log to audit trail
  ↓
Response to compute-agent
  ├→ Include decision + decided_by
```

**Nodes:**
- Webhook receiver (input)
- Slack message formatter
- Slack node (send interactive message)
- Wait node (for button response)
- Decision switch
- HTTP call to compute-agent
- Audit logger

**Test:** Manually trigger webhook to test Slack integration

```bash
curl -X POST http://localhost:5678/webhook/aiops/post-approval \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_id": "TICKET-123",
    "alert_name": "HighErrorRate",
    "rca_summary": "Cache expiration caused high load",
    "confidence": "high"
  }'
```

---

### Workflow 3: Smart-Router Agent
**File:** `n8n_workflows_03_smart_router_agent.json` (if generated)

**Purpose:** Intelligently selects LLM model and severity routing based on system state

**Flow:**
```
Webhook Input (from compute-agent alert ingestion)
  ↓
Fetch Prometheus Metrics
  ├→ CPU utilization
  ├→ Memory usage
  ├→ Current request latency
  ↓
Check Ollama Model Availability
  ├→ Query /api/tags endpoint
  ├→ List available models
  ↓
Routing Decision Logic
  ├→ IF cpu > 80% AND alert is CRITICAL
  │   → Use Mistral (faster, lower resource)
  ├→ IF memory < 20% available
  │   → Use Llama 3.2 (efficient)
  ├→ IF description length > 5000 chars
  │   → Use Full reasoning model (better analysis)
  ├→ ELSE
  │   → Default to qwen2:7b (balanced)
  ↓
Call Bridge API
  ├→ Send model_override: "mistral" (or other)
  ├→ Continue with selected model
  ↓
Audit Log (decision + selected model)
  ↓
Response to compute-agent
```

**Nodes:**
- Webhook receiver (input)
- Prometheus HTTP node (fetch metrics)
- Ollama HTTP node (model check)
- Decision switch (routing logic)
- Bridge API call (multiple branches)
- Audit logger
- Response node

**Test:** Manually trigger webhook to test model selection

```bash
curl -X POST http://localhost:5678/webhook/aiops/smart-router \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "HighCPU",
    "severity": "critical",
    "description": "CPU utilization at 95%" 
  }'
```

---

### How to Import N8N Workflows

Since these are generated (not in repo), you'll need to create them manually or export them from a reference instance.

**Option 1: Create Manually in N8N UI**

1. Open N8N: `http://localhost:5678`
2. Click **"Create Workflow"**
3. Add nodes matching the flows above
4. Configure webhook paths: `/webhook/aiops/pre-enrichment`, etc.
5. Click **"Deploy"** to activate

**Option 2: Import from JSON (if available)**

1. Go to **Workflows** tab
2. Click **"Import from file"**
3. Select `n8n_workflows_01_pre_enrichment_agent.json`
4. Review webhook configuration
5. Click **"Deploy"**

**Key Configuration for All Workflows:**

Webhook node settings:
```
Path: /webhook/aiops/{pattern}  (pattern = pre-enrichment, post-approval, or smart-router)
Method: POST
Response: Send response back
Data to return: (workflow dependent)
```

---

## 📊 Streamlit Dashboard

### What It Does

The **Streamlit dashboard** is a **read-only** real-time monitoring interface for the AIOps platform.

**Purpose:** Visualize system health, alerts, pipeline execution, and approvals without creating new backend endpoints.

### Pages

#### Page 1: Dashboard
**Shows:**
- System health status (compute-agent, storage-agent, obs-intelligence)
- Active alerts count
- Risk level distribution (Low/Medium/High/Critical)
- AI confidence statistics
- Approval pending count
- Quick stats: Total incidents handled, Average resolution time

**Refreshes:** Every 30 seconds (cached)

**API Calls Made:**
```
GET /health                    (each agent)
GET /intelligence/current      (obs-intelligence)
GET /autonomy/history          (compute-agent)
```

#### Page 2: Pipeline View
**Shows:**
- Current pipeline execution trace
- Alert → Logs → Metrics → Analysis → Approval → Execution
- Each step's duration and status
- OpenTelemetry trace ID (clickable link to Grafana Tempo)
- JSON payload inspector

**Refreshes:** Real-time on page load

**API Calls Made:**
```
GET /pipeline/session/{id}     (compute-agent)
```

#### Page 3: Approvals
**Shows:**
- List of pending approval tickets
- Alert name, severity, confidence, RCA summary
- "View in xyOps" button (navigate to make decision)
- Approval timeout countdown
- Auto-refresh on completion

**Refreshes:** Every 15 seconds

**API Calls Made:**
```
GET /intelligence/approvals    (obs-intelligence)
```

#### Page 4: Settings
**Shows:**
- Current API endpoints
- Environment variables reference
- Troubleshooting guide
- Links to:
  - xyOps Tickets: `http://localhost:5522`
  - Grafana Tempo (traces): `http://localhost:3001`
  - Prometheus (metrics): `http://localhost:9090`

**No API calls** (static reference)

### How to Access

1. **Start Streamlit server:**
   ```bash
   cd ui-streamlit
   streamlit run app.py
   ```

2. **Open browser:**
   ```
   http://localhost:8501
   ```

3. **Navigate pages** using sidebar menu

### Example Output

```
┌─────────────────────────────────────────────────┐
│  🔧 AIOps Dashboard                             │
├─────────────────────────────────────────────────┤
│                                                 │
│  System Health                                  │
│  ├─ Compute Agent:      ✅ Healthy (200)       │
│  ├─ Storage Agent:      ✅ Healthy (200)       │
│  ├─ Obs Intelligence:   ✅ Healthy (200)       │
│  └─ xyOps:              ✅ Healthy (5522)      │
│                                                 │
│  Active Alerts: 3    Approvals Pending: 1      │
│  Risk Level:  ████▓░░░ 45% MEDIUM              │
│  AI Confidence: ▓▓▓▓▓░░ 74%                    │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🎫 xyOps Integration

### How xyOps Picks Up Tickets

The **AIOps Bridge** (compute-agent) creates rich, meaningful tickets in xyOps after AI analysis.

### Ticket Creation Flow

1. **Alert arrives** → Prometheus AlertManager → compute-agent webhook
2. **Pipeline processes:** Logs → Metrics → AI Analysis
3. **Rich body assembled** with:
   ```markdown
   ## Automated Incident — AIOps Agent Pipeline
   
   | Field | Value |
   |-------|-------|
   | Service | `frontend-api` |
   | Alert | `HighErrorRate` |
   | Severity | `CRITICAL` |
   | Detected at | 2026-03-22T10:15:30Z |
   | Dashboard | [Grafana](http://...) |
   
   ### Root Cause Analysis (RCA)
   Error rate spike due to backend database connection pool exhaustion.
   Probable cause: Recent deployment with higher concurrency.
   Impact scope: All frontend API endpoints dependent on DB lookups.
   
   ### Proposed Ansible Remediation
   ```yaml
   - name: Fix DB connection pool
     tasks:
       - name: Increase pool size
         # ... playbook ...
   ```
   
   ### Test Plan
   - PRE: Verify DB connectivity before remediation
   - POST: Verify error rate recovered to < 1%
   ```

4. **Ticket stored** with all context in xyOps database
5. **Approval workflow** routed to SRE team
6. **Comments auto-posted** with step updates:
   - Step 1: ✅ Logs fetched (12 sec)
   - Step 2: ✅ Metrics analyzed (8 sec)
   - Step 3: ✅ AI analysis complete (confidence: HIGH)
   - Step 4: ⏳ Awaiting human approval
   - Step 5: ✅ Playbook executed (return code: 0)

### Ticket Fields

**Auto-populated by compute-agent:**
- Title: `[AI] {Service} — {AlertName} (Severity: {LEVEL})`
- Description: Rich markdown with RCA + playbook
- Severity: Inherited from alert
- Status: `draft` → `approving` → `executing` → `resolved`
- Tags: `[aiops]`, `[auto]`, `[{service}]`
- Comments: Step feedback + execution results

**Example Title:**
```
[AI] frontend-api — HighErrorRate (Severity: CRITICAL)
```

### Why the Ticket is Meaningful

✅ **Immediate context:**
- Exact service and alert that triggered incident
- Links to Grafana dashboard for visualization
- OpenTelemetry trace ID for deep-dive debugging

✅ **RCA included:**
- Probable root cause (not just symptoms)
- Impact scope (what else is affected)
- Supporting evidence (metrics, logs)

✅ **Actionable remediation:**
- Ready-to-run Ansible playbook
- Pre/post-validation test cases
- Rollback procedure documented
- Estimated fix time

✅ **Audit trail:**
- Every step logged as comment
- Decision maker and timestamps
- Execution results with return codes

---

## ⚙️ Ansible Playbook Execution

### Playbook Structure

AI-generated Ansible playbooks follow this structure:

```yaml
---
# Play 1: Pre-validation (collect baseline)
- name: Pre-validation - Assert baseline state
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Assert DB connection pool is reachable
      ansible.builtin.assert:
        that:
          - service_state == "healthy"
        fail_msg: "Service not healthy before remediation"

# Play 2: Remediation (fix the issue)
- name: Remediate frontend-api
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Increase DB connection pool size
      ansible.builtin.shell: |
        # Adjust pool configuration
        # Restart service workers
      register: remediation_result
      
    - name: Log remediation completion
      ansible.builtin.debug:
        msg: "Pool size increased"
  
  post_tasks:
    - name: Wait for service to stabilize
      ansible.builtin.pause:
        seconds: 10

# Play 3: Post-validation (verify recovery)
- name: Post-validation - Verify recovery
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Assert error rate recovered
      ansible.builtin.assert:
        that:
          - error_rate < 1.0
        fail_msg: "Error rate not recovered"

# Play 4: Rollback (if needed)
- name: Rollback frontend-api
  hosts: localhost
  tags: [rollback]
  tasks:
    - name: Revert to previous configuration
      ansible.builtin.shell: |
        # Revert pool size
        # Reload service
```

### Execution Phases

#### Phase 1: **Validate** (Dry-Run)
```
POST /ansible-runner/validate
  ├─ Run in --check mode
  ├─ Execute pre-flight assertions
  ├─ No actual changes made
  ├─ Return: test_results (PASS/FAIL per assertion)
```

**Result in xyOps ticket:**
```
## ✅ Pre-Validation Results

| Test Case | Status | Output |
|-----------|--------|--------|
| TC-PRE-1: Assert DB connection pool reachable | PASSED | ✓ Service responds |
| TC-PRE-2: Verify baseline error rate | PASSED | ✓ Current: 2.3% |
```

#### Phase 2: **Execute** (Real or Simulated)
```
POST /ansible-runner/run
  ├─ If LIVE_MODE=true → Real execution
  ├─ If LIVE_MODE=false → Simulated (default)
  ├─ Execute all plays (pre + remediation + post)
  ├─ Return: stdout, stderr, return_code, test_results
```

**Result in xyOps ticket:**
```
## ✅ Remediation Executed Successfully

| Field | Value |
|-------|-------|
| Return Code | 0 (Success) |
| Duration | 45 seconds |
| Mode | check (dry-run) |

### Test Results

| Phase | Test Case | Status | Output |
|-------|-----------|--------|--------|
| PRE | Assert DB pool reachable | PASSED | ✓ |
| PRE | Baseline error rate | PASSED | ✓ 2.3% |
| POST | Error rate recovered | PASSED | ✓ 0.8% |
| POST | Service endpoints | PASSED | ✓ All HTTP 200 |

### Execution Output

\`\`\`
PLAY [Pre-validation: Assert baseline state] ****
TASK [Assert DB connection pool is reachable]
ok: [localhost] => {"assertion": "Service responds"}

PLAY [Remediate frontend-api] ****
TASK [Increase DB connection pool size]
changed: [localhost] => {"msg": "Pool size increased to 150"}

PLAY [Post-validation: Verify recovery] ****
TASK [Assert error rate recovered]
ok: [localhost] => {"assertion": "Error rate 0.8% < 1.0%"}
\`\`\`
```

### Test Cases (Generated by AI)

Each playbook includes structured test cases:

```json
{
  "test_cases": [
    {
      "id": "TC-PRE-1",
      "name": "Assert service is reachable",
      "assertion": "HTTP GET /health returns 200",
      "phase": "pre"
    },
    {
      "id": "TC-PRE-2",
      "name": "Baseline error rate check",
      "assertion": "error_rate metric < 10%",
      "phase": "pre"
    },
    {
      "id": "TC-POST-1",
      "name": "Error rate recovery",
      "assertion": "error_rate < 1% after remediation",
      "phase": "post"
    },
    {
      "id": "TC-POST-2",
      "name": "Service endpoints healthy",
      "assertion": "All endpoints returning HTTP 200",
      "phase": "post"
    }
  ]
}
```

---

## 🧪 Testing Sequence

### Test 1: Alert Ingestion (5 min)

**Goal:** Verify compute-agent receives alert and creates ticket

**Steps:**

1. **Send test alert to compute-agent:**
   ```bash
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
   ```

2. **Check compute-agent logs:**
   ```bash
   docker logs aiops-bridge | grep -i "alert\|session"
   ```

3. **Verify ticket created in xyOps:**
   - Open: `http://localhost:5522`
   - Navigate: **Tickets** tab
   - Look for: `[AI] frontend-api — HighErrorRate`
   - Verify: Title, description (RCA + playbook), status

**Expected Result:** ✅ Ticket visible in xyOps with rich markdown body

---

### Test 2: AI Analysis & Playbook Generation (10 min)

**Goal:** Verify AI generates meaningful RCA and Ansible playbook

**Criteria:**

1. **Ticket comment with step feedback:**
   ```
   ✅ Step 1: Logs fetched (256 lines from Loki)
   ✅ Step 2: Metrics analyzed (24-hour context)
   ✅ Step 3: AI analysis complete
      - Confidence: HIGH
      - RCA: Connection pool exhaustion
      - Estimated fix: 15 minutes
   ✅ Step 4: Playbook generated (32 lines of YAML)
   ```

2. **Ticket body includes:**
   - RCA summary (2-3 sentences)
   - Root cause (specific issue)
   - Blast radius (what's affected)
   - Ansible playbook (copy-paste ready)
   - Test plan (pre/post validations)
   - GitHub PR suggestion (if applicable)

3. **Playbook is valid YAML:**
   ```bash
   # Extract playbook from ticket and validate
   curl -s "http://localhost:5522/api/..." | python3 -m json.tool | grep -A 50 "ansible_playbook" | \
   python3 -c "
   import sys, yaml
   try:
       yaml.safe_load(sys.stdin)
       print('✅ Valid YAML')
   except:
       print('❌ Invalid YAML')
   "
   ```

**Expected Result:** ✅ Ticket has executable playbook + test cases

---

### Test 3: Streamlit Dashboard (5 min)

**Goal:** Verify dashboard displays pipeline status and alerts

**Steps:**

1. **Start Streamlit (if not running):**
   ```bash
   cd /Volumes/Data/Codehub/xyopsver2/ui-streamlit
   streamlit run app.py
   ```

2. **Open dashboard:**
   ```
   http://localhost:8501
   ```

3. **Check each page:**

   **Dashboard Page:**
   - [ ] All services show ✅ Healthy
   - [ ] Active alerts showing recent alert
   - [ ] Risk level indicator visible
   - [ ] AI confidence > 70%

   **Pipeline View Page:**
   - [ ] Shows session from Test 1
   - [ ] Each step has duration
   - [ ] Trace ID clickable to Grafana

   **Approvals Page:**
   - [ ] Recent ticket shows in pending list
   - [ ] "View in xyOps" button works
   - [ ] Approval countdown visible

   **Settings Page:**
   - [ ] All endpoints configured correctly
   - [ ] Links functional

**Expected Result:** ✅ Dashboard shows real-time status + links to xyOps

---

### Test 4: N8N Workflows (Optional - 5 min each)

**Goal:** Verify N8N orchestration working (if enabled)

#### Test 4a: Pre-Enrichment Webhook

1. **Manually trigger webhook:**
   ```bash
   curl -X POST "http://localhost:5678/webhook/aiops/pre-enrichment" \
     -H "Content-Type: application/json" \
     -d '{
       "service_name": "frontend-api",
       "alert_name": "HighErrorRate",
       "severity": "critical",
       "description": "Error rate 8.5%",
       "trace_id": "abc123"
     }'
   ```

2. **Check N8N UI:**
   - Open: `http://localhost:5678`
   - Go to: Workflow → Executions
   - Verify: Execution shows ✅ completed
   - Check: All nodes executed successfully

3. **Verify logs:**
   ```bash
   docker logs n8n | grep -i "pre-enrichment\|webhook"
   ```

**Expected Result:** ✅ N8N workflow executes, posts enriched data to compute-agent

---

#### Test 4b: Post-Approval Workflow

1. **Create ticket in xyOps** (from Test 1)

2. **Trigger approval workflow:**
   ```bash
   curl -X POST "http://localhost:5678/webhook/aiops/post-approval" \
     -H "Content-Type: application/json" \
     -d '{
       "ticket_id": "TICKET-123",
       "alert_name": "HighErrorRate",
       "rca_summary": "Connection pool exhaustion",
       "confidence": "high"
     }'
   ```

3. **Check Slack** (if configured):
   - Look for approval message
   - Verify buttons: [✅ Approve] [❌ Reject]
   - Click button and verify callback

4. **Check N8N execution:**
   - Verify workflow completed
   - Check response captured

**Expected Result:** ✅ N8N sends approval request, waits for decision

---

#### Test 4c: Smart-Router Workflow

1. **Trigger router workflow:**
   ```bash
   curl -X POST "http://localhost:5678/webhook/aiops/smart-router" \
     -H "Content-Type: application/json" \
     -d '{
       "alert_name": "HighCPU",
       "severity": "critical",
       "description": "CPU utilization at 95% for 5 minutes"
     }'
   ```

2. **Check model selection:**
   ```bash
   docker logs n8n | grep -i "mistral\|llama\|model"
   ```

3. **Verify routing logic:**
   - N8N should select model based on:
     - CPU > 80% → Mistral (fast)
     - Memory < 20% → Llama 3.2 (efficient)
     - Description > 5000 chars → Full reasoning
   - Default: qwen2:7b (balanced)

**Expected Result:** ✅ N8N correctly routes to appropriate LLM model

---

### Test 5: Approval Workflow (10 min)

**Goal:** Test human approval → playbook execution flow

**Steps:**

1. **Navigate to xyOps Tickets:**
   ```
   http://localhost:5522
   ```

2. **Find approval ticket:**
   - Status: `approving` or `awaiting_decision`
   - Click to open

3. **Review ticket content:**
   - [ ] Ticket has RCA summary
   - [ ] Playbook is readable YAML
   - [ ] Test cases listed
   - [ ] Confidence level shown

4. **Approve the ticket:**
   ```bash
   # OR via UI: Click "Approve" button
   # Backend updates ticket status to "executing"
   ```

5. **Monitor execution:**
   - Watch ticket comments for step updates
   - Expect: Step 4 → Step 5 (Execution)

6. **Check Ansible results:**
   - Comment should show:
     ```
     ✅ Playbook execution result
     Return code: 0 (Success)
     Passed tests: 4/4
     Duration: 45 seconds
     ```

7. **Verify in Streamlit:**
   - Refresh dashboard
   - Approvals page → ticket should be gone
   - Pipeline view shows completed execution

**Expected Result:** ✅ Ticket transitions from approval → execution → resolved

---

### Test 6: End-to-End Flow (15 min)

**Goal:** Complete flow from alert → ticket → approval → execution

**Checklist:**

```
[ ] 1. Alert arrives at compute-agent
[ ] 2. Pipeline processes (logs, metrics, AI)
[ ] 3. Ticket created in xyOps (with RCA + playbook)
[ ] 4. Streamlit dashboard shows alert + pipeline status
[ ] 5. Approval page shows pending decision
[ ] 6. Human approves ticket in xyOps
[ ] 7. Ansible playbook validation passes (dry-run)
[ ] 8. Playbook execution completes (tests pass)
[ ] 9. Results posted back to xyOps ticket
[ ] 10. Streamlit shows completed pipeline
```

**Commands to verify each step:**

```bash
# Step 1: Check compute-agent received alert
docker logs aiops-bridge | grep "Alert received"

# Step 2: Check pipeline processing
docker logs aiops-bridge | grep "Agent.*complete"

# Step 3: Check ticket created
curl http://localhost:5522/api/app/get_tickets/v1 | jq '.tickets[] | select(.title | contains("AI"))'

# Step 4: Check Streamlit sees data
curl http://localhost:8501/health  # Not a real endpoint, verify manually

# Step 5: Check approval status
curl http://localhost:5522/api/app/get_approvals/v1 | jq '.approvals[]'

# Step 6: Approve via API or UI

# Step 7: Check validation results
docker logs ansible-runner | grep "validate\|PASSED"

# Step 8: Check execution results
docker logs ansible-runner | grep "return_code.*0"

# Step 9: Check ticket comments
curl http://localhost:5522/api/app/get_ticket_comments/v1?id=TICKET-123 | jq '.comments[-1]'

# Step 10: Refresh Streamlit dashboard
```

---

## 🔧 Troubleshooting

### Issue: Ticket Not Created in xyOps

**Symptoms:**
- Alert sent to compute-agent
- No ticket appears in xyOps

**Debug:**
```bash
# 1. Check compute-agent logs
docker logs aiops-bridge | tail -50

# 2. Verify xyOps API is reachable
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:5522/api/app/get_event/v1

# 3. Check pipeline session
curl http://localhost:9000/pipeline/session/SESSION_ID | jq '.'

# 4. Verify .env has XYOPS_URL and API_KEY
cat .env | grep XYOPS
```

**Fix:**
```bash
# Ensure .env has:
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=<valid-api-key>

# Restart compute-agent
docker restart aiops-bridge
```

---

### Issue: Playbook Not Generated

**Symptoms:**
- Ticket created but no Ansible playbook in description
- Step 3 comment shows "AI analysis failed"

**Debug:**
```bash
# 1. Check Ollama is running
curl http://localhost:11434/api/tags | jq '.models[]'

# 2. Check LLM response
docker logs aiops-bridge | grep -i "ollama\|llm\|generate"

# 3. Check for errors
docker logs aiops-bridge | grep -i "error\|exception"
```

**Fix:**
```bash
# Verify Ollama has a model
docker exec ollama ollama list

# If empty, pull a model
docker exec ollama ollama pull qwen2:7b

# Restart compute-agent
docker restart aiops-bridge
```

---

### Issue: Streamlit Shows "Unable to Connect"

**Symptoms:**
- Streamlit dashboard loads
- Get "Unable to connect to compute-agent"

**Debug:**
```bash
# 1. Check Streamlit can reach agents
docker logs ui-streamlit | grep -i "error\|timeout"

# 2. Verify agent ports
netstat -tlnp | grep -E "9000|9001|9100"

# 3. Test agent directly
curl http://localhost:9000/health
```

**Fix:**
```bash
# Check .env variables in docker-compose.yml
# Should have:
#   COMPUTE_AGENT_URL=http://compute-agent:9000

# If running on localhost, use:
#   COMPUTE_AGENT_URL=http://localhost:9000

# Restart services
docker-compose down && docker-compose up -d
```

---

### Issue: Playbook Execution Fails (RC != 0)

**Symptoms:**
- Ticket shows ❌ Playbook execution failed
- ansible-runner returns non-zero return code

**Debug:**
```bash
# 1. Check playbook YAML syntax
docker exec ansible-runner python3 -m yaml playbook.yml

# 2. Check ansible-runner logs
docker logs ansible-runner | tail -50

# 3. Check test case assertions
curl http://localhost:5522/api/app/get_ticket_comments/v1?id=TICKET-123 | jq '.comments[] | .body'
```

**Fix:**
```bash
# 1. Verify playbook structure
# Should have 4 plays: pre-validation, remediation, post-validation, rollback

# 2. Check test case assertions match service
# Example: if testing a Java service, assertion should check JVM metrics

# 3. If playbook is malformed, rerun compute-agent
docker restart aiops-bridge
```

---

### Issue: N8N Webhook Not Triggering

**Symptoms:**
- Webhook URL called manually works
- But compute-agent not triggering it

**Debug:**
```bash
# 1. Verify N8N workflows are ACTIVE
# Open http://localhost:5678 → Workflows tab
# Each workflow should show green checkmark

# 2. Check webhook registration
curl http://localhost:5678/rest/webhooks | jq '.data[]'

# 3. Verify compute-agent is trying to call
docker logs aiops-bridge | grep -i "n8n\|webhook"

# 4. Check N8N logs
docker logs n8n | tail -50
```

**Fix:**
```bash
# 1. In N8N UI: Click workflow → Deploy
# 2. Verify webhook path matches:
#    - Pre-enrichment: /webhook/aiops/pre-enrichment
#    - Post-approval: /webhook/aiops/post-approval
#    - Smart-router: /webhook/aiops/smart-router

# 3. Set in .env:
ENABLE_N8N=true  # or false to disable
N8N_PRE_ENRICHMENT_ENABLED=true  # etc.

# 4. Restart compute-agent
docker restart aiops-bridge
```

---

## 📚 Quick Reference

### Key URLs

| Service | URL | Purpose |
|---------|-----|---------|
| xyOps | `http://localhost:5522` | Ticket management |
| Streamlit | `http://localhost:8501` | Dashboard |
| N8N | `http://localhost:5678` | Workflow orchestration |
| Grafana | `http://localhost:3001` | Traces + Metrics |
| Prometheus | `http://localhost:9090` | Metrics DB |
| AlertManager | `http://localhost:9093` | Alert routing |
| Loki | `http://localhost:3100` | Log aggregation |

### Key Endpoints (Compute-Agent)

```bash
POST   /webhook              # Alert ingestion
POST   /pipeline/start       # Create ticket
POST   /pipeline/agent/logs  # Fetch logs
POST   /pipeline/agent/metrics  # Fetch metrics
POST   /pipeline/agent/analyze  # AI analysis
POST   /pipeline/agent/ticket  # Enrich description
POST   /pipeline/agent/approval # Approval gateway
GET    /pipeline/session/{id}  # Inspect session
```

### Key Environment Variables

```bash
# Compute Agent
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=<api-key>
OLLAMA_API_URL=http://ollama:11434
LOCAL_LLM_ENABLED=true
LOCAL_LLM_MODEL=qwen2:7b

# N8N (optional)
ENABLE_N8N=true
N8N_PATTERN=pre-enrichment  # or post-approval or smart-router
N8N_PRE_ENRICHMENT_WEBHOOK=http://n8n:5678/webhook/aiops/pre-enrichment

# Ansible Runner
ANSIBLE_RUNNER_URL=http://ansible-runner:8000
ANSIBLE_LIVE_MODE=false  # Keep false for safety

# Streamlit
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
```

### Test Alert JSON (Copy-Paste Ready)

```bash
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
    }],
    "commonLabels": {
      "severity": "critical"
    },
    "commonAnnotations": {
      "dashboard": "http://localhost:3001/d/frontend-api",
      "runbook": "https://wiki.example.com/incidents"
    }
  }'
```

---

## ✅ Success Criteria

You've successfully validated the entire system when:

1. ✅ **Alert ingestion**: Webhook receives alert, computes session
2. ✅ **AI analysis**: RCA + playbook generated in < 30 seconds
3. ✅ **Ticket creation**: Meaningful ticket in xyOps with context
4. ✅ **Dashboard**: Streamlit shows real-time status + links work
5. ✅ **Approvals**: Human can review and approve/reject
6. ✅ **Playbook execution**: Ansible runs test cases (pre/post)
7. ✅ **Results**: Execution summary posted back to ticket
8. ✅ **Audit trail**: All decisions logged in ticket comments

---

**Happy Testing! 🚀**
