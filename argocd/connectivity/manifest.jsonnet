local application = import '../_lib/application.libsonnet';

local istioBaseIgnoreDifferences = [{
  group: 'admissionregistration.k8s.io',
  kind: 'ValidatingWebhookConfiguration',
  name: 'istiod-default-validator',
  jqPathExpressions: ['.webhooks[].failurePolicy'],
}];

local istiodIgnoreDifferences = [{
  group: 'apps',
  kind: 'Deployment',
  name: 'istiod',
  jqPathExpressions: ['.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor'],
}];

local applications = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '01', name: 'istio-base', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: istioBaseIgnoreDifferences },
  { wave: '01', name: 'metallb', namespace: 'metallb-system' },
  { wave: '02', name: 'istiod', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: istiodIgnoreDifferences },
  { wave: '03', name: 'istio-ingress', namespace: 'istio-ingress' },
  { wave: '03', name: 'istio-ingress-internal', namespace: 'istio-ingress-internal', path: 'helm-charts/istio-ingress', helm: { valueFiles: ['value/istio-ingress-internal.yaml'] } },
  { wave: '10', name: 'httpbin', namespace: 'httpbin' },
];

[
  application(a).render
  for a in applications
]
