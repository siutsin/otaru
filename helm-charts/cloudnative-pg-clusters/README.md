# cloudnative-pg-clusters

Configures and manages multiple CloudNativePG clusters with ObjectStore resource for PostgreSQL backups to Backblaze B2 using the plugin-barman-cloud.

## Prerequisites

- CloudNativePG operator installed in the cluster
- `cloudnative-pg-plugin-barman-cloud` chart deployed
- 1Password Connect configured with External Secrets Operator
- Backblaze B2 credentials stored in 1Password

## Configuration

### Default Values

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
      isWALArchiver: false  # Disabled to reduce costs
      parameters:
        barmanObjectName: "b2-backup"
    backup:
      retentionPolicy: "2d"
  scheduledBackup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
```

### Cluster Configuration

Define your clusters in `values.yaml` under the `clusters` object:

```yaml
clusters:
  example-db:
    bootstrap:
      initdb:
        database: "example"
        owner: "example"
        secret:
          name: "example-app"

  production-db:
    instances: 3
    storage:
      size: "10Gi"
    backup:
      retentionPolicy: "7d"
    bootstrap:
      initdb:
        database: "production"
        owner: "app"
        secret:
          name: "production-app"

  restored-db:
    bootstrap:
      recovery:
        source: "production-db"
        backup:
          name: "production-db-backup-2024-01-15"
```

## Installation

```bash
helm install cloudnative-pg-clusters ./helm-charts/cloudnative-pg-clusters/
```

## WAL Configuration

This chart is configured to minimise WAL (Write-Ahead Logging) costs:

- **WAL Archiving**: Disabled (`isWALArchiver: false`) to reduce storage costs
- **WAL Level**: Set to `minimal` to reduce logging overhead
- **WAL Retention**: Reduced to 256MB for both `max_slot_wal_keep_size` and `wal_keep_size`
- **Checkpoint Timeout**: Increased to 30 minutes to reduce checkpoint frequency
- **Max WAL Size**: Reduced to 2GB to minimise storage usage

These settings prioritise cost reduction over advanced recovery capabilities. For production environments requiring point-in-time recovery, consider re-enabling WAL archiving.

## Generated Resources

For each cluster, the chart generates:

- PostgreSQL Cluster
- Scheduled Backup (if enabled)
- External Secret for B2 credentials
- ObjectStore for B2 backup configuration
