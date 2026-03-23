"""
integrations
────────────────────────────────────────────────────────────────
Parallel integrations for external systems (ServiceNow, n8n).

- servicenow_client: Non-blocking incident creation
- n8n_client: Webhook trigger for orchestration

All integrations run async and do not block main workflow.
"""

from .servicenow_client import create_incident_async
from .n8n_client import send_to_n8n

__all__ = [
    "create_incident_async",
    "send_to_n8n",
]
