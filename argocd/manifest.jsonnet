local ArgoCDApplication = import 'lib/argocd-application.libsonnet';

local revision = 'HEAD';

local divisorJqPath = '.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor';
local resourceFieldRefDivisor(name) = [{
  group: 'apps',
  kind: 'Deployment',
  name: name,
  jqPathExpressions: [divisorJqPath],
}];

local webhookCaBundleAndFailurePolicy(name) = [{
  group: 'admissionregistration.k8s.io',
  kind: 'ValidatingWebhookConfiguration',
  name: name,
  jqPathExpressions: [
    '.webhooks[]?.clientConfig.caBundle',
    '.webhooks[]?.failurePolicy',
  ],
}];

local crdConversionCABundle(name) = [{
  group: 'apiextensions.k8s.io',
  kind: 'CustomResourceDefinition',
  name: name,
  jsonPointers: [
    '/spec/conversion/webhook/clientConfig/caBundle',
  ],
}];

local kyvernoDefaultedCrdFields(crdNames) = [
  {
    group: 'apiextensions.k8s.io',
    kind: 'CustomResourceDefinition',
    name: crdName,
    jsonPointers: [
      '/spec/conversion',
    ],
    jqPathExpressions: [
      '.metadata.annotations | select(. == {})',
      '.metadata.labels | select(. == {})',
    ],
  }
  for crdName in crdNames
];

local cleanerExcludeDeleted = [{
  group: 'apps.projectsveltos.io',
  kind: 'Cleaner',
  jqPathExpressions: ['.spec.resourcePolicySet.resourceSelectors[].excludeDeleted'],
}];

local alertmanagerSsaDefaults = [{
  group: 'apps',
  kind: 'StatefulSet',
  name: 'monitoring-alertmanager',
  namespace: 'monitoring',
  jqPathExpressions: [
    '.spec.minReadySeconds',
    '.spec.persistentVolumeClaimRetentionPolicy',
    '.spec.podManagementPolicy',
    '.spec.updateStrategy',
    '.spec.volumeClaimTemplates[]?.status',
    '.spec.template.spec.containers[].volumeMounts[]?.subPath',
    '.spec.template.spec.containers[].livenessProbe.failureThreshold',
    '.spec.template.spec.containers[].livenessProbe.periodSeconds',
    '.spec.template.spec.containers[].livenessProbe.successThreshold',
    '.spec.template.spec.containers[].livenessProbe.timeoutSeconds',
    '.spec.template.spec.containers[].livenessProbe.httpGet.scheme',
    '.spec.template.spec.containers[].readinessProbe.failureThreshold',
    '.spec.template.spec.containers[].readinessProbe.periodSeconds',
    '.spec.template.spec.containers[].readinessProbe.successThreshold',
    '.spec.template.spec.containers[].readinessProbe.timeoutSeconds',
    '.spec.template.spec.containers[].readinessProbe.httpGet.scheme',
    '.spec.template.spec.containers[].terminationMessagePath',
    '.spec.template.spec.containers[].terminationMessagePolicy',
    '.spec.template.spec.dnsPolicy',
    '.spec.template.spec.restartPolicy',
    '.spec.template.spec.schedulerName',
    '.spec.template.spec.terminationGracePeriodSeconds',
    '.spec.template.spec.serviceAccount',
    '.spec.template.spec.volumes[].secret.defaultMode',
    '.spec.volumeClaimTemplates[]?.apiVersion',
    '.spec.volumeClaimTemplates[]?.kind',
    '.spec.volumeClaimTemplates[]?.spec.volumeMode',
  ],
}];

local cnpgClusterOperatorDefaults = [{
  group: 'postgresql.cnpg.io',
  kind: 'Cluster',
  jqPathExpressions: [
    '.metadata.annotations["kubectl.kubernetes.io/restartedAt"]',
    '.metadata.annotations["cnpg.io/reloadedAt"]',
    '.spec.bootstrap.initdb.encoding',
    '.spec.bootstrap.initdb.localeCType',
    '.spec.bootstrap.initdb.localeCollate',
    '.spec.managed.roles[].inherit',
    '.spec.probes',
    '.spec.storage.resizeInUseVolumes',
  ],
}];

local _ignoreDifferences = {
  bootstrap: {
    metallb: crdConversionCABundle('bgppeers.metallb.io'),
  },
  scheduling: {
    'k8s-cleaner': resourceFieldRefDivisor('k8s-cleaner') + cleanerExcludeDeleted,
    reloader: resourceFieldRefDivisor('reloader-reloader'),
  },
  serviceMesh: {
    'istio-base': webhookCaBundleAndFailurePolicy('istiod-default-validator'),
    istiod: webhookCaBundleAndFailurePolicy('istio-validator-istio-system'),
  },
  monitoring: {
    // alertmanager subchart + ServerSideApply: kube defaults and subPath: null differ from rendered manifest.
    alertmanager: alertmanagerSsaDefaults,
  },
  security: {
    // Re-check this list against rendered Kyverno CRDs when bumping the kyverno chart.
    kyverno: kyvernoDefaultedCrdFields([
      'deletingpolicies.policies.kyverno.io',
      'generatingpolicies.policies.kyverno.io',
      'imagevalidatingpolicies.policies.kyverno.io',
      'mutatingpolicies.policies.kyverno.io',
      'namespaceddeletingpolicies.policies.kyverno.io',
      'namespacedgeneratingpolicies.policies.kyverno.io',
      'namespacedimagevalidatingpolicies.policies.kyverno.io',
      'namespacedmutatingpolicies.policies.kyverno.io',
      'namespacedvalidatingpolicies.policies.kyverno.io',
      'policyexceptions.policies.kyverno.io',
      'validatingpolicies.policies.kyverno.io',
    ]),
  },
};

local _grafanaDashboards = [
  'dashboards/blocky.yaml',
  'dashboards/container-log-dashboard.yaml',
  'dashboards/onzack-cluster-monitoring.yaml',
  'dashboards/prometheus-stats.yaml',
];

local jung2botHelm = { parameters: [{ name: 'irsa.awsAccountId', value: std.extVar('AWS_ACCOUNT_ID') }] };
local cnpgHelm = {
  releaseName: 'cloudnative-pg',
  valuesObject: {
    podLabels: {
      'istio.io/dataplane-mode': 'none',
    },
    resources: {
      requests: {
        cpu: '100m',
        memory: '128Mi',
        'ephemeral-storage': '128Mi',
      },
      limits: {
        memory: '128Mi',
        'ephemeral-storage': '128Mi',
      },
    },
  },
};
local cnpgClustersHelm = { parameters: [
  { name: 'backup.b2.bucket', value: std.extVar('CNPG_BACKUP_BUCKET') },
  { name: 'backup.b2.endpoint', value: std.extVar('CNPG_BACKUP_ENDPOINT') },
] };
local longhornHelm = { parameters: [{ name: 'longhorn.defaultBackupStore.backupTarget', value: std.extVar('LONGHORN_BACKUP_TARGET') }] };
local homeAssistantVolumeHelm = { parameters: [{ name: 'longhorn-volume-lib.volumes.home-assistant-config.fromBackup', value: std.extVar('HOME_ASSISTANT_VOLUME_FROM_BACKUP') }] };
local openClawHelm = { parameters: [{ name: 'route.hostname', value: std.extVar('OPENCLAW_CONTROL_UI_HOSTNAME') }] };
local application = [
  { wave: '10', name: 'blocky', namespace: 'blocky' },
  { wave: '10', name: 'changedetection-volume', namespace: 'changedetection' },
  { wave: '10', name: 'cyberchef', namespace: 'cyberchef' },
  { wave: '10', name: 'excalidraw', namespace: 'excalidraw' },
  { wave: '10', name: 'home-assistant-volume', namespace: 'home-assistant', helm: homeAssistantVolumeHelm },
  { wave: '10', name: 'jsoncrack', namespace: 'jsoncrack' },
  { wave: '10', name: 'kubernetes-mcp-server', namespace: 'kubernetes-mcp-server' },
  { wave: '10', name: 'openclaw-volume', namespace: 'openclaw' },
  { wave: '11', name: 'openclaw', namespace: 'openclaw', helm: openClawHelm },
  { wave: '10', name: 'teslamate', namespace: 'teslamate' },
  { wave: '10', name: 'umami', namespace: 'umami' },
  { wave: '11', name: 'changedetection', namespace: 'changedetection' },
  { wave: '11', name: 'home-assistant', namespace: 'home-assistant' },
  { wave: '30', name: 'jung2bot', namespace: 'jung2bot', path: 'helm-charts/jung2bot', helm: jung2botHelm },
  { wave: '30', name: 'jung2bot-dev', namespace: 'jung2bot-dev', path: 'helm-charts/jung2bot', helm: jung2botHelm { valueFiles: ['value/dev.yaml'] } },
];

local baseline = [
  { wave: '01', name: 'coredns', namespace: 'kube-system' },
  { wave: '02', name: 'argocd-config', namespace: 'argocd' },
];

// Re-track bootstrap resources
local bootstrap = [
  { wave: '20', name: 'namespaces', namespace: 'argocd' },
  { wave: '20', name: 'argocd', namespace: 'argocd' },
  { wave: '20', name: 'argocd-bootstrap', namespace: 'argocd', helm: { parameters: [{ name: 'targetRevision', value: revision }] } },
  // Known issue: syncing this app reproducibly fails to apply the
  // clustersecretstores/secretstores CRDs ("metadata.annotations: Too long").
  // ServerSideApply=true (already the default below), ServerSideDiff=true,
  // Replace=true, and helm.skipCrds were all tried live and none fixed it --
  // see documentation/gotcha.md for what was tried and why disabling CRD
  // creation via chart values is not a safe option (it would stop the
  // operator processing the ClusterSecretStore every ExternalSecret in this
  // cluster depends on). No live impact: the CRDs themselves stay healthy
  // and Synced; only ArgoCD's own sync attempt for these two fails.
  { wave: '20', name: 'external-secrets', namespace: 'external-secrets' },
  { wave: '20', name: 'gateway-api', namespace: 'kube-system' },
  { wave: '20', name: 'k3s-apiserver-loadbalancer', namespace: 'k3s-apiserver-loadbalancer-system' },
  { wave: '20', name: 'metallb', namespace: 'metallb-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.bootstrap.metallb },
  { wave: '20', name: 'onepassword-connect', namespace: 'onepassword' },
  // Keep the Argo CD Application name stable during the chart rename so the
  // old app finalizer does not prune the live Kubernetes API VIP resources.
  { wave: '21', name: 'gateway-api-kubernetes', namespace: 'default', path: 'helm-charts/metallb-vip', helm: { releaseName: 'metallb-vip' } },
];

local connectivity = [
  { wave: '01', name: 'cloudflare-tunnel', namespace: 'cloudflare-tunnel' },
  { wave: '02', name: 'envoy-gateway', namespace: 'envoy-gateway-system', helm: { skipCrds: true } },
  { wave: '10', name: 'httpbin', namespace: 'httpbin' },
];

local database = [
  // https://github.com/cloudnative-pg/charts/issues/344
  // Apply the chart directly to generate webhook and TLS certs
  {
    local s = self,
    wave: '03',
    name: 'cloudnative-pg',
    namespace: 'cnpg-system',
    source: {
      repoURL: 'https://cloudnative-pg.io/charts/',
      chart: s.name,
      targetRevision: '0.28.2',
      helm: cnpgHelm,
    },
  },
  { wave: '04', name: 'cloudnative-pg-plugin-barman-cloud', namespace: 'cnpg-system' },
  {
    wave: '06',
    name: 'cloudnative-pg-clusters',
    namespace: 'cnpg-system',
    helm: cnpgClustersHelm,
    syncOptions: ['RespectIgnoreDifferences=true'],
    ignoreDifferences: cnpgClusterOperatorDefaults,
  },
];

local monitoring = [
  { wave: '05', name: 'heartbeats', namespace: 'heartbeats-operator-system' },
  { wave: '05', name: 'kiali', namespace: 'kiali' },
  { wave: '10', name: 'metrics-server', namespace: 'monitoring' },
  {
    wave: '10',
    name: 'monitoring',
    namespace: 'monitoring',
    helm: { valueFiles: _grafanaDashboards },
    serverSideDiff: 'true',
    syncOptions: ['RespectIgnoreDifferences=true'],
    ignoreDifferences: _ignoreDifferences.monitoring.alertmanager,
  },
];

local scheduling = [
  { wave: '02', name: 'descheduler', namespace: 'descheduler' },
  { wave: '02', name: 'k8s-cleaner', namespace: 'k8s-cleaner', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.scheduling['k8s-cleaner'] },
  { wave: '02', name: 'keda', namespace: 'keda' },
  { wave: '02', name: 'reloader', namespace: 'reloader', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.scheduling.reloader },
];

local security = [
  { wave: '02', name: 'cert-manager', namespace: 'cert-manager' },
  { wave: '03', name: 'kyverno', namespace: 'kyverno', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.security.kyverno },
  { wave: '04', name: 'kyverno-policy', namespace: 'kyverno' },
  { wave: '10', name: 'oidc-provider', namespace: 'default' },
  { wave: '20', name: 'amazon-eks-pod-identity-webhook', namespace: 'default' },
];

local storage = [
  { wave: '04', name: 'longhorn', namespace: 'longhorn-system', helm: longhornHelm },
  { wave: '05', name: 'longhorn-config', namespace: 'longhorn-system' },
];

local serviceMesh = [
  { wave: '03', name: 'istio-base', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.serviceMesh['istio-base'] },
  { wave: '03', name: 'istio-cni', namespace: 'kube-system' },
  { wave: '04', name: 'istiod', namespace: 'istio-system', syncOptions: ['RespectIgnoreDifferences=true'], ignoreDifferences: _ignoreDifferences.serviceMesh.istiod },
  { wave: '05', name: 'ztunnel', namespace: 'istio-system' },
  { wave: '06', name: 'waypoints', namespace: 'argocd' },
];

[
  ArgoCDApplication.new(appConfig, revision)
  for appConfig in application + baseline + bootstrap + connectivity + database + monitoring + scheduling + security + serviceMesh + storage
]
