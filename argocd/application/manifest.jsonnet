local application = import '../_lib/application.libsonnet';

local adguardHomeIgnoreDifferences = [{
  group: '*',
  kind: 'ConfigMap',
  name: 'adguard-home-configmap',
  jqPathExpressions: ['.data'],
}];

local applications = [
  { wave: '10', name: 'adguard-home', namespace: 'adguard-home', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: adguardHomeIgnoreDifferences },
  { wave: '10', name: 'jellyfin', namespace: 'jellyfin' },
];

[
  application(a).render
  for a in applications
]
