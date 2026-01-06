"""
Otaru Architecture Diagram.

This script generates a comprehensive architecture diagram for the Otaru project,
covering public traffic flow, GitOps, TLS/Certificate management, secret management,
monitoring, control plane, storage, database, and OIDC/IRSA authentication.

The diagram is generated using the 'diagrams' Python library and includes custom
icons and color-coded edges for different logical flows.
"""

import sys

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.database import Dynamodb
from diagrams.aws.security import IAMAWSSts
from diagrams.custom import Custom
from diagrams.generic.blank import Blank
from diagrams.k8s.compute import Deployment
from diagrams.k8s.controlplane import APIServer
from diagrams.k8s.ecosystem import Helm
from diagrams.k8s.infra import ETCD, Master, Node
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.k8s.rbac import ServiceAccount
from diagrams.k8s.storage import PV, PVC
from diagrams.onprem.certificates import LetsEncrypt
from diagrams.onprem.client import User
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.gitops import Argocd
from diagrams.onprem.logging import Loki
from diagrams.onprem.monitoring import Grafana, Prometheus
from diagrams.onprem.vcs import Github
from diagrams.saas.cdn import Cloudflare
from diagrams.saas.chat import Telegram

# Get output filename from command line argument, default to otaru-architecture
output_filename = sys.argv[1] if len(sys.argv) > 1 else "otaru-architecture"

# Semantic colours for logical flow grouping
COLOUR_OIDC = "#00A4A7"  # DLR - OIDC/IRSA Authentication
COLOUR_PUBLIC = "#DC241f"  # Central - Public Traffic
COLOUR_GITOPS = "#A0A5A9"  # Jubilee - GitOps
COLOUR_TLS = "#0098D4"  # Victoria - TLS/Certificate
COLOUR_SECRET = "#003688"  # Piccadilly - Secret Management
COLOUR_VPN = "#000000"  # Northern - VPN/External Access
COLOUR_MONITORING = "#9B0056"  # Metropolitan - Monitoring
COLOUR_CONTROL_PLANE = "#00782A"  # District - Control Plane
COLOUR_NODE = "#B36305"  # Bakerloo - Node Connectivity
COLOUR_STORAGE = "#EE7C0E"  # Overground - Storage
COLOUR_DATABASE = "#7156A5"  # Elizabeth - Database

graph_attr = {
    "concentrate": "true",
    "splines": "spline",
    "nodesep": "0.8",
    "ranksep": "1.0",
    "margin": "0.2",
    "pad": "0.2",
    "fontsize": "28",
}

node_attr = {
    "fontsize": "16",
}

edge_attr = {
    "fontsize": "18",
}

cluster_attr = {
    "margin": "20",
    "pad": "0.5",
    "fontsize": "28",
}


def edge(label="", colour=None, minlen=None):
    """Create an edge with consistent font size and optional styling.

    The diagrams library doesn't apply global edge_attr to individual Edge objects
    when using the >> operator. We need to explicitly unpack edge_attr for each edge
    to ensure consistent font sizing across all edge labels.

    See:
    - https://github.com/mingrammer/diagrams/issues/699
    - https://github.com/mingrammer/diagrams/issues/701

    Args:
        label: Edge label text
        colour: Edge and label colour
        minlen: Minimum edge length

    Returns:
        Edge object with applied attributes
    """
    attrs = {**edge_attr}
    if colour:
        attrs["color"] = colour
        attrs["fontcolor"] = colour
    if minlen:
        attrs["minlen"] = minlen
    return Edge(label=label, **attrs)


def icon_node(label, icon_name):
    """Create a Custom node with a local PNG icon.

    Args:
        label: Node label text
        icon_name: Filename of the icon (without path or .png extension)
    """
    return Custom(label, f"../assets/icons/{icon_name}.png")


def legend_row(items):
    """Generate a row of legend items for the diagram's legend cluster.

    This helper creates a series of blank nodes connected by styled edges to
    represent different logical flows in the diagram's legend.

    Args:
        items: A sequence of (label, colour) tuples representing each flow.
    """
    blanks = [Blank("") for _ in range(len(items) + 1)]
    for (label, colour), left, right in zip(items, blanks, blanks[1:]):
        left >> edge(label, colour=colour, minlen="1") >> right


with Diagram(
    filename=f"../assets/{output_filename}",
    show=False,
    outformat="png",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    with Cluster("Internet", graph_attr={**cluster_attr, "bgcolor": "transparent"}):
        # External services
        github = Github("GitHub")
        telegram = Telegram("Telegram Bot API")
        cloudflare = Cloudflare("Cloudflare")
        webgazer = icon_node("WebGazer", "webgazer")
        onepassword = icon_node("1Password", "1password")
        letsencrypt = LetsEncrypt("Let's Encrypt")
        external_user = User("User")
        wifiman = icon_node("Wifiman", "wifiman")
        backblaze_b2 = icon_node("Backblaze B2", "backblaze")

        with Cluster("AWS", graph_attr=cluster_attr):
            aws_sts = IAMAWSSts("STS")
            aws_resource = Dynamodb("DynamoDB")

        # Home Network
        with Cluster("Home Network", graph_attr=cluster_attr):
            unifi_gateway = icon_node("UniFi Cloud\nGateway", "unifi")
            with Cluster("K3s Cluster", graph_attr=cluster_attr):
                # Control Plane
                apiserver_lb_operator = Deployment(
                    "k3s-apiserver-\nloadbalancer\nOperator"
                )
                api_server = APIServer("K3s API\nServer")

                # Networking
                cloudflared = Deployment("cloudflared")
                cilium = icon_node("Cilium Gateway", "cilium")

                # Core applications
                argocd = Argocd("ArgoCD")
                atlantis = icon_node("Atlantis", "atlantis")
                applications = Deployment("Applications")
                cert_manager = icon_node("cert-manager", "cert-manager")
                tls_cert = Secret("TLS Cert")

                # Secret management
                onepassword_connect = Helm("1Password\nConnect")
                external_secrets = icon_node("external-secrets", "external-secrets")
                secrets = Secret("Secrets")

                # Security
                falco = icon_node("Falco", "falco")

                # Monitoring
                grafana = Grafana("Grafana")
                prometheus = Prometheus("Prometheus")
                promtail = Grafana("Promtail")
                loki = Loki("Loki")
                metrics_server = Deployment("Metrics Server")
                heartbeats_operator = Deployment("Heartbeats\nOperator")
                heartbeat_crd = CRD("Heartbeats")

                # Storage
                longhorn = icon_node("Longhorn", "longhorn")
                pv = PV("Encrypted\nVolume")
                pvcs = PVC("Encrypted\nPVCs")
                application_with_volume = Deployment("Application with\nvolume")

                # Database
                cnpg = icon_node("CloudNativePG", "cloudnative-pg")
                cnpg_db_cluster = PostgreSQL("CNPG PostgreSQL\nCluster")
                application_with_db = Deployment("Application with\ndatabase backend")

                # OIDC/IRSA
                pod_identity_webhook = Helm("amazon-eks-pod-\nidentity-webhook")
                service_account = ServiceAccount(
                    "Service Account\nwith AWS role\nannotation"
                )
                application_with_irsa = Deployment(
                    "Application with\nAWS IRSA\nannotation"
                )

            with Cluster("Nodes", graph_attr=cluster_attr):
                etcd = ETCD("etcd\n(NUC Mini PC\nUbuntu + SSD)")
                master = Master("Master\n(Raspberry Pi\nwith SD Card)")
                worker = Node("Worker\n(Raspberry Pi\nwith SD Card)")

        # Legend
        with Cluster(
            "Legend",
            graph_attr={
                **cluster_attr,
                "bgcolor": "white",
                "margin": "5",
                "fontsize": "14",
                "ranksep": "0.05",
                "nodesep": "0.1",
            },
        ):
            # Split legend into two rows for more compact layout
            legend_row(
                [
                    ("OIDC/IRSA", COLOUR_OIDC),
                    ("Public Traffic", COLOUR_PUBLIC),
                    ("GitOps", COLOUR_GITOPS),
                    ("TLS/Certificate", COLOUR_TLS),
                    ("Secret Mgmt", COLOUR_SECRET),
                    ("VPN Access", COLOUR_VPN),
                ]
            )

            legend_row(
                [
                    ("Monitoring", COLOUR_MONITORING),
                    ("Control Plane", COLOUR_CONTROL_PLANE),
                    ("Node Connectivity", COLOUR_NODE),
                    ("Storage", COLOUR_STORAGE),
                    ("Database", COLOUR_DATABASE),
                ]
            )

    # Public traffic via Cloudflare Tunnel
    github >> edge("PR events\nwebhook", colour=COLOUR_GITOPS) >> cloudflare
    telegram >> edge("New message webhook", colour=COLOUR_PUBLIC) >> cloudflare
    (
        cloudflare
        >> edge("Cloudflare\nZero Trust\nTunnel", colour=COLOUR_PUBLIC)
        >> cloudflared
    )
    (
        cloudflared
        >> edge("Route public\ntraffic to\ngateway", colour=COLOUR_PUBLIC)
        >> cilium
    )
    (
        cilium
        >> edge(colour=COLOUR_PUBLIC)
        >> [
            applications,
            application_with_volume,
            application_with_db,
            application_with_irsa,
        ]
    )

    # GitOps
    argocd >> edge("Pull when\nreceived\nwebhook event", colour=COLOUR_GITOPS) >> github
    (
        atlantis
        >> edge(
            "Interact with\nGitHub PR webhooks.\n"
            "Currently disabled\ndue to security\nconcern",
            colour=COLOUR_GITOPS,
        )
        >> github
    )

    # TLS
    tls_cert << edge("Mount", colour=COLOUR_TLS) << cilium
    (
        letsencrypt
        << edge("Request Certificate\nvia ACME Protocol", colour=COLOUR_TLS)
        << cert_manager
    )
    (
        letsencrypt
        >> edge("Verify Domain\nOwnership\nvia DNS Record", colour=COLOUR_TLS)
        >> cloudflare
    )
    cert_manager >> edge("Issue certificate", colour=COLOUR_TLS) >> tls_cert

    # Secret flow
    (
        onepassword
        << edge("Retrieve Secret\nfrom 1Password", colour=COLOUR_SECRET)
        << onepassword_connect
    )
    (
        onepassword_connect
        << edge("Pull secrets", colour=COLOUR_SECRET)
        << external_secrets
    )
    external_secrets >> edge("Create K8s\nSecret", colour=COLOUR_SECRET) >> secrets

    # External User Access
    external_user >> edge(colour=COLOUR_VPN) >> wifiman
    wifiman >> edge("VPN", colour=COLOUR_VPN) >> unifi_gateway
    unifi_gateway >> edge("Access internal\napplications", colour=COLOUR_VPN) >> cilium
    unifi_gateway >> edge("Manage cluster", colour=COLOUR_VPN) >> api_server

    # Monitoring
    applications << edge("Scrape metrics", colour=COLOUR_MONITORING) << prometheus
    applications << edge("Scrape logs", colour=COLOUR_MONITORING) << promtail
    promtail >> edge("Push logs", colour=COLOUR_MONITORING) >> loki
    (
        applications
        << edge("Runtime security\nmonitoring", colour=COLOUR_MONITORING)
        << falco
    )
    prometheus << edge("Query metrics", colour=COLOUR_MONITORING) << grafana
    loki << edge("Query logs", colour=COLOUR_MONITORING) << grafana
    loki >> edge("Collect logs", colour=COLOUR_MONITORING) >> falco
    metrics_server << edge("Query metrics", colour=COLOUR_MONITORING) << api_server
    heartbeat_crd >> edge("Monitor", colour=COLOUR_MONITORING) >> heartbeats_operator
    (
        heartbeats_operator
        >> edge("Check liveness", colour=COLOUR_MONITORING)
        >> applications
    )
    (
        heartbeats_operator
        >> edge("Heartbeat monitor", colour=COLOUR_MONITORING)
        >> webgazer
    )
    cloudflare << edge("HTTPS monitor", colour=COLOUR_MONITORING) << webgazer

    # API Server
    (
        apiserver_lb_operator
        >> edge(
            "Maintain LoadBalancer\ntype for Virtual IP", colour=COLOUR_CONTROL_PLANE
        )
        >> api_server
    )
    api_server >> edge("Store cluster\nstate", colour=COLOUR_CONTROL_PLANE) >> etcd

    # Infrastructure
    (
        etcd
        << edge("External etcd\nfor SD card\nperformance", colour=COLOUR_CONTROL_PLANE)
        << master
    )
    (
        master
        >> edge(
            "Node-to-Node\nConnectivity via\nCilium (eBPF)\nsecured by WireGuard",
            colour=COLOUR_NODE,
        )
        >> worker
    )

    # Storage
    (
        longhorn
        >> edge("Create", colour=COLOUR_STORAGE)
        >> pv
        >> edge("Bind", colour=COLOUR_STORAGE)
        >> pvcs
    )
    pvcs << edge("Mount", colour=COLOUR_STORAGE) << application_with_volume
    pvcs << edge("Mount", colour=COLOUR_STORAGE) << prometheus
    pvcs << edge("Mount", colour=COLOUR_STORAGE) << loki
    longhorn >> edge("Backup volume", colour=COLOUR_STORAGE) >> backblaze_b2
    (
        secrets
        << edge("Mount secret\nfor LUKS and\nB2 credential", colour=COLOUR_STORAGE)
        << longhorn
    )

    # Database
    cnpg >> edge("Manage", colour=COLOUR_DATABASE) >> cnpg_db_cluster
    cnpg >> edge("Backup database", colour=COLOUR_DATABASE) >> backblaze_b2
    cnpg_db_cluster >> edge("Mount", colour=COLOUR_DATABASE) >> pvcs
    cnpg_db_cluster << edge("Connect", colour=COLOUR_DATABASE) << application_with_db

    # OIDC/IRSA flow
    (
        api_server
        >> edge("Admission\nwebhook", colour=COLOUR_OIDC)
        >> pod_identity_webhook
    )
    (
        pod_identity_webhook
        >> edge(
            "Mutate pod to\ninject IRSA\nenvironment variables\n"
            "such that AWS SDK\ncan exchange JWT\nfor credentials",
            colour=COLOUR_OIDC,
        )
        >> application_with_irsa
    )
    (
        application_with_irsa
        >> edge("Use service\naccount for\nJWT token", colour=COLOUR_OIDC)
        >> service_account
    )
    service_account << edge("Issue JWT", colour=COLOUR_OIDC) << api_server
    (
        application_with_irsa
        >> edge(
            "Exchange AWS\naccess token with\nk3s API server\nissued JWT",
            colour=COLOUR_OIDC,
        )
        >> aws_sts
    )
    (
        aws_sts
        >> edge("Fetch JWKS\npublic key to\nvalidate JWT", colour=COLOUR_OIDC)
        >> cloudflare
    )
    (
        cloudflare
        >> edge(
            "Route to\nwell-known\nendpoint\nvia cloudflared\nand Cilium Gateway",
            colour=COLOUR_OIDC,
        )
        >> api_server
    )
    (
        application_with_irsa
        >> edge("Access AWS\nresource with\naccess token", colour=COLOUR_OIDC)
        >> aws_resource
    )
