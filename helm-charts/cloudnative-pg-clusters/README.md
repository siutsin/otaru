# cloudnative-pg-clusters

Configures and manages multiple CloudNativePG clusters with ObjectStore resource for PostgreSQL backups to Backblaze B2 using the plugin-barman-cloud.

## Overview

This Helm chart provides a flexible way to manage multiple PostgreSQL clusters using CloudNativePG. It includes:

- **Multiple cluster support** - Configure and manage multiple PostgreSQL clusters from a single chart
- **B2 backup integration** - Automatic backup to Backblaze B2 using the Barman Cloud plugin
- **Scheduled backups** - Configurable scheduled backups with retention policies
- **Secret management** - Integration with 1Password via External Secrets Operator
- **Flexible configuration** - Each cluster can have custom settings or inherit sensible defaults

## Prerequisites

- CloudNativePG operator installed in the cluster
- `cloudnative-pg-plugin-barman-cloud` chart deployed
- 1Password Connect configured with External Secrets Operator
- Backblaze B2 credentials stored in 1Password

## Configuration

### Default Values

The chart provides sensible defaults for common settings:

```yaml
defaults:
  cluster:
    instances: 2
    storage:
      size: "1Gi"
      storageClass: "longhorn-crypto-global"
    plugins:
    - enabled: true
      name: "barman-cloud.cloudnative-pg.io"
      isWALArchiver: true
      parameters:
        barmanObjectName: "b2-backup"
    backup:
      retentionPolicy: "2d"
  scheduledBackup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
```

### Cluster Configuration

Define your clusters in `values.yaml` under the `clusters` object. Each key is the cluster name, and the value is the configuration for that cluster.

#### Basic Example

```yaml
clusters:
  example-db:
    bootstrap:
      initdb:
        database: "example"
        owner: "example"
        secret:
          name: "example-app"
```

This cluster will inherit all default settings for storage, plugins, and backup configuration.

#### Advanced Example

```yaml
clusters:
  production-db:
    instances: 3
    storage:
      size: "10Gi"
      storageClass: "longhorn-crypto-global"
    plugins:
      - enabled: true
        name: "barman-cloud.cloudnative-pg.io"
        isWALArchiver: true
        parameters:
          barmanObjectName: "b2-backup"
    backup:
      retentionPolicy: "7d"
    scheduledBackup:
      enabled: true
      schedule: "0 1 * * *"  # Daily at 1 AM
    bootstrap:
      initdb:
        database: "production"
        owner: "app"
        secret:
          name: "production-app"
  
  staging-db:
    instances: 1
    storage:
      size: "5Gi"
    scheduledBackup:
      enabled: false  # Disable scheduled backups for staging
    bootstrap:
      initdb:
        database: "staging"
        owner: "app"
        secret:
          name: "staging-app"
```

## Generated Resources

For each cluster configuration, the chart generates:

1. **PostgreSQL Cluster** - The main CloudNativePG cluster resource
2. **Scheduled Backup** - Automatic backup job (if enabled)
3. **External Secret** - B2 backup credentials from 1Password
4. **ObjectStore** - B2 backup configuration

### Resource Naming

- **Cluster**: Uses the cluster name from configuration
- **Scheduled Backup**: `{cluster-name}-scheduled-backup`
- **External Secret**: `b2-backup-credentials` (shared across all clusters)
- **ObjectStore**: `b2-backup` (shared across all clusters)

## Backup Configuration

### B2 ObjectStore

The chart creates a shared B2 ObjectStore resource configured for:

- **Endpoint**: `https://s3.eu-central-003.backblazeb2.com`
- **Bucket**: `github-otaru-cloudnative-pg-backup`
- **Path**: `cnpg-backups/`
- **Credentials**: Retrieved from 1Password via External Secrets

### Scheduled Backups

Each cluster can have its own scheduled backup configuration:

```yaml
scheduledBackup:
  enabled: true
  schedule: "0 2 * * *"  # Cron format
```

If `scheduledBackup` is not specified, the cluster will use the default configuration.

**Note**: Retention policy is configured at the cluster level (`spec.backup.retentionPolicy`) and applies to all backups, including those created by scheduled backups.

## Values Reference

| Parameter                                 | Type   | Default                                       | Description                            |
|-------------------------------------------|--------|-----------------------------------------------|----------------------------------------|
| `name`                                    | string | `"cloudnative-pg-clusters"`                   | Chart name                             |
| `namespace`                               | string | `"cnpg-system"`                               | Namespace for all resources            |
| `backup.b2.bucket`                        | string | `"github-otaru-cloudnative-pg-backup"`        | B2 bucket name                         |
| `backup.b2.endpoint`                      | string | `"https://s3.eu-central-003.backblazeb2.com"` | B2 endpoint URL                        |
| `defaults.cluster.instances`              | int    | `2`                                           | Default number of PostgreSQL instances |
| `defaults.cluster.storage.size`           | string | `"1Gi"`                                       | Default storage size                   |
| `defaults.cluster.storage.storageClass`   | string | `"longhorn-crypto-global"`                    | Default storage class                  |
| `defaults.cluster.backup.retentionPolicy` | string | `"2d"`                                        | Default backup retention               |
| `defaults.scheduledBackup.enabled`        | bool   | `true`                                        | Enable scheduled backups by default    |
| `defaults.scheduledBackup.schedule`       | string | `"0 2 * * *"`                                 | Default backup schedule                |

| `clusters` | object | `{}` | Cluster configurations |

### Cluster Configuration Options

Each cluster can override any default setting:

| Parameter                  | Type   | Description                    |
|----------------------------|--------|--------------------------------|
| `instances`                | int    | Number of PostgreSQL instances |
| `storage.size`             | string | Storage size                   |
| `storage.storageClass`     | string | Storage class                  |
| `plugins`                  | array  | Plugin configurations          |
| `backup.retentionPolicy`   | string | Backup retention policy        |
| `scheduledBackup.enabled`  | bool   | Enable scheduled backups       |
| `scheduledBackup.schedule` | string | Backup schedule (cron format)  |
| `bootstrap`                | object | Initial database setup         |

## Installation

1. Ensure prerequisites are met
2. Configure your clusters in `values.yaml`
3. Install the chart:

```bash
helm install cloudnative-pg-clusters ./helm-charts/cloudnative-pg-clusters/
```

## Dependencies

This chart depends on:

- `cloudnative-pg-plugin-barman-cloud` chart (deployed separately)
- CloudNativePG operator
- External Secrets Operator
- 1Password Connect

## Testing Backup Functionality

### Manual Backup Test

Create a manual backup to test the backup system:

```bash
kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: test-backup-manual
  namespace: cnpg-system
spec:
  cluster:
    name: example-db
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
EOF
```

### Monitor Backup Status

```bash
# Check backup status
kubectl get backups.postgresql.cnpg.io -n cnpg-system

# Check scheduled backups
kubectl get scheduledbackups.postgresql.cnpg.io -n cnpg-system

# Check cluster status
kubectl get clusters -n cnpg-system
```

### Verify Backup Data

```bash
# Check backup details
kubectl get backups.postgresql.cnpg.io test-backup-manual -n cnpg-system -o yaml

# Check ObjectStore configuration
kubectl get objectstore -n cnpg-system
```

## Troubleshooting

### Common Issues

1. **Backup failures**: Check that B2 credentials are correctly stored in 1Password
2. **Storage issues**: Verify the specified storage class exists
3. **Plugin errors**: Ensure the Barman Cloud plugin is installed
4. **Racing conditions**: The ExternalSecret has Reloader annotations to prevent racing issues

### Verification

Check cluster status:

```bash
kubectl get clusters -n cnpg-system
```

Check backup status:

```bash
kubectl get scheduledbackups -n cnpg-system
```

Check ObjectStore:

```bash
kubectl get objectstore -n cnpg-system
```

Check ExternalSecret:

```bash
kubectl get externalsecret -n cnpg-system
```
