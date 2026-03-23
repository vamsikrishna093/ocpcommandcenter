import requests
import threading
import os
import logging

logger = logging.getLogger(__name__)

SERVICENOW_URL = os.getenv("SERVICENOW_URL")
USER = os.getenv("SERVICENOW_USER")
PASSWORD = os.getenv("SERVICENOW_PASSWORD")


def _create_incident(data):
    try:
        response = requests.post(
            f"{SERVICENOW_URL}/api/now/table/incident",
            auth=(USER, PASSWORD),
            json=data,
            headers={"Content-Type": "application/json"},
            timeout=5
        )

        if response.status_code in [200, 201]:
            incident = response.json()
            logger.info(f"ServiceNow Incident Created: {incident}")
        else:
            logger.error(f"ServiceNow Error: {response.text}")

    except Exception as e:
        logger.error(f"ServiceNow Exception: {str(e)}")


def create_incident_async(data):
    thread = threading.Thread(target=_create_incident, args=(data,))
    thread.start()



# After xyOps ticket creation

if os.getenv("ENABLE_SERVICENOW", "false") == "true":
    from integrations.servicenow_client import create_incident_async

    payload = {
        "short_description": alert_name,
        "description": llm_summary,
        "severity": risk_level,
        "category": "infrastructure",
        "subcategory": domain
    }

    create_incident_async(payload)