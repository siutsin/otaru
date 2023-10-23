local ArgoApp = import 'lib/application.libsonnet';

local ignoreDifferences = {
  application: {
    adguardHome: [{
      group: '*',
      kind: 'ConfigMap',
      name: 'adguard-home-configmap',
      jqPathExpressions: ['.data'],
    }],
  },
  connectivity: {
    istioBase: [{
      group: 'admissionregistration.k8s.io',
      kind: 'ValidatingWebhookConfiguration',
      name: 'istiod-default-validator',
      jqPathExpressions: ['.webhooks[].failurePolicy'],
    }],
    istiod: [{
      group: 'apps',
      kind: 'Deployment',
      name: 'istiod',
      jqPathExpressions: ['.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor'],
    }],
  },
};

local application = [
  { wave: '10', name: 'adguard-home', namespace: 'adguard-home', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: ignoreDifferences.application.adguardHome },
  { wave: '10', name: 'jellyfin', namespace: 'jellyfin' },
];

local baseline = [
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
];

local connectivity = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '01', name: 'istio-base', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: ignoreDifferences.connectivity.istioBase },
  { wave: '01', name: 'metallb', namespace: 'metallb-system' },
  { wave: '02', name: 'istiod', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: ignoreDifferences.connectivity.istiod },
  { wave: '03', name: 'istio-ingress', namespace: 'istio-ingress' },
  { wave: '03', name: 'istio-ingress-internal', namespace: 'istio-ingress-internal', path: 'helm-charts/istio-ingress', helm: { valueFiles: ['value/istio-ingress-internal.yaml'] } },
  { wave: '10', name: 'httpbin', namespace: 'httpbin' },
];

local monitoring = [
  { wave: '03', name: 'kiali', namespace: 'istio-system' },
  { wave: '10', name: 'healthcheck-io', namespace: 'istio-ingress' },
];

local security = [
  { wave: '01', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '02', name: 'cert-manager', namespace: 'cert-manager' },
];

local storage = [
  { wave: '04', name: 'longhorn', namespace: 'longhorn-system' },
];

[
  ArgoApp(appConfig).render
  for appConfig in application + baseline + connectivity + monitoring + security + storage
]
