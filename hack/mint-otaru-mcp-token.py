#!/usr/bin/env python3
"""Mint a Hydra client_credentials access token for otaru-mcp (private_key_jwt).

Signs the client assertion with ES256 and low-S ECDSA normalisation so Hydra
(go-jose) accepts the signature. Retries transient invalid_client responses
that a single bad Hydra replica can return while the Service still balances
to healthy pods.

Requires cryptography, for example:

uvx --with cryptography python hack/mint-otaru-mcp-token.py

Environment:

OTARU_MCP_KEY path to EC private PEM (required)
OTARU_MCP_KID JWK kid (default mcp-20260728)
OTARU_MCP_CLIENT_ID client id (default otaru-mcp)
OTARU_MCP_TOKEN_URL token endpoint
OTARU_MCP_SCOPE scope (default mcp)
OTARU_MCP_MINT_ATTEMPTS max token requests (default 5)
"""

from __future__ import annotations

import base64
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
DEFAULT_ATTEMPTS = 5

# NIST P-256 curve order (RFC 7518 ES256). go-jose rejects S > n/2.
_P256_N = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
_P256_HALF_N = _P256_N // 2


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _json_b64url(obj: dict) -> str:
    return _b64url(
        json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")
    )


def _sign_es256_low_s(private_key, signing_input: bytes) -> bytes:
    """Return raw R||S (64 bytes) with S forced into the low half of the curve."""
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec, utils

    der = private_key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = utils.decode_dss_signature(der)
    if s > _P256_HALF_N:
        s = _P256_N - s
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def _load_ec_private_key(pem: bytes):
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec

    key = serialization.load_pem_private_key(pem, password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise ValueError("OTARU_MCP_KEY must be an EC private key (P-256)")
    if not isinstance(key.curve, ec.SECP256R1):
        raise ValueError("OTARU_MCP_KEY must use the P-256 (secp256r1) curve")
    return key


def _client_assertion(
    private_key,
    *,
    client_id: str,
    token_url: str,
    kid: str,
) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": kid, "typ": "JWT"}
    claims = {
        "iss": client_id,
        "sub": client_id,
        "aud": token_url,
        "iat": now,
        "exp": now + 60,
        "jti": str(uuid.uuid4()),
    }
    signing_input = f"{_json_b64url(header)}.{_json_b64url(claims)}".encode(
        "ascii"
    )
    signature = _sign_es256_low_s(private_key, signing_input)
    return f"{signing_input.decode('ascii')}.{_b64url(signature)}"


def _request_token(
    *,
    token_url: str,
    client_id: str,
    scope: str,
    assertion: str,
) -> tuple[dict | None, str | None, int | None]:
    body = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "scope": scope,
            "client_assertion_type": (
                "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
            ),
            "client_assertion": assertion,
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
            return json.loads(resp.read().decode()), None, resp.status
    except urllib.error.HTTPError as exc:
        return None, exc.read().decode(), exc.code
    except urllib.error.URLError as exc:
        return None, f"token request failed: {exc}", None


def _retryable_client_error(status: int | None, body: str) -> bool:
    if status != 401:
        return False
    return "client_assertion" in body or "invalid_client" in body


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
        attempts = int(
            os.environ.get("OTARU_MCP_MINT_ATTEMPTS", str(DEFAULT_ATTEMPTS))
        )
    except ValueError:
        print("OTARU_MCP_MINT_ATTEMPTS must be an integer", file=sys.stderr)
        return 2
    if attempts < 1:
        print("OTARU_MCP_MINT_ATTEMPTS must be >= 1", file=sys.stderr)
        return 2

    try:
        from cryptography.hazmat.primitives.asymmetric import ec  # noqa: F401
    except ImportError:
        print(
            "cryptography is required; run via: "
            "uvx --with cryptography python ...",
            file=sys.stderr,
        )
        return 2

    try:
        private_key = _load_ec_private_key(Path(key_path).read_bytes())
    except (OSError, ValueError) as exc:
        print(f"failed to load OTARU_MCP_KEY: {exc}", file=sys.stderr)
        return 2

    last_error = "token request failed"
    for attempt in range(1, attempts + 1):
        # Fresh jti every attempt so a prior success is not jti_known.
        assertion = _client_assertion(
            private_key,
            client_id=client_id,
            token_url=token_url,
            kid=kid,
        )
        data, err, status = _request_token(
            token_url=token_url,
            client_id=client_id,
            scope=scope,
            assertion=assertion,
        )
        if data is not None:
            token = data.get("access_token")
            if token:
                print(token)
                return 0
            last_error = json.dumps(data, indent=2)
            break

        last_error = err or last_error
        if attempt < attempts and _retryable_client_error(status, last_error):
            time.sleep(0.15 * attempt)
            continue
        break

    print(last_error, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
