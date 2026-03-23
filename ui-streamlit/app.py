"""
ui-streamlit/app.py
────────────────────────────────────────────────────────────────
Streamlit Dashboard for AIOps Platform

Replaces the React Command Center with a simplified Streamlit UI.
Queries existing agent APIs (compute-agent, storage-agent) without
creating new backend endpoints (zero breaking changes).

Pages:
  - Dashboard: Active alerts, risk levels, LLM summaries
  - Pipeline View: Execution status and audit trail
  - Approvals: Read-only view of pending tasks (xyOps is source of truth)

Environment variables:
  COMPUTE_AGENT_URL     http://compute-agent:9000 (default)
  STORAGE_AGENT_URL     http://storage-agent:9001 (default)
  OBS_INTELLIGENCE_URL  http://obs-intelligence:9100 (default)
  XYOPS_URL             http://xyops:5522 (default)
"""

import asyncio
import logging
import os
from datetime import datetime, timedelta

import httpx
import streamlit as st
from streamlit_option_menu import option_menu

# ── Configuration ──────────────────────────────────────────────────────────────
COMPUTE_AGENT_URL = os.getenv("COMPUTE_AGENT_URL", "http://localhost:9000")
STORAGE_AGENT_URL = os.getenv("STORAGE_AGENT_URL", "http://localhost:9001")
OBS_INTELLIGENCE_URL = os.getenv("OBS_INTELLIGENCE_URL", "http://localhost:9100")
XYOPS_URL = os.getenv("XYOPS_URL", "http://localhost:5522")

logger = logging.getLogger("ui-streamlit")
logging.basicConfig(level=logging.INFO)

# ── Page config ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="AIOps Dashboard",
    page_icon="🔧",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Session state ──────────────────────────────────────────────────────────────
if "refresh_count" not in st.session_state:
    st.session_state.refresh_count = 0


# ── Helper functions ──────────────────────────────────────────────────────────

@st.cache_data(ttl=30)
def fetch_compute_health():
    """Fetch compute-agent health status."""
    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.get(f"{COMPUTE_AGENT_URL}/health")
            return r.json() if r.status_code == 200 else {"status": "error"}
    except Exception as e:
        logger.warning("Failed to fetch compute-agent health: %s", e)
        return {"status": "error", "detail": str(e)}


@st.cache_data(ttl=30)
def fetch_storage_health():
    """Fetch storage-agent health status."""
    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.get(f"{STORAGE_AGENT_URL}/health")
            return r.json() if r.status_code == 200 else {"status": "error"}
    except Exception as e:
        logger.warning("Failed to fetch storage-agent health: %s", e)
        return {"status": "error", "detail": str(e)}


@st.cache_data(ttl=30)
def fetch_obs_intelligence():
    """Fetch obs-intelligence current state."""
    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.get(f"{OBS_INTELLIGENCE_URL}/intelligence/current")
            return r.json() if r.status_code == 200 else {}
    except Exception as e:
        logger.warning("Failed to fetch obs-intelligence: %s", e)
        return {}


@st.cache_data(ttl=30)
def fetch_autonomy_history(window_days=90):
    """Fetch autonomy decision history from compute-agent."""
    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.get(
                f"{COMPUTE_AGENT_URL}/autonomy/history?window_days={window_days}"
            )
            return r.json() if r.status_code == 200 else {}
    except Exception as e:
        logger.warning("Failed to fetch autonomy history: %s", e)
        return {}


# ── Pages ────────────────────────────────────────────────────────────────────

def page_dashboard():
    """Main dashboard showing active alerts and system status."""
    st.title("🔧 AIOps Dashboard")

    # ── Service Health Row ───────────────────────────────────────────────────
    st.subheader("System Health")
    col1, col2, col3 = st.columns(3)

    with col1:
        compute_health = fetch_compute_health()
        status_icon = "✅" if compute_health.get("status") == "ok" else "❌"
        st.metric(
            "Compute Agent",
            f"{status_icon} {compute_health.get('status', 'unknown')}",
            help=f"AI enabled: {compute_health.get('ai_enabled', 'unknown')}",
        )

    with col2:
        storage_health = fetch_storage_health()
        status_icon = "✅" if storage_health.get("status") == "ok" else "❌"
        st.metric(
            "Storage Agent",
            f"{status_icon} {storage_health.get('status', 'unknown')}",
            help=f"Active sessions: {storage_health.get('active_sessions', 0)}",
        )

    with col3:
        st.metric(
            "Dashboard",
            "✅ Running",
            help="Streamlit UI is live",
        )

    # ── Obs-Intelligence Intelligence ───────────────────────────────────────
    st.subheader("Intelligence Engine Status")
    obs_intel = fetch_obs_intelligence()

    col1, col2, col3 = st.columns(3)
    with col1:
        analysis_count = obs_intel.get("analysis_loop_count", 0)
        st.metric("Analysis Iterations", analysis_count)

    with col2:
        forecast_count = obs_intel.get("forecast_loop_count", 0)
        st.metric("Forecast Iterations", forecast_count)

    with col3:
        last_analysis = obs_intel.get("last_analysis_at", "never")
        st.metric("Last Analysis", last_analysis)

    # ── Autonomy History ─────────────────────────────────────────────────────
    st.subheader("Approval Automation Statistics (90-day)")
    history = fetch_autonomy_history(window_days=90)

    if history and "summary" in history:
        summary = history["summary"]
        col1, col2, col3, col4 = st.columns(4)

        with col1:
            st.metric("Total Approvals", summary.get("total_processed", 0))

        with col2:
            approved = summary.get("approved", 0)
            st.metric("Approved", approved)

        with col3:
            autonomous = summary.get("autonomous", 0)
            st.metric("Autonomous Actions", autonomous)

        with col4:
            rejected = summary.get("rejected", 0)
            st.metric("Rejected", rejected)

        # Service breakdown
        if "by_service" in summary:
            st.write("**By Service:**")
            for service, count in sorted(summary["by_service"].items()):
                st.write(f"  - `{service}`: {count} decisions")
    else:
        st.info("No approval history available yet.")

    # ── Refresh button ───────────────────────────────────────────────────────
    if st.button("🔄 Refresh", use_container_width=True):
        st.session_state.refresh_count += 1
        st.cache_data.clear()
        st.rerun()

    st.caption(f"Last updated: {datetime.now().strftime('%H:%M:%S')}")


def page_pipeline():
    """Pipeline view showing execution status and audit trail."""
    st.title("📊 Pipeline Execution View")

    st.info(
        "This page shows the status of the AIOps processing pipeline. "
        "The full audit trail is currently stored in xyOps tickets and accessible via the xyOps web UI."
    )

    # ── Compute Pipeline Status ──────────────────────────────────────────────
    st.subheader("Compute Agent Pipeline")
    compute_health = fetch_compute_health()

    col1, col2 = st.columns(2)
    with col1:
        st.write(f"**Status**: {compute_health.get('status', 'unknown')}")
        st.write(f"**xyOps URL**: {compute_health.get('xyops_url', 'N/A')}")

    with col2:
        st.write(f"**AI Enabled**: {compute_health.get('ai_enabled', 'N/A')}")
        st.write(f"**Approval Required**: {compute_health.get('approval_required', 'N/A')}")

    st.markdown("**Pipeline Steps:**")
    steps = [
        "1. 📨 Receive Alertmanager webhook",
        "2. 📝 Create skeleton xyOps ticket",
        "3. 📊 Fetch Loki logs context",
        "4. 📈 Fetch Prometheus metrics",
        "5. 🤖 Claude AI root-cause analysis",
        "6. ✏️ Update ticket body with enriched content",
        "7. ✅ Create approval gate (if required)",
        "8. 🔗 Send to ServiceNow (async, non-blocking)",
        "9. 🎯 Trigger n8n webhook (async, non-blocking)",
    ]
    for step in steps:
        st.write(step)

    # ── Storage Pipeline Status ──────────────────────────────────────────────
    st.subheader("Storage Agent Pipeline")
    storage_health = fetch_storage_health()

    col1, col2 = st.columns(2)
    with col1:
        st.write(f"**Status**: {storage_health.get('status', 'unknown')}")
        st.write(f"**xyOps URL**: {storage_health.get('xyops_url', 'N/A')}")

    with col2:
        st.write(f"**AI Enabled**: {storage_health.get('ai_enabled', 'N/A')}")
        st.write(f"**Active Sessions**: {storage_health.get('active_sessions', 0)}")

    st.markdown("**Pipeline Steps:**")
    steps = [
        "1. 📨 Receive Alertmanager webhook",
        "2. 📊 Extract OSD status and pool metrics",
        "3. 📝 Fetch Loki log context",
        "4. 🧠 Run storage-specific analysis",
        "5. ✏️ Create xyOps ticket with findings",
        "6. ✅ Create approval gate (if required)",
        "7. 🔗 Send to ServiceNow (async, non-blocking)",
        "8. 🎯 Trigger n8n webhook (async, non-blocking)",
    ]
    for step in steps:
        st.write(step)

    # ── Audit Trail Note ─────────────────────────────────────────────────────
    st.subheader("📋 Full Audit Trail")
    st.markdown(
        f"### All execution details are stored in xyOps tickets.\n\n"
        f"Access the full audit trail and ticket history in xyOps at:\n\n"
        f"**[{XYOPS_URL}]({XYOPS_URL})**\n\n"
        f"Each ticket contains:\n"
        f"- OTel trace_id for distributed tracing in Grafana → Tempo\n"
        f"- Live step-by-step comments as pipeline executes\n"
        f"- Full diagnostic context (logs, metrics, AI analysis)\n"
        f"- Approval gate status\n"
        f"- Execution history and outcomes"
    )


def page_approvals():
    """Approval view — read-only display of pending tasks."""
    st.title("✅ Approval Status")

    st.info(
        "This page shows pending approval requests. "
        "Approvals are managed in xyOps (source of truth). "
        "Navigate to xyOps to approve or reject actions."
    )

    # ── Compute Agent Approvals ──────────────────────────────────────────────
    st.subheader("Compute Agent Pending Approvals")

    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.get(f"{COMPUTE_AGENT_URL}/approvals/pending")
            if r.status_code == 200:
                approvals = r.json()
                items = approvals.get("items", [])

                if items:
                    for item in items:
                        with st.expander(
                            f"🔔 {item['alert_name']} ({item['approval_id'][:12]}...)"
                        ):
                            col1, col2 = st.columns(2)
                            with col1:
                                st.write(f"**Approval ID**: {item['approval_id']}")
                                st.write(f"**Service**: {item['service_name']}")
                                st.write(f"**Severity**: {item['severity']}")

                            with col2:
                                st.write(f"**Status**: {item['status']}")
                                st.write(f"**Created**: {item['created_at']}")
                                if item.get("decided_by"):
                                    st.write(f"**Decided by**: {item['decided_by']}")

                            col1, col2 = st.columns(2)
                            with col1:
                                st.write(
                                    f"**xyOps Ticket**: #{item.get('approval_ticket_id', 'N/A')}"
                                )
                            with col2:
                                st.write(
                                    f"**Incident Ticket**: #{item.get('incident_ticket_id', 'N/A')}"
                                )

                            st.warning(
                                f"👉 **Action**: Navigate to xyOps to review and approve/reject. "
                                f"Ticket #{item.get('approval_ticket_id', 'N/A')}"
                            )
                else:
                    st.success("✅ No pending approvals for compute agent")
            else:
                st.error(f"Failed to fetch compute approvals: {r.status_code}")
    except Exception as e:
        st.error(f"Error fetching compute approvals: {e}")

    st.divider()

    # ── Storage Agent Approvals ──────────────────────────────────────────────
    st.subheader("Storage Agent Pending Approvals")

    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.get(f"{STORAGE_AGENT_URL}/approvals/pending")
            if r.status_code == 200:
                approvals = r.json()
                items = approvals.get("items", [])

                if items:
                    for item in items:
                        with st.expander(
                            f"🔔 {item.get('alert_name', 'Unknown')} ({item.get('session_id', '?')[:12]}...)"
                        ):
                            col1, col2 = st.columns(2)
                            with col1:
                                st.write(f"**Session ID**: {item.get('session_id')}")
                                st.write(f"**Service**: {item.get('service_name')}")

                            with col2:
                                st.write(f"**Status**: {item.get('status')}")
                                st.write(f"**Created**: {item.get('created_at', 'N/A')}")

                            st.warning(
                                "👉 **Action**: Navigate to xyOps to review and approve/reject."
                            )
                else:
                    st.success("✅ No pending approvals for storage agent")
            else:
                st.error(f"Failed to fetch storage approvals: {r.status_code}")
    except Exception as e:
        st.error(f"Error fetching storage approvals: {e}")

    st.divider()

    # ── Direct link to xyOps ─────────────────────────────────────────────────
    st.subheader("📋 Access Approvals in xyOps")
    st.markdown(
        f"### Approvals are managed in xyOps\n\n"
        f"Go to: **[{XYOPS_URL}]({XYOPS_URL})**\n\n"
        f"**To approve an action:**\n"
        f"1. Open the approval ticket in xyOps\n"
        f"2. Review the incident and recommended action\n"
        f"3. Click \"Approve\" or \"Reject\"\n"
        f"4. Add optional notes\n"
        f"5. The execution will proceed or be cancelled\n\n"
        f"Approval decisions are recorded in the approval history and used to "
        f"build trust for autonomous action execution."
    )


def page_settings():
    """Settings and configuration."""
    st.title("⚙️ Settings & Configuration")

    st.subheader("API Endpoints")
    col1, col2 = st.columns(2)

    with col1:
        st.write(f"**Compute Agent**: {COMPUTE_AGENT_URL}")
        st.write(f"**Storage Agent**: {STORAGE_AGENT_URL}")

    with col2:
        st.write(f"**Obs-Intelligence**: {OBS_INTELLIGENCE_URL}")
        st.write(f"**xyOps**: {XYOPS_URL}")

    st.subheader("Environment Variables")
    env_vars = {
        "COMPUTE_AGENT_URL": COMPUTE_AGENT_URL,
        "STORAGE_AGENT_URL": STORAGE_AGENT_URL,
        "OBS_INTELLIGENCE_URL": OBS_INTELLIGENCE_URL,
        "XYOPS_URL": XYOPS_URL,
    }

    for key, value in env_vars.items():
        st.code(f"{key}={value}", language="bash")

    st.subheader("Documentation")
    st.markdown(
        """
        ### Architecture
        
        - **Compute Agent**: Handles OpenShift compute alerts (pods, nodes, resources)
        - **Storage Agent**: Handles OpenShift storage/Ceph alerts (pools, OSDs, latency)
        - **Obs-Intelligence**: Cross-domain analysis and predictive alerts
        - **xyOps**: Incident ticketing and approval workflows
        - **Streamlit UI**: Read-only dashboard (this interface)
        
        ### Integration Flow
        
        1. Prometheus Alertmanager → Agents (webhooks)
        2. Agents create xyOps tickets and run AI analysis
        3. Agents send parallel incidents to ServiceNow (async)
        4. Agents trigger n8n orchestration webhooks (async)
        5. Humans approve/reject actions in xyOps
        6. Approved actions execute via Ansible
        
        ### No Breaking Changes
        
        All existing xyOps workflows and approval mechanisms remain unchanged.
        Integrations (ServiceNow, n8n) run in the background and never block
        the primary xyOps workflow.
        """
    )


# ── Main app ───────────────────────────────────────────────────────────────────

def main():
    """Main entry point."""
    st.sidebar.title("🔧 AIOps Dashboard")

    # Sidebar menu
    selected = option_menu(
        menu_title=None,
        options=["Dashboard", "Pipeline", "Approvals", "Settings"],
        icons=["graph-up", "diagram-3", "check2-circle", "gear"],
        menu_icon="cast",
        default_index=0,
        orientation="vertical",
    )

    # Render selected page
    if selected == "Dashboard":
        page_dashboard()
    elif selected == "Pipeline":
        page_pipeline()
    elif selected == "Approvals":
        page_approvals()
    elif selected == "Settings":
        page_settings()

    # Footer
    st.sidebar.divider()
    st.sidebar.caption(
        "🔒 AIOps Platform — Observability-driven incident management\n\n"
        "xyOps is the source of truth for all approval decisions and ticket history."
    )


if __name__ == "__main__":
    main()
