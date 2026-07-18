#!/bin/bash

# Verify pinned image digests reference the multi-arch index, not a
# single-arch child manifest. A digest captured on an arm64 machine (e.g.
# via `docker inspect`) can silently resolve to the arm64 child manifest of
# a multi-arch image instead of the index digest. The pin then works by
# accident until the pod is scheduled onto a different architecture, where
# it fails with "exec format error". See documentation/gotcha.md ("A
# Pinned Digest Can Silently Be Single-Arch, Not Multi-Arch").

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

CHARTS_DIR="${1:-./helm-charts}"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/check-image-digests.XXXXXX")
PINS_FILE="${TEMP_DIR}/pins"
FAILURES_FILE="${TEMP_DIR}/failures"
HEADER_FILE="${TEMP_DIR}/headers"
BODY_FILE="${TEMP_DIR}/body"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

if ! command_exists yq; then
    exit_with_error "yq is not installed or not in PATH"
fi

if ! command_exists jq; then
    exit_with_error "jq is not installed or not in PATH"
fi

if ! directory_exists "$CHARTS_DIR"; then
    exit_with_error "Charts directory '$CHARTS_DIR' does not exist"
fi

INLINE_IMAGE_RE='image:[[:space:]]*[a-zA-Z0-9][a-zA-Z0-9./_-]*:[a-zA-Z0-9._-]+@sha256:[0-9a-f]{64}'
MANIFEST_ACCEPT="application/vnd.oci.image.index.v1+json,"
MANIFEST_ACCEPT="$MANIFEST_ACCEPT application/vnd.docker.distribution.manifest.list.v2+json,"
MANIFEST_ACCEPT="$MANIFEST_ACCEPT application/vnd.oci.image.manifest.v1+json,"
MANIFEST_ACCEPT="$MANIFEST_ACCEPT application/vnd.docker.distribution.manifest.v2+json"

collect_pins() {
    local file="$1"
    local line repository tag_digest registry

    # Structured `{registry?, repository, tag}` maps, anywhere in the tree.
    # Field separator is `|`, not tab: POSIX `read` treats tab as IFS
    # whitespace and silently strips/collapses leading empty fields even
    # when IFS is set to only a tab, which would corrupt the empty-registry
    # case. `|` never appears in a repository, tag, or digest string.
    while IFS='|' read -r registry repository tag_digest; do
        if [ -z "$repository" ]; then
            continue
        fi
        if [ -n "$registry" ]; then
            repository="${registry}/${repository}"
        fi
        printf '%s|%s|%s\n' "$repository" "$tag_digest" "$file" >> "$PINS_FILE"
    done < <(
        yq eval-all \
            '[..] | .[] | select(tag == "!!map")
            | select(has("tag") and has("repository"))
            | [(.registry // ""), .repository, .tag] | join("|")' \
            "$file" 2>/dev/null || true
    )

    # Inline single-line form: image: repo:tag@sha256:digest
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        line="${line#*image:}"
        line="$(echo "$line" | sed -E 's/^[[:space:]]+//')"
        repository="${line%%:*}"
        tag_digest="${line#*:}"
        printf '%s|%s|%s\n' "$repository" "$tag_digest" "$file" >> "$PINS_FILE"
    done < <(grep -oE "$INLINE_IMAGE_RE" "$file" 2>/dev/null || true)
}

registry_host_and_path() {
    local repository="$1"
    local first rest

    if [[ "$repository" == ghcr.io/* ]]; then
        echo "ghcr.io" "${repository#ghcr.io/}"
        return
    fi
    if [[ "$repository" != */* ]]; then
        echo "registry-1.docker.io" "library/${repository}"
        return
    fi
    first="${repository%%/*}"
    rest="${repository#*/}"
    if [[ "$first" == *.* || "$first" == *:* ]]; then
        if [ "$first" = "docker.io" ]; then
            echo "registry-1.docker.io" "$rest"
        else
            echo "$first" "$rest"
        fi
        return
    fi
    echo "registry-1.docker.io" "$repository"
}

fetch_token() {
    local host="$1" repo_path="$2" scope

    scope="repository:${repo_path}:pull"
    case "$host" in
        ghcr.io)
            curl -fsS "https://ghcr.io/token?service=ghcr.io&scope=${scope}" 2>/dev/null \
                | jq -r '.token // empty' 2>/dev/null || true
            ;;
        registry-1.docker.io)
            curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=${scope}" 2>/dev/null \
                | jq -r '.token // empty' 2>/dev/null || true
            ;;
        *)
            echo ""
            ;;
    esac
}

# Prints "OK", "WARN: <message>", or "FAIL: <message>" on stdout. Never
# returns non-zero -- every internal failure is captured and reported as
# WARN so a transient registry hiccup cannot abort the whole check.
check_pin() {
    local repository="$1" tag="$2" digest="$3" source="$4"
    local host repo_path token index_digest media_type arch

    read -r host repo_path <<< "$(registry_host_and_path "$repository" || true)"
    token=$(fetch_token "$host" "$repo_path" || true)

    if ! curl -fsS -D "$HEADER_FILE" \
        -H "Accept: $MANIFEST_ACCEPT" \
        ${token:+-H "Authorization: Bearer $token"} \
        "https://${host}/v2/${repo_path}/manifests/${tag}" -o "$BODY_FILE" 2>/dev/null; then
        echo "WARN: ${repository}:${tag} -- could not verify (registry request failed); skipping"
        return 0
    fi

    index_digest=$( (grep -i '^docker-content-digest:' "$HEADER_FILE" || true) | tr -d '\r' | awk '{print $2}')
    media_type=$(jq -r '.mediaType // ""' "$BODY_FILE" 2>/dev/null || echo "")

    case "$media_type" in
        application/vnd.oci.image.index.v1+json|application/vnd.docker.distribution.manifest.list.v2+json)
            ;;
        *)
            # No multi-arch index for this tag right now; any pin is fine.
            echo "OK"
            return 0
            ;;
    esac

    if [ "$digest" = "$index_digest" ]; then
        echo "OK"
        return 0
    fi

    if jq -e --arg d "$digest" '.manifests[]? | select(.digest == $d)' "$BODY_FILE" >/dev/null 2>&1; then
        arch=$(jq -r --arg d "$digest" '.manifests[] | select(.digest == $d) | .platform.architecture // "unknown"' "$BODY_FILE" 2>/dev/null || echo "unknown")
        echo "FAIL: ${source}: ${repository}:${tag}@${digest} is pinned to the ${arch}-only child manifest, not the multi-arch index. Re-pin to @${index_digest}."
        return 0
    fi

    # Pinned digest matches neither the current index nor any current child --
    # the tag has simply moved past this pin (normal, intentional version
    # pinning). Not this check's concern.
    echo "OK"
}

: > "$PINS_FILE"
while IFS= read -r -d '' file; do
    collect_pins "$file"
done < <(find "$CHARTS_DIR" -name '*.yaml' -print0)

sort -u -t '|' -k1,1 -k2,2 "$PINS_FILE" -o "$PINS_FILE"

checked=0
: > "$FAILURES_FILE"
while IFS='|' read -r repository tag_digest source; do
    if [ -z "$repository" ]; then
        continue
    fi
    tag="${tag_digest%%@*}"
    digest="${tag_digest#*@}"
    checked=$((checked + 1))
    result=$(check_pin "$repository" "$tag" "$digest" "$source" || true)
    case "$result" in
        FAIL:*)
            echo "$result" >> "$FAILURES_FILE"
            ;;
        WARN:*)
            echo "$result"
            ;;
    esac
done < "$PINS_FILE"

log_info "Checked $checked pinned image digest(s)."

if [ -s "$FAILURES_FILE" ]; then
    echo ""
    log_error "$(wc -l < "$FAILURES_FILE" | tr -d ' ') mispinned digest(s) found:"
    echo ""
    while IFS= read -r line; do
        echo "  - ${line#FAIL: }"
    done < "$FAILURES_FILE"
    exit 1
fi

log_success "All pinned digests are correct: index-pinned or genuinely single-arch."
