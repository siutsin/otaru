local application = import '../_lib/application.libsonnet';

local applications = [
  { name: 'application', path: 'argocd/application' },
  { name: 'baseline', path: 'argocd/baseline' },
  { name: 'connectivity', path: 'argocd/connectivity' },
  { name: 'monitoring', path: 'argocd/monitoring' },
  { name: 'security', path: 'argocd/security' },
  { name: 'storage', path: 'argocd/storage' },
];

[
  application(a).render
  for a in applications
]
