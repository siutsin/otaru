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

export B2_APPLICATION_KEY=...
export B2_APPLICATION_KEY_ID=...
export B2_CNPG_BACKUP_BUCKET=...
export B2_MEDIA_STORAGE_BUCKET=...

export CLOUDFLARE_ACCOUNT_ID=...
export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_TUNNEL_SECRET=...
export CLOUDFLARE_ZONE=example.com
export CLOUDFLARE_ZONE_ID=...
export CLOUDFLARE_ZONE_SUBDOMAIN=subdomain
export CLOUDFLARE_ZONE_TUNNEL_IP_LIST='["1.2.3.4/32"]'
export CLOUDFLARE_DNS_IP=192.168.12.34
export CLOUDFLARE_DNS_SUBDOMAINS='["subdomain1.internal","subdomain2.internal"]'

export GITHUB_TOKEN=...

export UNIFI_API_URL=...
export UNIFI_LHR_WLAN01_PASSWORD=...
export UNIFI_LHR_WLAN01_SSID=...
export UNIFI_LHR_WLAN02_PASSWORD=...
export UNIFI_LHR_WLAN02_SSID=...
export UNIFI_LHR_WLAN03_PASSWORD=...
export UNIFI_LHR_WLAN03_SSID=...
export UNIFI_LHR_WLAN04_PASSWORD=...
export UNIFI_LHR_WLAN04_SSID=...
export UNIFI_PASSWORD=...
export UNIFI_USERNAME=...
```

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

## Check

Run this before bootstrap:

```shell
direnv allow
test -r "$OTARU_1PASSWORD_CREDENTIALS_FILE"
test -r "$OTARU_1PASSWORD_CONNECT_TOKEN_FILE"
```
