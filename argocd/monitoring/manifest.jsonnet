local application = import '../_lib/application.libsonnet';

local applications = [
  { wave: '03', name: 'kiali', namespace: 'istio-system' },
  { wave: '10', name: 'healthcheck-io', namespace: 'istio-ingress' },
];

[
  application(a).render
  for a in applications
]
