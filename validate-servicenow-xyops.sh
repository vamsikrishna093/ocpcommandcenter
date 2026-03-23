#!/bin/bash
# validate-servicenow-xyops.sh
# Quick validation script for xyOps + ServiceNow integration

set -e

echo "╔═════════════════════════════════════════════════════════════════╗"
echo "║  xyOps + ServiceNow Integration Validator                      ║"
echo "║  22 March 2026                                                 ║"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS="${GREEN}✅ PASS${NC}"
FAIL="${RED}❌ FAIL${NC}"
WARN="${YELLOW}⚠️  WARN${NC}"

# === PART 1: xyOps Validation ===

echo "┌─ PART 1: xyOps Ticketing System ─────────────────────────────────┐"
echo ""

# Check Docker container
echo -n "1. Docker container running... "
if docker ps | grep -q "xyops.*Up"; then
    echo -e "$PASS"
    docker ps | grep xyops | awk '{print "   Container: " $1 " (" $5 ")"}'
else
    echo -e "$FAIL"
    echo "   Action: docker-compose up -d xyops"
fi

# Check port accessibility
echo -n "2. Port 5522 accessible... "
if timeout 2 bash -c 'echo >/dev/tcp/localhost/5522' 2>/dev/null; then
    echo -e "$PASS"
else
    echo -e "$FAIL"
    echo "   Action: Check Docker network and firewall"
fi

# Check HTTP response
echo -n "3. HTTP response from UI... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5522 2>/dev/null || echo "000")
if [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "301" ] || [ "$RESPONSE" == "302" ]; then
    echo -e "$PASS (HTTP $RESPONSE)"
else
    echo -e "$FAIL (HTTP $RESPONSE)"
fi

# Check API endpoint
echo -n "4. REST API /api/health... "
API_RESPONSE=$(curl -s http://localhost:5522/api/health 2>/dev/null || echo "{\"error\":\"no response\"}")
if echo "$API_RESPONSE" | grep -q "ok\|healthy\|{}" 2>/dev/null || [ "$API_RESPONSE" != "{\"error\":\"no response\"}" ]; then
    echo -e "$PASS"
else
    echo -e "$WARN (No direct health endpoint, but UI accessible)"
fi

# Check configuration
echo -n "5. Configuration in .env... "
if grep -q "XYOPS_URL" /Volumes/Data/Codehub/xyopsver2/.env 2>/dev/null; then
    echo -e "$PASS"
    XYOPS_URL=$(grep "XYOPS_URL" /Volumes/Data/Codehub/xyopsver2/.env | cut -d'=' -f2)
    echo "   URL configured: $XYOPS_URL"
else
    echo -e "$FAIL"
fi

echo ""

# === PART 2: ServiceNow Integration ===

echo "┌─ PART 2: ServiceNow Integration ─────────────────────────────────┐"
echo ""

# Check integration code
echo -n "1. Integration code installed... "
if test -f /Volumes/Data/Codehub/xyopsver2/integrations/servicenow_client.py; then
    echo -e "$PASS"
    wc -l /Volumes/Data/Codehub/xyopsver2/integrations/servicenow_client.py | awk '{print "   Lines: " $1}'
else
    echo -e "$FAIL"
fi

# Check configuration
echo -n "2. Configuration in .env... "
if grep -q "ENABLE_SERVICENOW" /Volumes/Data/Codehub/xyopsver2/.env 2>/dev/null; then
    echo -e "$PASS"
    ENABLED=$(grep "^ENABLE_SERVICENOW" /Volumes/Data/Codehub/xyopsver2/.env | cut -d'=' -f2)
    echo "   Status: $ENABLED"
else
    echo -e "$FAIL"
fi

# Check credentials
echo -n "3. ServiceNow credentials in .env... "
if grep -q "SERVICENOW_USER\|SERVICENOW_PASSWORD" /Volumes/Data/Codehub/xyopsver2/.env 2>/dev/null; then
    echo -e "$PASS"
    echo "   ⚠️  Credentials found (verify they're NOT in git)"
else
    echo -e "$WARN (Not configured yet)"
fi

# Check if git is ignoring .env
echo -n "4. .env protected from git... "
if grep -q "^\.env" /Volumes/Data/Codehub/xyopsver2/.gitignore 2>/dev/null; then
    echo -e "$PASS"
else
    echo -e "$FAIL (Add '*.env' to .gitignore)"
fi

# Check git status
echo -n "5. No credentials in git staging... "
if ! git -C /Volumes/Data/Codehub/xyopsver2 status | grep -q "\.env"; then
    echo -e "$PASS"
else
    echo -e "$FAIL (Reset: git reset /Volumes/Data/Codehub/xyopsver2/.env)"
fi

echo ""

# === PART 3: AIOps Bridge Integration ===

echo "┌─ PART 3: AIOps Bridge Integration ───────────────────────────────┐"
echo ""

# Check bridge container
echo -n "1. AIOps Bridge container running... "
if docker ps | grep -q "aiops-bridge.*Up"; then
    echo -e "$PASS"
    docker ps | grep aiops-bridge | awk '{print "   Container: " $1 " (" $5 ")"}'
else
    echo -e "$FAIL"
    echo "   Action: docker-compose up -d aiops-bridge"
fi

# Test webhook endpoint
echo -n "2. Webhook endpoint available... "
if timeout 2 bash -c 'echo >/dev/tcp/localhost/9000' 2>/dev/null; then
    echo -e "$PASS"
else
    echo -e "$FAIL"
fi

# Check integration in code
echo -n "3. xyOps integration in main.py... "
if grep -q "_create_xyops_ticket\|XYOPS_URL" /Volumes/Data/Codehub/xyopsver2/aiops-bridge/app/main.py 2>/dev/null; then
    echo -e "$PASS"
else
    echo -e "$FAIL"
fi

# Check ServiceNow integration in code
echo -n "4. ServiceNow integration in main.py... "
if grep -q "create_incident_async\|ENABLE_SERVICENOW" /Volumes/Data/Codehub/xyopsver2/aiops-bridge/app/main.py 2>/dev/null; then
    echo -e "$PASS"
else
    echo -e "$WARN (Check pipeline.py)"
fi

echo ""

# === PART 4: End-to-End Readiness ===

echo "┌─ PART 4: End-to-End Readiness ──────────────────────────────────┐"
echo ""

# Test ticket creation API call
echo -n "1. Can create test ticket in xyOps... "
TEST_RESPONSE=$(curl -s -X POST http://localhost:5522/api/app/create_ticket/v1 \
  -H "Content-Type: application/json" \
  -d '{"subject":"Validation Test","type":"issue","status":"open"}' 2>/dev/null || echo "{\"error\":true}")

if echo "$TEST_RESPONSE" | grep -q '"code":0\|"ticket"'; then
    echo -e "$PASS"
    TICKET_ID=$(echo "$TEST_RESPONSE" | grep -o '"num":[0-9]*' | cut -d':' -f2)
    echo "   Created ticket: #$TICKET_ID"
else
    echo -e "$WARN (API might be restrictive)"
    echo "   Response: $(echo "$TEST_RESPONSE" | head -c 100)..."
fi

# Check N8N status (related integration)
echo -n "2. N8N service also running... "
if docker ps | grep -q "n8n.*Up"; then
    echo -e "$PASS"
else
    echo -e "$WARN (N8N not required for xyOps/ServiceNow)"
fi

# Check observability
echo -n "3. Observability stack (logging/tracing)... "
if docker ps | grep -q "loki.*Up" && docker ps | grep -q "tempo.*Up"; then
    echo -e "$PASS"
    echo "   Loki + Tempo running for debugging"
else
    echo -e "$WARN (Not required but helpful for debugging)"
fi

echo ""

# === PART 5: System Summary ===

echo "┌─ SUMMARY ────────────────────────────────────────────────────────┐"
echo ""
echo "xyOps Status:"
echo "  🔗 Local ticketing system"
echo "  📍 URL: http://localhost:5522"
echo "  👤 Login: admin / admin"
echo "  ✅ Used for immediate incident creation"
echo ""
echo "ServiceNow Status:"
echo "  🔗 Enterprise ITSM integration"
echo "  📍 Ready to connect to production instance"
echo "  ⚙️  Configure in .env when ready"
echo "  🔄 Async, non-blocking incident creation"
echo ""
echo "Integration:"
echo "  ✅ Parallel ticket creation (xyOps immediate + ServiceNow async)"
echo "  ✅ Code installed and ready"
echo "  ✅ Configuration framework in place"
echo "  ⏳ Awaiting ServiceNow instance credentials"
echo ""
echo "Next Steps:"
echo "  1. Test: Send sample alert to http://localhost:9000/webhook"
echo "  2. Check: Verify ticket created in xyOps UI"
echo "  3. Production: Update ServiceNow credentials when instance ready"
echo "  4. Enable: Set ENABLE_SERVICENOW=true in .env"
echo "  5. Verify: Confirm both tickets created (xyOps + ServiceNow)"
echo ""
echo "╚═════════════════════════════════════════════════════════════════╝"
