local ArgoCDApplication = import 'lib/argocd-application.libsonnet';

local revision = 'monitoring';

local _ignoreDifferences = {
  scheduling: {
    reloader: [{ group: 'apps', kind: 'Deployment', name: 'reloader-reloader', jqPathExpressions: ['.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor'] }],
  }
};

local application = [
  { wave: '10', name: 'cyberchef', namespace: 'cyberchef' },
//  { wave: '10', name: 'home-assistant-volume', namespace: 'home-assistant' },
//  { wave: '10', name: 'jellyfin-volume', namespace: 'jellyfin' },
  { wave: '10', name: 'jung2bot', namespace: 'jung2bot', path: 'helm-charts/jung2bot' },
  { wave: '10', name: 'jung2bot-dev', namespace: 'jung2bot-dev', path: 'helm-charts/jung2bot', helm: { valueFiles: ['value/dev.yaml'] } },
//  { wave: '11', name: 'home-assistant', namespace: 'home-assistant' },
//  { wave: '11', name: 'jellyfin-projectsend-mysql', namespace: 'jellyfin' },
//  { wave: '12', name: 'jellyfin', namespace: 'jellyfin' },
];

local baseline = [
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
  { wave: '02', name: 'metrics-server', namespace: 'kube-system' },
];

// Re-track bootstrap resources
local bootstrap = [
  { wave: '20', name: 'argocd', namespace: 'argocd' },
  { wave: '20', name: 'argocd-bootstrap', namespace: 'argocd', helm: { parameters: [{ name: 'targetRevision', value: revision }] } },
  { wave: '20', name: 'cilium', namespace: 'kube-system', serverSideDiff: 'true' },
  { wave: '20', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '20', name: 'gateway-api', namespace: 'kube-system' },
  { wave: '20', name: 'gateway-api-kubernetes', namespace: 'default' },
  { wave: '20', name: 'kubernetes-service-patcher', namespace: 'default' },
  { wave: '20', name: 'onepassword-connect', namespace: 'onepassword' },
];

local connectivity = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '02', name: 'cilium-gateway', namespace: 'cilium-gateway' },
  { wave: '10', name: 'httpbin', namespace: 'httpbin' },
];

local monitoring = [
  { wave: '10', name: 'grafana-cloud', namespace: 'monitoring' },
  { wave: '10', name: 'healthcheck-io', namespace: 'cilium-gateway' },
];

local scheduling = [
  { wave: '02', name: 'descheduler', namespace: 'descheduler' },
  { wave: '02', name: 'keda', namespace: 'keda' },
  { wave: '02', name: 'reloader', namespace: 'reloader', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.scheduling.reloader },
];

local security = [
  { wave: '02', name: 'cert-manager', namespace: 'cert-manager' },
];

local storage = [
  { wave: '04', name: 'longhorn', namespace: 'longhorn-system' },
  { wave: '05', name: 'longhorn-config', namespace: 'longhorn-system' },
];

[
  ArgoCDApplication.new(appConfig, revision)
  for appConfig in application + baseline + bootstrap + connectivity + monitoring + scheduling + security + storage
]
