# Fix n8n Webhook Node Configuration

## Problem Found
- ✅ Workflow executes with **GET** requests
- ❌ aiops-bridge sends **POST** requests with JSON body
- **Need:** Reconfigure webhook node to accept POST

## Fix: Update Webhook Node in n8n UI

### Step 1: Open the Workflow in n8n
1. Go to http://localhost:5679
2. Click **Workflows**
3. Open **"AIOps: Pre-Enrichment Agent"**

### Step 2: Configure Webhook Node
1. **Click the Webhook node** (the first node on the canvas, labeled "Webhook: AlertManager")
2. On the right panel, look for these settings:

   | Setting | Current | Fix To |
   |---------|---------|--------|
   | **HTTP Method** | GET | ✅ **POST** |
   | **Response Mode** | onReceived | ✅ **Keep as is** |
   | **Path** | aiops/pre-enrichment | ✅ **Keep as is** |

3. **Change HTTP Method to POST:**
   - Click the dropdown next to "GET"
   - Select **"POST"**

### Step 3: Test the Fix
1. Click **"Execute Workflow"** again (re-activate test mode)
2. Send POST request:
   ```bash
   curl -X POST http://localhost:5679/webhook-test/aiops/pre-enrichment \
     -H "Content-Type: application/json" \
     -d '{
       "alert_id": "post-test-001",
       "alert_name": "TestAlert",
       "severity": "HIGH",
       "instance": "test-service",
       "description": "Testing POST",
       "timestamp": "2026-03-20T20:30:00Z",
       "labels": {"service": "test"}
     }'
   ```

3. **Expected Response:**
   ```json
   {
     "alert_id": "post-test-001",
     "enrichment_data": {
       "team": "ops-default",
       "service": "test-service",
       "...": "..."
     },
     "enrichment_timestamp": "2026-03-20T..."
   }
   ```

### Step 4: Check n8n Executions Tab
1. Click **"Executions"** tab on the workflow
2. Should show successful execution with:
   - Input: Your POST data
   - Output: Enriched data

## Other Workflows
**Check and fix the other 2 workflows similarly:**
- Post-approval workflow: Change webhook to POST
- Smart-router workflow: Change webhook to POST

All should use **POST** method to match aiops-bridge expectations.

## Once Fixed
After updating all 3 workflows to POST:
1. Click **"Deploy"** (optional - makes it permanent)
2. The integration will work end-to-end with aiops-bridge ✅
