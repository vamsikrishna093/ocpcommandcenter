# 🏗️ Complete Project Build & Workflow Architecture

**Project**: xyopsver2 v14.0.0 — Multi-Agent AIOps Platform  
**Updated**: March 22, 2026 (Post-Merge with obseransiblerepo)

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Build Process](#build-process)
3. [Architecture & Data Flow](#architecture--data-flow)
4. [Runtime Workflow](#runtime-workflow)
5. [Service Dependencies](#service-dependencies)
6. [Deployment Process](#deployment-process)
7. [Orchestration & Coordination](#orchestration--coordination)
8. [Intelligence Pipeline](#intelligence-pipeline)
9. [Observability & Metrics](#observability--metrics)

---

## 📌 Project Overview

### What This Project Does

xyopsver2 is an **end-to-end AIOps platform** that:
1. Collects telemetry from applications (metrics, traces, logs via OpenTelemetry)
2. Detects anomalies and fires alerts via Prometheus
3. Routes alerts to domain-specific agents (Compute, Storage)
4. Analyzes incidents using an intelligent correlation engine
5. Creates tickets in the xyOps ITSM platform
6. Executes approved remediation via Ansible
7. Tracks outcomes and builds knowledge for continuous improvement

### Key Innovation: Multi-Agent Intelligence Sharing

Unlike traditional silos, all agents share:
- **Unified Intelligence Engine (OIE)**: Scenario matching, anomaly detection, forecasting, risk scoring
- **Shared Knowledge Store**: ChromaDB vector store of past incidents for similarity matching
- **Unified LLM Layer**: Local (Ollama/qwen3.5) + external (OpenAI/Claude) with automatic failover

---

## 🚀 Build Process

### Stage 1: Docker Image Building

The project uses **multi-stage Docker builds** with **docker-compose up --build** orchestration.

#### Base Images

| Service | Base Image | Purpose |
|---------|-----------|---------|
| **obs-intelligence** | `python:3.12-slim` | Shared ML/analysis core |
| **compute-agent** | `python:3.12-slim` | Alert ingestion + ticket creation |
| **storage-agent** | `python:3.12-slim` | Storage domain wrapper |
| **otel-collector** | `otel/opentelemetry-collector-contrib:0.x` | Official OTEL distro |
| **prometheus** | `prom/prometheus:latest` | Official Prometheus image |
| **tempo** | `grafana/tempo:latest` | Grafana trace storage |
| **loki** | `grafana/loki:latest` | Grafana log aggregation |
| **grafana** | `grafana/grafana:latest` | Official Grafana |
| **alertmanager** | `prom/alertmanager:latest` | Official Alertmanager |
| **local-llm** | `ollama/ollama:latest` | Local LLM (qwen3.5) |
| **knowledge-store** | `chromadb/chroma:latest` | Vector database |
| **xyops** | Custom Python/Node | AIOps platform |
| **ansible-runner** | `custom (Dockerfile)` | Playbook executor |
| **gitea** | `gitea/gitea:latest` | Git platform |
| **aiops-ui** | `nginx:latest` | Static file server (React) |
| **ui-backend** | `python:3.12-slim` | FastAPI BFF |
| **command-center** | `node:20-slim` | Vite dev/build |
| **streamlit-dashboard** | `python:3.12-slim` | Streamlit UI |

#### Build Layers for Python Services

**Example: compute-agent**

```dockerfile
# 1. Base layer
FROM python:3.12-slim

# 2. Setup for obs_intelligence dependency
COPY obs-intelligence/app/obs_intelligence /app/obs_intelligence

# 3. Install requirements (includes -e /app/obs_intelligence)
COPY compute-agent/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy application code
COPY compute-agent/app/ ./app/

# 5. Expose port
EXPOSE 9000

# 6. Start service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9000"]
```

**Build Order** (docker-compose respects dependency graph):
1. `obs-intelligence` → shared package (no dependents)
2. `compute-agent`, `storage-agent` → depend on obs-intelligence built package
3. `ui-backend` → depends on obs_intelligence if needed
4. All other services → parallel (no dependencies)

### Stage 2: Volume Mounting

Each service mounts **configuration + data volumes**:

```yaml
services:
  prometheus:
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml  # Config (read-only)
      - ./prometheus/alert-rules.yml:/etc/alert-rules.yml          # Rules (read-only)
      - prometheus-data:/prometheus                                 # Data (persistent)

  obs-intelligence:
    volumes:
      - ./obs-intelligence/scenarios:/app/scenarios  # YAML scenario files (read-only)
      - obs-intelligence-data:/app/data              # Runtime data (persistent)
```

### Stage 3: Network Setup

All services on custom bridge network `obs-net`:
```yaml
networks:
  obs-net:
    driver: bridge
```

**Benefit**: DNS resolution by service name (e.g., `http://prometheus:9090` from any container)

### Stage 4: Environment Variables

Each service inherits `.env` file + explicit `environment:` section:

```yaml
environment:
  # Block F: LLM
  LOCAL_LLM_MODEL: "qwen3.5"          # Originally llama3.2:3b, upgraded in v14
  LOCAL_LLM_ENABLED: "true"           #
  
  # Block F: Knowledge Store
  CHROMA_URL: "http://knowledge-store:8000"
  
  # Observability
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
  
  # API Keys (optional, fallback to deterministic if missing)
  OPENAI_API_KEY: "${OPENAI_API_KEY}"      # Optional
  ANTHROPIC_API_KEY: "${ANTHROPIC_API_KEY}" # Optional
```

### Stage 5: Health Checks

Each service defines `healthcheck:`:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:9090/-/healthy"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 30s
```

Docker waits for health green before starting dependent services.

---

## 🏛️ Architecture & Data Flow

### Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     TELEMETRY SOURCES                              │
├─────────────────────────────────────────────────────────────────────┤
│  frontend-api (8080) ─┐                                             │
│  backend-api (8081)  ├──→ OTel SDK (spans, metrics, logs)         │
│  xyops (5522)        ─┘                                             │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────┐
        │  OTel Collector (4317/gRPC)       │
        │  - Receives OTLP telemetry        │
        │  - Batch + retry logic            │
        └───────────────────────────────────┘
         ↙                    ↓                  ↘
    Prometheus          Loki (3100)          Tempo (3200)
    (Metrics)          (Logs)                (Traces)
         ↓                    ↓                  ↓
    Storage:            Storage:            Storage:
    prometheus-data    loki-data           tempo-data
        
    ├─→ Alert Rules Evaluation (every 1 min)
    └─→ FIRING alerts →→→ Alertmanager (9093)
```

### Alert Routing Pipeline

```
Alertmanager (9093)
    ↓
    ├─→ [Labels: domain=compute] → Compute Agent (9000) via webhook
    │       POST /webhook
    │
    ├─→ [Labels: domain=storage] → Storage Agent (9001) via webhook
    │       POST /webhook
    │
    └─→ [Inhibition Rules] (suppress child alerts if parent firing)
```

### Agent Analysis Pipeline (Compute or Storage)

```
Agent receives Alert
    ↓
1️⃣  PARSE: Extract labels, annotations, timing
    ↓
2️⃣  FETCH CONTEXT: Query Prometheus + Loki for historical metrics/logs
    ↓
3️⃣  EXTRACT FEATURES: Build typed ObsFeatures object
    ↓
4️⃣  CALL OIE: POST /analyze to Obs-Intelligence Engine
    ↓
    Obs-Intelligence Engine (OIE at 9100):
    ├─→ 🔄 Scenario Matching (20 scenarios, 10 compute + 10 storage)
    ├─→ 📊 Risk Scoring (30% severity + 40% confidence + 15% anomaly + 15% forecast)
    ├─→ 🤖 SRE Reasoning (deterministic causal chain building)
    ├─→ 🧠 Optional LLM (OpenAI/Claude with Ollama qwen3.5 validation)
    ├─→ 📋 Evidence Building (matched signals, log counts, thresholds)
    └─→ Returns: Recommendation, RiskAssessment, EvidenceReport, LLMEnrichment
    ↓
5️⃣  CREATE TICKET: Call xyOps API to create incident ticket
    ├─→ Ticket includes: risk level, evidence, LLM narrative, scenarios matched
    ├─→ Auto-assigns autonomy level (human_only / approval_gated / autonomous)
    ↓
6️⃣  EXECUTE REMEDIATION (if autonomy allows)
    ├─→ Call /run at ansible-runner (8090)
    ├─→ Playbook dry-run by default (ANSIBLE_LIVE_MODE=false)
    ├─→ If approved + live mode: playbook executes on target hosts
    ├─→ Creates PR in Gitea (3002) for audit trail
    ↓
7️⃣  RECORD OUTCOME: Report success/failure back to OIE
    └─→ POST /intelligence/record-outcome updates knowledge store
```

### Complete Data Flow Diagram

```
┌──────────────────┐
│ Telemetry Source │
└────────┬─────────┘
         │ OTLP/gRPC
         ▼
┌──────────────────────────┐
│  OTel Collector (4317)   │
├──────────────────────────┤
│ • Metrics   ──→ Prom     │
│ • Logs      ──→ Loki     │
│ • Traces    ──→ Tempo    │
└──────┬───────────────────┘
       │
       ▼
   Prometheus (9090)
       │ every 60s
       ├─→ Evaluate alert rules
       └─→ FIRING → Alertmanager (9093)
               │
               ├─ [domain=compute] ──→ Compute Agent (9000)
               └─ [domain=storage]  ──→ Storage Agent (9001)
                       │
                       ├─→ Query Prometheus + Loki
                       ├─→ Extract features
                       └─→ 🎯 POST /analyze → OIE (9100)
                
            Obs-Intelligence Engine (9100)
            ├─ Scenario Correlator                    
            ├─ SRE Reasoning Agent (deterministic)   
            ├─ Risk Scorer                            
            ├─ Anomaly Detector                       
            ├─ Forecaster                              
            ├─ LLM Enricher:                             
            │  └─ OpenAI/Claude (primary)             
            │  └─ Ollama qwen3.5 (validation)         
            │  └─ ChromaDB (similarity search)         
            ├─ Evidence Builder                       
            └─ Metrics Publisher                      
                       │
                       ├─→ Create xyOps Ticket (5522)
                       ├─→ Execute Playbook (if autonomous)
                       │   └─→ ansible-runner (8090)
                       │   └─→ Create PR in Gitea (3002)
                       └─→ Record outcome in knowledge store
                
        Knowledge Store (ChromaDB 8020)
        └─ Vector embeddings of all incidents
           └─ Used for similarity matching on next alert
```

---

## ⚙️ Runtime Workflow

### Startup Sequence (docker-compose up --build)

**Phase 1: Infrastructure (parallel, except where noted)**

```
T=0      docker-compose build [all services in dependency order]
         ├─ obs-intelligence (no deps)
         ├─ compute-agent (waits for obs-intelligence)
         ├─ storage-agent (waits for obs-intelligence)
         └─ All others (no Python deps)

T=+3m    Services start:
         1. otel-collector (4317) - readiness: /status
         2. prometheus (9090) - readiness: /-/healthy
         3. loki (3100) - readiness: /ready
         4. tempo (3200) - readiness: /ready
         5. knowledge-store/ChromaDB (8020) - readiness: /ready
         6. local-llm/Ollama (11434) - entrypoint: pull qwen3.5 + nomic-embed-text (~2 min)
         7. alertmanager (9093) - waits for prometheus running
         
T=+5m    Data services healthy:
         - grafana (3000) - reads datasources (Prom, Loki, Tempo) ← cross-link enabled
         - xyops (5522) - needs admin setup (generate API key)
         - ansible-runner (8090) - ready for playbook calls
         - gitea (3002) - ready for PR creation
```

**Phase 2: Core Intelligence (must wait for Phase 1)**

```
T=+5m    obs-intelligence (9100):
         - Loads 20 scenario YAML files from ./obs-intelligence/scenarios/
         - Initializes Prometheus cached client
         - Initializes Loki cached client
         - Starts APScheduler:
           * Every 60 s: anomaly scan (Z-score per metric)
           * Every 5 min: forecasting + predictive alert dispatch
         - Readiness: /health endpoint returns {"status": "ok"}
         
         compute-agent (9000):
         - Imports obs_intelligence package
         - Initializes FastAPI app with webhook endpoint POST /webhook
         - Queries xyOps API (if XYOPS_API_KEY set) for ticket creation capability
         - Readiness: /health endpoint
         
         storage-agent (9001):
         - Same as compute-agent, alternate domain
         - Readiness: /health endpoint
```

**Phase 3: UI Layer (optional, waits for core)**

```
T=+6m    ui-backend (9005):
         - BFF aggregator for frontend
         - Connects to: compute-agent, storage-agent, obs-intelligence, xyops, gitea
         - Endpoints: /pipeline/*, /scenarios/*, /autonomy/*
         
         command-center / Vite (3500):
         - React SPA developed (dev mode only, production built to aiops-ui)
         
         aiops-ui / Nginx (3005):
         - Serves React build from ./command-center/dist/
         - Proxies /api/* → ui-backend:9005
         
         streamlit-dashboard (8501):
         - 7 interactive pages for operational visibility
         - Connects to ui-backend for real-time data
```

**Phase 4: Demo Traffic (optional, via profiles)**

```
T=+7m    loadgen (if --profile loadgen):
         - Generates steady traffic to frontend-api/backend-api
         - Triggers metrics + traces flowing through system
         
         troublemaker (if --profile troublemaker):
         - Schedules chaos scenarios (CPU spike, memory leak, etc.)
         - Outputs schedule at http://localhost:8088/scenarios
         - Watches at: docker compose logs -f troublemaker
```

### Warm-Up Phase (First Run)

After `docker compose up success`, before first alert fires:

1. **Ollama Downloads Models** (~2 GB, 5-10 min)
   ```bash
   docker logs local-llm | grep "pulling"
   # ✓ pulling qwen3.5...
   # ✓ pulling nomic-embed-text...
   ```

2. **xyOps Initial Setup** (one-time)
   ```
   Open http://localhost:5522 → Login: admin/admin
   Admin → API Keys → Create Key
   Set XYOPS_API_KEY in docker-compose.yml env
   docker compose restart compute-agent storage-agent
   ```

3. **First Alert Fires** (via troublemaker or manual curl)
   ```bash
   curl -X POST http://localhost:9000/webhook \
     -H "Content-Type: application/json" \
     -d '{alert payload}'
   ```

4. **Agent Processing** (~5-10 s)
   - Parse alert → Fetch context → Extract features
   - Call OIE /analyze → Scenario matching + risk scoring
   - Create xyOps ticket
   - Execute playbook (if autonomous)
   - Record outcome

5. **Outcome Visible In**
   - xyOps dashboard (5522) - ticket details
   - Grafana (3000) - risk score gauge, scenario outcome counter
   - Streamlit dashboard (8501) - pipeline visualization
   - N8N (5679) - if enabled, orchestrator receives alert

---

## 🔗 Service Dependencies

### Build-Time Dependencies

```
obs-intelligence (Python package)
    ↑
    ├─── compute-agent (imports obs_intelligence)
    ├─── storage-agent (imports obs_intelligence)
    └─── ui-backend (imports obs_intelligence for type hints)
```

### Runtime Dependencies

```
Any Service
    ↓ depends on
Network: obs-net (bridge)

compute-agent (9000)
    ↓ depends on
    ├─ prometheus:9090 (fetch context queries)
    ├─ loki:3100 (fetch context queries)
    ├─ obs-intelligence:9100 (POST /analyze)
    ├─ xyops:5522 (ticket creation)
    └─ alertmanager:9093 (alert ingestion from)

storage-agent (9001)
    ↓ depends on
    ├─ [same as compute-agent]
    └─ storage-simulator:9200 (optional, generates test events)

obs-intelligence (9100)
    ↓ depends on
    ├─ prometheus:9090 (metric queries, scenario correlation)
    ├─ loki:3100 (log queries for evidence)
    ├─ local-llm:11434 (POST /api/embeddings + /api/generate, graceful degradation)
    └─ knowledge-store:8020 (ChromaDB, query() + add())

local-llm (11434)
    ↓ depends on
    └─ ollama-data volume (persistent models: qwen3.5, nomic-embed-text)

knowledge-store (8020)
    ↓ depends on
    └─ chroma-data volume (persistent vector database)

otel-collector (4317)
    ↓ depends on (exports to)
    ├─ prometheus:9090 (metrics exporter)
    ├─ loki:3100 (log exporter)
    └─ tempo:3200 (trace exporter)

alertmanager (9093)
    ↓ depends on
    ├─ prometheus:9090 (for alert rules status)
    └─ webhook receivers: compute-agent:9000, storage-agent:9001

ui-backend (9005)
    ↓ depends on
    ├─ compute-agent:9000 (/session/{id})
    ├─ storage-agent:9001 (/session/{id})
    ├─ obs-intelligence:9100 (/intelligence/current)
    ├─ xyops:5522 (ticket + workflow data)
    └─ gitea:3002 (PR audit trail)

aiops-ui Nginx (3005)
    ↓ depends on
    └─ ui-backend:9005 (proxied /api/*)

ansible-runner (8090)
    ↓ depends on
    ├─ gitea:3002 (clone playbook repos)
    └─ target hosts (inventory, if ANSIBLE_LIVE_MODE=true)

N8N (5678, external port 5679)
    ↓ depends on
    ├─ compute-agent:9000 (orchestration calls)
    └─ optional: all other services
```

### Startup Order (Enforced via healthcheck)

1. Networks created (obs-net)
2. Volumes mounted (prometheus-data, loki-data, etc.)
3. Non-dependent services start (otel-collector, prometheus, loki, tempo)
4. OIE dependencies ready (obs-intelligence starts only after Prom + Loki healthy)
5. Agents start (compute-agent, storage-agent)
6. Optional services (N8N, Streamlit, etc.)

---

## 📦 Deployment Process

### Local Development

```bash
# 1. Clone repo
git clone https://github.com/vamsikrishna093/obseransiblerepo.git xyopsver2
cd xyopsver2

# 2. Configure environment
cp .env.example .env
# Edit .env with optional API keys

# 3. Build + start
docker compose up --build

# 4. Verify all services healthy
docker ps --format "table {{.Names}}\t{{.Status}}"

# 5. xyOps one-time setup (if needed)
curl -X POST http://localhost:5522/admin/api-keys \
  -H "Authorization: Bearer admin_token" \
  -d '{...}'
# Copy key to .env → XYOPS_API_KEY

# 6. Restart agents with API key
docker compose restart compute-agent storage-agent

# 7. Send test alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{alert}'

# 8. Monitor
docker compose logs -f
```

### Production Deployment (Docker Swarm / K8s)

**Would require:**
1. Extracting docker-compose to Kubernetes manifests (Helm charts)
2. Adding persistent storage (NFS, S3, managed DB)
3. Authentication middleware (OAuth2, certificates)
4. Multi-replica services (load balancing)
5. Secrets management (HashiCorp Vault, k8s Secrets)
6. Ingress rules (reverse proxy with TLS)
7. Monitoring of platform itself (meta-observability)

---

## 🎯 Orchestration & Coordination

### How Services Coordinate

#### 1. Compute Agent + Storage Agent (Independent)

- Both listen independently on /webhook
- Alertmanager routes based on label selector
- No direct communication between agents
- Both call shared OIE for analysis

#### 2. Multi-Alert Correlation (Not Yet Implemented)

Future enhancement: When compute + storage alerts fire simultaneously,
a **meta-coordinator** would:
- Detect cross-domain cascade
- Call OIE with unified feature set
- Produce joint recommendation (e.g., "downsize VM before expanding storage pool")

#### 3. State Sharing via OIE

- Agents are **stateless** (just routers)
- OIE holds **mutable state**: current alerts, risk levels, anomalies
- Knowledge store (ChromaDB) holds **persistent state**: past incidents
- Both agents can call `/intelligence/current` to sync state

#### 4. Workflow Triggering

```
Agent → xyOps Ticket Creation
    ↓
xyOps Workflow Canvas:
    ├─ Pre-approval hooks (email, Slack, N8N)
    ├─ Parallel approval tasks
    ├─ Auto-approval for autonomous actions
    └─ Webhook on approval → ansible-runner
    
    ↓
ansible-runner → Playbook Execution
    ├─ Dry-run first (default)
    ├─ Log to Gitea PR for audit
    └─ Record outcome → POST /intelligence/record-outcome
```

### Communication Patterns

| Pattern | Source → Dest | Protocol | Reliability |
|---------|---|---|---|
| **Sync RPC** | Agent → OIE | HTTP POST /analyze | Retry 3x, then fail-safe |
| **Sync Query** | Agent → Prometheus/Loki | PromQL/LogQL | Cached, 30s TTL |
| **Async Webhook** | Alertmanager → Agent | HTTP POST | At-least-once (Alertmanager handles retry) |
| **Async Outcome** | Agent → OIE | HTTP POST /record-outcome | Fire-and-forget |
| **Event Stream** | N8N → Agents | HTTP Webhook | Reliable (N8N queues) |

---

## 🧠 Intelligence Pipeline

### The 6-Step Analysis Pipeline

Every alert flows through this deterministic sequence:

```
1️⃣  PARSE INPUT
    ├─ Extract: alert labels, annotations, firing time
    ├─ Filter: domain label (compute vs storage)
    └─ Timestamp: alert first seen

2️⃣  FETCH CONTEXT (Last 1h)
    ├─ Prometheus PromQL queries:
    │  ├─ avg_over_time(container_cpu_usage[1h])
    │  ├─ quantile(0.95, rate(http_request_duration[5m]))
    │  ├─ count(kube_pod_container_status_restarts_total > 10)
    │  └─ ... (80+ metric queries total)
    │
    └─ Loki LogQL queries:
       ├─ count_over_time({service_name="frontend-api", level="error"} | pattern `<_>` [1h])
       ├─ topk(10, {level="warn"} | json | service_name="backend-api" [1h])
       └─ ... (20+ log queries total)

3️⃣  EXTRACT FEATURES
    └─ Convert raw metrics + logs → typed ObsFeatures object:
       ├─ cpu_utilization_pct: float
       ├─ memory_used_gb: float
       ├─ latency_ms: float
       ├─ error_rate_5m: float
       ├─ request_volume_rps: float
       ├─ pod_restart_count: int
       ├─ disk_io_reads_sec: float
       ├─ storage_pool_fill_pct: float  (storage domain)
       ├─ anomaly_log_count: int
       └─ ... (40+ typed features)

4️⃣  SCENARIO MATCHING (OIE Scenario Correlator)
    └─ For each of 20 YAML scenario files:
       ├─ Load thresholds & rules (e.g., cpu_utilization_pct >= 90.0)
       ├─ Evaluate feature conditions & confidence weights
       ├─ Example: scenario_cpu_saturation.yml
       │  conditions:
       │    - cpu_utilization_pct >= 90.0  [weight: 0.4]
       │    - request_volume_rps > 5000    [weight: 0.3]
       │    - error_rate_5m > 0.1          [weight: 0.2]
       │    - latency_ms > 500             [weight: 0.1]
       │  confidence = (0.4 + 0.3 + 0.2 + 0.1) / 4 = 0.5  (50%)
       │
       └─ Return: List[ScenarioMatch] sorted by confidence DESC
    
    Result: Top 3 matching scenarios with confidence scores

5️⃣  RISK SCORING (OIE Risk Scorer)
    └─ Composite score: 0.0 — 1.0
       ├─ 30% × severity (from alert label)
       ├─ 40% × scenario_confidence (from step 4)
       ├─ 15% × anomaly_log_factor (new logs detected)
       └─ 15% × forecast_urgency (trend extrapolation)
    
    Result: RiskAssessment with:
       ├─ risk_score: 0.75
       ├─ trend: "degrading" | "stable" | "improving"
       ├─ time_to_critical_s: 3600  (if degrading)
       └─ urgency: "critical" | "high" | "medium" | "low"

6️⃣  EVIDENCE BUILDING + LLM ENRICHMENT (Optional)
    ├─ Evidence Builder:
    │  ├─ Matched scenarios: which + confidence
    │  ├─ Metric snapshots: current values + thresholds
    │  ├─ Log excerpts: top error messages (last 10)
    │  ├─ Anomaly count: number of features out of range
    │  └─ Forecast: predicted trajectory (e.g., "disk will fill in 6h")
    │
    ├─ LLM Enricher (Optional):
    │  ├─ Format evidence as prompt block
    │  ├─ Call OpenAI/Claude ("What's happening?")
    │  ├─ Get narrative (root cause hypothesis)
    │  ├─ Call Ollama qwen3.5 for validation:
    │  │  └─ Verdict: "corroborated" | "weak_support" | "divergent"
    │  └─ Result: LLMEnrichment with narrative + confidence
    │
    └─ Result: EvidenceReport + LLMEnrichment
       ├─ matched_scenarios: [ScenarioMatch, ...]
       ├─ metric_anomalies: int
       ├─ log_anomalies: int
       ├─ forecast_status: "normal" | "degrading" | "critical"
       └─ llm_narrative: "CPU exhaustion due to unoptimized query..."

================================================================================

SUMMARY: Single Alert → [ features (40+) → scenarios (20) → risk (1) → evidence + narrative ]
```

### SRE Reasoning Agent (Deterministic)

After scenario matching, the **SRE Reasoning Agent** builds a causal chain:

```python
# Input: ObsFeatures + ScenarioMatch
# Output: SREAssessment

sre_assessment = SREReasoningAgent.analyze(
  features=obs_features,
  top_scenario=cpu_saturation_scenario,
  domain="compute"
)

# Produces:
{
  "degradation_summary": "CPU utilization 95%, request volume 6000 RPS, latency spike to 800ms",
  "causal_chain": {
    "root_cause": "CPU exhaustion",
    "contributing_factors": [
      "Inefficient query in new deployment",
      "Horizontal scaling disabled (max pods = 3)"
    ],
    "blast_radius": "All HTTP APIs degraded, mobile app timeouts"
  },
  "predicted_impact": {
    "affected_services": ["frontend-api", "backend-api"],
    "user_impact": "5000+ concurrent users experience > 2s latency",
    "time_to_critical": "10 minutes"
  },
  "recommended_actions": [
    "IMMEDIATE: Scale frontend pods to 5 (from 3)",
    "SHORT TERM: CPU profile the new query",
    "MEDIUM TERM: Implement query cache"
  ],
  "autonomy_recommendation": "approval_gated",
  "urgency": "critical",
  "evidence_strength": 0.87
}
```

---

## 📊 Observability & Metrics

### Metrics Published by Each Service

#### compute-agent / storage-agent

```
# Webhook metrics
agent_webhook_requests_total{domain, method, status}
agent_webhook_duration_seconds{domain, quantile}

# Analysis metrics
agent_analysis_scenarios_matched{domain, scenario_id}
agent_analysis_risk_score{domain}  (gauge: 0.0—1.0)
agent_analysis_decisions{domain, decision}  (human_only, approval_gated, autonomous)

# Ticket creation
agent_ticket_created_total{domain, risk_level}
agent_ticket_creation_duration_seconds{domain}

# Ansible execution
agent_playbook_executed_total{domain, status}
agent_playbook_duration_seconds{domain}
```

#### obs-intelligence

```
# Scenario matching
oie_scenario_match_total{scenario_id, confidence_bucket}
oie_scenario_match_duration_seconds{scenario_id}

# Risk scoring
oie_risk_score{service_name}  (gauge: 0.0—1.0)
oie_risk_score_components{component}  (severity, confidence, anomaly, forecast)

# Anomaly detection
oie_anomaly_detections_total{service_name, metric_name}
oie_anomaly_z_score{service_name, metric_name}  (gauge)

# Forecasting
oie_forecast_predictions_total{service_name, status}
oie_forecast_accuracy_rmse{service_name}

# LLM enrichment
oie_llm_calls_total{provider, status}  (openai, claude, ollama)
oie_llm_validation_verdicts{verdict}  (corroborated, divergent, etc.)

# Knowledge store
oie_knowledge_store_entries{type}  (gauge: incident count)
oie_knowledge_store_similarity_hits{score_bucket}  (gauge: match count)

# Background loops
oie_anomaly_scan_duration_seconds
oie_forecasting_duration_seconds
oie_predictive_alert_dispatch_total{service_name}
```

#### Grafana Dashboards

| Dashboard | Purpose | Panels |
|-----------|---------|--------|
| **agentic-ai-overview** | Executive summary | Risk gauges, active alerts, scenario outcomes, autonomy distribution |
| **obs-intelligence-detail** | Deep dive | Scenario correlations, anomaly heatmap, forecast trends, LLM validation verdicts |
| **sre-incident-timeline** | Incident archaeology | Risk timeline, firing alerts timeline, user impact estimate, playbook outcomes |
| **ui-backend** | BFF metrics | API latency, aggregator health, upstream call success rates |
| **command-center-debug** | Streamlit perf | Page load times, data refresh rates, WebSocket connections |

### Alert Rules (Prometheus)

```yaml
# High risk detected
- alert: HighAnomalyZScore
  expr: oie_anomaly_z_score > 3
  for: 5m
  annotations:
    summary: "Anomaly detected: {{ $labels.metric_name }}"

- alert: NoAlertFiringButHighRisk
  expr: oie_risk_score > 0.75 AND count(ALERTS{alertstate="firing"}) == 0
  for: 5m
  annotations:
    summary: "Predictive risk high but no active alert"
    description: "OIE predicts degradation in {{ $labels.service_name }}"

# Integration health
- alert: OIEUnhealthy
  expr: up{job="obs-intelligence"} == 0
  for: 2m
  annotations:
    summary: "Obs-Intelligence Engine is down"

- alert: LocalLLMUnavailable
  expr: up{job="local-llm"} == 0
  for: 5m
  annotations:
    summary: "Ollama LLM unavailable (graceful degradation to deterministic)"
```

---

## 🔄 Complete Flow Example: CPU Saturation Alert

```
======= T=120s (Alert fires) =======

Prometheus rule eval @ T=120s:
  container_cpu_usage{pod="frontend-api"} = 95%  (> threshold 90%)
  ↓
  ALERT cpu_saturation triggered

Alertmanager receives alert:
  {
    "alertname": "cpu_saturation",
    "pod": "frontend-api",
    "severity": "critical",
    "domain": "compute"
  }
  ↓
  Route by domain=compute → POST http://compute-agent:9000/webhook

======= T=121s (Agent receives) =======

Compute Agent (9000):
  1. PARSE: domain=compute, alert=cpu_saturation, severity=critical
  
  2. FETCH CONTEXT (Prometheus + Loki):
     PromQL queries → get metrics from last 1h
     LogQL queries → get logs from last 1h
  
  3. EXTRACT FEATURES:
     {
       "cpu_utilization_pct": 95.0,
       "request_volume_rps": 6200,
       "latency_ms": 750,
       "error_rate_5m": 0.08,
       "pod_restart_count": 2,
       ...40 more features
     }
  
  4. POST /analyze to OIE:
     {
       "features": {...},
       "domain": "compute",
       "service_name": "frontend-api"
     }

======= T=125s (OIE analyzes) =======

Obs-Intelligence Engine (9100):
  
  SCENARIO MATCHING:
  ├─ cpu_saturation.yml:
  │  ├─ cpu >= 90% ✓ weight=0.4
  │  ├─ rps > 5000 ✓ weight=0.3
  │  ├─ latency > 500ms ✓ weight=0.2
  │  ├─ error_rate > 0.05 ✓ weight=0.1
  │  └─ confidence = 100% → 1.0
  │
  ├─ memory_leak_emergence.yml:
  │  ├─ memory > 85% ✗ weight=0.5
  │  └─ confidence = 0% → 0.0
  │
  └─ Result: Top match = cpu_saturation (conf=1.0)

  RISK SCORING:
  ├─ severity (critical) = 1.0 × 30% = 0.30
  ├─ scenario_confidence = 1.0 × 40% = 0.40
  ├─ anomaly_factor (20 error logs) = 0.8 × 15% = 0.12
  ├─ forecast (CPU trending up) = 1.0 × 15% = 0.15
  └─ TOTAL RISK = 0.30 + 0.40 + 0.12 + 0.15 = 0.97 (97% risk!)

  SRE REASONING:
  └─ "Frontend API CPU saturated due to unvaried workload spike.
      Horizontal scaling unable to catch up (max pods=3). 
      Error rate spiking (400 errors/min). User impact: 5000+ users
      experiencing >2s latency. Time to critical: 10 minutes."

  LLM ENRICHMENT (Optional, if API key set):
  ├─ Send to OpenAI: "Analyze: CPU saturation, high RPS, latency spike"
  ├─ Get response: "This is a classic horizontal scaling bottleneck..."
  └─ Validate with Ollama qwen3.5:
     ├─ Prompt: "Is the diagnosis correct?"
     ├─ Verdict: ✓ "corroborated" (high confidence)
     └─ Confidence: 0.89

  EVIDENCE BUILDING:
  └─ {
       "matched_scenarios": [
         {"name": "cpu_saturation", "confidence": 1.0}
       ],
       "metric_anomalies": 5,
       "log_anomalies": 18,
       "forecast_status": "critical",
       "llm_narrative": "CPU exhaustion due to horizontal scaling limit...",
       "llm_validation": "corroborated"
     }

  RECOMMENDATION:
  └─ {
       "playbook": "scale_frontend_pods",
       "proposed_action": "Scale frontend-api from 3 → 5 pods",
       "autonomy_level": "approval_gated",  (not fully auto due to scale change)
       "mttr_estimate_min": 5
     }

  Response to Agent:
  └─ HTTP 200 with Recommendation + RiskAssessment + EvidenceReport

======= T=126s (Agent creates ticket) =======

Compute Agent (9000):
  POST http://xyops:5522/api/tickets
  {
    "title": "CPU saturation: frontend-api",
    "description": "CPU exhaustion due to horizontal scaling limit...",
    "risk_level": "critical",
    "risk_score": 0.97,
    "matched_scenarios": ["cpu_saturation"],
    "evidence": {...},
    "llm_narrative": "...",
    "automation_level": "approval_gated",
    "proposed_remediation": "Scale frontend pods from 3 to 5"
  }
  
  Response: HTTP 201 ticket_id=1847

======= T=130s (Ticket in xyOps) =======

xyOps Web UI (5522):
  Ticket #1847 created:
  ├─ Title: CPU saturation: frontend-api
  ├─ Risk Badge: 🔴 CRITICAL (0.97)
  ├─ Scenarios: cpu_saturation (100% confidence)
  ├─ Evidence: CPU 95%, RPS 6.2K, Latency 750ms, 18 errors
  ├─ LLM Analysis: "CPU exhaustion due to horizontal scaling limit..."
  ├─ LLM Validation: ✓ corroborated (89% confidence)
  └─ Approval Canvas: [APPROVE] [ESCALATE] [DISMISS]

  Workflow: Pending approval

  Email notification sent to on-call engineer

======= T=150s (Engineer approves) =======

Engineer logs into xyOps:
  Sees ticket #1847, reviews evidence, LLM narrative, risk score
  Clicks [APPROVE]
  
  xyOps Workflow triggers:
    ├─ Update ticket status → "approved"
    ├─ POST http://ansible-runner:8090/run
    │  {
    │    "playbook": "scale_frontend_pods.yml",
    │    "extra_vars": {"target_pods": 5},
    │    "dry_run": false  (ANSIBLE_LIVE_MODE=true in production)
    │  }
    │
    └─ Gitea PR created: airflow/ansible-playbooks/scale-frontend-1847
       └─ PR title: "Scale frontend-api pods (ticket #1847)"
       └─ Changes: update HPA max=5

======= T=152s (Playbook executes) =======

ansible-runner (8090):
  Runs scale_frontend_pods.yml:
    ├─ $ kubectl patch hpa frontend-api-hpa -p '{"spec":{"maxReplicas":5}}'
    ├─ Wait for new pod to reach "Running"
    ├─ Verify: 5 frontend-api pods now Running
    ├─ HTTP GET frontend-api /health → 200 OK
    └─ Status: SUCCESS

  Logs to Gitea PR:
    ├─ Playbook execution duration: 3 seconds
    ├─ Changed: hpa/frontend-api-hpa
    ├─ Result: 5 pods running, CPU balanced to 45% across all
    └─ Rollback command: (for audit docs)

======= T=153s (Outcome recorded) =======

Agent (via webhook post-action):
  POST http://obs-intelligence:9100/intelligence/record-outcome
  {
    "alert_id": "cpu_saturation_1847",
    "scenario_id": "cpu_saturation",
    "outcome": "resolved",
    "action_taken": "scale_frontend_pods",
    "mttr_seconds": 33,
    "incident_impact": "5000 users, ~150 error events"
  }

  OIE updates:
    ├─ ChromaDB entry added to knowledge store
    ├─ Scenario outcome counter incremented
    ├─ Confidence weight for cpu_saturation scenario updated
    └─ Prometheus counter:
       oie_scenario_outcome_total{scenario="cpu_saturation", outcome="resolved"} += 1

======= T=160s (Prometheus alert clears) =======

Prometheus rule re-evaluation:
  container_cpu_usage{pod="frontend-api"} = 42%  (< 90% threshold)
  ↓
  Alert cpu_saturation → state: RESOLVED

Alertmanager notifies:
  ├─ xyOps ticket #1847 auto-updates status → "Resolved"
  ├─ Engineer receives email: "Ticket #1847 resolved"
  └─ Grafana panel updates: resolved alert count += 1

======= T=300s (Analytics) =======

Incident closed. Engineer can now review:
  ├─ xyOps dashboard: Ticket #1847 complete timeline
  ├─ Grafana: Risk assessment timeline showing 0.97 → 0.05 score drop
  ├─ Grafana: Scenario outcome bar chart (cpu_saturation: 1 resolved)
  ├─ Streamlit: Pipeline visualization shows execution + success
  ├─ Gitea: PR history and playbook log
  └─ N8N (if enabled): Master Orchestrator logs all steps

MTTR: 33 seconds from alert to resolution via automatic scaling
SUCCESS RATE for cpu_saturation scenario: now includes 1 successful outcome
```

---

## 🎬 Summary

**The complete xyopsver2 build and workflow:**

1. **Build Stage** → Docker multi-stage, shared Python packages, dependency injection
2. **Deploy Stage** → docker-compose with health checks, volume mounts, env vars
3. **Initialization** → Services start, OIE loads scenarios, agents register with Alertmanager
4. **Alert Generated** → Prometheus fires, Alertmanager routes by domain
5. **Analysis** → Agent queries context, calls OIE for scenario matching + risk scoring
6. **Enrichment** → Optional LLM analysis + validation
7. **Ticketing** → xyOps ticket created with full evidence + narrative
8. **Approval** → Human approves (or auto-executes if autonomous)
9. **Execution** → Ansible playbook runs, PR created for audit
10. **Outcome** → Result recorded in knowledge store, metrics published
11. **Continuous Improvement** → Knowledge base grows, forecasting improves

**Key Features in v14.0.0:**
- ✨ Streamlit dashboard for real-time visibility
- ✨ Qwen3. superior LLM for reasoning
- ✨ Multi-agent architecture sharing intelligence
- ✨ Deterministic + AI hybrid analysis
- ✨ Enterprise-grade observability

