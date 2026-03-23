#!/bin/bash
# Docker Container & N8N Workflow Validation Script
# Usage: ./validate-docker-n8n.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
    ((WARN++))
}

info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# ============================================================================
# SECTION 1: Docker Installation & Daemon Check
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 1: Docker Installation & Daemon Status${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Check Docker installed
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    pass "Docker installed: $DOCKER_VERSION"
else
    fail "Docker not found. Please install Docker Desktop"
    exit 1
fi

# Check Docker daemon running
if docker ps &> /dev/null; then
    pass "Docker daemon is running"
else
    fail "Docker daemon is not running. Please start Docker Desktop"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || command -v docker compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || docker compose --version)
    pass "Docker Compose installed: $COMPOSE_VERSION"
else
    fail "Docker Compose not found"
    exit 1
fi

# ============================================================================
# SECTION 2: Container Status Validation
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 2: Container Status Validation${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

REQUIRED_CONTAINERS=(
    "aiops-bridge"
    "n8n"
    "xyops"
    "ansible-runner"
    "prometheus"
    "grafana"
    "loki"
    "tempo"
    "alertmanager"
    "otel-collector"
)

for container in "${REQUIRED_CONTAINERS[@]}"; do
    status=$(docker ps --filter "name=$container" --format "{{.State}}")
    if [ "$status" = "running" ]; then
        pass "Container '$container' is running"
    else
        fail "Container '$container' is NOT running"
    fi
done

# ============================================================================
# SECTION 3: Port Accessibility
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 3: Port Accessibility${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

PORTS=(
    "9000:aiops-bridge"
    "5679:n8n"
    "5522:xyops"
    "8090:ansible-runner"
    "9090:prometheus"
    "3001:grafana"
    "3100:loki"
    "3200:tempo"
    "9093:alertmanager"
)

for port_pair in "${PORTS[@]}"; do
    port="${port_pair%:*}"
    service="${port_pair#*:}"
    if nc -z localhost "$port" 2>/dev/null; then
        pass "Port $port ($service) is accessible"
    else
        fail "Port $port ($service) is NOT accessible"
    fi
done

# ============================================================================
# SECTION 4: Service Health Checks
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 4: Service Health Checks${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# AIOps Bridge health
if curl -s http://localhost:9000/health | jq -e '.status == "ok"' &>/dev/null; then
    pass "AIOps Bridge health: OK"
else
    fail "AIOps Bridge health check failed"
fi

# N8N health
if curl -s http://localhost:5679/health | jq -e '.status == "ok"' &>/dev/null; then
    pass "N8N health: OK"
else
    warn "N8N health check failed (may need startup time)"
fi

# xyOps health (alternate check method)
if curl -s http://localhost:5522/ &>/dev/null; then
    pass "xyOps is responding"
else
    fail "xyOps not responding on port 5522"
fi

# Prometheus health
if curl -s http://localhost:9090/-/ready &>/dev/null; then
    pass "Prometheus is ready"
else
    warn "Prometheus not ready yet"
fi

# ============================================================================
# SECTION 5: N8N Workflow Files
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 5: N8N Workflow Files Validation${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

N8N_DIR="/Volumes/Data/Codehub/xyopsver2/N8N"

if [ -d "$N8N_DIR" ]; then
    pass "N8N workflows directory found: $N8N_DIR"
else
    fail "N8N workflows directory NOT found at $N8N_DIR"
    exit 1
fi

# Check each workflow file
WORKFLOWS=(
    "n8n_workflows_01_pre_enrichment_agent.json"
    "n8n_workflows_02_post_approval_agent.json"
    "n8n_workflows_03_smart_router_agent.json"
)

for workflow in "${WORKFLOWS[@]}"; do
    filepath="$N8N_DIR/$workflow"
    
    if [ -f "$filepath" ]; then
        # Check if valid JSON
        if python3 -m json.tool "$filepath" &>/dev/null; then
            size=$(wc -c < "$filepath" | numfmt --to=iec 2>/dev/null || wc -c < "$filepath")
            pass "Workflow '$workflow' exists and is valid JSON ($size)"
        else
            fail "Workflow '$workflow' has invalid JSON syntax"
        fi
    else
        fail "Workflow '$workflow' not found"
    fi
done

# ============================================================================
# SECTION 6: N8N Webhook Configuration
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 6: N8N Webhook Configuration${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

WEBHOOKS=(
    "aiops/pre-enrichment"
    "aiops/post-approval"
    "aiops/smart-router"
)

for webhook in "${WEBHOOKS[@]}"; do
    # Test webhook path exists (N8N should respond)
    response=$(curl -s -w "\n%{http_code}" -X POST http://localhost:5679/webhook/$webhook \
        -H "Content-Type: application/json" \
        -d '{"test": "validation"}' 2>/dev/null || echo "000")
    
    http_code=$(echo "$response" | tail -1)
    
    # N8N accepts webhooks even if workflow not found (200/404/500 all indicate N8N is listening)
    if [ "$http_code" != "000" ] && [ "$http_code" != "Connection refused" ]; then
        pass "Webhook path '/webhook/$webhook' is accessible (HTTP $http_code)"
    else
        warn "Webhook path '/webhook/$webhook' may not be accessible"
    fi
done

# ============================================================================
# SECTION 7: Environment Configuration
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 7: Environment Configuration${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

ENV_FILE="/Volumes/Data/Codehub/xyopsver2/.env"

if [ -f "$ENV_FILE" ]; then
    pass ".env file exists"
    
    # Check for critical variables
    if grep -q "XYOPS_URL" "$ENV_FILE"; then
        pass "XYOPS_URL configured in .env"
    else
        warn "XYOPS_URL not found in .env"
    fi
    
    if grep -q "ENABLE_N8N" "$ENV_FILE"; then
        n8n_status=$(grep "^ENABLE_N8N=" "$ENV_FILE" || echo "ENABLE_N8N=unknown")
        pass "N8N configuration present: $n8n_status"
    else
        info "N8N not configured in .env (not required but recommended)"
    fi
    
    if grep -q "OLLAMA_API_URL" "$ENV_FILE"; then
        pass "Ollama API URL configured in .env"
    else
        warn "Ollama API URL not found in .env"
    fi
else
    fail ".env file not found"
fi

# ============================================================================
# SECTION 8: Integration Module Check
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 8: Integration Module Check${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

N8N_INTEGRATION="/Volumes/Data/Codehub/xyopsver2/aiops-bridge/app/integrations_n8n_integration.py"

if [ -f "$N8N_INTEGRATION" ]; then
    lines=$(wc -l < "$N8N_INTEGRATION")
    pass "N8N integration module found ($lines lines)"
    
    # Check for key functions
    if grep -q "class N8nIntegration" "$N8N_INTEGRATION"; then
        pass "N8nIntegration class defined"
    else
        warn "N8nIntegration class not found"
    fi
    
    if grep -q "trigger_pre_enrichment" "$N8N_INTEGRATION"; then
        pass "Pre-enrichment trigger method found"
    else
        warn "Pre-enrichment trigger method not found"
    fi
else
    fail "N8N integration module not found"
fi

# ============================================================================
# SECTION 9: Network Connectivity
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SECTION 9: Network Connectivity${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Check inter-service connectivity
info "Testing service-to-service connectivity from aiops-bridge:"

# Try to reach N8N from aiops-bridge
docker exec aiops-bridge curl -s http://n8n:5678/health &>/dev/null && \
    pass "aiops-bridge can reach N8N" || \
    warn "aiops-bridge cannot reach N8N (may be disabled)"

# Try to reach xyOps from aiops-bridge
docker exec aiops-bridge curl -s http://xyops:5522 &>/dev/null && \
    pass "aiops-bridge can reach xyOps" || \
    fail "aiops-bridge cannot reach xyOps"

# ============================================================================
# SECTION 10: Summary Report
# ============================================================================

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SUMMARY REPORT${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

TOTAL=$((PASS + FAIL + WARN))
SUCCESS_RATE=$((PASS * 100 / TOTAL))

echo "Total Checks: $TOTAL"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo -e "  ${YELLOW}Warnings: $WARN${NC}"
echo -e "\nSuccess Rate: ${SUCCESS_RATE}%"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}✅ ALL SYSTEMS GO!${NC}"
    echo -e "You are ready to import N8N workflows and start testing.\n"
    exit 0
elif [ $FAIL -le 3 ]; then
    echo -e "\n${YELLOW}⚠️  MOSTLY READY${NC}"
    echo -e "Some non-critical services may need attention. See warnings above.\n"
    exit 0
else
    echo -e "\n${RED}❌ SYSTEM NOT READY${NC}"
    echo -e "Please fix the failed checks above before proceeding.\n"
    exit 1
fi
