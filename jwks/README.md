# Public JWKS

Public signing keys only. Never put private keys here.

| File                        | Key id         |
|-----------------------------|----------------|
| `otaru-mcp-oauth.jwks.json` | `mcp-20260728` |

Hydra OAuth client `otaru-mcp` loads this set via `jwksUri` for
`private_key_jwt` (ES256). Mint an access token with the matching private
PEM (never committed):

```shell
OTARU_MCP_KEY=/path/to/otaru-mcp-oauth-key.pem \
  uvx --with cryptography python hack/mint-otaru-mcp-token.py
```

If minting fails intermittently, see
`documentation/gotcha.md` ("Hydra private_key_jwt fails on one replica
only").
