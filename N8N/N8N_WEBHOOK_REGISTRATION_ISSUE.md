# 🔍 n8n Webhook Registration Issue - Diagnostic

## What's Happening

When aiops-bridge calls the n8n webhooks, n8n responds:
```
"Received request for unknown webhook: The requested webhook 'aiops/pre-enrichment' is not registered."
```

This means:
- ❌ Webhooks are NOT listening
- ❌ Workflows may be published but webhooks aren't active
- ❌ n8n returns error response dict (not approval data)
- ❌ Trying to parse error as ApprovalResponse fails

## Why This Happens

In n8n, webhooks work in **two scenarios:**

| Scenario | Status | How to Fix |
|----------|--------|-----------|
| **Test Mode** | Temporary (1 call only) | Click "Execute Workflow" |
| **Deployed** | Permanent | Click blue "Deploy" button |

**Current Status:** Workflows may be published but webhooks not properly registered.

## Fix: Verify Webhooks in n8n UI

### 1. Open n8n
Go to: **http://localhost:5679**

### 2. For Each Workflow

**Pre-Enrichment:**
1. Click **Workflows** → **"AIOps: Pre-Enrichment Agent"**
2. Look at the **Webhook node** on canvas
3. In the right panel, check:
   - ✅ Path: `aiops/pre-enrichment`
   - ✅ HTTP Method: `POST`
   - ✅ Response Mode: `onReceived`
4. If settings are wrong, **fix them and click Deploy again**

**Post-Approval:**
1. Click **Workflows** → **"AIOps: Post-Approval Agent"**
2. Same checks as above
3. Path should be: `aiops/post-approval`

**Smart-Router:**
1. Click **Workflows** → **"AIOps: Smart Router Agent"**
2. Same checks as above
3. Path should be: `aiops/smart-router`

### 3. Check Active Status

In Workflows list, each workflow should have:
- ✅ **Green checkmark** or **"Active"** status
- ✅ Not in test mode (would say "Test mode")

### 4. Manual Webhook Trigger

If workflows show green/active:

```bash
# Test if webhooks work
curl -X POST http://localhost:5679/webhook-test/aiops/pre-enrichment \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

**Expected:**
- ✅ HTTP 200 with workflow response
- ❌ HTTP 404 = webhook not registered

---

## Why ticket_id Error Still Appears

If n8n webhooks aren't registered:
1. n8n returns HTTP 404 with error JSON: `{"code": 404, "message": "not registered"}`
2. aiops-bridge receives this error dict as `response`
3. Code tries: `ApprovalResponse(**response)` 
4. Response dict looks like: `{"code": 404, "message": "...", "fallback": true}`
5. Missing fields: `ticket_id`, `approved`, `approved_by` = validation fails
6. Different error thrown about Pydantic fields

**Real issue:** Webhooks aren't registered in n8n, so we need to fix that first.

---

## Action Items

**CHECK IN N8N UI:**
1. ✅ Are all 3 workflows showing as "Active" (green)?
2. ✅ Are webhook nodes properly configured (path, method, response)?
3. ✅ Can you manually trigger a test webhook (curl or n8n UI test)?

**If NO to any:**
- Delete workflow
- Re-import from JSON file
- Ensure webhook settings are correct
- Click "Deploy" (not just "Save")
- Test manual webhook call

**If YES to all:**
- n8n is working
- Back to debugging why aiops-bridge responses aren't being interpreted correctly

Let me know what you see in the n8n UI!
