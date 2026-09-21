# Public JWKS

Public signing keys only. Never put private keys here.

| File                        | Key id          | Used by                                    |
|-----------------------------|-----------------|--------------------------------------------|
| `otaru-mcp-oauth.jwks.json` | `mcp-20260728`  | Hydra OAuth client `otaru-mcp` (ES256 JWT) |
| `muse-oauth.jwks.json`      | `muse-20260921` | Hydra OAuth client `muse` (ES256 JWT)      |

Register the public JWK on the Hydra client. Keep the matching private key
outside Git: `OTARU_MCP_KEY` on the workstation for `otaru-mcp`, and Muse's
own key store for `muse`. Mint and inject flow is in
[MCP authentication](../documentation/mcp-auth.md).
