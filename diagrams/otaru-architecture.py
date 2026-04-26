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
from diagrams.k8s.infra import ETCD, Master, Node
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.k8s.storage import PV, PVC
from diagrams.onprem.certificates import LetsEncrypt
from diagrams.onprem.client import User
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.gitops import Argocd
from diagrams.onprem.monitoring import Grafana
from diagrams.onprem.network import Envoy, Istio
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
    "dpi": "60",
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


def stack_vertically(*nodes):
    """Force nodes onto one graph rank so they render as a vertical stack."""
    node_ids = "; ".join(f'"{node._id}"' for node in nodes)
    current_cluster = nodes[0]._cluster
    current_cluster.dot.body.append(f"{{ rank=same; {node_ids}; }}")
    for upper, lower in zip(nodes, nodes[1:]):
        current_cluster.dot.edge(
            upper._id,
            lower._id,
            style="invis",
            weight="100",
            constraint="false",
        )


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
                    cloudflared = Deployment("cloudflared")
                    gateway_api = CRD("Gateway API\nCRDs")
                    gateway_api_kubernetes = Deployment(
                        "Gateway API\nKubernetes\nService VIP"
                    )
                    metallb = Deployment("MetalLB")
                    envoy_gateway = Envoy("Envoy\nGateway")
                    istio = Istio("Istio ambient\nmesh")

                # Core applications
                argocd = Argocd("ArgoCD")
                atlantis = icon_node("Atlantis\n(inactive)", "atlantis")
                applications = Deployment("Applications")

                with Cluster(
                    "Certificate Management",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    cert_manager = icon_node("cert-manager", "cert-manager")
                    tls_cert = Secret("TLS Cert")

                with Cluster(
                    "Secret Management",
                    direction="TB",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    onepassword_connect = Deployment("1Password\nConnect")
                    external_secrets = icon_node("external-secrets", "external-secrets")
                    secrets = Secret("Secrets")
                    stack_vertically(secrets, external_secrets, onepassword_connect)

                with Cluster(
                    "Monitoring",
                    graph_attr={**cluster_attr, "fontsize": "20"},
                ):
                    monitoring_stack = Grafana("Grafana LGTM\nStack")
                    kiali = Istio("Kiali")
                    heartbeats_operator = Deployment("Heartbeats\nOperator")

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
    cloudflared >> edge("Route public\ntraffic", colour=COLOUR_PUBLIC) >> envoy_gateway
    (
        gateway_api
        >> edge("Configure\nGateway and\nHTTPRoute", colour=COLOUR_PUBLIC)
        >> envoy_gateway
    )
    (envoy_gateway >> edge(colour=COLOUR_PUBLIC) >> applications)

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
    tls_cert << edge("Mount", colour=COLOUR_TLS) << envoy_gateway
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
    (
        unifi_gateway
        >> edge("Access internal\napplications", colour=COLOUR_VPN)
        >> envoy_gateway
    )
    unifi_gateway >> edge("Manage cluster", colour=COLOUR_VPN) >> api_server

    # Monitoring
    (
        applications
        << edge("Metrics and logs", colour=COLOUR_MONITORING)
        << monitoring_stack
    )
    kiali >> edge("Visualize mesh", colour=COLOUR_MONITORING) >> istio
    monitoring_stack >> edge("Dashboards", colour=COLOUR_MONITORING) >> webgazer
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
    (
        api_server
        >> edge("Store cluster\nstate", colour=COLOUR_CONTROL_PLANE)
        >> embedded_etcd
    )

    # Infrastructure
    (
        gateway_api_kubernetes
        >> edge(
            "Maintain API\nLoadBalancer VIP\n192.168.10.50",
            colour=COLOUR_CONTROL_PLANE,
        )
        >> metallb
    )
    (
        metallb
        >> edge(
            "Advertise ingress VIP\n192.168.10.51",
            colour=COLOUR_CONTROL_PLANE,
        )
        >> envoy_gateway
    )
    (
        embedded_etcd
        << edge("Embedded etcd\nmembers", colour=COLOUR_CONTROL_PLANE)
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
        >> edge("East-west\nservice traffic\nvia ztunnel", colour=COLOUR_CONTROL_PLANE)
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
    pvcs << edge("Mount", colour=COLOUR_STORAGE) << applications
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
    cnpg_db_cluster << edge("Connect", colour=COLOUR_DATABASE) << applications

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
        >> applications
    )
    applications << edge("Issue JWT", colour=COLOUR_OIDC) << api_server
    (
        applications
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
            "Route to\nwell-known\nendpoint\nvia cloudflared\nand Envoy Gateway",
            colour=COLOUR_OIDC,
        )
        >> api_server
    )
    (
        applications
        >> edge("Access AWS\nresource with\naccess token", colour=COLOUR_OIDC)
        >> aws_resource
    )
