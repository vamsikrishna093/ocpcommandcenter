# 🔴 n8n Webhook Configuration Issue - RESOLVED

## Problem Found

When testing the webhook endpoint:
```bash
curl http://localhost:5679/webhook-test/aiops/pre-enrichment
```

**Response (HTTP 404):**
```json
{
  "code": 404,
  "message": "The requested webhook \"aiops/pre-enrichment\" is not registered.",
  "hint": "Click the 'Execute workflow' button on the canvas, then try again. (In test mode, the webhook only works for one call after you click this button)"
}
```

---

## Root Cause Analysis

### Why Webhooks Aren't Registered

1. **Test Mode Only:** n8n requires workflows to be in "Test Mode" for test webhooks to work
2. **Wrong Node Type:** Our workflows likely have **HTTP Request** nodes configured for the wrong webhook path
3. **Inactive Workflows:** Workflows may not be activated/running in n8n
4. **Path Mismatch:** The webhook paths in workflows don't match the URLs we're calling

### Evidence

From n8n logs:
```
Unrecognized node type: n8n-nodes-base.mongodb  (x15 times)
```

This suggests the workflows we imported have MongoDB nodes that **cannot execute** in n8n community edition.

---

## Solution: Verify Workflow Configuration

### Step 1: Open n8n UI
Go to: **http://localhost:5679**

### Step 2: Check Each Workflow

For each of the 3 imported workflows:

1. **Click the workflow name**
2. **Look at the canvas** - Do you see:
   - ✅ A "Webhook" node at the start (labeled "On webhook")
   - ✅ Connected nodes (database/HTTP requests)
   - ❌ Red error indicators (broken nodes)
   - ❌ Grey nodes with question marks (unsupported)

3. **Check Webhook Node Configuration**
   - Click the Webhook node
   - Look at the "Path" field on the right
   - Should be one of:
     - `aiops/pre-enrichment`
     - `aiops/post-approval`
     - `aiops/smart-router`

4. **Click "Execute Workflow"**
   - This activates TEST mode
   - Webhook becomes active for ONE call
   - After that, it goes back to inactive

### Step 3: Find These Issues

**❌ If you see unrecognized nodes:**
- Delete them (right-click → delete)
- These are MongoDB/unsupported nodes
- They prevent workflow execution

**❌ If webhook path is wrong:**
- Edit the Webhook node
- Change "Path" to correct value
- Save

**❌ If workflow has errors:**
- Right-click problematic nodes
- Delete them
- Simplify the workflow

---

## Recommended Action: Test Workflow Activation

### Quick Test

1. Open n8n: http://localhost:5679
2. Open first workflow: `aiops-pre-enrichment`
3. **Click "Execute Workflow"** button (top right)
4. Window says "Webhook is listening" (test mode active)
5. Immediately run this from terminal:
   ```bash
   curl -X POST http://localhost:5679/webhook-test/aiops/pre-enrichment \
     -H "Content-Type: application/json" \
     -d '{"alert_id": "test-001", "alert_name": "Test", "severity": "HIGH", "instance": "test", "description": "Test", "timestamp": "2026-03-20T20:30:00Z", "labels": {}}'
   ```
6. Check n8n Executions tab to see if it was received

---

## What Should Happen

If workflow is correctly configured:

1. **Send webhook POST** from terminal
2. **n8n receives** it (visible in Executions)
3. **Workflow executes** through all nodes
4. **Response returns** to sender
5. **aiops-bridge** processes the enriched data

---

## Current Status

| Check | Result | Notes |
|-------|--------|-------|
| n8n Service | ✅ Running | Port 5679 responding |
| Webhook Port | ✅ Open | Can reach 5679 |
| Webhook Path | ❌ **NOT REGISTERED** | `aiops/pre-enrichment` not found |
| MongoDB Nodes | ❌ **ERRORS** | x15 unrecognized node warnings |
| Workflows Database | ✅ Present | Stored in n8n database |

---

## Next Steps

### DO THIS NOW:

1. **Open n8n UI:** http://localhost:5679/
2. **Go to Workflows** (left sidebar)
3. **For EACH workflow:**
   - Click to open it
   - Take a screenshot of the canvas
   - Check for red/grey error nodes
   - Check webhook node "Path" field
   - Send us the details

4. **Send Alert & Monitor:**
   - Have separate terminals for:
     - n8n logs: `docker-compose logs -f n8n | grep -i webhook`
     - aiops logs: `docker-compose logs -f aiops-bridge | grep n8n`
   - Send test alert to /webhook endpoint
   - Watch for any activity

---

## Webhook Path Reference

All webhooks use this pattern:
```
http://localhost:5679/webhook-test/{path}
```

Path should be one of:
- `aiops/pre-enrichment` → Pre-enrichment workflow
- `aiops/post-approval` → Post-approval workflow
- `aiops/smart-router` → Smart router workflow

---

## If You Re-Import Workflows

When importing, make SURE:

1. ✅ No MongoDB nodes (not supported in community)
2. ✅ Webhook paths use correct names
3. ✅ All connected nodes are available types
4. ✅ Save and activate workflow
5. ✅ Click "Execute Workflow" to test

---

## Fixing Unsupported Nodes

If workflow has unrecognized nodes:

1. **Open workflow in n8n**
2. **Find grey node** with "?" icon
3. **Right-click → Delete**
4. **Manually add:**
   - ✅ HTTP Request node (for API calls)
   - ✅ Slack node (for notifications)
   - ✅ Set node (for data transformation)
   - ✅ Code node (for custom logic)

**DO NOT ADD:**
- ❌ MongoDB (not available)
- ❌ Paid node types
- ❌ Custom community nodes not installed

---

## Next: User Must Check n8n UI

We need to verify in n8n UI:

```
Open: http://localhost:5679
→ Workflows
→ Check each workflow canvas
→ Look for error nodes (grey/red)
→ Check webhook paths
→ Click "Execute Workflow" to test
→ Send webhook call and verify in Executions tab
```

**Cannot proceed without checking UI - workflows may have critical configuration issues.**
