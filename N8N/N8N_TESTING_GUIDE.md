# 🧪 n8n Integration Complete Testing Guide

## Step 1: Verify n8n is Running

### Check Service Status
```bash
docker-compose ps | grep n8n
```

Expected output:
```
n8n    n8nio/n8n:latest    Up 52 minutes   0.0.0.0:5679->5678/tcp
```

### Access n8n Web UI
Open in browser: **http://localhost:5679**

---

## Step 2: Check Workflows in n8n UI

1. **Go to Workflows Tab** (left sidebar)
2. **Look for these 3 workflows:**
   - `aiops-pre-enrichment`
   - `aiops-post-approval`
   - `aiops-smart-router`

3. **Check Status** (should say "Active" or have a green checkmark)

4. **View Execution History:**
   - Click **Executions** tab
   - Should show webhook calls from aiops-bridge

---

## Step 3: Manual Webhook Test

### Test Pre-Enrichment Webhook Directly
```bash
curl -X POST http://localhost:5678/webhook-test/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{
    "alert_id": "test-001",
    "alert_name": "TestAlert",
    "severity": "HIGH",
    "instance": "test-service",
    "description": "Testing webhook",
    "timestamp": "2026-03-20T20:30:00Z",
    "labels": {"service": "test"}
  }'
```

### Expected Response
```json
{
  "enriched_by": "n8n",
  "enrichment_data": {...},
  "enrichment_timestamp": "2026-03-20T20:30:00Z"
}
```

---

## Step 4: Send Alert & Monitor

### Send Test Alert
```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "version": "4",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestN8nFlow",
        "service_name": "test-service",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Testing complete n8n flow",
        "description": "This should trigger n8n workflows"
      },
      "startsAt": "2026-03-20T20:30:00Z",
      "endsAt": "0001-01-01T00:00:00Z"
    }]
  }'
```

### Monitor in Real-Time
```bash
# Terminal 1: Watch logs
docker-compose logs -f aiops-bridge | grep -E "(trigger|n8n|enrichment|approval)"

# Terminal 2: Send alert
curl -X POST http://localhost:9000/webhook ... (from above)
```

---

## Step 5: Check Execution Results

### In n8n UI
1. Click **Executions** tab
2. Look for recent executions
3. Click on an execution to see:
   - Input data received
   - Each node's output
   - Errors (if any)

### In aiops-bridge Logs
```bash
docker-compose logs aiops-bridge | grep -E "Triggering n8n"
```

Should show:
```
Triggering n8n pre-enrichment agent  ticket=tmmx...
Triggering n8n post-approval agent  ticket=tmmx...
```

### In xyOps
1. Go to http://localhost:5522
2. Look for newly created tickets (Incident or Approval)
3. Check ticket details for n8n enrichment data

---

## Troubleshooting

### Issue: "Unrecognized node type: n8n-nodes-base.mongodb"
**Cause:** MongoDB nodes aren't available in n8n community edition  
**Solution:** See "MongoDB Workaround" below

### Issue: Webhooks not being called
**Check:**
```bash
# Verify webhook URLs in .env
cat .env | grep N8N_.*WEBHOOK

# Test webhook connectivity
curl http://n8n:5678/webhook-test/aiops/pre-enrichment

# Should return 405 (Method Not Allowed) - that's OK, means webhook exists
```

### Issue: Webhook called but no data returned
**Check:**
```bash
# View n8n execution logs
docker-compose logs n8n | grep -i error

# Check if MongoDB nodes are blocking execution
# If so, remove them from workflow (see MongoDB Workaround)
```

---

## MongoDB Workaround

**If workflows have MongoDB nodes** (they don't in our simplified version):

### Edit Workflow in n8n
1. Open workflow
2. Delete MongoDB audit nodes
3. Save and test

Our workflows don't have MongoDB, so this shouldn't be an issue.

---

## Quick Health Check Commands

```bash
# 1. Check if n8n is responding
curl -s http://localhost:5679/healthz | head -20

# 2. Check if aiops-bridge can reach n8n
docker-compose exec aiops-bridge curl -I http://n8n:5678/

# 3. Check if webhooks exist
for webhook in pre-enrichment post-approval smart-router; do
  echo "Testing $webhook..."
  curl -I http://localhost:5678/webhook-test/aiops/$webhook
done

# 4. View recent n8n executions
docker-compose logs n8n | grep -i "execution\|webhook" | tail -20

# 5. View recent aiops-bridge calls to n8n
docker-compose logs aiops-bridge | grep -i "triggering n8n" | tail -10
```

---

## Full End-to-End Test Sequence

**Terminal 1: Watch n8n logs**
```bash
docker-compose logs -f n8n | grep -E "webhook|execute|trigger|Execution"
```

**Terminal 2: Watch aiops-bridge logs**
```bash
docker-compose logs -f aiops-bridge | grep -E "Triggering n8n|trigger|enrichment|approval"
```

**Terminal 3: Send test alert**
```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d @test_alert.json
```

**Then check:**
1. Terminal 1: See n8n webhook execution
2. Terminal 2: See aiops-bridge calling n8n
3. n8n UI: Executions tab shows the webhook call
4. xyOps: New ticket created with enrichment data

---

## Expected Flow with Data

```
1. Alert arrives
   └─ POST /webhook

2. aiops-bridge processes
   ├─ Creates ticket in xyOps
   ├─ Logs: "Created skeleton xyOps ticket #XX"
   └─ Starts n8n integration

3. n8n pre-enrichment is called
   ├─ POST http://n8n:5678/webhook-test/aiops/pre-enrichment
   ├─ n8n logs execution
   ├─ n8n returns enrichment data
   └─ aiops-bridge logs: "Triggering n8n pre-enrichment agent"

4. n8n post-approval is called
   ├─ POST http://n8n:5678/webhook-test/aiops/post-approval
   ├─ n8n returns approval decision
   └─ aiops-bridge logs: "Triggering n8n post-approval agent"

5. Results in xyOps
   ├─ Ticket #XX: Incident with enrichment data
   └─ Ticket #YY: Approval request
```

---

## Data Should Show In

### 1. aiops-bridge Logs
```
✅ "Triggering n8n pre-enrichment agent"
✅ "Alert enriched by n8n"
✅ "Triggering n8n post-approval agent"
```

### 2. n8n Executions Tab
```
✅ Shows webhook URL called
✅ Shows input data received
✅ Shows output data returned
```

### 3. xyOps Ticket Details
```
✅ Enrichment data in ticket body
✅ n8n workflow IDs in metadata
✅ Approval ticket with decision
```

### 4. Docker Logs
```bash
docker-compose logs aiops-bridge | grep -i "n8n\|enrichment\|approval"
```

---

## Summary of What Works ✅

| Component | Status | How to Verify |
|-----------|--------|--------------|
| n8n Service | ✅ Running | `curl http://localhost:5679` |
| aiops-bridge | ✅ Running | `curl http://localhost:9000/health` |
| Webhooks Configured | ✅ Yes | Check `.env` file |
| Webhook URLs Accessible | ✅ Yes | `curl -I http://localhost:5678/webhook-test/...` |
| n8n Workflows Imported | ✅ Yes | Visit http://localhost:5679 → Workflows |
| Alert Flow Triggering | ✅ Yes | Send alert, check logs |
| n8n Being Called | ✅ Yes | Logs show "Triggering n8n..." |

---

## Next: Verify Workflow Data

1. **Open n8n UI:** http://localhost:5679
2. **Click Executions**
3. **Look for latest webhook call from aiops-bridge**
4. **Click to expand and see:**
   - Input payload from aiops-bridge
   - Output returned to aiops-bridge
   - Any errors (if workflow has issues)

All data should flow through! ✅
