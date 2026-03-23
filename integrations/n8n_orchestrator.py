"""
integrations/n8n_orchestrator.py
────────────────────────────────────────────────────────────────
n8n PRIMARY Orchestration Client

n8n is the SINGLE orchestration layer. Agents call n8n webhooks
for ALL operations: ticket creation, ticket updates, step comments,
approval gates, and incident resolution.

n8n workflows then decide which backends to invoke:
  - xyOps (ITSM tickets)
  - ServiceNow (incident mirroring)
  - Ansible Runner (remediation playbooks)

Agents NEVER call xyOps or ServiceNow directly.

Webhook endpoints (handled by n8n Master Orchestrator workflow):
  POST /webhook/orchestrator/create-ticket
  POST /webhook/orchestrator/update-ticket
  POST /webhook/orchestrator/add-comment
  POST /webhook/orchestrator/resolve-ticket
  POST /webhook/orchestrator/create-approval
  POST /webhook/orchestrator/execute-remediation
  POST /webhook/orchestrator/notify

Environment variables:
  N8N_BASE_URL           http://n8n:5678           (default)
  ENABLE_N8N             true/false                 (default: true)
  N8N_ORCHESTRATOR_TIMEOUT  10                      (seconds, default)
────────────────────────────────────────────────────────────────
"""

import logging
import os
from typing import Any

import httpx

logger = logging.getLogger("integrations.n8n_orchestrator")

# ── Configuration ──────────────────────────────────────────────────────────────
N8N_BASE_URL: str = os.getenv("N8N_BASE_URL", "http://n8n:5678")
ENABLE_N8N: bool = os.getenv("ENABLE_N8N", "true").lower() in ("true", "1")
N8N_TIMEOUT: float = float(os.getenv("N8N_ORCHESTRATOR_TIMEOUT", "10"))

# Webhook paths on the n8n Master Orchestrator workflow
_WEBHOOK_CREATE_TICKET = "/webhook/orchestrator/create-ticket"
_WEBHOOK_UPDATE_TICKET = "/webhook/orchestrator/update-ticket"
_WEBHOOK_ADD_COMMENT = "/webhook/orchestrator/add-comment"
_WEBHOOK_RESOLVE_TICKET = "/webhook/orchestrator/resolve-ticket"
_WEBHOOK_CREATE_APPROVAL = "/webhook/orchestrator/create-approval"
_WEBHOOK_EXECUTE_REMEDIATION = "/webhook/orchestrator/execute-remediation"
_WEBHOOK_NOTIFY = "/webhook/orchestrator/notify"

if ENABLE_N8N:
    logger.info("n8n orchestrator enabled  base_url=%s", N8N_BASE_URL)
else:
    logger.info("n8n orchestrator disabled — agents will NOT create tickets")


# ── Internal HTTP helper ───────────────────────────────────────────────────────

async def _n8n_post(
    webhook_path: str,
    payload: dict[str, Any],
    timeout: float | None = None,
) -> dict[str, Any]:
    """
    POST to an n8n webhook endpoint. Returns the JSON response.

    On failure, returns {"error": "...", "n8n_unavailable": True} so callers
    can handle gracefully (e.g. log and continue, or raise).
    """
    if not ENABLE_N8N:
        logger.debug("n8n orchestrator disabled, skipping %s", webhook_path)
        return {"error": "n8n orchestrator disabled", "n8n_unavailable": True}

    url = f"{N8N_BASE_URL}{webhook_path}"
    try:
        async with httpx.AsyncClient(timeout=timeout or N8N_TIMEOUT) as client:
            resp = await client.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
            )
            resp.raise_for_status()
            result = resp.json()
            logger.debug("n8n %s → %s", webhook_path, result)
            return result
    except httpx.HTTPStatusError as exc:
        logger.warning(
            "n8n webhook %s HTTP %d: %s",
            webhook_path, exc.response.status_code, exc.response.text[:300],
        )
        return {"error": f"HTTP {exc.response.status_code}", "n8n_unavailable": True}
    except Exception as exc:  # noqa: BLE001
        logger.warning("n8n webhook %s failed: %s", webhook_path, exc)
        return {"error": str(exc), "n8n_unavailable": True}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — called by compute-agent and storage-agent
# ═══════════════════════════════════════════════════════════════════════════════


async def create_ticket(
    *,
    domain: str,
    subject: str,
    body: str,
    severity: str = "warning",
    service_name: str = "",
    alert_name: str = "",
    tags: list[str] | None = None,
    notify: list[str] | None = None,
    bridge_trace_id: str = "",
) -> dict[str, Any]:
    """
    Request n8n to create a ticket via its orchestration workflow.

    n8n will:
      1. Create the ticket in xyOps
      2. Mirror to ServiceNow (if configured)
      3. Return {"ticket_id": "...", "ticket_num": N, ...}

    Returns the response from n8n (which includes xyOps ticket fields).
    """
    payload = {
        "action": "create_ticket",
        "domain": domain,
        "subject": subject,
        "body": body,
        "severity": severity,
        "service_name": service_name,
        "alert_name": alert_name,
        "tags": tags or [],
        "notify": notify or [],
        "bridge_trace_id": bridge_trace_id,
        "type": "issue",
        "status": "open",
    }
    result = await _n8n_post(_WEBHOOK_CREATE_TICKET, payload)

    # Normalize response: n8n workflow returns the xyOps result directly
    if result.get("n8n_unavailable"):
        return result

    return result


async def update_ticket(
    *,
    ticket_id: str,
    body: str,
    domain: str = "",
) -> dict[str, Any]:
    """
    Request n8n to update a ticket body (e.g. enrich with RCA analysis).
    """
    payload = {
        "action": "update_ticket",
        "ticket_id": ticket_id,
        "body": body,
        "domain": domain,
    }
    return await _n8n_post(_WEBHOOK_UPDATE_TICKET, payload)


async def add_comment(
    *,
    ticket_id: str,
    step_num: int,
    status: str,
    message: str,
    total_steps: int = 6,
) -> dict[str, Any]:
    """
    Request n8n to add a step comment to a ticket.
    n8n forwards to xyOps add_ticket_change and optionally logs to ServiceNow.
    """
    if not ticket_id:
        return {"status": "skipped", "reason": "no ticket_id"}
    payload = {
        "action": "add_comment",
        "ticket_id": ticket_id,
        "step_num": step_num,
        "status": status,
        "message": message,
        "total_steps": total_steps,
    }
    return await _n8n_post(_WEBHOOK_ADD_COMMENT, payload)


async def resolve_tickets(
    *,
    domain: str,
    alert_name: str,
    service_name: str,
    bridge_trace_id: str = "",
) -> dict[str, Any]:
    """
    Request n8n to find and close tickets matching this alert.
    n8n will search xyOps + update ServiceNow.
    """
    payload = {
        "action": "resolve_tickets",
        "domain": domain,
        "alert_name": alert_name,
        "service_name": service_name,
        "bridge_trace_id": bridge_trace_id,
    }
    return await _n8n_post(_WEBHOOK_RESOLVE_TICKET, payload, timeout=15.0)


async def create_approval(
    *,
    domain: str,
    incident_ticket_id: str,
    alert_name: str,
    service_name: str,
    severity: str,
    action: str,
    autonomy_level: str,
    analysis: dict[str, Any],
    bridge_trace_id: str = "",
    callback_url: str = "",
) -> dict[str, Any]:
    """
    Request n8n to create an approval-gate ticket.
    n8n creates the ticket in xyOps and optionally sets up a
    ServiceNow Change Request.
    """
    payload = {
        "action": "create_approval",
        "domain": domain,
        "incident_ticket_id": incident_ticket_id,
        "alert_name": alert_name,
        "service_name": service_name,
        "severity": severity,
        "recommended_action": action,
        "autonomy_level": autonomy_level,
        "ansible_playbook": analysis.get("ansible_playbook", ""),
        "rca_summary": analysis.get("rca_summary", ""),
        "bridge_trace_id": bridge_trace_id,
        "callback_url": callback_url,
    }
    return await _n8n_post(_WEBHOOK_CREATE_APPROVAL, payload)


async def execute_remediation(
    *,
    domain: str,
    alert_name: str,
    service_name: str,
    ticket_id: str,
    playbook_content: str,
    extra_vars: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Request n8n to execute an Ansible remediation playbook.
    n8n routes to ansible-runner and tracks execution status.
    """
    payload = {
        "action": "execute_remediation",
        "domain": domain,
        "alert_name": alert_name,
        "service_name": service_name,
        "ticket_id": ticket_id,
        "playbook_content": playbook_content,
        "extra_vars": extra_vars or {},
    }
    return await _n8n_post(_WEBHOOK_EXECUTE_REMEDIATION, payload, timeout=120.0)


async def notify(
    *,
    domain: str,
    event_type: str,
    alert_name: str = "",
    service_name: str = "",
    ticket_id: str = "",
    risk: str = "",
    summary: str = "",
    **extra: Any,
) -> dict[str, Any]:
    """
    Generic notification via n8n (Slack, email, etc. as configured in n8n).
    """
    payload = {
        "action": "notify",
        "domain": domain,
        "event_type": event_type,
        "alert_name": alert_name,
        "service_name": service_name,
        "ticket_id": ticket_id,
        "risk": risk,
        "summary": summary,
        **extra,
    }
    return await _n8n_post(_WEBHOOK_NOTIFY, payload)
