local application = import '../_lib/application.libsonnet';

local applications = [
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
];

[
  application(a).render
  for a in applications
]
