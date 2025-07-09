# cloudnative-pg-plugin-barman-cloud

A Helm chart for deploying the Barman Cloud plugin for CloudNativePG.

This chart installs the Barman Cloud plugin, which enables backup and WAL archiving to object storage (such as Backblaze B2, S3, MinIO, etc.)
for CloudNativePG clusters.

## Usage

Install this chart in the same namespace as your CloudNativePG operator and clusters. Reference the plugin in your CloudNativePG cluster manifests
using the `barman-cloud.cloudnative-pg.io` plugin name.

For more information, see the
[CloudNativePG Barman Cloud Plugin documentation](https://cloudnative-pg.io/plugin-barman-cloud/docs/usage/).
