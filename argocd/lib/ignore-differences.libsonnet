// ignoreDifferences sets for the applications in manifest.jsonnet.
// Each entry hides a named divergence between the rendered manifest and
// the live object: fields the API, a controller or an operator defaults
// or writes after apply, which never appear in the rendered manifest.

local divisorJqPath = '.spec.template.spec.containers[].env[].valueFrom.resourceFieldRef.divisor';

// The live Deployment stores a divisor on its resourceFieldRef env
// entries; the rendered chart manifest omits it.
local resourceFieldRefDivisor(name) = [{
  group: 'apps',
  kind: 'Deployment',
  name: name,
  jqPathExpressions: [divisorJqPath],
}];

// Istiod writes the CA bundle into its webhook configurations at
// runtime, and the API defaults failurePolicy.
local webhookCaBundleAndFailurePolicy(name) = [{
  group: 'admissionregistration.k8s.io',
  kind: 'ValidatingWebhookConfiguration',
  name: name,
  jqPathExpressions: [
    '.webhooks[]?.clientConfig.caBundle',
    '.webhooks[]?.failurePolicy',
  ],
}];

// The webhook certificate controller injects the CA bundle into the
// CRD conversion webhook configuration after apply.
local crdConversionCABundle(name) = [{
  group: 'apiextensions.k8s.io',
  kind: 'CustomResourceDefinition',
  name: name,
  jsonPointers: [
    '/spec/conversion/webhook/clientConfig/caBundle',
  ],
}];

// Kyverno defaults these on the live ClusterPolicy at admission time.
local kyvernoClusterPolicyApiCallDefaults(policyNames) = [
  {
    group: 'kyverno.io',
    kind: 'ClusterPolicy',
    name: policyName,
    jqPathExpressions: [
      '.spec.rules[].context[]?.apiCall?.method',
      '.spec.rules[].skipBackgroundRequests',
    ],
  }
  for policyName in policyNames
];

// Fields the API defaults on the live Kyverno policy CRDs.
// Re-check this list against rendered Kyverno CRDs when bumping the kyverno chart.
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

// alertmanager subchart + ServerSideApply: kube defaults and subPath: null differ from rendered manifest.
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

// zot subchart + ServerSideApply: kube defaults, the null pod-template
// annotations and the reloader env entry differ from the rendered manifest.
// The workload takes its whole config from the mounted Secret, so the only
// env entry is the one reloader injects.
local zotStatefulsetSsaDefaults = [{
  group: 'apps',
  kind: 'StatefulSet',
  name: 'zot',
  namespace: 'zot',
  jqPathExpressions: [
    '.spec.persistentVolumeClaimRetentionPolicy',
    '.spec.podManagementPolicy',
    '.spec.revisionHistoryLimit',
    '.spec.updateStrategy',
    '.spec.template.metadata.annotations',
    '.spec.template.spec.containers[].env',
    '.spec.template.spec.containers[].livenessProbe.failureThreshold',
    '.spec.template.spec.containers[].livenessProbe.periodSeconds',
    '.spec.template.spec.containers[].livenessProbe.successThreshold',
    '.spec.template.spec.containers[].livenessProbe.timeoutSeconds',
    '.spec.template.spec.containers[].readinessProbe.failureThreshold',
    '.spec.template.spec.containers[].readinessProbe.periodSeconds',
    '.spec.template.spec.containers[].readinessProbe.successThreshold',
    '.spec.template.spec.containers[].readinessProbe.timeoutSeconds',
    '.spec.template.spec.containers[].startupProbe.successThreshold',
    '.spec.template.spec.containers[].startupProbe.timeoutSeconds',
    '.spec.template.spec.containers[].terminationMessagePath',
    '.spec.template.spec.containers[].terminationMessagePolicy',
    '.spec.template.spec.restartPolicy',
    '.spec.template.spec.schedulerName',
    '.spec.template.spec.serviceAccount',
    '.spec.template.spec.terminationGracePeriodSeconds',
    '.spec.template.spec.volumes[].secret.defaultMode',
    '.spec.volumeClaimTemplates[]?.apiVersion',
    '.spec.volumeClaimTemplates[]?.kind',
    '.spec.volumeClaimTemplates[]?.spec.volumeMode',
    '.spec.volumeClaimTemplates[]?.status',
  ],
}];

// The CNPG operator defaults and annotates the Cluster objects it manages.
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

{
  zotStatefulsetSsaDefaults: zotStatefulsetSsaDefaults,
  cnpgClusterOperatorDefaults: cnpgClusterOperatorDefaults,

  // Per-application sets, grouped by the domain of the application list
  // that uses them.
  entries: {
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
      alertmanager: alertmanagerSsaDefaults,
    },
    security: {
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
      'kyverno-policy': kyvernoClusterPolicyApiCallDefaults([
        'require-pod-disruption-budget',
      ]),
    },
    connectivity: {
      // The API and the controller default these on the live EnvoyProxy;
      // they never appear in the rendered chart manifest.
      'envoy-gateway': [{
        group: 'gateway.envoyproxy.io',
        kind: 'EnvoyProxy',
        name: 'gateway',
        namespace: 'gateway',
        jqPathExpressions: [
          '.spec.logging.level.default',
          '.spec.provider.kubernetes.envoyService.externalTrafficPolicy',
          '.spec.provider.kubernetes.envoyService.type',
          '.spec.telemetry.tracing.provider.backendRefs[].weight',
          '.spec.telemetry.tracing.provider.port',
          '.spec.telemetry.tracing.provider.type',
        ],
      }],
    },
  },
}
