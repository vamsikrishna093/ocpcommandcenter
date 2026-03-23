# ⚠️ IMPORTANT: Activate Workflows for Webhook Testing

## The Issue

n8n webhooks require **activation** before they accept requests. Even though workflows are published, the hint message tells us:

```
"Click the 'Execute workflow' button on the canvas, then try again"
```

## What You Need To Do RIGHT NOW

### For Each of the 3 Workflows:

**1. Pre-Enrichment:**
- Open n8n: http://localhost:5679
- Click **Workflows** → **"AIOps: Pre-Enrichment Agent"**
- Click the blue **"Execute Workflow"** button (top right)
- n8n will show: **"Webhook is listening"** ✅
- Do NOT close this workflow
- **Keep it open in a browser tab!**

**2. Post-Approval:**
- Same steps
- Open in a NEW browser tab (keep pre-enrichment tab open)
- Don't close after activating

**3. Smart-Router:**
- Same steps
- Open in a THIRD browser tab
- Don't close after activating

### Why Keeping Tabs Open Matters

- While the tab is open = webhook is listening
- If you close the tab = webhook stops listening
- Multiple tabs = workflows stay active simultaneously

---

## Test After Activation

Once allthree workflow tabs are open with "Webhook is listening":

```bash
# Test pre-enrichment
curl -X POST http://localhost:5679/webhook-test/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{"alert_id":"test-001","alert_name":"Test","severity":"HIGH","instance":"service","description":"Test","timestamp":"2026-03-20T20:45:00Z","labels":{}}'
```

**Expected response:**
```json
{
  "alert_id": "test-001",
  "enrichment_data": {...},
  "enrichment_timestamp": "..."
}
```

**NOT:**
```json
{"code": 404, "message": "webhook is not registered"}
```

---

## Alternative: Use Production Deployment

If keeping browser tabs open is inconvenient, there's a **production mode**:

1. In each workflow, click **"Deploy"** button (should show green checkmark)
2. This makes webhooks permanent (no tabs needed)
3. BUT: Deploy button may not show if workflow has issues

**For now, use the browser tab method** - it's most reliable.

---

## Then Test End-to-End

Once webhooks are listening (all 3 tabs active):

```bash
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "version": "4",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "EndToEndN8n",
        "service_name": "test-service",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Full workflow test",
        "description": "Testing all 3 n8n workflows"
      },
      "startsAt": "2026-03-20T21:20:00Z",
      "endsAt": "0001-01-01T00:00:00Z"
    }]
  }'
```

Then check:
- aiops-bridge logs for "Triggering n8n..."
- n8n browser tabs for execution updates  
- xyOps for created tickets

---

## Key Points

✅ **Publish** = Save workflow definition  
✅ **Execute** = Activate webhook (temporary, one session)  
✅ **Deploy** = Webhook permanent (requires no errors)

For testing right now: **Execute workflow in 3 browser tabs** ✅

Let me know when all 3 tabs show "Webhook is listening"!
