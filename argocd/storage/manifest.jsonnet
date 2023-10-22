local application = import '../_lib/application.libsonnet';

local applications = [
  { wave: '04', name: 'longhorn', namespace: 'longhorn-system' },
];

[
  application(a).render
  for a in applications
]
