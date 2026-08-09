# Secrets

Secrets must live outside this Git checkout. By default, this repo looks under:

```text
~/dotfiles/secrets/otaru
```

The committed `.envrc` only loads the external `envrc` file. Do not put secret
values in the committed `.envrc`, and do not commit the files shown below.

## Files

Create this layout:

```text
~/dotfiles/secrets/otaru/
├── envrc
├── tfconfig
├── 1password-credentials.json
├── token
└── etcd/
    ├── ca.pem
    ├── client.pem
    └── client-key.pem
```

## `envrc`

Example:

```shell
export OTARU_SECRETS_DIR="${HOME}/dotfiles/secrets/otaru"
export OTARU_1PASSWORD_CREDENTIALS_FILE="${OTARU_SECRETS_DIR}/1password-credentials.json"
export OTARU_1PASSWORD_CONNECT_TOKEN_FILE="${OTARU_SECRETS_DIR}/token"
export OTARU_ETCD_CA_FILE="${OTARU_SECRETS_DIR}/etcd/ca.pem"
export OTARU_ETCD_CLIENT_CERT_FILE="${OTARU_SECRETS_DIR}/etcd/client.pem"
export OTARU_ETCD_CLIENT_KEY_FILE="${OTARU_SECRETS_DIR}/etcd/client-key.pem"
export OTARU_TF_CONFIG_FILE="${OTARU_SECRETS_DIR}/tfconfig"

export B2_APPLICATION_KEY=...
export B2_APPLICATION_KEY_ID=...

export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_TUNNEL_SECRET=...

# Controller URL is not an env var -- it comes from tfconfig
# (unifi.controller.api_url), interpolated into the generated provider block
# in infrastructure/root.hcl.
export UNIFI_USERNAME=...
export UNIFI_PASSWORD=...
export UNIFI_LHR_WLAN01_PASSWORD=...
export UNIFI_LHR_WLAN01_SSID=...
export UNIFI_LHR_WLAN02_PASSWORD=...
export UNIFI_LHR_WLAN02_SSID=...
export UNIFI_LHR_WLAN03_PASSWORD=...
export UNIFI_LHR_WLAN03_SSID=...
export UNIFI_LHR_WLAN04_PASSWORD=...
export UNIFI_LHR_WLAN04_SSID=...

# OpenTofu GitHub provider (Access unit IP data source). Prefer env over
# embedding tokens in generated provider.tf / .terragrunt-cache.
export GITHUB_TOKEN="$(gh auth token)"
```

## `tfconfig`

Terraform configuration that should stay outside the public repository belongs
in `~/dotfiles/secrets/otaru/tfconfig`. Keep this local JSON file synchronized
with the `tfconfig` Document item in the `github-otaru` 1Password vault,
matching the existing `envrc` Document pattern. This covers Terraform values
that are not credential secrets but would still reveal personal or home-network
details if committed (Cloudflare zone/account identifiers, tunnel egress IP
ranges, internal subdomain naming, UniFi client/device MACs). Keep everything
else (module structure, non-identifying defaults) in HCL:

```json
{
  "b2": {
    "bucket": {
      "cnpg_backup": "example-cnpg-backup",
      "media_storage": "example-media-storage"
    }
  },
  "cloudflare": {
    "account": {
      "id": "..."
    },
    "zone": {
      "hostname": "example.com",
      "id": "...",
      "subdomain": "example-subdomain",
      "tunnel_ip_list": ["1.2.3.4/32"],
      "dns_ip": "192.168.12.34"
    },
    "dns": {
      "device-key": "subdomain.internal"
    }
  },
  "unifi": {
    "controller": {
      "api_url": "https://unifi.example.com"
    },
    "clients": {
      "device-name": {
        "mac": "00:00:00:00:00:00"
      }
    },
    "devices": {
      "device-key": {
        "mac": "00:00:00:00:00:00"
      }
    }
  }
}
```

OpenTofu/Terragrunt providers take credentials from the environment
(see `infrastructure/root.hcl`); UniFi's controller URL is the one non-secret
exception, sourced from `tfconfig` instead:

| Provider   | Environment variables                              |
|------------|----------------------------------------------------|
| AWS        | standard AWS SDK chain (`AWS_PROFILE`, keys, etc.) |
| B2         | `B2_APPLICATION_KEY`, `B2_APPLICATION_KEY_ID`      |
| Cloudflare | `CLOUDFLARE_API_TOKEN`                             |
| GitHub     | `GITHUB_TOKEN`                                     |
| UniFi      | `UNIFI_USERNAME`, `UNIFI_PASSWORD`                 |

Run `gh auth login` before Terraform targets or Helm OCI chart updates that
need GitHub. Export `GITHUB_TOKEN` as above so the GitHub provider does not
need `gh` invoked from Terragrunt.

## `1password-credentials.json`

Example shape:

```json
{
  "version": "2",
  "verifier": "replace-me",
  "encCredentials": {
    "kid": "replace-me",
    "enc": "replace-me",
    "cty": "replace-me"
  }
}
```

Use the real credentials JSON generated for the Connect server.

## `token`

Example:

```text
replace-with-connect-token
```

Keep this as a single token value.

Only needed once for the very first bootstrap of a cluster. After that,
`onepassword-connect-token` (namespace `external-secrets`) is managed by an
`ExternalSecret` that reads `op://github-otaru/1Password Token/credential`
via the same `ClusterSecretStore` it authenticates — rotate by updating that
1Password item, not by re-running the bootstrap `kubectl create secret`
step. If the live token is ever invalidated before the new value is synced
(revoked, expired, leaked), this self-referential sync breaks and the
Secret needs the manual bootstrap step again to re-seed it.

## `etcd/ca.pem`

Example:

```text
-----BEGIN CERTIFICATE-----
replace-with-ca-certificate
-----END CERTIFICATE-----
```

## `etcd/client.pem`

Example:

```text
-----BEGIN CERTIFICATE-----
replace-with-client-certificate
-----END CERTIFICATE-----
```

## `etcd/client-key.pem`

Example:

```text
-----BEGIN PRIVATE KEY-----
replace-with-client-private-key
-----END PRIVATE KEY-----
```

## LUKS

LUKS image creation and remote unlock workflows also use:

```text
~/dotfiles/secrets/ansible/ansible_vault.yaml
```

Example:

```yaml
otaru_luks_password: "replace-me"
```

This file is not required for normal cluster bootstrap.

## Ory

The `Ory` Password item in the `github-otaru` vault provides two independent,
stable Hydra fields: `hydraSecretsSystem` and `hydraSecretsCookie`. The
component prefix keeps room for other Ory services in the same item. Hydra uses
them to encrypt persisted data and protect browser state. Do not rotate either
field as a normal password rotation: Hydra secret rotation requires an overlap
period with both the old and new values configured.

OAuth client signing keys are separate from these server secrets. Keep client
private keys outside Git and Kubernetes; register only their public JWKs when a
client is onboarded.

### MCP machine client

Client id `otaru-mcp` uses `private_key_jwt` (ES256). Public JWK is committed
under `jwks/`. Private key stays on the operator workstation (for example
`~/.config/otaru-mcp/oauth-key.pem` via `OTARU_MCP_KEY`). Do not load it into
the cluster. Architecture and token path:
[MCP authentication](mcp-auth.md).

## Check

Run this before bootstrap:

```shell
direnv allow
test -r "$OTARU_1PASSWORD_CREDENTIALS_FILE"
test -r "$OTARU_1PASSWORD_CONNECT_TOKEN_FILE"
```
