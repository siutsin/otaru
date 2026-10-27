local ArgoCDApplication = import 'lib/argocd-application.libsonnet';
local HelmOverrides = import 'lib/helm-overrides.libsonnet';
local IgnoreDiff = import 'lib/ignore-differences.libsonnet';

local revision = 'HEAD';

local application = [
  { wave: '10', name: 'blocky', namespace: 'blocky' },
  { wave: '10', name: 'browserless', namespace: 'browserless' },
  { wave: '10', name: 'changedetection-volume', namespace: 'changedetection' },
  { wave: '10', name: 'cyberchef', namespace: 'cyberchef' },
  { wave: '10', name: 'excalidraw', namespace: 'excalidraw' },
  { wave: '10', name: 'firecrawl', namespace: 'firecrawl' },
  { wave: '10', name: 'generic-device-plugin', namespace: 'generic-device-plugin' },
  { wave: '10', name: 'hermes-volume', namespace: 'hermes' },
  { wave: '10', name: 'home-assistant-volume', namespace: 'home-assistant', helm: HelmOverrides.homeAssistantVolume },
  { wave: '10', name: 'hydra', namespace: 'hydra' },
  { wave: '10', name: 'inference-volume', namespace: 'inference' },
  { wave: '10', name: 'jsoncrack', namespace: 'jsoncrack' },
  { wave: '10', name: 'kubernetes-mcp-server', namespace: 'kubernetes-mcp-server' },
  { wave: '10', name: 'searxng', namespace: 'searxng' },
  { wave: '10', name: 'teslamate', namespace: 'teslamate' },
  { wave: '10', name: 'umami', namespace: 'umami' },
  { wave: '10', name: 'unifi-mcp', namespace: 'unifi-mcp' },
  { wave: '10', name: 'zot', namespace: 'zot', ignoreDiff: IgnoreDiff.zotStatefulsetSsaDefaults },
  { wave: '11', name: 'changedetection', namespace: 'changedetection' },
  { wave: '11', name: 'hermes', namespace: 'hermes' },
  { wave: '11', name: 'home-assistant', namespace: 'home-assistant' },
  { wave: '11', name: 'inference', namespace: 'inference' },
  { wave: '30', name: 'jung2bot', namespace: 'jung2bot', path: 'helm-charts/jung2bot', helm: HelmOverrides.jung2bot },
  { wave: '30', name: 'jung2bot-dev', namespace: 'jung2bot-dev', path: 'helm-charts/jung2bot', helm: HelmOverrides.jung2bot { valueFiles: ['value/dev.yaml'] } },
];

local baseline = [
  { wave: '01', name: 'coredns', namespace: 'kube-system' },
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
];

// Re-track bootstrap resources
local bootstrap = [
  { wave: '20', name: 'namespaces', namespace: 'argocd' },
  { wave: '20', name: 'argocd', namespace: 'argocd' },
  { wave: '20', name: 'argocd-bootstrap', namespace: 'argocd', helm: { parameters: [{ name: 'targetRevision', value: revision }] } },
  // Known issue: syncing this app reproducibly fails to apply the
  // clustersecretstores/secretstores CRDs ("metadata.annotations: Too long").
  // ServerSideApply=true (already the default below), ServerSideDiff=true,
  // Replace=true, and helm.skipCrds were all tried live and none fixed it --
  // see documentation/gotcha.md for what was tried and why disabling CRD
  // creation via chart values is not a safe option (it would stop the
  // operator processing the ClusterSecretStore every ExternalSecret in this
  // cluster depends on). No live impact: the CRDs themselves stay healthy
  // and Synced; only ArgoCD's own sync attempt for these two fails.
  { wave: '20', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '20', name: 'gateway-api', namespace: 'kube-system' },
  { wave: '20', name: 'k3s-apiserver-loadbalancer', namespace: 'k3s-apiserver-loadbalancer-system' },
  { wave: '20', name: 'metallb', namespace: 'metallb-system', ignoreDiff: IgnoreDiff.entries.bootstrap.metallb },
  { wave: '20', name: 'onepassword-connect', namespace: 'onepassword' },
  // Keep the Argo CD Application name stable during the chart rename so the
  // old app finalizer does not prune the live Kubernetes API VIP resources.
  { wave: '21', name: 'gateway-api-kubernetes', namespace: 'default', path: 'helm-charts/metallb-vip', helm: { releaseName: 'metallb-vip' } },
];

local connectivity = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '02', name: 'envoy-gateway', namespace: 'envoy-gateway-system', helm: { skipCrds: true }, ignoreDiff: IgnoreDiff.entries.connectivity['envoy-gateway'] },
  { wave: '02', name: 'tailscale-operator', namespace: 'tailscale', syncOptions: ['SkipDryRunOnMissingResource=true'] },
  { wave: '10', name: 'httpbin', namespace: 'httpbin' },
];

local database = [
  // https://github.com/cloudnative-pg/charts/issues/344
  // Apply the chart directly to generate webhook and TLS certs
  {
    local s = self,
    wave: '03',
    name: 'cloudnative-pg',
    namespace: 'cnpg-system',
    source: {
      repoURL: 'https://cloudnative-pg.io/charts/',
      chart: s.name,
      targetRevision: '0.29.1',
      helm: HelmOverrides.cnpg,
    },
  },
  { wave: '04', name: 'cloudnative-pg-plugin-barman-cloud', namespace: 'cnpg-system' },
  { wave: '06', name: 'cloudnative-pg-clusters', namespace: 'cnpg-system', helm: HelmOverrides.cnpgClusters, ignoreDiff: IgnoreDiff.cnpgClusterOperatorDefaults },
];

local monitoring = [
  { wave: '05', name: 'heartbeats', namespace: 'heartbeats-operator-system' },
  { wave: '05', name: 'kiali', namespace: 'kiali' },
  { wave: '10', name: 'metrics-server', namespace: 'monitoring' },
  { wave: '10', name: 'monitoring', namespace: 'monitoring', helm: HelmOverrides.monitoring, serverSideDiff: 'true', ignoreDiff: IgnoreDiff.entries.monitoring.alertmanager },
];

local scheduling = [
  { wave: '02', name: 'descheduler', namespace: 'descheduler' },
  { wave: '02', name: 'k8s-cleaner', namespace: 'k8s-cleaner', ignoreDiff: IgnoreDiff.entries.scheduling['k8s-cleaner'] },
  { wave: '02', name: 'keda', namespace: 'keda', helm: HelmOverrides.keda },
  { wave: '02', name: 'reloader', namespace: 'reloader', ignoreDiff: IgnoreDiff.entries.scheduling.reloader },
  { wave: '05', name: 'vpa', namespace: 'vpa' },  // after cert-manager (wave 02)
];

local security = [
  { wave: '02', name: 'cert-manager', namespace: 'cert-manager' },
  { wave: '03', name: 'kyverno', namespace: 'kyverno', ignoreDiff: IgnoreDiff.entries.security.kyverno },
  { wave: '04', name: 'kyverno-policy', namespace: 'kyverno', ignoreDiff: IgnoreDiff.entries.security['kyverno-policy'] },
  { wave: '10', name: 'falco', namespace: 'falco' },
  { wave: '10', name: 'oidc-provider', namespace: 'default' },
  { wave: '10', name: 'trivy-operator', namespace: 'trivy-operator', helm: HelmOverrides.trivyOperator },
  { wave: '20', name: 'amazon-eks-pod-identity-webhook', namespace: 'default' },
];

local storage = [
  { wave: '03', name: 'snapshot-controller', namespace: 'kube-system' },
  { wave: '04', name: 'longhorn', namespace: 'longhorn-system', helm: HelmOverrides.longhorn },
  { wave: '05', name: 'longhorn-config', namespace: 'longhorn-system' },
];

local serviceMesh = [
  { wave: '03', name: 'istio-base', namespace: 'istio-system', ignoreDiff: IgnoreDiff.entries.serviceMesh['istio-base'] },
  { wave: '03', name: 'istio-cni', namespace: 'kube-system' },
  { wave: '04', name: 'istiod', namespace: 'istio-system', ignoreDiff: IgnoreDiff.entries.serviceMesh.istiod },
  { wave: '05', name: 'ztunnel', namespace: 'istio-system' },
  { wave: '06', name: 'waypoints', namespace: 'argocd' },
];

[
  ArgoCDApplication.new(appConfig, revision)
  for appConfig in application + baseline + bootstrap + connectivity + database + monitoring + scheduling + security + serviceMesh + storage
]
