local ArgoCDApplication = import 'lib/argocd-application.libsonnet';

local revision = 'HEAD';

local _ignoreDifferences = {
  scheduling: {
    reloader: [{ group: 'apps', kind: 'Deployment', name: 'reloader-reloader', jqPathExpressions: ['.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor'] }],
  },
};

local _grafanaDashboards = [
  'dashboards/blocky.yaml',
  'dashboards/container-log-dashboard.yaml',
  'dashboards/falco.yaml',
  'dashboards/k3s-cluster-monitoring.yaml',
  'dashboards/onzack-cluster-monitoring.yaml',
  'dashboards/prometheus-stats.yaml',
];

local jung2botHelm = { parameters: [{ name: 'irsa.awsAccountId', value: std.extVar('AWS_ACCOUNT_ID') }] };
local application = [
  { wave: '10', name: 'blocky', namespace: 'blocky' },
  { wave: '10', name: 'cyberchef', namespace: 'cyberchef' },
  { wave: '10', name: 'excalidraw', namespace: 'excalidraw' },
  { wave: '10', name: 'home-assistant-volume', namespace: 'home-assistant' },
  { wave: '10', name: 'jsoncrack', namespace: 'jsoncrack' },
  { wave: '10', name: 'jung2bot', namespace: 'jung2bot', path: 'helm-charts/jung2bot', helm: jung2botHelm },
  { wave: '10', name: 'jung2bot-dev', namespace: 'jung2bot-dev', path: 'helm-charts/jung2bot', helm: jung2botHelm { valueFiles: ['value/dev.yaml'] } },
  { wave: '10', name: 'teslamate', namespace: 'teslamate' },
  { wave: '10', name: 'yaade-volume', namespace: 'yaade' },
  { wave: '11', name: 'home-assistant', namespace: 'home-assistant' },
  { wave: '11', name: 'yaade', namespace: 'yaade' },
];

local baseline = [
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
];

// Re-track bootstrap resources
local bootstrap = [
  { wave: '20', name: 'argocd', namespace: 'argocd' },
  { wave: '20', name: 'argocd-bootstrap', namespace: 'argocd', helm: { parameters: [{ name: 'targetRevision', value: revision }] } },
  { wave: '20', name: 'cilium', namespace: 'kube-system', serverSideDiff: 'true' },
  { wave: '20', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '20', name: 'gateway-api', namespace: 'kube-system' },
  { wave: '20', name: 'gateway-api-kubernetes', namespace: 'default' },
  { wave: '20', name: 'k3s-apiserver-loadbalancer', namespace: 'k3s-apiserver-loadbalancer-system' },
  { wave: '20', name: 'onepassword-connect', namespace: 'onepassword' },
];

local cicd = [
  { wave: '10', name: 'atlantis', namespace: 'atlantis' },
];

local connectivity = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '02', name: 'cilium-gateway', namespace: 'cilium-gateway' },
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
      targetRevision: '0.23.2',
      helm: { releaseName: s.name },
    },
  },
  { wave: '04', name: 'cloudnative-pg-plugin-barman-cloud', namespace: 'cnpg-system' },
  { wave: '05', name: 'cloudnative-pg-clusters', namespace: 'cnpg-system' },
];

local monitoring = [
  { wave: '05', name: 'heartbeats', namespace: 'heartbeats-operator-system' },
  { wave: '10', name: 'metrics-server', namespace: 'monitoring' },
  { wave: '10', name: 'monitoring', namespace: 'monitoring', helm: { valueFiles: _grafanaDashboards } },
];

local scheduling = [
  { wave: '02', name: 'descheduler', namespace: 'descheduler' },
  { wave: '02', name: 'keda', namespace: 'keda' },
  { wave: '02', name: 'reloader', namespace: 'reloader', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.scheduling.reloader },
];

local security = [
  { wave: '02', name: 'cert-manager', namespace: 'cert-manager' },
  { wave: '10', name: 'falco', namespace: 'falco' },
  { wave: '10', name: 'oidc-provider', namespace: 'default' },
  { wave: '10', name: 'amazon-eks-pod-identity-webhook', namespace: 'default' },
];

local storage = [
  { wave: '04', name: 'longhorn', namespace: 'longhorn-system' },
  { wave: '05', name: 'longhorn-config', namespace: 'longhorn-system' },
];

[
  ArgoCDApplication.new(appConfig, revision)
  for appConfig in application + baseline + bootstrap + cicd + connectivity + database + monitoring + scheduling + security + storage
]
