# 🔧 ServiceNow Connection Troubleshooting

## ❓ Why Can't I Access http://mock-servicenow:8080?

**Answer:** It's not running. And you don't need it!

### The Situation

- ❌ No `mock-servicenow` service in docker-compose (intentional)
- ✅ xyOps is running (port 5522) ← Use this instead
- ✅ ServiceNow integration code is installed and ready
- 🔄 ServiceNow async integration waits for real production credentials

---

## ✅ What You Should Use Now

### Development (Today)

```bash
# Current .env state — THIS IS CORRECT
ENABLE_SERVICENOW=false
XYOPS_URL=http://xyops:5522

# ✅ Start testing with xyOps
open http://localhost:5522
# Login: admin / admin
```

**Your primary ticketing system for now:** **xyOps** (port 5522)

### Production (When Ready)

```bash
# Later, when you have ServiceNow instance
ENABLE_SERVICENOW=true
SERVICENOW_URL=https://your-company.service-now.com
SERVICENOW_USER=your_api_user@company.com
SERVICENOW_PASSWORD=your_api_token

# ✅ Both systems active
# - xyOps: Immediate (blocking)
# - ServiceNow: Background async
```

---

## 🎯 Current System State

```
┌─────────────────────────────────────────┐
│        Ticketing System Status          │
├─────────────────────────────────────────┤
│ xyOps        ✅ Running (port 5522)     │
│ N8N          ✅ Running (port 5679)     │
│ ServiceNow   🔄 Ready (no service yet)  │
│ AIOps Bridge ✅ Running (port 9000)     │
└─────────────────────────────────────────┘
```

---

## 📋 What to Do Now

### Step 1: Verify xyOps is Working

```bash
# Check service
docker ps | grep xyops

# Expected: xyops container up and running

# Access UI
open http://localhost:5522
# Should load without errors
```

### Step 2: Test Alert → xyOps Ticket

```bash
# Send test alert
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "service_name": "frontend-api",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Test alert",
        "description": "Testing xyOps integration",
        "dashboard_url": "http://localhost:3001"
      },
      "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }]
  }'

# Check xyOps for new ticket
open http://localhost:5522
# Should see Ticket #1 created
```

### Step 3: Import N8N Workflows (Optional)

```bash
# Open N8N
open http://localhost:5679

# Import 3 workflows from:
/Volumes/Data/Codehub/xyopsver2/N8N/
  ├── n8n_workflows_01_pre_enrichment_agent.json
  ├── n8n_workflows_02_post_approval_agent.json
  └── n8n_workflows_03_smart_router_agent.json
```

---

## 🚀 When You Have ServiceNow Credentials

**Timeline: Later, when you have production instance**

```bash
# 1. Get credentials from ServiceNow admin
#    └─ Instance URL: https://company.service-now.com
#    └─ API User: aiops_api_user@company.com
#    └─ API Token: ******* (generated in ServiceNow)

# 2. Update .env
nano /Volumes/Data/Codehub/xyopsver2/.env

# Set these values:
ENABLE_SERVICENOW=true
SERVICENOW_URL=https://company.service-now.com
SERVICENOW_USER=aiops_api_user@company.com
SERVICENOW_PASSWORD=your_api_token

# 3. Save and restart
docker restart aiops-bridge

# 4. Verify
docker logs aiops-bridge | grep -i servicenow
# Should see: "ServiceNow integration enabled"

# 5. Test
# Send alert → Check both xyOps AND ServiceNow
```

---

## ✅ Development Checklist

```
□ xyOps running at http://localhost:5522
□ Can login with admin/admin
□ N8N running at http://localhost:5679
□ AIOps Bridge running at http://localhost:9000
□ Can send webhook alert to port 9000
□ Ticket created in xyOps after alert
□ Observability stack running (Grafana, Loki, Tempo)
□ .env configured with xyOps settings
□ ServiceNow disabled (ENABLE_SERVICENOW=false)
□ ServiceNow credentials NOT in .env yet (intentional)
```

---

## 🆘 Common Issues

### Issue: Port 5522 (xyOps) not responding

```bash
# Check container
docker ps | grep xyops

# Restart
docker restart xyops

# View logs
docker logs xyops | tail -30
```

### Issue: Webhook not creating ticket

```bash
# Check AIOps Bridge logs
docker logs aiops-bridge | grep -i "xyops\|ticket\|error"

# Verify bridge is running
docker ps | grep aiops-bridge

# Verify xyOps is reachable from bridge
docker exec aiops-bridge curl -v http://xyops:5522
```

### Issue: Firewall/network (localhost vs 127.0.0.1)

```bash
# Try both:
open http://localhost:5522
open http://127.0.0.1:5522

# Or use docker internal name:
docker exec aiops-bridge curl http://xyops:5522
```

---

## 📚 Documentation

**For xyOps details:** See [SERVICENOW-XYOPS-VALIDATION.md](SERVICENOW-XYOPS-VALIDATION.md) Part 1

**For N8N workflows:** See [DOCKER-VALIDATION-N8N-ONBOARDING.md](DOCKER-VALIDATION-N8N-ONBOARDING.md)

**For complete testing:** See [TESTING-GUIDE.md](TESTING-GUIDE.md)

---

## 🎯 Summary

| Question | Answer |
|----------|--------|
| **Why can't I access mock-servicenow:8080?** | It's not running (not in docker-compose) |
| **Do I need it?** | No. xyOps works instead. |
| **What should I use now?** | xyOps (http://localhost:5522) |
| **When do I use ServiceNow?** | When you have production credentials |
| **Will it break if ServiceNow is down?** | No. Async design never blocks. |
| **Can I test everything without ServiceNow?** | Yes. xyOps alone is sufficient for dev. |

---

## ✨ You're Good to Go!

**Use xyOps (port 5522) for your local testing.**  
**ServiceNow integration is ready for production when needed.**  
**No mock ServiceNow required.**

---

**Status:** 🟢 **READY**  
**Primary System:** xyOps (port 5522)  
**Secondary System:** ServiceNow (awaiting credentials)  

Next step: Send a test alert and verify ticket creation in xyOps! 🚀
