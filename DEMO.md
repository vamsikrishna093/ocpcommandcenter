# AIOps Platform — Management Demo Runbook

**Duration:** ~10 minutes
**Audience:** VP Engineering / CTO / Leadership

---

## Pre-Demo Setup

### 1. Start the Platform

```bash
cd /Volumes/Data/Codehub/xyopsver2
./xyops-start.sh --start
```

Or if already running, verify health:

```bash
./xyops-start.sh --test
```

### 2. Open Browser Tabs

| Tab | URL | Login | Purpose |
|-----|-----|-------|---------|
| 1 | http://localhost:5522 | `admin` / `admin` | **xyOps** — Ticket & workflow system |
| 2 | http://localhost:3001 | `admin` / `admin` | **Grafana** — Observability dashboards |
| 3 | http://localhost:3002 | `aiops` / `Aiops1234!` | **Gitea** — Git audit trail |
| 4 | Terminal | — | For firing alerts |

### 3. Pre-Navigate in Each Tab

- **xyOps:** Click **Tickets** tab (top nav)
- **Grafana:** Open **Dashboards → Agentic AI Overview**
- **Gitea:** Navigate to http://localhost:3002/aiops-org/ansible-playbooks/pulls

---

## Act 1 — "The Problem" (1 minute)

### Talking Points

> *"Our frontend-api service just started throwing 500 errors. In a traditional setup, an engineer gets paged, SSHs into the box, checks logs, checks metrics, writes a runbook, executes it. That takes 30–60 minutes.*
>
> *Let's watch what our AIOps platform does — fully automated, from detection to remediation."*

### Action: Fire the Alert

Paste this into your terminal:

```bash
curl -s -X POST http://localhost:9000/webhook \
  -H 'Content-Type: application/json' \
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
        "summary": "Error rate exceeded 5% threshold on frontend-api"
      },
      "startsAt": "2026-03-23T10:00:00Z"
    }]
  }'
```

**Expected output:** `"action":"ticket_created"` with a ticket number.

> *"I just simulated what Prometheus does when it detects a threshold breach. Prometheus fires an alert → Alertmanager routes it → our Compute Agent picks it up."*

---

## Act 2 — "AI Analysis" (2 minutes)

### Action: Switch to xyOps (Tab 1)

1. Click **Tickets** → find the newest ticket: `[AIOPS] HighErrorRate on frontend-api [WARNING]`
2. Open it

### What to Point Out

| Section in Ticket | What It Shows |
|-------------------|---------------|
| **Service / Alert / Severity** table | Auto-classified metadata |
| **Dashboard** link | Clickable link to Grafana (localhost:3001) |
| **OTel Trace ID** | Paste into Grafana → Tempo to see the full trace waterfall |
| **AI Root Cause Analysis** | LLM-generated RCA with confidence score |
| **Scenario Match** | System recognized this degradation pattern from a catalog of 20+ patterns |
| **Risk Score** | Weighted assessment (severity 30%, scenario confidence 40%, logs 15%, forecast 15%) |
| **Local LLM Validation** | Second-opinion from self-hosted llama3.2 — `corroborated` / `weak_support` / `divergent` |

### Talking Points

> *"Within 10 seconds, the platform:*
> 1. *Pulled the last 50 log lines from Loki*
> 2. *Queried Prometheus for golden-signal metrics (error rate, latency, restart count)*
> 3. *Matched this against a catalog of 20+ known degradation scenarios*
> 4. *Computed a risk score from 4 evidence signals*
> 5. *Ran an SRE reasoning engine to build a deterministic causal chain*
> 6. *Sent everything to GPT-4 for root cause analysis and remediation plan*
> 7. *Validated the GPT-4 result against historical incidents using a local LLM (llama3.2)*
>
> *All of that is in this one ticket."*

---

## Act 3 — "The Remediation Plan" (2 minutes)

### Action: Scroll Down in the Same Ticket

| Section | What It Shows |
|---------|---------------|
| **Ansible Playbook** | Auto-generated YAML — ready to execute |
| **Test Plan** | Pre-validated before execution |
| **Rollback Steps** | Automatic rollback if the playbook fails |
| **Gitea PR** | `View PR #XX` — clickable link |
| **Repository** | `http://localhost:3002/aiops-org/ansible-playbooks` |

### Action: Click the PR Link → Opens Gitea (Tab 3)

Show:
- The **branch name**: `remediation/frontend-api-higherrorrate-YYYYMMDD-HHMMSS`
- The **committed file**: an Ansible playbook YAML
- The **diff view**: exactly what will be executed

### Talking Points

> *"Every remediation is committed to Git BEFORE it runs. This gives us:*
> - *Full audit trail — who approved what, when*
> - *Code review — the playbook is visible as a PR diff*
> - *Rollback — revert the commit if something goes wrong*
> - *Compliance — Git history is immutable evidence"*

---

## Act 4 — "Human Approval Gate" (2 minutes)

### Talking Points

> *"The system doesn't just run things blindly. We have a 4-tier trust model:"*

| Tier | Service Type | Requirements for Autonomous Mode |
|------|-------------|----------------------------------|
| **Production** | Customer-facing | 10+ approved runs, ≥95% success rate, risk < 0.50 |
| **Staging** | Pre-prod / QA | 5+ approved runs, ≥90% success, risk < 0.65 |
| **Development** | Dev / integration | 3+ approved runs, ≥80% success, risk < 0.75 |
| **Sandbox** | Playground / demo | Immediate autonomous (risk < 0.85) |

> *"frontend-api is classified as Production, so it ALWAYS requires two steps: merge the PR, then click Approve. As the system builds trust through successful executions, staging and dev services can auto-remediate."*

### Action: Merge the PR on Gitea

1. On the Gitea PR page, click **Merge Pull Request** → **Merge**
2. Note the PR number (e.g., `#24`)

### Action: Approve the Remediation

Find the approval ID from the ticket body (or from the test output), then:

```bash
# Replace <APPROVAL_ID> with the actual value, e.g. apr-4fb75040c002
curl -s -X POST http://localhost:9000/approval/<APPROVAL_ID>/decision \
  -H 'Content-Type: application/json' \
  -d '{"approved": true, "decided_by": "demo-user"}'
```

**Expected:** Ansible playbook executes → result posted as comment on the xyOps ticket.

### Action: Refresh the xyOps Ticket

Show the execution result comment that appeared at the bottom of the ticket.

> *"The playbook ran, the result is logged back to the ticket, the PR is merged to Git, and the outcome is stored in our knowledge base for future learning."*

---

## Act 5 — "Observability of the AI" (2 minutes)

### Action: Switch to Grafana (Tab 2)

Open **Dashboards → Agentic AI Overview**

### What to Point Out

| Panel | What It Shows |
|-------|---------------|
| Webhooks Received | Alert ingestion rate |
| Autonomous Actions | Actions that bypassed approval |
| Pending Approvals | Current human-gated items |
| Local LLM Validation | Verdicts: corroborated vs divergent |
| Processing Latency | End-to-end pipeline speed |

### Talking Points

> *"We observe the observers. Every AI decision, every approval, every execution is tracked with OpenTelemetry traces and Prometheus metrics. We can see:*
> - *How fast the AI responds*
> - *Whether the local LLM agrees with the cloud LLM*
> - *How many incidents are being handled autonomously vs requiring approval*
> - *Trust score trends per service over time"*

---

## Act 6 — "Architecture & The Bigger Picture" (1 minute)

### Talking Points

> *"Under the hood, this is 20+ containerised services in Docker Compose:"*

| Layer | Components |
|-------|------------|
| **Telemetry** | OpenTelemetry Collector → Prometheus, Loki, Tempo |
| **Alerting** | Prometheus alert rules → Alertmanager → domain routing |
| **Agents** | Compute Agent + Storage Agent (shared intelligence engine) |
| **Intelligence** | Scenario correlator, risk scorer, anomaly detector (Z-score), forecaster (linear regression), SRE reasoning agent |
| **LLM (3-tier)** | Deterministic reasoning → GPT-4/Claude (authoritative) → Ollama llama3.2 (advisory) |
| **Knowledge** | ChromaDB vector store — learns from every resolved incident |
| **Execution** | Ansible Runner → Gitea PR audit trail |
| **Ticketing** | xyOps platform + optional ServiceNow + optional n8n orchestration |
| **UI** | React Command Center + Grafana dashboards |

> *"The key architectural innovation: both agents share ONE intelligence engine. Adding a network agent or database agent tomorrow reuses the same scenario engine, risk scorer, and knowledge store — zero duplication."*

### If Asked: "What's the Roadmap?"

- **Network / Database agents** — same shared intelligence engine, zero duplication
- **Slack / PagerDuty integration** — Alertmanager already supports it, 1-day effort
- **Multi-cluster Kubernetes** — scale across clusters with the same pipeline
- **Cost tracking** — cost per incident, cost savings from automation
- **Progressive autonomy** — the system gets smarter with every incident

---

## Quick Reference — All URLs

| Service | URL |
|---------|-----|
| xyOps (Tickets) | http://localhost:5522 |
| Grafana | http://localhost:3001 |
| Gitea (PRs) | http://localhost:3002/aiops-org/ansible-playbooks/pulls |
| Compute Agent Health | http://localhost:9000/health |
| Storage Agent Health | http://localhost:9001/health |
| Obs-Intelligence | http://localhost:9100/intelligence/current |
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| n8n Workflows | http://localhost:5679 |
| Streamlit Dashboard | http://localhost:8501 |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Ticket not appearing in xyOps | Check `curl http://localhost:9000/health` — if unhealthy, run `docker compose up -d compute-agent` |
| PR link shows "page not found" | Gitea may need a moment — refresh after 5 seconds |
| Approval says "PR not merged" | Merge the PR on Gitea first, then retry the approve curl |
| Grafana panels empty | Run `docker compose restart grafana`, wait 10s, refresh |
| Pipeline stuck at `awaiting_approval` | This is normal for Production-tier — merge PR + approve |
