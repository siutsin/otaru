local ArgoCDApplication = import 'lib/argocd-application.libsonnet';

local revision = 'fix';

local _ignoreDifferences = {
  application: {
    adguardHome: [{ group: '*', kind: 'ConfigMap', name: 'adguard-home-configmap', jqPathExpressions: ['.data'] }],
  },
  connectivity: {
    istioBase: [{ group: 'admissionregistration.k8s.io', kind: 'ValidatingWebhookConfiguration', name: 'istiod-default-validator', jqPathExpressions: ['.webhooks[].failurePolicy'] }],
    istiod: [{ group: 'apps', kind: 'Deployment', name: 'istiod', jqPathExpressions: ['.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor'] }],
  },
  scheduling: {
    keda: [{ group: 'apiregistration.k8s.io', kind: 'APIService', name: 'v1beta1.external.metrics.k8s.io', jqPathExpressions: ['.spec.insecureSkipTLSVerify'] }]
  }
};

local application = [
  { wave: '10', name: 'adguard-home', namespace: 'adguard-home', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.application.adguardHome },
  { wave: '10', name: 'cyberchef', namespace: 'cyberchef' },
  { wave: '10', name: 'home-assistant-volume', namespace: 'home-assistant' },
  { wave: '10', name: 'jellyfin-volume', namespace: 'jellyfin' },
  { wave: '10', name: 'jung2bot', namespace: 'jung2bot', path: 'helm-charts/jung2bot' },
  { wave: '10', name: 'jung2bot-dev', namespace: 'jung2bot-dev', path: 'helm-charts/jung2bot', helm: { valueFiles: ['value/dev.yaml'] } },
  { wave: '10', name: 'repave', namespace: 'repave' },
  { wave: '11', name: 'home-assistant', namespace: 'home-assistant' },
  { wave: '11', name: 'jellyfin', namespace: 'jellyfin' },
];

local baseline = [
  { wave: '01', name: 'namespaces', namespace: 'default' },
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
];

// Re-track bootstrap resources
local bootstrap = [
  { wave: '20', name: 'argocd', namespace: 'argocd' },
  { wave: '20', name: 'argocd-bootstrap', namespace: 'argocd', helm: { parameters: [{ name: 'targetRevision', value: revision }] } },
  { wave: '20', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '20', name: 'onepassword-connect', namespace: 'onepassword' },
];

local connectivity = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '01', name: 'istio-base', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.connectivity.istioBase },
  { wave: '01', name: 'metallb', namespace: 'metallb-system' },
  { wave: '02', name: 'istiod', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.connectivity.istiod },
  { wave: '03', name: 'istio-ingress', namespace: 'istio-ingress' },
  { wave: '03', name: 'istio-ingress-internal', namespace: 'istio-ingress-internal', path: 'helm-charts/istio-ingress', helm: { valueFiles: ['value/istio-ingress-internal.yaml'] } },
  { wave: '04', name: 'istio-ingress-routes', namespace: 'istio-ingress' },
  { wave: '10', name: 'httpbin', namespace: 'httpbin' },
];

local monitoring = [
  { wave: '03', name: 'kiali', namespace: 'istio-system' },
  { wave: '10', name: 'healthcheck-io', namespace: 'istio-ingress' },
];

local scheduling = [
  { wave: '02', name: 'descheduler', namespace: 'descheduler' },
  { wave: '02', name: 'keda', namespace: 'keda', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.scheduling.keda },
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
