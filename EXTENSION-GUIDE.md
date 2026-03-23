# AIOps Platform Extension — Integration Guide

## Overview

This document describes the extensions made to the existing AIOps platform. All changes are **non-breaking** — existing xyOps workflows remain fully operational.

## What's New

### 1. ServiceNow Integration (`/integrations/servicenow_client.py`)

**Purpose**: Create incidents in ServiceNow in parallel to xyOps tickets

**Key Features**:
- ✅ Async, non-blocking (fire-and-forget)
- ✅ Never raises exceptions (fail-safe)
- ✅ Failures logged only, never block main workflow
- ✅ Risk score calculation based on severity

**Usage in Agents**:
```python
from integrations.servicenow_client import create_incident_async

# After xyOps ticket is created
await create_incident_async(
    alert_name="HighErrorRate",
    service_name="frontend-api",
    risk_score=0.65,
    title="High error rate on frontend-api",
    description="Error rate exceeded 5%",
    domain="compute",
)
```

**Configuration**:
```bash
ENABLE_SERVICENOW=false          # Set to true to enable
SERVICENOW_URL=http://mock-servicenow:8080
SERVICENOW_USER=admin
SERVICENOW_PASSWORD=admin
```

**Behavior**:
- Runs in background task (doesn't wait for response)
- Posts to `POST /api/now/table/incident`
- Includes custom fields: alert_name, service_name, domain, risk_score

---

### 2. n8n Integration (`/integrations/n8n_client.py`)

**Purpose**: Trigger n8n workflows for orchestration and automation

**Key Features**:
- ✅ Async, non-blocking (fire-and-forget)
- ✅ Never raises exceptions (fail-safe)
- ✅ Failures logged only, never block main workflow
- ✅ Passes rich context (domain, risk, summary, ticket_id)

**Usage in Agents**:
```python
from integrations.n8n_client import send_to_n8n

# After xyOps ticket and analysis complete
await send_to_n8n(
    domain="compute",
    risk="high",
    summary="Root cause: Pod restarts due to OOM",
    ticket_id="xyops-ticket-123",
    alert_name="HighErrorRate",
    service_name="frontend-api",
)
```

**Configuration**:
```bash
ENABLE_N8N=false                              # Set to true to enable
N8N_WEBHOOK_URL=http://n8n:5678/webhook/incident
```

**Webhook Payload**:
```json
{
  "source": "aiops-agent",
  "domain": "compute|storage",
  "risk": "high|medium|low",
  "summary": "LLM-generated summary",
  "ticket_id": "xyops-ticket-id",
  "alert_name": "HighErrorRate",
  "service_name": "frontend-api"
}
```

**Behavior**:
- Runs in background task (doesn't wait for response)
- Posts to `N8N_WEBHOOK_URL`
- Converts numeric risk_score (0.0-1.0) to categorical risk (high/medium/low)

---

### 3. Streamlit Dashboard UI (`/ui-streamlit/`)

**Purpose**: Replace React Command Center with lightweight read-only dashboard

**Key Features**:
- ✅ Dashboard: System health, intelligence status, approval statistics
- ✅ Pipeline View: Execution status and audit trail
- ✅ Approvals: Read-only display of pending tasks
- ✅ Settings: API endpoints and configuration reference
- ✅ Zero breaking changes (queries existing agent APIs only)

**Access**:
```
http://localhost:8501
```

**Configuration**:
```bash
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
OBS_INTELLIGENCE_URL=http://obs-intelligence:9100
XYOPS_URL=http://xyops:5522
```

**Architecture**:
- Read-only interface (no state mutations)
- Queries existing agent health + approval endpoints
- 30-second cache on all API queries (reduces load)
- Caching is cleared when user hits "Refresh" button

**Pages**:

#### Dashboard
- Service health status (✅/❌)
- Obs-Intelligence loop counters
- Approval statistics (90-day window)
- Auto-refresh button

#### Pipeline View
- Compute agent pipeline steps (9 stages)
- Storage agent pipeline steps (8 stages)
- Link to xyOps for full audit trail
- Each step documented with description

#### Approvals
- Read-only list of pending approval requests
- Shows status, service, severity
- **Navigation**: "✅ Please go to xyOps to approve/reject"
- xyOps remains source of truth for all decisions

#### Settings
- Display of all API endpoints
- Environment variable reference
- Architecture overview
- Integration flow diagram

**Deployment**:
```bash
# Local development
streamlit run ui-streamlit/app.py

# Docker
docker compose up ui-streamlit
```

---

## Agent Modifications

### `compute-agent/app/main.py`

**Changes**:
1. Added imports for `create_incident_async` and `send_to_n8n`
2. Added graceful fallback if integrations module not available
3. Added integration calls in `_create_xyops_ticket()` after ticket creation

**Code locations**:
- Imports: Lines ~80-100
- Integration calls: After xyOps ticket pipeline completes (lines ~1050-1085)

**Integration flow**:
```
1. Create xyOps ticket (existing)
2. Run AI analysis (existing)
3. Create approval gate (existing)
4. ✅ NEW: Send to ServiceNow (async)
5. ✅ NEW: Send to n8n webhook (async)
→ Return response to Alertmanager (existing)
```

**No breaking changes**: All existing functionality preserved exactly as-is.

### `storage-agent/app/main.py`

**Changes**:
1. Added imports for `create_incident_async` and `send_to_n8n`
2. Added graceful fallback if integrations module not available
3. Added integration calls in `_run_storage_pipeline()` after ticket creation

**Code locations**:
- Imports: Lines ~54-67
- Integration calls: After pipeline completes (lines ~442-473)

**Integration flow**:
```
1. Start pipeline (existing)
2. Fetch metrics (existing)
3. Fetch logs (existing)
4. Run analysis (existing)
5. Create ticket (existing)
6. Approval gate (existing)
7. ✅ NEW: Send to ServiceNow (async)
8. ✅ NEW: Send to n8n webhook (async)
```

**No breaking changes**: All existing functionality preserved exactly as-is.

---

## Directory Structure

```
/integrations/
  ├── __init__.py                # Package exports
  ├── servicenow_client.py       # ServiceNow async client
  └── n8n_client.py              # n8n async client

/ui-streamlit/
  ├── app.py                     # Streamlit dashboard
  ├── Dockerfile                 # Container build
  ├── requirements.txt           # Python dependencies
  └── README.md                  # UI documentation

compute-agent/
  └── app/main.py               # ✏️ Modified to use integrations

storage-agent/
  └── app/main.py               # ✏️ Modified to use integrations

docker-compose.yml              # ✏️ Added ui-streamlit service

env.md                           # ✏️ Added new env vars
```

---

## Environment Variables

### New Variables

```bash
# ServiceNow Integration
ENABLE_SERVICENOW=false
SERVICENOW_URL=http://mock-servicenow:8080
SERVICENOW_USER=admin
SERVICENOW_PASSWORD=admin

# n8n Integration
ENABLE_N8N=false
N8N_WEBHOOK_URL=http://n8n:5678/webhook/incident

# Streamlit UI
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
OBS_INTELLIGENCE_URL=http://obs-intelligence:9100
```

All new variables are **optional** and have sensible defaults.
Integrations are **disabled by default** (set `ENABLE_*=false`).

---

## Execution Flow (Updated)

```
┌─────────────────┐
│  Alertmanager   │
└────────┬────────┘
         │ webhook (firing/resolved)
         │
    ┌────▼────────────────────┐
    │  compute-agent/         │
    │  storage-agent/         │
    │  POST /webhook          │
    └────┬───────────────────┬┘
         │                   │
    ┌────▼──────┐      ┌────▼──────┐
    │ Create    │      │ Run AI    │
    │ xyOps     │      │ Analysis  │
    │ ticket    │      │           │
    └────┬──────┘      └────┬──────┘
         │                  │
    ┌────▼──────────────────▼────┐
    │  Approval gate (if needed) │
    └────┬───────────────────────┘
         │
    ┌────▼───────────────────────────────┐
    │  ✅ NEW: Async Integrations        │
    ├───────────────────────────────────┤
    │  • ServiceNow incident (async)     │
    │  • n8n webhook (async)            │
    │  (Non-blocking, never raise)      │
    └────┬───────────────────────────────┘
         │
    ┌────▼────────────────┐
    │ Return 200 OK to    │
    │ Alertmanager        │
    └─────────────────────┘
         │
         ├─► ServiceNow (background)
         │
         └─► n8n (background)
```

---

## Testing

### Unit Tests

Run integration module tests:
```bash
python -m pytest integrations/test_servicenow_client.py -v
python -m pytest integrations/test_n8n_client.py -v
```

### Integration Tests

Start all services:
```bash
docker compose up --build
```

Test Streamlit dashboard:
```
http://localhost:8501
```

Test compute-agent webhook:
```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "labels": {
        "alertname": "HighErrorRate",
        "service_name": "frontend-api",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Error rate is high",
        "description": "Error rate exceeded 5%",
        "dashboard_url": "http://grafana:3000/d/..."
      },
      "startsAt": "2026-03-22T10:00:00Z"
    }]
  }'
```

Check logs:
```bash
docker compose logs -f compute-agent     # See xyOps + integrations
docker compose logs -f storage-agent     # See storage pipeline
docker compose logs -f ui-streamlit      # See dashboard logs
```

### Verify No Breaking Changes

1. **xyOps workflow**: Existing tickets created exactly as before
2. **Approvals**: Existing approval flow unchanged
3. **Ansible playbooks**: Still executed via xyOps workflow
4. **Gitea integration**: Still works for PR audits
5. **OTel instrumentation**: All tracing preserved

All endpoints remain at same ports:
- `compute-agent:9000` (was 9000)
- `storage-agent:9001` (was 9001)
- `obs-intelligence:9100` (was 9100)
- `xyops:5522` (was 5522)

---

## Debugging

### ServiceNow Integration Issues

Check container logs:
```bash
docker compose logs ui-streamlit | grep servicenow
```

Common issues:
- `ENABLE_SERVICENOW=false` → Check env var
- `HTTP 401` → Check SERVICENOW_USER / SERVICENOW_PASSWORD
- `Connection refused` → Check SERVICENOW_URL and ensure mock-servicenow is running

### n8n Integration Issues

Check container logs:
```bash
docker compose logs compute-agent | grep n8n
docker compose logs storage-agent | grep n8n
```

Common issues:
- `ENABLE_N8N=false` → Check env var
- `HTTP 404` → Check N8N_WEBHOOK_URL is correct
- `Connection refused` → Check n8n container is running

### Streamlit Dashboard Issues

Access dashboard:
```
http://localhost:8501
```

Check logs:
```bash
docker compose logs -f ui-streamlit
```

Common issues:
- Cannot reach agents → Check COMPUTE_AGENT_URL and STORAGE_AGENT_URL
- Refresh doesn't work → Check browser console for errors
- Shows "error" status → Agents may not be ready (wait 30s)

---

## Rollback / Disabling

To disable new integrations without code changes:

```bash
# In env file or docker-compose.yml
ENABLE_SERVICENOW=false
ENABLE_N8N=false

# Restart agents
docker compose restart compute-agent storage-agent
```

Existing xyOps workflow will continue working identically.

To remove Streamlit UI:
```bash
docker compose down ui-streamlit
```

The dashboard is entirely optional. All core functionality runs without it.

---

## Security Considerations

### ServiceNow

- Credentials passed in environment variables
- Recommend using secrets management (Vault, K8s Secrets) in production
- HTTP client validates SSL by default

### n8n

- Webhook URL must be accessible from agent containers
- No authentication built-in (recommend securing n8n itself)
- Payload includes ticket_id and service name (audit trail)

### Streamlit

- Read-only interface (no state mutations)
- No user authentication built-in (recommend using reverse proxy in production)
- Queries agent APIs directly (agent authentication inherited if configured)

---

## Future Enhancements

Possible additions (all non-breaking):

1. **Slack integration** → Post alerts to Slack channels
2. **PagerDuty integration** → Create/acknowledge incidents
3. **Jira integration** → Create tickets in Jira instead of xyOps
4. **Custom webhooks** → Extensible webhook system
5. **Streamlit authentication** → Add user login to dashboard
6. **Multi-agent orchestration** → Agents coordinate across domains

All can be added to `/integrations/` without modifying existing agents.

---

## Summary

✅ **Zero breaking changes** — All existing functionality preserved
✅ **Parallel, async integrations** — Never block main workflow
✅ **Fail-safe design** — Failures logged, never raise exceptions
✅ **Optional by default** — Disabled until explicitly enabled
✅ **Modular architecture** — Can be extended easily
✅ **Read-only UI** — Dashboard for visibility, xyOps remains source of truth

The platform is now extended with:
- **ServiceNow synchronization** for incident management
- **n8n orchestration** for automation
- **Streamlit dashboard** for observability

All while keeping the existing AIOps platform fully operational.
