// Per-application Helm overrides for the applications in
// manifest.jsonnet: parameters, extra value files and values objects
// that the default chart source cannot express on its own.

// Memory limit: 2026-10-10: 30d spike ~116.8Mi vs 128Mi limit (91.3% - OOM risk); limit -> 141Mi (ceil(spike*1.2)). Request stays 128Mi.
local cnpg = {
  releaseName: 'cloudnative-pg',
  valuesObject: {
    podLabels: { 'istio.io/dataplane-mode': 'none' },
    resources: {
      requests: { cpu: '100m', memory: '128Mi', 'ephemeral-storage': '128Mi' },
      limits: { memory: '141Mi', 'ephemeral-storage': '128Mi' },
    },
  },
};

local cnpgClusters = { parameters: [
  { name: 'backup.b2.bucket', value: std.extVar('CNPG_BACKUP_BUCKET') },
  { name: 'backup.b2.endpoint', value: std.extVar('CNPG_BACKUP_ENDPOINT') },
] };

local grafanaDashboards = [
  'dashboards/blocky.yaml',
  'dashboards/container-log-dashboard.yaml',
  'dashboards/jung2bot.yaml',
  'dashboards/kyverno-policy-metrics.yaml',
  'dashboards/onzack-cluster-monitoring.yaml',
  'dashboards/prometheus-stats.yaml',
  'dashboards/vpa.yaml',
];

local homeAssistantVolume = { parameters: [{ name: 'longhorn-volume-lib.volumes.home-assistant-config.fromBackup', value: std.extVar('HOME_ASSISTANT_VOLUME_FROM_BACKUP') }] };

local jung2bot = { parameters: [{ name: 'irsa.awsAccountId', value: std.extVar('AWS_ACCOUNT_ID') }] };

local keda = {
  valuesObject: {
    keda: {
      serviceAccount: {
        operator: {
          annotations: { 'eks.amazonaws.com/role-arn': 'arn:aws:iam::' + std.extVar('AWS_ACCOUNT_ID') + ':role/keda' },
        },
      },
    },
  },
};

local longhorn = { parameters: [{ name: 'longhorn.defaultBackupStore.backupTarget', value: std.extVar('LONGHORN_BACKUP_TARGET') }] };

local monitoring = { parameters: [{ name: 'yace.irsa.awsAccountId', value: std.extVar('AWS_ACCOUNT_ID') }], valueFiles: grafanaDashboards };

// CPU limit: 2026-10-18: null removes the subchart default CPU limit; the house rule sets no CPU limits.
local trivyOperator = { valuesObject: { 'trivy-operator': { trivy: { server: { resources: { limits: { cpu: null } } } } } } };

{
  cnpg: cnpg,
  cnpgClusters: cnpgClusters,
  homeAssistantVolume: homeAssistantVolume,
  jung2bot: jung2bot,
  keda: keda,
  longhorn: longhorn,
  monitoring: monitoring,
  trivyOperator: trivyOperator,
}
