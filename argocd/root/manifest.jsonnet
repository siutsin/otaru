local application = import '../_lib/application.libsonnet';

local applications = [
  { name: 'application' },
  { name: 'baseline' },
  { name: 'connectivity' },
  { name: 'monitoring' },
  { name: 'security' },
  { name: 'storage' },
];

[
  application(a).render
  for a in applications
]
