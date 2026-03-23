# 🎯 xyopsver2 v14.0.0 — New Features Quick Start

## 🌐 Streamlit Command Center

After merging obseransiblerepo, xyopsver2 now includes a modern **Streamlit dashboard** with 7 operational pages.

### Starting the Dashboard

```bash
# Option 1: Just the dashboard
docker compose up streamlit-dashboard

# Option 2: Full stack
docker compose up
```

**Access:** `http://localhost:8501`

### Dashboard Pages

```
📊 Streamlit Command Center
├── 🔴 1️⃣  Live Pipeline          — Real-time execution monitor
├── 📦 2️⃣  Storage Pipeline        — Storage orchestration
├── ✅ 3️⃣  Pending Approvals       — Approval workflows
├── 📈 4️⃣  Workflow Outcomes       — Results + analytics
├── 📋 5️⃣  Pipeline History        — Execution timeline
├── 🤖 6️⃣  Autonomy Trust          — Agent confidence scores
└── 🌐 7️⃣  Agent Mesh              — Multi-agent coordination
```

### Key Features

- **Real-time Updates:** WebSocket-based live execution tracking
- **Interactive Charts:** Plotly dashboards with drill-down capability
- **Shared Utilities:** Common authentication & UI components (`shared.py`)
- **Responsive Design:** Works on desktop, tablet, mobile

---

## 🧠 Qwen3.5 LLM Upgrade

xyopsver2 now uses the superior **Qwen 3.5 model** for AI-driven incident analysis.

### What Changed

```bash
# Model: llama3.2:3b → qwen3.5
LOCAL_LLM_MODEL: "qwen3.5"

# Affected Services:
# - aiops-bridge      (incident corroboration)
# - compute-agent     (workflow decisions)
# - storage-agent     (storage analysis)
```

### Why Qwen3.5?

| Feature | llama3.2:3b | qwen3.5 |
|---------|------------|---------|
| Reasoning | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Speed | Medium | Fast |
| Accuracy | Good | Excellent |
| Context Length | 8K | 128K |
| Specialized Knowledge | General | Tech + Enterprise |

### First Run

On first startup, Ollama will download qwen3.5 (~8GB):

```bash
# Monitor the download
docker logs local-llm | tail -f

# Expected output:
# ✓ pulling qwen3.5...
# ✓ pulling nomic-embed-text...
# Ready for inference
```

---

## 🔗 Integration Points

### Still Using N8N Workflows?

✅ **All N8N integrations work exactly as before:**
- Master Orchestrator
- Pre-enrichment Agent
- Smart Router
- Post-approval Agent

**No changes needed.** Your N8N workflows will now leverage Qwen3.5 for better LLM decisions.

### ServiceNow Integration?

✅ **Fully preserved:**
- ITSM ticket creation
- Integration guides remain valid
- All validation docs apply

### Streamlit + N8N

The Streamlit dashboard can now visualize N8N workflow execution:
- See which workflows are active
- Monitor agent responses
- Track approval workflows in real-time

---

## 📊 Example: Testing the Merge

### 1. Verify qwen3.5 is Running

```bash
curl http://localhost:11434/api/tags
# Response: {"models": [{"name": "qwen3.5"}, {"name": "nomic-embed-text"}]}
```

### 2. Load Dashboard

```bash
open http://localhost:8501/1_Live_Pipeline
```

### 3. Send Test Alert

```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestQwen35",
        "service_name": "frontend-api",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Test with Qwen3.5 LLM",
        "description": "Verifying enhanced reasoning capability",
        "dashboard_url": "http://localhost:3001"
      },
      "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }]
  }'
```

### 4. Watch in Real-time

- **N8N:** Check Master Orchestrator execution → `http://localhost:5679`
- **Streamlit:** Monitor in dashboard → `http://localhost:8501/4_Workflow_Outcomes`
- **xyOps:** View ticket created → `http://localhost:5522`

---

## 🚀 Version Upgrade Path

```
v13.0.0 (obseransiblerepo)
  ↓ [Merged]
v14.0.0 (xyopsver2)
  ✨ Streamlit dashboard added
  ✨ Qwen3.5 LLM integrated
  ✨ All N8N features preserved
  ✨ ServiceNow integration intact
```

---

## ❓ FAQ

**Q: Will this break my N8N workflows?**  
A: No. N8N workflows continue to work. They'll now use Qwen3.5 for better LLM decisions.

**Q: How much disk space does qwen3.5 need?**  
A: ~8GB for the model itself. First download takes 5-10 minutes depending on internet speed.

**Q: Can I switch back to llama3.2:3b?**  
A: Yes. Edit `docker-compose.yml` `LOCAL_LLM_MODEL` and Ollama entrypoint, then rebuild.

**Q: Is the Streamlit dashboard mobile-friendly?**  
A: Yes. All pages are responsive and work on mobile.

**Q: How do I use Streamlit pages with N8N workflows?**  
A: The dashboard displays real-time orchestration data pulled from your N8N webhooks and agent responses.

---

## 📝 Related Documents

- [MERGE-SUMMARY.md](MERGE-SUMMARY.md) — Detailed merge information
- [N8N-FIX-COMPLETE.md](N8N-FIX-COMPLETE.md) — N8N setup & troubleshooting
- [N8N-MASTER-ORCHESTRATOR-GUIDE.md](N8N-MASTER-ORCHESTRATOR-GUIDE.md) — Orchestrator details
- [QUICK-START.md](QUICK-START.md) — Original xyopsver2 quick start

---

## 🎓 Architecture Update

```
                    ┌─────────────────────────────┐
                    │ Streamlit Command Center    │
                    │ http://8501                 │
                    │ (7 dashboard pages)         │
                    └──────────────┬──────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
   ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
   │ N8N Workflows           │ AIOps Bridge│          │ xyOps UI    │
   │ (Orchestration)         │ (Router)    │          │ (ITSM)      │
   └──────┬──────┘          └──────┬──────┘          └──────┬──────┘
          │                        │                        │
          └────────────────┬───────┴────────────────┬───────┘
                           │                        │
                    ┌──────▼────────┐      ┌────────▼──────┐
                    │ Qwen3.5 LLM   │      │ ServiceNow    │
                    │ (Reasoning)   │      │ (Ticketing)   │
                    └───────────────┘      └───────────────┘
```

All services now leverage **Qwen3.5** for intelligent, enterprise-grade incident response.

