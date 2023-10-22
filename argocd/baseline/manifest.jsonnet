local application = import '../_lib/application.libsonnet';

local applications = [
  { wave: '02', name: 'argocd-config.yaml' },
];

[
  application(a).render
  for a in applications
]
