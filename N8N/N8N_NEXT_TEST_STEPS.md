# ✅ n8n Pre-Enrichment Workflow is Working!

## What Just Happened

1. ✅ You configured webhook to accept **POST** requests
2. ✅ Clicked **"Execute Workflow"** to activate test mode
3. ✅ Sent **first POST request** → Workflow executed successfully
4. ✅ Sent **second POST request** → Got 404 (this is normal - test mode = 1 call only)

## Next: View Execution Results

### Check What the Workflow Returned

1. **In n8n UI** (http://localhost:5679):
   - Look for **"Executions"** tab on the workflow canvas
   - Click it to see the execution history
   - Click the latest execution to expand it
   - Look at the **"Response"** node output
   - You should see:
     ```json
     {
       "alert_id": "test-001",
       "alert_name": "Test",
       "severity": "HIGH",
       "instance": "service",
       "enrichment_data": {
         "team": "ops-default",
         "service": "service",
         "owner_email": "ops@company.com",
         "escalation_policy": "urgent",
         "auto_remediate": false,
         "tags": [],
         "cmdb_lookup": {
           "service_id": "svc_service",
           "app_tier": "backend",
           "environment": "production"
         }
       },
       "enrichment_timestamp": "2026-03-20T..."
     }
     ```

## Test Again

To send another request:

1. **In n8n UI:**
   - Click **"Execute Workflow"** button again
   - n8n will show "Webhook is listening" again

2. **Then run this command** (one execution only):
   ```bash
   curl -X POST http://localhost:5679/webhook-test/aiops/pre-enrichment \
     -H "Content-Type: application/json" \
     -d '{"alert_id":"test-003","alert_name":"DBAlert","severity":"CRITICAL","instance":"postgresql","description":"Connection pool exhausted","timestamp":"2026-03-20T20:40:00Z","labels":{"team":"database","service":"postgres"}}'
   ```

3. **Check the response:**
   - Should get enriched alert JSON back
   - With metadata, team info, and CMDB lookup data

## Repeat for Other 2 Workflows

**Do the same for:**
1. ✅ Pre-enrichment (DONE!)
2. ⏳ **Post-approval workflow** - Change to POST, test
3. ⏳ **Smart-router workflow** - Change to POST, test

## Then Test Full Integration

Once all 3 are working:

```bash
# Send alert to aiops-bridge
curl -X POST http://localhost:9000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "version": "4",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "EndToEndTest",
        "service_name": "test-service",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Testing complete n8n flow",
        "description": "All three workflows should execute"
      },
      "startsAt": "2026-03-20T20:50:00Z",
      "endsAt": "0001-01-01T00:00:00Z"
    }]
  }'
```

Then check:
- ✅ n8n Executions tabs (all 3 workflows)
- ✅ xyOps for created ticket with enrichment data
- ✅ aiops-bridge logs for "Triggering n8n" messages
