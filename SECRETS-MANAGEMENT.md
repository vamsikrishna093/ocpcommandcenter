# 🔐 Environment Configuration & Secrets Management Guide

## Overview

This guide explains how to safely manage sensitive configuration data (API keys, passwords, secrets) using `.env` files and `.gitignore`.

---

## 📁 Files Explained

### `.env.template` (✅ Tracked in Git)
- **Purpose**: Example configuration template
- **Contains**: Placeholder values and documentation
- **Status**: Safe to commit to GitHub
- **Usage**: Copy this to `.env` and fill in your real values

### `.env` (❌ NOT tracked in Git)
- **Purpose**: Your actual working configuration
- **Contains**: Real API keys, passwords, secrets
- **Status**: Protected by `.gitignore` — **NEVER** commit
- **Usage**: Created from `.env.template` for local development

### `.gitignore` (✅ Tracked in Git)
- **Purpose**: Tells Git which files to ignore
- **Contains**: Patterns matching sensitive files
- **Status**: Safe to commit to GitHub
- **Usage**: Automatically prevents `.env` from being committed

---

## 🚀 Quick Start

### Step 1: Create `.env` from Template

```bash
# Copy the template
cp .env.template .env

# Now you have a .env file with default values
```

### Step 2: Fill in Your Secrets

```bash
# Edit .env and replace placeholder values
nano .env
```

Replace these values with your actual secrets:

| Variable | Example | Where to Get |
|----------|---------|--------------|
| `XYOPS_API_KEY` | `abc-123-xyz` | xyOps admin dashboard |
| `SERVICENOW_USER` | `your-username` | ServiceNow account |
| `SERVICENOW_PASSWORD` | `*****` | ServiceNow password |
| `N8N_WEBHOOK_TOKEN` | `secure-token-xyz` | Generate a strong token |
| `N8N_HMAC_SECRET` | `hmac-secret-xyz` | Generate a strong secret |

### Step 3: Verify `.env` is Protected

```bash
# Check that .env is ignored by Git
git status

# Output should NOT show .env file
# If .env appears, it means .gitignore isn't working
```

If `.env` is showing in `git status`, fix it:

```bash
# Remove it from Git tracking (if accidentally tracked)
git rm --cached .env
git commit -m "Remove .env from tracking"

# Verify
git status  # .env should not appear
```

### Step 4: Load Environment (Local Development)

```bash
# Option 1: Source the file
source .env

# Option 2: Docker Compose automatically reads .env
docker compose up
```

---

## 📊 What Goes in `.env`

### ✅ DO Store in `.env`

```env
# API Keys & Tokens
XYOPS_API_KEY=your-secret-key
N8N_WEBHOOK_TOKEN=secure-token
N8N_HMAC_SECRET=secret-hmac

# Passwords & Credentials
SERVICENOW_USER=username
SERVICENOW_PASSWORD=password
SERVICENOW_URL=http://your-instance

# Internal URLs (can be public)
PROMETHEUS_URL=http://prometheus:9090
LOKI_URL=http://loki:3100

# Feature Flags
ENABLE_SERVICENOW=true
ENABLE_N8N=false
LOCAL_LLM_ENABLED=true
```

### ❌ DO NOT Store in `.env`

```env
# Don't add these to .env:
# - Source code
# - Binary files
# - Documentation
# - Configuration management code
```

---

## 🔒 Safety Checklist

Before pushing to GitHub, verify:

```bash
# 1. Check .env is in .gitignore ✅
grep "^.env$" .gitignore

# 2. Verify .env not tracked
git status  # Should NOT show .env

# 3. Check no secrets in commits
git log --all --full-history -- .env  # Should show nothing

# 4. Check repo history for leaked secrets
git log -S "XYOPS_API_KEY" --all      # Should find nothing

# 5. Never use `git add .env` ⚠️
# Always use:
git add .env.template  # ✅ Safe
```

---

## 📝 Environment Variables Reference

### Core Services

```env
# xyOps Ticketing
XYOPS_URL=http://xyops:5522
XYOPS_API_KEY=your-api-key-here  # ⚠️ SENSITIVE

# Approval & Automation
REQUIRE_APPROVAL=true
ANSIBLE_RUNNER_URL=http://ansible-runner:8080
```

### LLM Configuration

```env
# Local Ollama (Recommended)
LOCAL_LLM_ENABLED=true
LOCAL_LLM_MODEL=qwen2:7b
OLLAMA_API_URL=http://host.docker.internal:11434
LOCAL_LLM_TIMEOUT=60

# External APIs (Deprecated)
OPENAI_API_KEY=              # Leave empty
CLAUDE_API_KEY=              # Leave empty
```

### Integrations

```env
# n8n Orchestration
ENABLE_N8N=false
N8N_WEBHOOK_URL=http://n8n:5678/webhook/incident
N8N_WEBHOOK_TOKEN=your-token  # ⚠️ SENSITIVE
N8N_API_KEY=your-api-key      # ⚠️ SENSITIVE

# ServiceNow
ENABLE_SERVICENOW=false
SERVICENOW_URL=http://servicenow:8080
SERVICENOW_USER=admin         # ⚠️ SENSITIVE
SERVICENOW_PASSWORD=admin     # ⚠️ SENSITIVE
```

### Observability

```env
# Backends
PROMETHEUS_URL=http://prometheus:9090
LOKI_URL=http://loki:3100

# Dashboard
COMPUTE_AGENT_URL=http://compute-agent:9000
STORAGE_AGENT_URL=http://storage-agent:9001
OBS_INTELLIGENCE_URL=http://obs-intelligence:9100

# Telemetry
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
```

---

## 🐳 Docker Compose Integration

Docker Compose **automatically** reads `.env`:

```bash
# Start with environment from .env
docker compose up

# .env variables are injected into all services
# No additional configuration needed!
```

To verify environment is loaded:

```bash
# Check what Docker sees
docker compose config | grep XYOPS_API_KEY

# Should output your value from .env
```

---

## 🔑 Generating Secure Tokens

For sensitive values, generate strong tokens:

### Option 1: OpenSSL

```bash
# Generate a 32-character random token
openssl rand -hex 16

# Example output:
# a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

### Option 2: Python

```bash
python3 -c "import secrets; print(secrets.token_hex(16))"
```

### Option 3: /dev/urandom

```bash
head -c 32 /dev/urandom | base64
```

---

## 🚨 Common Mistakes

### ❌ Mistake 1: Committing `.env`

```bash
# WRONG ⚠️
git add .env
git commit -m "Add configuration"

# RIGHT ✅
git add .env.template
git commit -m "Update configuration template"
```

### ❌ Mistake 2: Hardcoding Secrets

```python
# WRONG ⚠️
XYOPS_API_KEY = "abc-123-secret-key"

# RIGHT ✅
import os
XYOPS_API_KEY = os.getenv("XYOPS_API_KEY")
```

### ❌ Mistake 3: Printing Secrets in Logs

```python
# WRONG ⚠️
logger.info(f"API Key: {api_key}")

# RIGHT ✅
logger.info(f"Using xyOps API (key: ***...{api_key[-4:]})")
```

### ❌ Mistake 4: Not Installing `.gitignore` First

```bash
# WRONG ⚠️
cp .env.template .env
git add .
git commit -m "Add .env"  # Oops! Now .env is tracked

# RIGHT ✅
# Ensure .gitignore is in place FIRST
cat .gitignore | grep "^.env$"  # Verify .env is ignored
cp .env.template .env
git add .
git commit -m "Update configuration"
```

---

## 🔧 Troubleshooting

### Issue: Docker Compose Not Reading `.env`

```bash
# Solution 1: Verify .env exists
ls -la .env

# Solution 2: Verify format (no spaces)
cat .env | head -5

# Solution 3: Check container environment
docker compose exec compute-agent printenv | grep XYOPS
```

### Issue: `.env` Accidentally Committed

```bash
# Step 1: Remove from git history
git rm --cached .env

# Step 2: Commit the removal
git commit -m "Remove .env from tracking"

# Step 3: Verify
git log --all --full-history -- .env
```

### Issue: Can't Find Variable in `.env`

```bash
# Search for variable
grep "XYOPS_API_KEY" .env

# If not found, add it from .env.template
cat .env.template | grep "XYOPS_API_KEY" >> .env
```

---

## 📋 Deployment Checklist

Before deploying to production:

- ✅ `.env` file created from `.env.template`
- ✅ All required secrets filled in
- ✅ `.env` is in `.gitignore`
- ✅ `.env` NOT committed to Git
- ✅ `.env` NOT pushed to GitHub
- ✅ Use secrets management (Vault, K8s Secrets) for production
- ✅ Different `.env` for staging/production
- ✅ Rotate secrets regularly
- ✅ Log environment loading (without printing values)
- ✅ Monitor access to `.env` file

---

## 🔐 Production Best Practices

### For Local Development

```bash
# Development: Use .env file
cp .env.template .env
# Fill in development values
source .env
```

### For Staging/Production

**DO NOT** use `.env` files in production!

Instead, use:

1. **Kubernetes Secrets**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: aiops-secrets
   data:
     XYOPS_API_KEY: <base64-encoded-value>
     SERVICENOW_PASSWORD: <base64-encoded-value>
   ```

2. **Docker Swarm Secrets**
   ```bash
   echo "actual-secret-value" | docker secret create xyops_api_key -
   ```

3. **HashiCorp Vault**
   ```bash
   vault kv put secret/aiops XYOPS_API_KEY=value
   ```

4. **AWS Secrets Manager**
   ```bash
   aws secretsmanager create-secret --name aiops/xyops_api_key
   ```

5. **Environment-Specific Files**
   ```bash
   # Don't track these either!
   .env.production.local
   .env.staging.local
   ```

---

## 📚 References

- [Docker Compose Environment Variables](https://docs.docker.com/compose/compose-file/compose-file-v3/#env_file)
- [Git .gitignore Documentation](https://git-scm.com/docs/gitignore)
- [OWASP: Secrets Management](https://owasp.org/www-community/attacks/Secrets_Management_Cheat_Sheet)
- [12 Factor App: Config](https://12factor.net/config)

---

## 🎯 Summary

| Task | Command |
|------|---------|
| Create `.env` | `cp .env.template .env` |
| Load environment | `source .env` |
| Run with Docker | `docker compose up` |
| Check if .env is tracked | `git status` |
| Remove .env from tracking | `git rm --cached .env` |
| Search for variable | `grep "VAR_NAME" .env` |
| Generate token | `openssl rand -hex 16` |
| Never commit | `git add .env` ❌ |
| Always commit | `git add .env.template` ✅ |

---

**Last Updated**: March 22, 2026  
**Status**: ✅ Production Ready  
**Security**: 🔒 Secrets Protected
