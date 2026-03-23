# AIOps Bridge Configuration
# Copy of .env.example with your n8n webhook URLs

# xyOps
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=k9-jyIiC4dVK-t3gVMnUTRIk7iMM44zoBhG8RFDo0YE

# Optional features
REQUIRE_APPROVAL=true
ANSIBLE_RUNNER_URL=http://ansible-runner:8080

# Local LLM Integration (Ollama)
OLLAMA_API_URL=http://host.docker.internal:11434
LOCAL_LLM_ENABLED=true
LOCAL_LLM_MODEL=qwen2:7b
LOCAL_LLM_TIMEOUT=60
USE_EXTERNAL_LLM_FALLBACK=true

# ========== n8n INTEGRATION (OPTIONAL) ==========

# Master Toggle
ENABLE_N8N=true

# Pattern Selection (choose one)
# Options: pre-enrichment | post-approval | smart-router
N8N_PATTERN=smart-router

# Your Actual n8n Webhook URLs (Use port 5679 - external N8N port)
N8N_PRE_ENRICHMENT_WEBHOOK=http://localhost:5679/webhook-test/aiops/pre-enrichment
N8N_POST_APPROVAL_WEBHOOK=http://localhost:5679/webhook-test/aiops/post-approval
N8N_SMART_ROUTER_WEBHOOK=http://localhost:5679/webhook-test/aiops/smart-router

# Security
N8N_WEBHOOK_TOKEN=test-token
N8N_HMAC_SECRET=test-hmac-secret
N8N_VERIFY_SSL=true

# Observability
N8N_ENABLE_TRACING=true
N8N_TRACE_SAMPLE_RATE=1.0
N8N_LOG_LEVEL=INFO

# Fallback Behavior
N8N_FALLBACK_ON_TIMEOUT=true
N8N_FALLBACK_ON_ERROR=true

# Approval Settings
N8N_APPROVAL_TIMEOUT_SEC=1800

# ========== SERVICENOW INTEGRATION (NEW) ==========

# Master Toggle
ENABLE_SERVICENOW=false

# ServiceNow Instance URL (or mock endpoint)
SERVICENOW_URL=http://mock-servicenow:8080

# ServiceNow Authentication
SERVICENOW_USER=admin
SERVICENOW_PASSWORD=admin

# ========== N8N WEBHOOK INTEGRATION (NEW) ==========

# n8n webhook endpoint for incident orchestration
N8N_WEBHOOK_URL=http://n8n:5678/webhook/incident

# ========== STREAMLIT UI CONFIGURATION (NEW) ==========

# Agent API endpoints (for Streamlit dashboard)
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
OBS_INTELLIGENCE_URL=http://obs-intelligence:9100
