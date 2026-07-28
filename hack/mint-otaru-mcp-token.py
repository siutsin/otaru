#!/usr/bin/env python3
"""Mint a Hydra client_credentials access token for otaru-mcp (private_key_jwt).

Requires jwcrypto, for example:

uvx --with jwcrypto python scripts/mint-otaru-mcp-token.py

Environment:

OTARU_MCP_KEY path to EC private PEM (required)
OTARU_MCP_KID JWK kid (default mcp-20260728)
OTARU_MCP_CLIENT_ID client id (default otaru-mcp)
OTARU_MCP_TOKEN_URL token endpoint
OTARU_MCP_SCOPE scope (default mcp)
"""

from __future__ import annotations

import json
import os
import sys
import time
import uuid
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_TOKEN_URL = "https://auth.siutsin.com/oauth2/token"


def main() -> int:
    key_path = os.environ.get("OTARU_MCP_KEY")
    if not key_path:
        print(
            "OTARU_MCP_KEY is required (path to private PEM)",
            file=sys.stderr,
        )
        return 2

    client_id = os.environ.get("OTARU_MCP_CLIENT_ID", "otaru-mcp")
    token_url = os.environ.get("OTARU_MCP_TOKEN_URL", DEFAULT_TOKEN_URL)
    kid = os.environ.get("OTARU_MCP_KID", "mcp-20260728")
    scope = os.environ.get("OTARU_MCP_SCOPE", "mcp")

    try:
        from jwcrypto import jwk, jwt
    except ImportError:
        print(
            "jwcrypto is required; run via: "
            "uvx --with jwcrypto python ...",
            file=sys.stderr,
        )
        return 2

    pem = Path(key_path).read_bytes()
    key = jwk.JWK.from_pem(pem)
    key.update(kid=kid)

    now = int(time.time())
    assertion = jwt.JWT(
        header={"alg": "ES256", "kid": kid, "typ": "JWT"},
        claims={
            "iss": client_id,
            "sub": client_id,
            "aud": token_url,
            "iat": now,
            "exp": now + 60,
            "jti": str(uuid.uuid4()),
        },
    )
    assertion.make_signed_token(key)

    body = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "scope": scope,
            "client_assertion_type": (
                "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
            ),
            "client_assertion": assertion.serialize(),
        }
    ).encode()

    req = urllib.request.Request(
        token_url,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        print(exc.read().decode(), file=sys.stderr)
        return 1

    token = data.get("access_token")
    if not token:
        print(json.dumps(data, indent=2), file=sys.stderr)
        return 1

    print(token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
