# Streamlit Data Dashboard

A lightweight Streamlit UI that replaces the React Command Center.

## Features

- **Dashboard**: System health, intelligence engine status, approval statistics
- **Pipeline View**: Execution status and audit trail (xyOps is source of truth)
- **Approvals**: Read-only display of pending tasks (navigate to xyOps to decide)
- **Settings**: API endpoints and configuration reference

## Quick Start

```bash
pip install streamlit httpx streamlit-option-menu
streamlit run app.py
```

## Environment Variables

```bash
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
OBS_INTELLIGENCE_URL=http://obs-intelligence:9100
XYOPS_URL=http://xyops:5522
```

## Architecture

- This is a **read-only** dashboard
- No new backend endpoints created (zero breaking changes)
- Queries existing agent APIs directly
- xyOps remains the source of truth for all approval decisions
- All audit trails and execution history stored in xyOps tickets

## Running in Docker

```bash
docker build -t ui-streamlit .
docker run -p 8501:8501 \
  -e COMPUTE_AGENT_URL=http://compute-agent:9000 \
  -e STORAGE_AGENT_URL=http://storage-agent:9001 \
  ui-streamlit
```
