"""
integrations/n8n_client.py
────────────────────────────────────────────────────────────────
n8n Webhook Integration — Async, non-blocking.

Triggers n8n workflows via webhooks. Failures are logged but never
raise exceptions (fail-safe design).

Environment variables:
  N8N_WEBHOOK_URL        http://n8n:5678/webhook/incident
  ENABLE_N8N             true/false (default: false)
"""

import asyncio
import logging
import os
from typing import Any

import httpx

logger = logging.getLogger("integrations.n8n")

# ── Configuration ──────────────────────────────────────────────────────────────
N8N_WEBHOOK_URL: str = os.getenv(
    "N8N_WEBHOOK_URL",
    "http://n8n:5678/webhook/incident",
)
ENABLE_N8N: bool = os.getenv("ENABLE_N8N", "false").lower() in ("true", "1")

if ENABLE_N8N:
    logger.info("n8n integration enabled  webhook=%s", N8N_WEBHOOK_URL)
else:
    logger.info("n8n integration disabled")


async def send_to_n8n(
    domain: str,
    risk: str,
    summary: str,
    ticket_id: str,
    alert_name: str = "",
    service_name: str = "",
) -> dict[str, Any]:
    """
    Send alert to n8n webhook (async, fire-and-forget).

    Always returns success dict (never raises). Failures are logged only.

    Args:
        domain: "compute" or "storage"
        risk: "high" | "medium" | "low"
        summary: LLM-generated summary
        ticket_id: xyOps ticket ID
        alert_name: Source alert name
        service_name: Source service

    Returns:
        {
            "status": "sent" | "queued" | "failed",
            "message": "...",
        }
    """
    if not ENABLE_N8N:
        logger.debug("n8n disabled, skipping webhook for %s", ticket_id)
        return {"status": "skipped", "message": "n8n integration disabled"}

    payload = {
        "source": "aiops-agent",
        "domain": domain,
        "risk": risk,
        "summary": summary,
        "ticket_id": ticket_id,
        "alert_name": alert_name,
        "service_name": service_name,
    }

    # Run in background task
    loop = asyncio.get_event_loop()
    loop.create_task(_send_webhook_impl(payload))

    return {
        "status": "queued",
        "message": f"n8n webhook triggered for ticket {ticket_id}",
    }


async def _send_webhook_impl(payload: dict[str, Any]) -> None:
    """
    Actual webhook implementation — runs in background.
    Catches all exceptions and logs them (never raises).
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                N8N_WEBHOOK_URL,
                json=payload,
                headers={"Content-Type": "application/json"},
            )
            response.raise_for_status()
            logger.info(
                "n8n webhook triggered  ticket=%s  domain=%s  risk=%s",
                payload.get("ticket_id", "?"),
                payload.get("domain", "?"),
                payload.get("risk", "?"),
            )
    except httpx.HTTPStatusError as exc:
        logger.warning(
            "n8n HTTP error (non-fatal)  status=%d  detail=%s",
            exc.response.status_code,
            exc.response.text,
        )
    except asyncio.CancelledError:
        logger.debug("n8n webhook cancelled")
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "n8n webhook failed (non-fatal): %s",
            exc,
        )
