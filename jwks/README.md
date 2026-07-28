# Public JWKS

Public signing keys only. Never put private keys here.

| File                        | Key id         | Used by                                     |
|-----------------------------|----------------|---------------------------------------------|
| `otaru-mcp-oauth.jwks.json` | `mcp-20260728` | Hydra OAuth client `otaru-mcp` (ES256 JWT)  |

Register the public JWK on the Hydra client. Keep the matching private PEM
on the workstation only (`OTARU_MCP_KEY`). Mint and inject flow is in
[MCP authentication](../documentation/mcp-auth.md).
