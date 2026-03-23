# Copy this file to .env and fill in your real values.
# .env is gitignored — never commit real secrets.

# NOTE: External LLM APIs (OpenAI, Claude) are DEPRECATED.
# The system now uses LOCAL LLM (Ollama) by default for cost savings and data privacy.
# If you have legacy OPENAI_API_KEY or CLAUDE_API_KEY set, they will be ignored.
# Configure LOCAL LLM settings below instead.

# DEPRECATED: External API Keys
# ── These are no longer required. Leave empty or remove.
#OPENAI_API_KEY=                # Deprecated: use local LLM instead
# CLAUDE_API_KEY=               # Deprecated: use local LLM instead

# xyOps
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=k9-jyIiC4dVK-t3gVMnUTRIk7iMM44zoBhG8RFDo0YE  # Replace with actual API key from xyOps

# Optional features
REQUIRE_APPROVAL=true
ANSIBLE_RUNNER_URL=http://ansible-runner:8080

# Local LLM Integration (Ollama)
OLLAMA_API_URL=http://host.docker.internal:11434
LOCAL_LLM_ENABLED=true
LOCAL_LLM_MODEL=qwen2:7b
LOCAL_LLM_TIMEOUT=60
USE_EXTERNAL_LLM_FALLBACK=true

# ========== n8n INTEGRATION (OPTIONAL - Agentic Orchestration) ==========
# n8n enables optional workflow orchestration, approvals, and multi-channel notifications
# Set ENABLE_N8N=false to use standard processing (default, backward compatible)
# Set ENABLE_N8N=true to enable n8n workflows

# Master Toggle
ENABLE_N8N=false                                      # Boolean: activate n8n integration

# n8n Connection
N8N_WEBHOOK_URL=http://n8n:5678/webhook/aiops       # Main n8n webhook URL
N8N_WEBHOOK_TOKEN=your-n8n-webhook-token            # Authorization token
N8N_REQUEST_TIMEOUT=30                               # Timeout in seconds
N8N_RETRY_ATTEMPTS=3                                 # Retry on failure
N8N_RETRY_DELAY_MS=1000                              # Delay between retries (ms)

# Pattern Selection (choose one)
# Options: pre-enrichment | post-approval | smart-router
N8N_PATTERN=pre-enrichment

# Pattern-Specific URLs
N8N_PRE_ENRICHMENT_WEBHOOK=http://n8n:5678/webhook/aiops/pre-enrichment
N8N_POST_APPROVAL_WEBHOOK=http://n8n:5678/webhook/aiops/post-approval
N8N_SMART_ROUTER_WEBHOOK=http://n8n:5678/webhook/aiops/smart-router

# Security
N8N_VERIFY_SSL=true                                  # Verify n8n SSL certificate
N8N_HMAC_SECRET=your-hmac-secret                     # Optional: HMAC-SHA256 signing
N8N_API_KEY=your-n8n-api-key                         # For n8n API calls

# Observability
N8N_ENABLE_TRACING=true                              # Send traces to OTEL collector
N8N_TRACE_SAMPLE_RATE=1.0                            # 100% trace every n8n call
N8N_LOG_LEVEL=INFO                                   # DEBUG | INFO | WARN | ERROR

# Fallback Behavior
N8N_FALLBACK_ON_TIMEOUT=true                         # Continue without n8n if timeout
N8N_FALLBACK_ON_ERROR=true                           # Continue without n8n if error

# Approval Workflow Settings
N8N_APPROVAL_TIMEOUT_SEC=1800                        # Max wait time for approval (30 min)