"""
integrations/servicenow_client.py
────────────────────────────────────────────────────────────────
ServiceNow Incident Integration — Async, non-blocking.

Creates incidents in ServiceNow in the background, parallel to xyOps workflow.
Failures are logged but never raise exceptions (fail-safe design).

Environment variables:
  SERVICENOW_URL          http://mock-servicenow:8080 (or actual ServiceNow instance)
  SERVICENOW_USER         username or api_key
  SERVICENOW_PASSWORD     password (can be empty if using API key auth)
  ENABLE_SERVICENOW       true/false (default: false)
"""

import asyncio
import logging
import os
from typing import Any

import httpx

logger = logging.getLogger("integrations.servicenow")

# ── Configuration ──────────────────────────────────────────────────────────────
SERVICENOW_URL: str = os.getenv("SERVICENOW_URL", "http://mock-servicenow:8080")
SERVICENOW_USER: str = os.getenv("SERVICENOW_USER", "admin")
SERVICENOW_PASSWORD: str = os.getenv("SERVICENOW_PASSWORD", "admin")
ENABLE_SERVICENOW: bool = os.getenv("ENABLE_SERVICENOW", "false").lower() in ("true", "1")

if ENABLE_SERVICENOW:
    logger.info("ServiceNow integration enabled  url=%s  user=%s", SERVICENOW_URL, SERVICENOW_USER)
else:
    logger.info("ServiceNow integration disabled")


async def create_incident_async(
    alert_name: str,
    service_name: str,
    risk_score: float,
    title: str,
    description: str,
    domain: str = "compute",
) -> dict[str, Any]:
    """
    Create a ServiceNow incident in the background (async, fire-and-forget).

    Always returns success dict (never raises). Failures are logged only.

    Args:
        alert_name: e.g. "HighErrorRate"
        service_name: e.g. "frontend-api"
        risk_score: 0.0-1.0 or absolute (e.g., 85)
        title: Short incident title
        description: Detailed description
        domain: "compute" or "storage"

    Returns:
        {
            "status": "queued" | "created" | "failed",
            "incident_id": "INC0123456" or "",
            "message": "...",
        }
    """
    if not ENABLE_SERVICENOW:
        logger.debug("ServiceNow disabled, skipping incident creation for %s", alert_name)
        return {"status": "skipped", "message": "ServiceNow integration disabled"}

    # Convert risk score to urgency
    if risk_score > 0.8:
        urgency = "1"  # High
    elif risk_score > 0.5:
        urgency = "2"  # Medium
    else:
        urgency = "3"  # Low

    payload = {
        "short_description": title,
        "description": description,
        "urgency": urgency,
        "impact": "2",  # Medium impact
        "assignment_group": "AIOps Team",
        "category": "Software",
        "subcategory": domain,
        "custom_fields": {
            "alert_name": alert_name,
            "service_name": service_name,
            "domain": domain,
            "risk_score": str(risk_score),
            "created_by": "AIOps Platform",
        },
    }

    # Run in background thread to avoid blocking
    loop = asyncio.get_event_loop()
    loop.create_task(_create_incident_impl(payload))

    return {
        "status": "queued",
        "message": f"ServiceNow incident creation queued for {alert_name}",
    }


async def _create_incident_impl(payload: dict[str, Any]) -> None:
    """
    Actual implementation — runs in background.
    Catches all exceptions and logs them (never raises).
    """
    try:
        async with httpx.AsyncClient(
            auth=(SERVICENOW_USER, SERVICENOW_PASSWORD),
            timeout=10.0,
        ) as client:
            response = await client.post(
                f"{SERVICENOW_URL}/api/now/table/incident",
                json=payload,
                headers={"Content-Type": "application/json"},
            )
            response.raise_for_status()
            result = response.json()
            incident_id = result.get("result", {}).get("number", "")
            logger.info(
                "ServiceNow incident created  id=%s  alert=%s  service=%s",
                incident_id,
                payload.get("custom_fields", {}).get("alert_name", "unknown"),
                payload.get("custom_fields", {}).get("service_name", "unknown"),
            )
    except httpx.HTTPStatusError as exc:
        logger.warning(
            "ServiceNow HTTP error (non-fatal)  status=%d  detail=%s",
            exc.response.status_code,
            exc.response.text,
        )
    except asyncio.CancelledError:
        logger.debug("ServiceNow incident creation cancelled")
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "ServiceNow incident creation failed (non-fatal): %s",
            exc,
        )
