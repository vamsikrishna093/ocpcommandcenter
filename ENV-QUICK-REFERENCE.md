# 🔐 Environment & Secrets — Quick Reference

## Files Created

| File | Purpose | Track? | Edit? |
|------|---------|--------|-------|
| `.env.template` | Configuration template with examples | ✅ YES | Replace values manually |
| `.env` | Actual working configuration with secrets | ❌ NO | Your working copy |
| `.gitignore` | Prevents committing sensitive files | ✅ YES | Usually don't touch |
| `SECRETS-MANAGEMENT.md` | Complete guide | ✅ YES | Reference only |

---

## One-Minute Setup

```bash
# 1. Create .env from template
cp .env.template .env

# 2. Edit .env with your secrets
nano .env
# OR
vi .env

# 3. Verify .env is protected
git status  # Should NOT show .env

# 4. Use it!
docker compose up
```

---

## What to Fill in `.env`

### Absolutely Required

```env
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=your-actual-api-key-here  # Get from xyOps admin
```

### Optional (Set as Needed)

```env
# ServiceNow (if using)
ENABLE_SERVICENOW=true
SERVICENOW_URL=http://your-servicenow:8080
SERVICENOW_USER=your-username
SERVICENOW_PASSWORD=your-password

# n8n Integration (if using)
ENABLE_N8N=true
N8N_WEBHOOK_TOKEN=generate-secure-token
N8N_HMAC_SECRET=generate-secure-secret
```

---

## Protected Extensions/Patterns

The `.gitignore` prevents these from being committed:

```
.env                    # Your working configuration
.env.local              # Local overrides
*.key                   # Private keys
*.pem                   # Certificates
secrets.json            # Secret files
credentials.json        # Credentials
.ssh/                   # SSH keys
.aws/                   # AWS credentials
.vault-token            # Vault tokens
```

---

## Never Do This ⚠️

```bash
# ❌ DON'T commit .env
git add .env

# ❌ DON'T put secrets in code
XYOPS_API_KEY = "hardcoded-secret"

# ❌ DON'T log sensitive values
logger.info(f"API Key: {api_key}")

# ❌ DON'T remove .env from .gitignore
# (Let it stay protected!)
```

---

## Always Do This ✅

```bash
# ✅ DO use .env for dynamic config
XYOPS_API_KEY = os.getenv("XYOPS_API_KEY")

# ✅ DO commit .env.template instead
git add .env.template

# ✅ DO verify .env is protected
git status  # Should not show .env

# ✅ DO use strong passwords
openssl rand -hex 16  # Generate secure token
```

---

## Quick Commands

```bash
# Create .env from template
cp .env.template .env

# Edit .env
nano .env

# Source environment (development)
source .env

# Check if .env is tracked (it shouldn't be)
git status

# Remove .env if accidentally tracked
git rm --cached .env

# Find where variables are defined
grep "XYOPS_API_KEY" .env

# Generate secure token
openssl rand -hex 16

# Start Docker with .env (automatic)
docker compose up

# Start Docker with specific .env
docker compose --env-file .env up

# Verify Docker loaded environment
docker compose exec compute-agent printenv | grep XYOPS
```

---

## Environment Variables by Category

### Core Services
```env
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=your-secret-key
REQUIRE_APPROVAL=true
ANSIBLE_RUNNER_URL=http://ansible-runner:8080
```

### LLM (Local Ollama)
```env
LOCAL_LLM_ENABLED=true
LOCAL_LLM_MODEL=qwen2:7b
OLLAMA_API_URL=http://host.docker.internal:11434
```

### Integrations
```env
ENABLE_N8N=false
ENABLE_SERVICENOW=false
N8N_WEBHOOK_URL=http://n8n:5678/webhook/incident
SERVICENOW_URL=http://servicenow:8080
```

### Backends
```env
PROMETHEUS_URL=http://prometheus:9090
LOKI_URL=http://loki:3100
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
OBS_INTELLIGENCE_URL=http://obs-intelligence:9100
```

---

## Troubleshooting

### Docker doesn't see variables

```bash
# Verify .env exists
ls -la .env

# Check format (no spaces around =)
cat .env | head -3

# Verify Docker loads it
docker compose config | grep XYOPS_API_KEY
```

### .env was accidentally committed

```bash
# Fix it
git rm --cached .env
git commit -m "Remove .env from tracking"

# Verify it's gone
git status
```

### Can't find a variable

```bash
# Search in .env
grep "VAR_NAME" .env

# Or add it from template
grep "VAR_NAME" .env.template >> .env
```

---

## Security Checklist

Before pushing to GitHub:

- [ ] `.env` created from `.env.template`
- [ ] `.env` file is in `.gitignore`
- [ ] `git status` does NOT show `.env`
- [ ] `.env` NOT in commit history (`git log -- .env`)
- [ ] No secrets hardcoded in source files
- [ ] `.env.template` committed (without real secrets)
- [ ] Used strong, random tokens for sensitive values

---

## File Locations

```
your-project/
  ├── .env                  ⚠️ SECRET (not tracked)
  ├── .env.template         ✅ Example (tracked)
  ├── .gitignore            ✅ Rules (tracked)
  ├── docker-compose.yml    ✅ Config (tracked)
  ├── SECRETS-MANAGEMENT.md ✅ Guide (tracked)
  └── ... other files
```

---

## Production Deployment

**LOCAL DEVELOPMENT**: Use `.env` file ✅

**STAGING/PRODUCTION**: Use secrets management ❌ NOT `.env`

Options:
- Kubernetes Secrets
- Docker Swarm Secrets
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Cloud Secret Manager

---

## Learn More

Read: `SECRETS-MANAGEMENT.md` for complete guide
