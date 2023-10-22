local application = import '../_lib/application.libsonnet';

local applications = [
  { wave: '01', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '02', name: 'cert-manager', namespace: 'cert-manager' },
];

[
  application(a).render
  for a in applications
]
