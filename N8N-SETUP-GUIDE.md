# N8N Workflow Setup Guide

Complete instructions for setting up the three N8N workflows.

---

## 📥 Importing Workflows

### Method 1: Manual Creation (Recommended for Learning)

Each workflow can be created manually in 5-10 minutes.

#### Workflow 1: Pre-Enrichment Agent

**Step 1: Create Workflow**
1. Open N8N: `http://localhost:5678`
2. Click **"New"** → **"New Workflow"**
3. Set name: `Pre-Enrichment Agent`

**Step 2: Add Webhook Trigger**
1. Click **"+"** → Search **"Webhook"**
2. Configure webhook node:
   - **Path:** `/webhook/aiops/pre-enrichment`
   - **Method:** POST
   - **Response:** Send response back
   - Click **"Save"**

**Step 3: Add Metadata Extraction**
1. **"+"** → Search **"Code"**
2. Code node configuration:
   ```javascript
   // Extract alert metadata
   return [
     {
       json: {
         service_name: $input.body.service_name,
         alert_name: $input.body.alert_name,
         severity: $input.body.severity,
         description: $input.body.description,
         trace_id: $input.body.trace_id || "",
         enrichment_start: new Date().toISOString()
       }
     }
   ]
   ```

**Step 4: Add CMDB Lookup (HTTP)**
1. **"+"** → Search **"HTTP Request"**
2. Configure HTTP node:
   - **Method:** GET
   - **URL:** `http://cmdb:8080/api/services/<< $json.service_name >>`
   - **Headers:** `Authorization: Bearer {{ env.CMDB_API_KEY }}`
   - Click **"Save"**

**Step 5: Add Bridge API Call**
1. **"+"** → Search **"HTTP Request"**
2. Configure:
   - **Method:** POST
   - **URL:** `http://aiops-bridge:9000/pipeline/agent/enriched`
   - **Headers:** `Content-Type: application/json`
   - **Body:**
     ```json
     {
       "service_name": $json.service_name,
       "alert_name": $json.alert_name,
       "enriched_context": $node["CMDB Lookup"].json,
       "trace_id": $json.trace_id
     }
     ```
   - Click **"Save"**

**Step 6: Connect Nodes**
1. Drag from Webhook → Code
2. Drag from Code → CMDB Lookup
3. Drag from CMDB Lookup → Bridge API Call
4. Drag from Bridge API Call → Webhook (response)

**Step 7: Deploy**
1. Click **"Deploy"** (top right)
2. Verify: Workflow shows green checkmark

---

#### Workflow 2: Post-Approval Agent

**Step 1: Create Workflow**
- Name: `Post-Approval Agent`

**Step 2: Webhook + Slack Setup**
1. Add **Webhook** node:
   - **Path:** `/webhook/aiops/post-approval`
   - **Method:** POST

2. Add **Code** node to format Slack message:
   ```javascript
   return [{
     json: {
       channel: {{ env.SLACK_CHANNEL_ID }},
       text: `🔐 *Approval Required*\n\n*Alert:* ${$input.body.alert_name}\n*Service:* ${$input.body.service_name}\n*Confidence:* ${$input.body.confidence}`,
       blocks: [
         {
           "type": "section",
           "text": {
             "type": "mrkdwn",
             "text": `*Alert:* ${$input.body.alert_name}\n*Service:* ${$input.body.service_name}\n*RCA:* ${$input.body.rca_summary}`
           }
         },
         {
           "type": "actions",
           "elements": [
             { "type": "button", "text": { "type": "plain_text", "text": "✅ Approve" }, "value": "approve", "action_id": "approve_btn" },
             { "type": "button", "text": { "type": "plain_text", "text": "❌ Reject" }, "value": "reject", "action_id": "reject_btn" }
           ]
         }
       ]
     }
   }]
   ```

3. Add **Slack** node:
   - **Method:** Message → Post to Channel
   - **Channel:** Use expression `{{ $json.channel }}`
   - **Message:** Use expression `{{ $json.text }}`

**Step 3: Wait for Response**
1. Add **Wait** node:
   - **Resume:** Webhook
   - **Path:** `/webhook/aiops/approval-response`
   - **Method:** POST
   - Set timeout: 1800 (30 minutes)

**Step 4: Decision Logic**
1. Add **Switch** node:
   - **Compare:** `$node["Wait"].json.decision`
   - **Case 1:** `==` `"approve"`
   - **Case 2:** `==` `"reject"`

**Step 5: Connect Branches**
- **Approve branch:**
  - HTTP POST to `http://aiops-bridge:9000/pipeline/agent/approval`
  - Body: `{ "approval_id": "...", "approved": true, "decided_by": "slack-user" }`

- **Reject branch:**
  - HTTP POST to same endpoint with `"approved": false`

**Step 6: Deploy**

---

#### Workflow 3: Smart-Router Agent

**Step 1: Create Workflow**
- Name: `Smart-Router Agent`

**Step 2: Webhook + Metric Fetch**
1. Add **Webhook** node:
   - **Path:** `/webhook/aiops/smart-router`
   - **Method:** POST

2. Add **HTTP Request** (Prometheus metrics):
   ```
   URL: http://prometheus:9090/api/v1/query?query=node_cpu_usage
   ```

3. Add **HTTP Request** (Ollama models):
   ```
   URL: http://ollama:11434/api/tags
   ```

**Step 3: Routing Decision (Code Node)**
```javascript
const cpu = $node["Prometheus"].json.data.result[0]?.value[1] || 0;
const memory = $node["Prometheus"].json.data.result[1]?.value[1] || 0;
const desc_len = $input.body.description?.length || 0;

let selected_model = "qwen2:7b"; // default

if (cpu > 80 && $input.body.severity === "critical") {
  selected_model = "mistral";  // Fast model
} else if (memory < 20) {
  selected_model = "llama2";   // Efficient model
} else if (desc_len > 5000) {
  selected_model = "neural-chat";  // Full reasoning
}

return [{
  json: {
    alert_name: $input.body.alert_name,
    selected_model: selected_model,
    routing_reason: `CPU: ${cpu}%, Memory: ${memory}%, Desc Length: ${desc_len}`,
    cpu_utilization: cpu,
    memory_usage: memory
  }
}];
```

**Step 4: Call Bridge with Model Override**
1. Add **HTTP Request** node:
   ```
   POST http://aiops-bridge:9000/pipeline/agent/analyze
   ```
   Body:
   ```json
   {
     "alert_name": $json.alert_name,
     "model_override": $json.selected_model
   }
   ```

**Step 5: Deploy**

---

### Method 2: Import from JSON File

If you have pre-generated JSON files:

1. Create files in root directory:
   ```
   n8n_workflows_01_pre_enrichment_agent.json
   n8n_workflows_02_post_approval_agent.json
   n8n_workflows_03_smart_router_agent.json
   ```

2. Open N8N → **Workflows** tab

3. Click **"Import"** → Select JSON file

4. Review configuration (paths, URLs, auth)

5. Click **"Deploy"**

---

## ✅ Workflow Checklist

After creating/importing each workflow:

### Pre-Enrichment
- [ ] Webhook path: `/webhook/aiops/pre-enrichment`
- [ ] Method: POST
- [ ] CMDB lookup configured
- [ ] Bridge API call configured
- [ ] Deployed (green checkmark visible)

### Post-Approval
- [ ] Webhook path: `/webhook/aiops/post-approval`
- [ ] Slack integration configured
- [ ] Wait node has 1800s timeout
- [ ] Approve/Reject buttons in Slack message
- [ ] Deployed

### Smart-Router
- [ ] Webhook path: `/webhook/aiops/smart-router`
- [ ] Prometheus queries working
- [ ] Ollama tags endpoint accessible
- [ ] Routing logic correct (CPU/Memory/Description-based)
- [ ] Model selection working
- [ ] Deployed

---

## 🧪 Testing Each Workflow

### Test Pre-Enrichment

```bash
curl -X POST "http://localhost:5678/webhook/aiops/pre-enrichment" \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "backend-api",
    "alert_name": "DiskSpaceHigh",
    "severity": "warning",
    "description": "Disk usage 85% on /data",
    "trace_id": "test-123"
  }'
```

**Expected Response:**
```json
{
  "status": "enriched",
  "cmdb_data": {
    "team": "platform",
    "owner": "alice@example.com",
    "related_services": ["database", "cache"]
  }
}
```

---

### Test Post-Approval

1. **Send approval request:**
```bash
curl -X POST "http://localhost:5678/webhook/aiops/post-approval" \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_id": "TICKET-456",
    "alert_name": "MemoryLeak",
    "rca_summary": "Node.js process memory growing unbounded",
    "confidence": "high"
  }'
```

2. **Check Slack for approval message**

3. **Click button in Slack**

4. **Verify callback processed:**
```bash
# N8N logs should show:
# "Wait node received approval response"
```

---

### Test Smart-Router

```bash
curl -X POST "http://localhost:5678/webhook/aiops/smart-router" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "HighCPU",
    "severity": "critical",
    "description": "CPU utilization 95% for 10 minutes on all nodes"
  }'
```

**Check N8N logs:**
```bash
docker logs n8n | grep -i "model_override\|mistral\|routing"
```

**Expected output:**
```
decision: mistral selected (high severity + high CPU)
```

---

## 🔌 Webhook Configuration Reference

All three workflows require specific webhook configurations:

### Webhook Settings Template

| Field | Pre-Enrichment | Post-Approval | Smart-Router |
|-------|---|---|---|
| **Path** | `/webhook/aiops/pre-enrichment` | `/webhook/aiops/post-approval` | `/webhook/aiops/smart-router` |
| **Method** | POST | POST | POST |
| **Send response** | Yes | Yes | Yes |
| **Response format** | JSON from Code node | Captured from Wait node | JSON from routing logic |
| **Timeout** | 30s | 15s | 10s |
| **Max retries** | 3 | 0 | 1 |

---

## 🔗 Integration Points

### How Compute-Agent Calls N8N

If `ENABLE_N8N=true` and pattern matched, compute-agent will:

```python
# Pre-enrichment (early in pipeline)
if pattern == "pre-enrichment":
    response = await http.post(
        f"{N8N_WEBHOOK_URL}/webhook/aiops/pre-enrichment",
        json=alert_dict,
        timeout=30
    )
    enriched_alert = response.json()

# Post-approval (after AI analysis)
elif pattern == "post-approval":
    response = await http.post(
        f"{N8N_WEBHOOK_URL}/webhook/aiops/post-approval",
        json=analysis_dict,
        timeout=15
    )
    approval_result = response.json()

# Smart-router (at start, to select model)
elif pattern == "smart-router":
    response = await http.post(
        f"{N8N_WEBHOOK_URL}/webhook/aiops/smart-router",
        json=alert_dict,
        timeout=10
    )
    model_override = response.json().get("selected_model")
```

---

## 🛠️ Troubleshooting

### Webhook Not Triggering

**Problem:** Manual curl works, but compute-agent doesn't call it

**Solution:**
1. Check `.env`:
   ```bash
   ENABLE_N8N=true
   N8N_WEBHOOK_URL=http://n8n:5678
   N8N_PATTERN=pre-enrichment  # or correct pattern
   ```

2. Verify workflow **deployed** (not just saved):
   - N8N UI shows green checkmark next to workflow name

3. Check N8N logs:
   ```bash
   docker logs n8n | grep -i "webhook\|registered"
   ```

---

### Webhook Times Out

**Problem:** N8N workflow takes > 30 seconds to respond

**Solution:**
1. Simplify workflow (remove slow HTTP calls)
2. Increase timeout in compute-agent `.env`:
   ```bash
   N8N_REQUEST_TIMEOUT=60  # instead of 30
   ```

3. Check N8N execution time:
   - N8N UI → Workflows → Click workflow → Executions tab
   - Look for long-running nodes (e.g., database queries)

---

### Workflow Executes but Response Invalid

**Problem:** N8N completes but bridge doesn't understand response

**Solution:**
1. Verify response JSON structure matches what bridge expects:
   ```json
   // Bridge expects flat object:
   {
     "service_name": "...",
     "enriched_context": { ... },
     "trace_id": "..."
   }
   ```

2. Add Code node before response to verify output:
   ```javascript
   console.log(JSON.stringify($input.json, null, 2));
   return [$input.json];
   ```

3. Check N8N logs for error details

---

## 📚 Quick Reference

### Disable N8N Temporarily

```bash
# In .env:
ENABLE_N8N=false

# Restart:
docker restart aiops-bridge
```

### View All N8N Webhooks

```bash
curl http://localhost:5678/rest/webhooks | jq '.'
```

### Debug N8N Execution

```bash
# Tail N8N logs
docker logs -f n8n | grep -E "webhook|error|execution"

# Check specific workflow in UI:
# 1. Workflows → Click workflow name
# 2. Click "Executions" tab
# 3. Find execution, click to inspect
# 4. Hover over node to see input/output
```

---

**Next Steps:** After workflows are setup, run the complete [TESTING-GUIDE.md](TESTING-GUIDE.md) to validate the entire pipeline.
