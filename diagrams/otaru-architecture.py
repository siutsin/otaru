"""
Otaru Architecture Diagram.

This script generates a comprehensive architecture diagram for the Otaru project,
covering public traffic flow, GitOps, TLS/Certificate management, secret management,
monitoring, control plane, storage, database, AI services, Tailscale access,
OIDC/JWT, and MCP authentication.

The diagram is generated using the 'diagrams' Python library and includes custom
icons and color-coded edges for different logical flows.
"""

import sys

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.database import Dynamodb
from diagrams.aws.robotics import Robotics
from diagrams.aws.security import IAMAWSSts
from diagrams.azure.identity import Users
from diagrams.custom import Custom
from diagrams.generic.blank import Blank
from diagrams.k8s.compute import Deployment
from diagrams.k8s.controlplane import APIServer
from diagrams.k8s.infra import ETCD, Master, Node
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.k8s.storage import PV, PVC
from diagrams.onprem.certificates import LetsEncrypt
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.gitops import Argocd
from diagrams.onprem.monitoring import Grafana
from diagrams.onprem.network import Envoy, Istio
from diagrams.onprem.vcs import Github
from diagrams.saas.cdn import Cloudflare
from diagrams.saas.chat import Telegram

# Get output filename from command line argument, default to architecture
output_filename = sys.argv[1] if len(sys.argv) > 1 else "architecture"

# Semantic colours for logical flow grouping.
#
# Flow                       TfL line
# -------------------------  -------------------
# AI                         Piccadilly
# Control Plane              District
# Database                   Bakerloo
# GitOps                     London Overground
# Monitoring                 Metropolitan
# Node Connectivity          DLR
# OIDC/JWT Authentication    Elizabeth
# Public Traffic             Central
# Secret Management          London Trams
# Storage                    Liberty
# TLS/Certificate            Victoria
# VPN Access                 Northern
COLOUR_AI = "#003688"
COLOUR_CONTROL = "#00782A"
COLOUR_DATABASE = "#B36305"
COLOUR_GITOPS = "#EE7C0E"
COLOUR_MONITORING = "#9B0056"
COLOUR_NODE = "#00A4A7"
COLOUR_OIDC = "#7156A5"
COLOUR_PUBLIC = "#DC241f"
COLOUR_SECRET = "#5FB526"
COLOUR_STORAGE = "#5D6061"
COLOUR_TLS = "#0098D4"
COLOUR_VPN = "#000000"

graph_attr = {
    "concentrate": "false",
    "newrank": "true",
    "splines": "spline",
    "nodesep": "0.4",
    "ranksep": "0.4",
    "margin": "0.2",
    "pad": "0.2",
    "fontsize": "28",
    "dpi": "60",
}

node_attr = {
    "fontsize": "16",
}

edge_attr = {
    "fontsize": "18",
}

cluster_attr = {
    "margin": "12",
    "pad": "0.5",
    "fontsize": "28",
}


def edge(label="", colour=None, minlen=None, **kwargs):
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
    attrs.update(kwargs)
    return Edge(label=label, **attrs)


def icon_node(label, icon_name):
    """Create a Custom node with a local PNG icon.

    Args:
        label: Node label text
        icon_name: Filename of the icon (without path or .png extension)
    """
    return Custom(label, f"../assets/icons/{icon_name}.png")


def same_rank(graph, *nodes):
    """Place nodes on one row of the given graph or cluster."""
    with graph.subgraph() as row:
        row.attr(rank="same")
        for node in nodes:
            row.node(node._id)


def align_horizontally(*nodes, graph=None):
    """Order a group left-to-right on one row without visible edges."""
    graph = graph or nodes[0]._cluster.dot
    same_rank(graph, *nodes)
    for left, right in zip(nodes, nodes[1:]):
        graph.edge(left._id, right._id, style="invis", weight="100")


def legend_row(items):
    """Generate a row of legend items for the diagram's legend cluster.

    This helper creates a series of blank nodes connected by styled edges to
    represent different logical flows in the diagram's legend.

    Args:
        items: A sequence of (label, colour) tuples representing each flow.

    Returns:
        The blank nodes in the row, left to right.
    """
    blanks = [Blank("", height="0.3") for _ in range(len(items) + 1)]
    same_rank(blanks[0]._cluster.dot, *blanks)
    for (label, colour), left, right in zip(items, blanks, blanks[1:]):
        left >> edge(label, colour=colour, minlen="1") >> right
    return blanks


with Diagram(
    filename=f"../assets/{output_filename}",
    show=False,
    direction="TB",
    outformat="png",
    graph_attr=graph_attr,
    node_attr=node_attr,
) as diagram:
    with Cluster("Internet", graph_attr={**cluster_attr, "bgcolor": "transparent"}):
        # External services
        external_user = Users("User")
        meta_muse = icon_node("Meta Muse", "meta-muse")
        tailnet_join = Blank(
            "",
            shape="point",
            width="0.12",
            color=COLOUR_VPN,
            style="filled",
        )
        github = Github("GitHub")
        telegram = Telegram("Telegram Bot API")
        cloudflare = Cloudflare("Cloudflare")
        webgazer = icon_node("WebGazer", "webgazer")
        onepassword = icon_node("1Password", "1password")
        letsencrypt = LetsEncrypt("Let's Encrypt")
        backblaze_b2 = icon_node("Backblaze B2", "backblaze")

        with Cluster("AWS", graph_attr=cluster_attr):
            aws_sts = IAMAWSSts("STS")
            aws_app_services = Dynamodb("DynamoDB\nand SQS")

        # Home Network
        with Cluster("Home Network", graph_attr=cluster_attr):
            ai_agent = Robotics("Coding Agent")
            agentgateway = icon_node("Local\nagentgateway", "agentgateway")
            with Cluster("K3s Cluster", graph_attr=cluster_attr):
                with Cluster(
                    "Cluster Platform",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    apiserver_lb_operator = Deployment(
                        "k3s-apiserver-\nloadbalancer\nOperator"
                    )
                    api_server = APIServer("K3s API\nServer")
                    pod_identity_webhook = Deployment(
                        "amazon-eks-pod-\nidentity-webhook"
                    )

                with Cluster(
                    "Connectivity",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    cloudflared = icon_node("cloudflared", "cloudflared")
                    gateway_api = CRD("Gateway API\nCRDs")
                    gateway_api_kubernetes = Deployment(
                        "Gateway API\nKubernetes\nService VIP"
                    )
                    metallb = icon_node("MetalLB", "metallb")
                    envoy_gateway = Envoy("Envoy\nGateway")
                    istio = Istio("Istio ambient\nmesh")
                    tailscale = icon_node("Tailscale\nConnector", "tailscale")

                # Core applications
                applications = Deployment("Applications")

                with Cluster(
                    "GitOps",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    argocd = Argocd("ArgoCD")

                with Cluster(
                    "AI",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    hermes = icon_node("Hermes", "hermes")
                    inference = icon_node("llama.cpp\ninference", "llama-cpp")
                    searxng = icon_node("SearXNG", "searxng")
                    firecrawl = icon_node("Firecrawl", "firecrawl")
                    kubernetes_mcp = icon_node("Kubernetes\nMCP", "kubernetes")
                    unifi_mcp = icon_node("UniFi\nMCP", "unifi")

                with Cluster(
                    "Identity",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    hydra = icon_node("Ory Hydra", "ory")

                with Cluster(
                    "Certificate Management",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    cert_manager = icon_node("cert-manager", "cert-manager")
                    tls_cert = Secret("TLS Cert")

                with Cluster(
                    "Secret Management",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    external_secrets = icon_node("external-secrets", "external-secrets")
                    secrets = Secret("Kubernetes\nSecrets")

                with Cluster(
                    "Monitoring",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    monitoring_stack = Grafana(
                        "Grafana,\nLoki,\nPrometheus,\nFluent Bit"
                    )
                    kiali = Istio("Kiali")
                    heartbeats_operator = Deployment("Heartbeats\nOperator")
                    align_horizontally(
                        monitoring_stack,
                        kiali,
                        heartbeats_operator,
                    )

                with Cluster(
                    "Storage",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    longhorn = icon_node("Longhorn", "longhorn")
                    pv = PV("Encrypted\nVolume")
                    pvcs = PVC("Encrypted\nPVCs")

                with Cluster(
                    "Database",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    cnpg = icon_node("CloudNativePG", "cloudnative-pg")
                    cnpg_db_cluster = PostgreSQL("CNPG PostgreSQL\nCluster")

            with Cluster("Nodes", graph_attr=cluster_attr):
                embedded_etcd = ETCD("Embedded etcd\nquorum")
                control_plane_nodes = Master("Control plane\nnodes")
                worker_nodes = Node("Worker\nnodes")

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
            legend_top = legend_row(
                [
                    ("OIDC/JWT", COLOUR_OIDC),
                    ("Public Traffic", COLOUR_PUBLIC),
                    ("GitOps", COLOUR_GITOPS),
                    ("TLS/Certificate", COLOUR_TLS),
                    ("Secret Mgmt", COLOUR_SECRET),
                    ("VPN Access", COLOUR_VPN),
                ]
            )

            legend_bottom = legend_row(
                [
                    ("Monitoring", COLOUR_MONITORING),
                    ("Control Plane", COLOUR_CONTROL),
                    ("Node Connectivity", COLOUR_NODE),
                    ("Storage", COLOUR_STORAGE),
                    ("Database", COLOUR_DATABASE),
                    ("AI", COLOUR_AI),
                ]
            )

    # Public traffic via Cloudflare Tunnel
    github >> edge("Webhook", colour=COLOUR_GITOPS) >> cloudflare
    telegram >> edge("Webhook", colour=COLOUR_PUBLIC) >> cloudflare
    (
        cloudflare
        >> edge("Cloudflare\nZero Trust\nTunnel", colour=COLOUR_PUBLIC)
        >> cloudflared
    )
    (cloudflared >> edge("Tunnel ingress", colour=COLOUR_PUBLIC) >> envoy_gateway)
    (
        gateway_api
        >> edge("Configure\nGateway and\nRoutes", colour=COLOUR_PUBLIC)
        >> envoy_gateway
    )
    (
        envoy_gateway
        >> edge("Forward to\napplications", colour=COLOUR_PUBLIC)
        >> applications
    )

    # GitOps
    (
        github
        << edge("Pull when\nreceived\nwebhook event", colour=COLOUR_GITOPS, minlen="2")
        << argocd
    )
    # TLS
    tls_cert << edge("Mount", colour=COLOUR_TLS) << envoy_gateway
    (
        letsencrypt
        << edge("Request Certificate\nvia ACME Protocol", colour=COLOUR_TLS, minlen="2")
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
        >> edge("Source secrets", colour=COLOUR_SECRET, minlen="2")
        >> external_secrets
    )
    external_secrets >> edge("Sync K8s\nSecrets", colour=COLOUR_SECRET) >> secrets

    # Monitoring
    (
        monitoring_stack
        >> edge("Metrics and logs", colour=COLOUR_MONITORING)
        >> applications
    )
    kiali >> edge("Visualize mesh", colour=COLOUR_MONITORING) >> istio
    (
        webgazer
        << edge("Dashboards", colour=COLOUR_MONITORING, minlen="2")
        << monitoring_stack
    )
    (
        heartbeats_operator
        >> edge("Check liveness", colour=COLOUR_MONITORING)
        >> applications
    )
    (
        webgazer
        << edge("Heartbeat monitor", colour=COLOUR_MONITORING, minlen="2")
        << heartbeats_operator
    )
    webgazer >> edge("HTTPS monitor", colour=COLOUR_MONITORING) >> cloudflare

    # AI
    (hermes >> edge("OpenAI-compatible\nAPI", colour=COLOUR_AI) >> inference)
    hermes >> edge("Web search", colour=COLOUR_AI) >> searxng
    hermes >> edge("Page extract", colour=COLOUR_AI) >> firecrawl
    ai_agent >> edge("Internal API\nvia gateway", colour=COLOUR_AI) >> envoy_gateway
    envoy_gateway >> edge("/v1 route", colour=COLOUR_AI) >> inference
    envoy_gateway >> edge("Dashboard route", colour=COLOUR_AI) >> hermes
    # Layout: the KV cache and database Mount edges into the PVCs do not set
    # ranks. This keeps the PVCs on the bottom row beside llama.cpp and saves
    # two ranks of height.
    (
        inference
        >> edge(
            "KV cache\nsave/restore", colour=COLOUR_AI, constraint="false", tailport="w"
        )
        >> pvcs
    )

    # Layout only: dot fails with "trouble in init_rank" without this invisible
    # edge. It is not a real flow.
    telegram << edge(style="invis", weight="0") << hermes

    telegram << edge("Alerts", colour=COLOUR_MONITORING, minlen="2") << monitoring_stack

    # Tailnet
    # One shared line: both clients join at a blank node before the Connector.
    (
        [external_user, meta_muse]
        >> edge(colour=COLOUR_VPN, arrowhead="none")
        >> tailnet_join
    )
    tailnet_join >> edge("Tailnet\nWireGuard", colour=COLOUR_VPN) >> tailscale
    tailscale >> edge("Subnet route\ningress VIP", colour=COLOUR_VPN) >> envoy_gateway
    tailscale >> edge("Subnet route\nAPI VIP", colour=COLOUR_VPN) >> api_server

    # API Server
    (
        apiserver_lb_operator
        >> edge("Maintain API VIP", colour=COLOUR_CONTROL)
        >> api_server
    )
    (api_server >> edge("Store cluster\nstate", colour=COLOUR_CONTROL) >> embedded_etcd)

    # Infrastructure
    (
        gateway_api_kubernetes
        >> edge("API VIP\n192.168.10.50", colour=COLOUR_CONTROL)
        >> metallb
    )
    (
        metallb
        >> edge("Ingress VIP\n192.168.10.51", colour=COLOUR_CONTROL)
        >> envoy_gateway
    )
    (
        embedded_etcd
        << edge("Embedded etcd\nmembers", colour=COLOUR_CONTROL)
        << control_plane_nodes
    )
    (
        control_plane_nodes
        - edge(
            "Flannel\nWireGuard",
            colour=COLOUR_NODE,
            dir="both",
            arrowtail="normal",
        )
        >> worker_nodes
    )
    (
        istio
        >> edge("Ambient mesh\nservice traffic", colour=COLOUR_CONTROL)
        >> applications
    )

    # Storage
    (
        longhorn
        >> edge("Create", colour=COLOUR_STORAGE)
        >> pv
        >> edge("Bind", colour=COLOUR_STORAGE)
        >> pvcs
    )
    applications >> edge("Mount", colour=COLOUR_STORAGE) >> pvcs
    backblaze_b2 << edge("Backup volume", colour=COLOUR_STORAGE, minlen="2") << longhorn
    (
        secrets
        << edge("Mount secret\nfor LUKS and\nB2 credential", colour=COLOUR_STORAGE)
        << longhorn
    )

    # Database
    cnpg >> edge("Manage", colour=COLOUR_DATABASE) >> cnpg_db_cluster
    (
        backblaze_b2
        << edge("Backup and\nrestore database", colour=COLOUR_DATABASE, minlen="2")
        << cnpg
    )
    cnpg_db_cluster >> edge("Mount", colour=COLOUR_DATABASE, constraint="false") >> pvcs
    applications >> edge("Connect", colour=COLOUR_DATABASE) >> cnpg_db_cluster

    # OIDC/IRSA flow
    (
        api_server
        >> edge("Admission\nwebhook", colour=COLOUR_OIDC)
        >> pod_identity_webhook
    )
    (pod_identity_webhook >> edge("Inject IRSA", colour=COLOUR_OIDC) >> applications)
    api_server >> edge("Issue JWT", colour=COLOUR_OIDC) >> applications
    (
        aws_sts
        << edge("Assume role\nwith JWT", colour=COLOUR_OIDC, minlen="2")
        << applications
    )
    (aws_sts >> edge("Validate JWT", colour=COLOUR_OIDC) >> cloudflare)
    (cloudflare >> edge("OIDC JWKS", colour=COLOUR_OIDC) >> api_server)
    (
        aws_app_services
        << edge("Use AWS APIs", colour=COLOUR_OIDC, minlen="2", tailport="w")
        << applications
    )

    # MCP JWT: workstation -> Hydra (mint) + Envoy (edge JWT) -> MCP.
    # Keep these edges short chains. constraint=false would draw long loops here.
    ai_agent >> edge("Local MCP", colour=COLOUR_OIDC) >> agentgateway
    agentgateway >> edge("Mint token", colour=COLOUR_OIDC) >> hydra
    agentgateway >> edge("Bearer JWT", colour=COLOUR_OIDC) >> envoy_gateway
    envoy_gateway >> edge("JWKS", colour=COLOUR_OIDC) >> hydra
    envoy_gateway >> edge("MCP", colour=COLOUR_OIDC) >> kubernetes_mcp
    envoy_gateway >> edge("MCP", colour=COLOUR_OIDC) >> unifi_mcp

    # Layout: most external services and clients share the top row. Cloudflare
    # ranks just below it. The legend sits at the bottom.
    align_horizontally(
        aws_app_services,
        aws_sts,
        backblaze_b2,
        github,
        letsencrypt,
        external_user,
        meta_muse,
        telegram,
        webgazer,
        onepassword,
        graph=diagram.dot,
    )
    [worker_nodes, pvcs, cnpg_db_cluster] >> edge(style="invis") >> legend_top[0]
    legend_top[0] >> edge(style="invis") >> legend_bottom[0]
