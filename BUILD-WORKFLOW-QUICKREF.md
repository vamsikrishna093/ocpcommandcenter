# 🎯 Quick Reference: Build & Workflow at a Glance

## 📊 Visual Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   TELEMETRY COLLECTION                          │
│  Applications → OTel SDK → OTel Collector (4317)                │
└──────────────────────────────────────────────────────────────┬──┘
                                                                 │
                ┌─────────────────────────────────┐             │
                │   OBSERVABILITY STORES           │             │
                ├─────────────────────────────────┤◄────────────┘
                │ • Prometheus (9090) - Metrics   │
                │ • Loki (3100) - Logs            │
                │ • Tempo (3200) - Traces         │
                │ • Grafana (3000) - Visualization│
                └────────────────┬────────────────┘
                                 │ Alert Rules
                                 ▼
                        Alertmanager (9093)
                        ├─ domain=compute ──→ compute-agent (9000)
                        └─ domain=storage  ──→ storage-agent (9001)
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
            ┌──────────────────────┐  ┌──────────────────────┐
            │ COMPUTE AGENT        │  │ STORAGE AGENT        │
            │ Alert Ingestion      │  │ Alert Ingestion      │
            │ Pipeline: 6 Steps    │  │ Pipeline: 6 Steps    │
            │ (see below)          │  │ (see below)          │
            └────────────┬─────────┘  └─────────────┬────────┘
                         │                          │
                         └──────────────┬───────────┘
                                        │ POST /analyze
                                        ▼
                    ┌─────────────────────────────────────┐
                    │  SHARED INTELLIGENCE ENGINE (9100)  │
                    ├─────────────────────────────────────┤
                    │ 1. Scenario Correlator (20 scenarios)│
                    │ 2. SRE Reasoning Agent (deterministic) │
                    │ 3. Risk Scorer (composite metric)    │
                    │ 4. Anomaly Detector (Z-score)        │
                    │ 5. Forecaster (trend projection)     │
                    │ 6. LLM Enricher (OpenAI/Claude)      │
                    │    └─ Validated by Ollama qwen3.5    │
                    │    └─ Similarity search: ChromaDB     │
                    └─────────┬───────────────────────────┘
                              │ Recommendation + Risk
                              ▼
                    ┌─────────────────────────────┐
                    │  xyOps Platform (5522)      │
                    │ • Create Ticket             │
                    │ • Approval Workflow Canvas  │
                    └─────────┬───────────────────┘
                              │ Approved
                              ▼
                    ┌─────────────────────────────┐
                    │  ansible-runner (8090)      │
                    │ • Playbook Dry-Run / Execute│
                    │ • Gitea PR Audit Trail (3002)
                    └──────────┬──────────────────┘
                               │ Outcome
                               ▼
                    ┌─────────────────────────────┐
                    │  Knowledge Store (ChromaDB) │
                    │ Learn from outcomes         │
                    └─────────────────────────────┘
```

---

## 🔄 6-Step Agent Analysis Pipeline

```
ALERT FIRES
    ↓
1️⃣  PARSE
    └─ Labels: domain, alertname, severity
    └─ Annotations: summary, description
    └─ Timestamps: firing_time
    
    ↓
2️⃣  FETCH CONTEXT (1h history)
    └─ Prometheus: 80+ metric queries
    └─ Loki: 20+ log queries
    └─ Result: Raw time-series data
    
    ↓
3️⃣  EXTRACT FEATURES
    └─ Convert metrics/logs → typed ObsFeatures
    └─ 40+ typed fields (cpu_pct, memory_gb, latency_ms, etc.)
    └─ Result: Typed, normalized feature vector
    
    ↓
4️⃣  SCENARIO MATCHING (OIE)
    └─ Compare features vs 20 scenario templates
    └─ Score each by confidence (0.0—1.0)
    └─ Result: Top 3 scenarios ranked by confidence
    
    ↓
5️⃣  RISK SCORING (OIE)
    └─ Composite: 30% severity + 40% confidence 
                  + 15% anomaly + 15% forecast
    └─ Result: Single risk_score (0.0—1.0)
    
    ↓
6️⃣  EVIDENCE + LLM ENRICHMENT (Optional)
    └─ Gather matched scenarios + metric snapshots + error logs
    └─ Call OpenAI/Claude for narrative
    └─ Validate with Ollama qwen3.5
    └─ Result: EvidenceReport + LLMEnrichment
    
    ↓
RECOMMENDATION + AUTONOMY DECISION
├─ risk_score ──→ urgency
├─ scenario ────→ playbook
└─ autonomy ────→ human_only / approval_gated / autonomous
```

---

## 🏃 Build & Start Timeline

```
docker compose up --build

T=0s:      Start build (parallel for non-dependent)
T=0-3m:    Build Python base images (obs-intelligence, agents, etc.)
T=3m:      Images built, services start (parallel):
           ├─ otel-collector (instant) ✓
           ├─ prometheus (2s)           ✓
           ├─ loki (2s)                 ✓
           ├─ tempo (2s)                ✓
           ├─ knowledge-store (1s)      ✓
           └─ alertmanager (1s)         ✓

T=5m:      Infrastructure healthy, OIE-dependent services start:
           ├─ obs-intelligence         (load 20 scenarios)
           ├─ compute-agent            (register webhook)
           └─ storage-agent            (register webhook)

T=6m:      Core services ready:
           ├─ grafana (3000)            ✓
           ├─ xyops (5522)              ✓ (admin setup needed)
           ├─ ansible-runner (8090)    ✓
           └─ gitea (3002)              ✓

T=7m:      Optional UI:
           ├─ ui-backend (9005)         ✓
           ├─ aiops-ui nginx (3005)    ✓
           ├─ streamlit dashboard (8501) ✓
           └─ command-center (3500)    ✓ (dev only)

T=8m:      Optional Demo Traffic (if profiles enabled):
           ├─ loadgen (steady traffic) ✓
           └─ troublemaker (chaos)     ✓

T=10m:     Ollama download (background) — qwen3.5 + nomic-embed (~2 GB)

T=15m:     System ready for production use
```

---

## 📊 Service Dependencies

```
MUST START FIRST:
  └─ otel-collector, prometheus, loki, tempo (independent)

DEPENDS ON ABOVE:
  └─ obs-intelligence (queries Prom + Loki)
  
DEPENDS ON OIE:
  ├─ compute-agent (calls /analyze)
  └─ storage-agent (calls /analyze)

DEPENDS ON AGENTS + OIE:
  ├─ ui-backend (queries both agents + OIE)
  ├─ xyops (receives tickets from agents)
  ├─ alertmanager (routes to agents)
  └─ grafana (queries all services for dashboards)

OPTIONAL (no hard dependencies):
  ├─ N8N orchestrator (subscribes to agents)
  ├─ streamlit dashboard (queries ui-backend)
  └─ command-center UI (queries ui-backend)
```

---

## 🔐 Configuration

### Required (must set before production)

```bash
# .env file
OPENAI_API_KEY=sk-...              # LLM enrichment (optional, falls back to deterministic)
ANTHROPIC_API_KEY=sk-...           # LLM failover (optional)
XYOPS_API_KEY=...                  # From xyOps admin panel (one-time setup)
```

### Optional

```bash
ANSIBLE_LIVE_MODE=false            # true = execute real playbooks, false = dry-run
OLLAMA_GPU=false                   # true = use GPU if available
LOCAL_LLM_MODEL=qwen3.5            # Alternative: llama3.2:3b (upgraded in v14)
```

---

## 🎯 First Alert Flow (30 seconds total)

```
T=0s:  Alert fires (manual curl or chaos injection)
T=1s:  Alertmanager routes to compute-agent:9000/webhook
T=2s:  Agent parses, fetches context, extracts features
T=3s:  Agent calls OIE /analyze
T=4s:  OIE: scenario matching + risk scoring
T=5s:  OIE: LLM enrichment (if enabled, adds 2-3s)
T=8s:  Agent receives recommendation
T=9s:  Agent creates xyOps ticket
T=10s: Ticket appears in xyOps UI with:
       ├─ Risk badge (color-coded by risk_score)
       ├─ Matched scenarios + confidence
       ├─ Evidence (metric snapshots, logs, forecast)
       ├─ LLM narrative (if enriched)
       ├─ Recommended playbook
       └─ Approval canvas

T=30s: Engineer approves (or auto-executes if autonomous)
T=33s: Playbook executes (2s duration)
T=...:  Outcome recorded → knowledge base updated
```

---

## 📈 Scaling & Customization

| Area | How to Scale |
|------|--------------|
| **Add Scenario** | Create `obs-intelligence/scenarios/new_scenario.yml` → OIE reloads automatically |
| **Add Metric** | Update `feature_extractor.py` → new typed field in ObsFeatures |
| **Add LLM Provider** | Edit `llm_enricher.py` → add new provider with fallback chain |
| **Add Agent** | Copy compute-agent → customize for new domain, reuse OIE |
| **Multi-replica** | Deploy OIE to K8s with HPA, agents stateless, share knowledge via Redis |
| **Persistence** | Replace in-memory state with Redis/SQLite |

---

## 🔍 Troubleshooting Quick-Links

| Issue | Check |
|-------|-------|
| Alerts not firing | `docker logs prometheus` — alert rules evaluation |
| Agents not receiving alerts | `docker logs alertmanager` — webhook routing config |
| OIE not matching scenarios | `docker logs obs-intelligence` — scenario correlation logs |
| LLM enrichment slow | `docker logs local-llm` — model loaded? GPU available? |
| Tickets not created | `docker logs compute-agent` — xyOps API key set? |
| Knowledge store not learning | `docker logs obs-intelligence` — `/record-outcome` called? |

---

## 🚀 Common Commands

```bash
# Start full stack
docker compose up --build

# Start with demo traffic + chaos
docker compose --profile loadgen --profile troublemaker up --build

# View logs
docker compose logs -f

# Specific service
docker compose logs -f compute-agent

# Run tests
docker compose run --rm obs-intelligence pytest tests/

# Shell into service
docker compose exec obs-intelligence /bin/bash

# Stop all
docker compose down

# Clean volumes (data loss!)
docker compose down -v

# Live metric scraping
curl http://localhost:9090/api/v1/query?query=up

# Send test alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d @tests/test_alert.json
```

---

## 📚 Documentation Map

| File | Purpose |
|------|---------|
| **README.md** | Project overview + quick start |
| **PROJECT-BUILD-WORKFLOW.md** | This deep-dive (complete system design) |
| **ARCHITECTURE_DESIGN_MULTI_AGENT.md** | Multi-agent design decisions |
| **CONTRIBUTING-SCENARIOS.md** | How to write new scenarios |
| **DEMO-RUNBOOK.md** | Step-by-step rehearsal guide |
| **RELEASE-NOTES.md** | Version history |
| **LEARNING-LAYER-ARCHITECTURE.md** | Feedback loop + learning |
| **MERGE-SUMMARY.md** | v14 obseransiblerepo merge details |
| **STREAMLIT-QUICKSTART.md** | Dashboard pages guide |
| **N8N-MASTER-ORCHESTRATOR-GUIDE.md** | N8N integration details |

---

## 🎓 Key Concepts

### Risk Score (0.0 — 1.0)

```
risk_score = (
  0.30 × severity_factor +        # Alert severity label
  0.40 × scenario_confidence +    # How well features match scenario
  0.15 × anomaly_log_factor +     # Unusual error/warn logs detected
  0.15 × forecast_urgency         # Trend extrapolation urgency
)

Example:
  Severity: critical (1.0)           → 0.30 × 1.0 = 0.30
  Scenario: cpu_saturation (1.0)    → 0.40 × 1.0 = 0.40
  Anomaly: 18 errors detected (0.8) → 0.15 × 0.8 = 0.12
  Forecast: degrading (1.0)         → 0.15 × 1.0 = 0.15
  ─────────────────────────────────────────────────
  TOTAL:                                        0.97 (critical!)
```

### Autonomy Levels

| Level | Trigger | Approval | Role |
|-------|---------|----------|------|
| **autonomous** | Low-risk actions (pod restart, cache clear) | None | Agent executes immediately |
| **approval_gated** | Medium-risk (scaling, config change) | Human | Agent creates ticket, waits for approval |
| **human_only** | High-risk (data delete, live migration) | Required | Agent creates ticket, no auto-execution |

### Scenario Confidence

Calculated from feature match:

```
Scenario has 4 conditions with weights [0.4, 0.3, 0.2, 0.1]

If all match:
  confidence = (1.0×0.4 + 1.0×0.3 + 1.0×0.2 + 1.0×0.1) / 4 = 1.0 (100%)

If 3 match:
  confidence = (1.0×0.4 + 1.0×0.3 + 1.0×0.2 + 0.0×0.1) / 4 = 0.75 (75%)

If 1 matches:
  confidence = (0.0×0.4 + 0.0×0.3 + 0.0×0.2 + 1.0×0.1) / 4 = 0.25 (25%)
```

---

## ✨ What Makes v14.0.0 Special

1. **Streamlit Dashboard** — Real-time operational visibility (7 pages)
2. **Qwen3.5 LLM** — Superior reasoning over previous llama3.2
3. **Hybrid AI** — Deterministic (SRE Agent) + LLM (narratives)
4. **Shared Intelligence** — All agents use same OIE core
5. **Local Validation** — Every external LLM result validated by local Ollama
6. **Knowledge Learning** — ChromaDB grows with each incident
7. **N8N Integration** — Orchestration layer for complex workflows
8. **Enterprise Ready** — Audit trails (Gitea), approval workflows, metrics

---

**For detailed implementation, see [PROJECT-BUILD-WORKFLOW.md](PROJECT-BUILD-WORKFLOW.md)**

