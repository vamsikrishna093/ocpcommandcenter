# 🎯 Validation & Testing Quick Start

Answers your specific questions about N8N, Streamlit, xyOps, and Ansible orchestration.

---

## Your Questions — Quick Answers

### ❓ "Which JSON files I need to import in N8N to check the orchestration?"

**Answer:** There are **3 N8N workflow JSON files** (generated, not in repo):

1. **`n8n_workflows_01_pre_enrichment_agent.json`**
   - Enriches alerts with CMDB data before AI analysis
   - **When:** Early in pipeline
   - **Test command:** See [N8N-SETUP-GUIDE.md](N8N-SETUP-GUIDE.md) → Testing → Test Pre-Enrichment

2. **`n8n_workflows_02_post_approval_agent.json`**
   - Sends Slack approval request with interactive buttons
   - **When:** After AI analysis, before execution
   - **Test command:** See [N8N-SETUP-GUIDE.md](N8N-SETUP-GUIDE.md) → Testing → Test Post-Approval

3. **`n8n_workflows_03_smart_router_agent.json`**
   - Selects best LLM model based on CPU/memory/complexity
   - **When:** At alert ingestion, routes alert to appropriate model
   - **Test command:** See [N8N-SETUP-GUIDE.md](N8N-SETUP-GUIDE.md) → Testing → Test Smart-Router

**⚠️ Important:** These are **optional** — if N8N is disabled, everything still works with defaults.

**Current Status:**
- `ENABLE_N8N=false` in `.env` (disabled by default)
- To enable: Set `ENABLE_N8N=true` and pick a pattern

---

### ❓ "What does Streamlit app do?"

**Answer:** **Read-only** real-time monitoring dashboard with 4 pages:

#### Page 1: Dashboard
- System health (compute-agent, storage-agent, obs-intelligence, xyOps)
- Active alerts count + risk level
- AI confidence statistics
- Approval pending count
- Refreshes: Every 30 seconds

#### Page 2: Pipeline View
- Current execution trace (alert → logs → metrics → analysis → approval → execution)
- Each step's duration + status
- Links to OpenTelemetry trace (Grafana Tempo)
- Refreshes: Real-time

#### Page 3: Approvals
- Pending approval tickets
- Alert name, severity, confidence, RCA summary
- **"View in xyOps" button** (clicking takes you to ticket for approval decision)
- Auto-refresh when completed
- Refreshes: Every 15 seconds

#### Page 4: Settings
- API endpoints reference
- Environment variables guide
- Troubleshooting links

**Access:** 
```
http://localhost:8501
```

---

### ❓ "How xyOps picks up tickets with meaningful description and having right ansible playbook?"

**Answer:** 3-step process — all automated by compute-agent:

#### Step 1: Rich Ticket Creation
When AI analysis completes, compute-agent calls xyOps `/create_ticket` API with:

```markdown
Title: [AI] {Service} — {Alert} (Severity: {LEVEL})

Description (Markdown):
### Root Cause Analysis
- Probable cause: (AI-generated RCA from logs + metrics)
- Blast radius: (what's affected)

### Proposed Ansible Remediation
\`\`\`yaml
- name: Fix {service}
  hosts: localhost
  tasks:
    # AI-generated playbook
\`\`\`

### Test Plan
- PRE: $assertion (baseline check)
- POST: $assertion (recovery check)

### GitHub PR
- PR Title: (AI-generated)
- PR Description: (why this fix prevents recurrence)
```

#### Step 2: Meaningful Content
The description is meaningful because:
- ✅ **RCA:** AI analyzed logs + metrics (not just alert summary)
- ✅ **Context:** Service name, severity, affected components
- ✅ **Actionable:** Ready-to-run YAML playbook + test cases
- ✅ **Traceable:** OpenTelemetry trace ID for debugging
- ✅ **Audit trail:** Links to Grafana dashboard

#### Step 3: Playbook Correctness
Playbooks are correct because AI generates them following structure:

```yaml
# Play 1: Pre-validation (collect baseline)
- name: Pre-validation
  tasks:
    - assert: service is healthy
    
# Play 2: Remediation (fix issue)
- name: Remediate
  tasks:
    - fix task 1
    - fix task 2
    - notify: reload
    
# Play 3: Post-validation (verify recovery)
- name: Post-validation
  tasks:
    - assert: error_rate < 1%
    - assert: responses < 500ms
    
# Play 4: Rollback (if needed)
- name: Rollback
  tasks:
    - revert changes
```

**Example output in xyOps ticket:**
```
✅ Step 1: Logs fetched | 256 lines from Loki (2.1s)
✅ Step 2: Metrics analyzed | 24h context (3.2s)
✅ Step 3: AI analysis done | confidence: HIGH | playbook: 32 lines (15.0s)
✅ Step 4: Ticket created | ID: TICKET-2024-001
⏳ Step 5: Awaiting approval
```

---

### ❓ "Want to test one by one"

**Answer:** Follow this sequence:

| # | Step | Time | Command |
|---|------|------|---------|
| 1️⃣ | Health check all services | 30s | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#1️⃣-health-check-30-seconds) |
| 2️⃣ | Send test alert | 1m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#2️⃣-send-test-alert-1-minute) |
| 3️⃣ | Check ticket created in xyOps | 2m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#3️⃣-check-ticket-created-2-minutes) |
| 4️⃣ | Inspect ticket for RCA + playbook | 2m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#4️⃣-inspect-ticket-body-2-minutes) |
| 5️⃣ | Monitor compute-agent processing | Real-time | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#5️⃣-monitor-compute-agent-logs-real-time) |
| 6️⃣ | View Streamlit dashboard | 5m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#8️⃣-streamlit-dashboard-access) |
| 7️⃣ | Approve ticket & trigger playbook | 1m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#9️⃣-approve-ticket--trigger-playbook) |
| 8️⃣ | Monitor ansible execution | Real-time | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#🔟-monitor-ansible-execution) |
| 9️⃣ | Check execution results in ticket | 1m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#1️⃣1️⃣-check-playbook-execution-results) |
| 🔟 | View full trace (optional) | 5m | See [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#1️⃣2️⃣-view-opentelemetry-trace-optional) |

**Total time to complete: ~30 minutes**

---

## 🚀 Start Here

### Option A: Test Everything (30 min)

1. **Copy test script:**
   ```bash
   cat QUICK-TEST-COMMANDS.md | grep -A 50 "Full Test Sequence Script"
   ```

2. **Run it:**
   ```bash
   ./test-flow.sh
   ```

3. **Then approve the ticket:**
   ```bash
   ./approve-flow.sh TICKET-2024-001
   ```

### Option B: Manual Testing (Step by Step)

Follow [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md) from top to bottom, stopping after each step to verify results.

### Option C: Full Detail (Learning)

Read [TESTING-GUIDE.md](TESTING-GUIDE.md) for:
- Component architecture explanation
- Why each piece works
- Troubleshooting guide
- Success criteria

---

## 📦 What You Have

### Deployed Services

```
Alert (Prometheus/AlertManager on your system)
  ↓
Compute-Agent (AIOps Bridge) — http://localhost:9000
  ├→ (Optional) N8N Pre-Enrichment — http://localhost:5678
  ├→ Loki Log Fetcher
  ├→ Prometheus Metrics
  ├→ Ollama LLM (port 11434)
  ├→ (Optional) N8N Post-Approval
  ↓
xyOps (Ticketing) — http://localhost:5522
  ├→ Receives rich AI-generated tickets
  ├→ Routes to approval workflow
  ↓
Storage-Agent (Data storage) — http://localhost:9001
  ├→ Stores decisions and audit trail
  ↓
Ansible-Runner (Playbook execution) — http://localhost:8000
  ├→ Executes remediation (dry-run by default)
  ├→ Validates pre- and post- assertions
  ↓
UI-Streamlit (Read-only dashboard) — http://localhost:8501
  ├→ Shows real-time status
  ├→ Links to approval decisions
  ↓
Observability Stack
  ├→ Grafana — http://localhost:3001 (traces + metrics)
  ├→ Prometheus — http://localhost:9090 (metrics)
  ├→ Tempo — (OpenTelemetry traces)
  ├→ Loki — http://localhost:3100 (logs)
```

### Configuration Files

All in root directory:
- ✅ `.env` — API keys, LLM config, endpoints
- ✅ `.env.template` — Reference template
- ✅ `docker-compose.yml` — All services orchestrated
- ✅ `SECRETS-MANAGEMENT.md` — How to manage secrets safely

### Documentation

- 📖 **[TESTING-GUIDE.md](TESTING-GUIDE.md)** — Complete walkthrough (30+ min read)
- 📖 **[N8N-SETUP-GUIDE.md](N8N-SETUP-GUIDE.md)** — How to setup N8N workflows (10+ min)
- 📖 **[QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md)** — Copy-paste commands (reference)
- 📖 **[QUICK-START.md](QUICK-START.md)** — This file

---

## ✅ Success Criteria

**You've successfully validated the system when:**

1. ✅ Alert arrives → ticket created in xyOps with RCA + playbook (< 30s)
2. ✅ Ticket body includes:
   - Problem description from AI RCA
   - Working Ansible YAML playbook
   - Pre/post validation test cases
3. ✅ Streamlit dashboard shows:
   - The alert in "Active Alerts"
   - Pipeline execution status
   - Approval in pending list
4. ✅ Human approves in xyOps → playbook executes
5. ✅ Execution results posted back to ticket:
   - Return code: 0 (success)
   - All test cases: PASSED
   - Duration: ~45 seconds
6. ✅ Ticket status transitions: draft → approving → executing → resolved

---

## 🐛 Troubleshooting Quick Path

### Problem: Ticket not created
```bash
$ docker logs aiops-bridge | tail -20 | grep -i error
```
→ See [TESTING-GUIDE.md](TESTING-GUIDE.md) → Troubleshooting → Ticket Not Created

### Problem: No playbook in ticket
```bash
$ curl http://localhost:11434/api/tags | jq '.models'
```
→ If empty: `docker exec ollama ollama pull qwen2:7b`

### Problem: Streamlit can't connect
```bash
$ netstat -tlnp | grep 9000
```
→ Verify compute-agent running

### Problem: Playbook execution fails
```bash
$ docker logs ansible-runner | grep -i error
```
→ Check test case assertions match service

---

## 📞 Next Steps

1. **Start with health check:**
   ```bash
   curl http://localhost:9000/health && echo "✅"
   ```

2. **Send test alert:**
   ```bash
   # Command from QUICK-TEST-COMMANDS.md → Section 2️⃣
   ```

3. **Monitor in Streamlit:**
   ```bash
   open http://localhost:8501
   ```

4. **Approve & execute:**
   ```bash
   # Via xyOps UI: http://localhost:5522 → Find ticket → Click Approve
   ```

5. **Review results:**
   ```bash
   # Check Streamlit for completed status
   # Or read ticket comments for full audit trail
   ```

---

## 📚 Document Map

```
├── QUICK-START.md ......................... (this file) Overview + quick answers
├── QUICK-TEST-COMMANDS.md ................ Copy-paste commands for each step
├── TESTING-GUIDE.md ...................... Deep dive (architecture + troubleshooting)
├── N8N-SETUP-GUIDE.md .................... N8N workflow setup & testing
├── SECRETS-MANAGEMENT.md ................. Security & environment configuration
├── ENV-QUICK-REFERENCE.md ............... .env variables reference
├── .env ................................. Your secrets (keep private!)
├── .env.template ......................... Template (safe to commit)
└── docker-compose.yml ................... Service orchestration
```

---

## 🎬 Let's Get Started!

Pick one:

- 🚀 **Fast path (5 min):** Copy-paste test from [QUICK-TEST-COMMANDS.md](QUICK-TEST-COMMANDS.md#2️⃣-send-test-alert-1-minute) then approve manually
- 🚶 **Step-by-step (30 min):** Follow [TESTING-GUIDE.md](TESTING-GUIDE.md) → Testing Sequence
- 📖 **Learning (60 min):** Read all docs then test

**First command:**
```bash
curl http://localhost:9000/health | jq '.'
```

If you see `"status": "ok"` ✅ → **You're ready to start testing!**

