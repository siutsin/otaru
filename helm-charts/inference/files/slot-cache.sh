#!/bin/sh
# Save and restore the llama-server slot KV cache across pod rotations.
# Usage: slot-cache.sh restore | prestop. Always exits 0, so a failure only means a cold start.
DIR=${SLOT_PATH:-/models/slots}
URL=http://localhost:${LLAMA_ARG_PORT:-9931}
N=${LLAMA_ARG_N_PARALLEL:-2}

log() { echo "slot-cache: $*" >/proc/1/fd/1 2>/dev/null; }

# The key changes with the server settings, the model file or the drafter, so a stale cache is never restored.
key() {
  # An updated snapshot can leave two links to the same blob, so count unique blobs.
  found=$(find /models -name "$LLAMA_ARG_HF_FILE" 2>/dev/null)
  model=$(printf '%s\n' "$found" | head -n 1)
  if [ -z "$model" ] || [ "$(printf '%s\n' "$found" | xargs -d '\n' stat -L -c '%i' | sort -u | wc -l)" != 1 ]; then
    log "model file missing or not unique, skipping"
    return 1
  fi
  {
    env | grep '^LLAMA_ARG_' | sort
    stat -L -c '%s %Y' "$model"
    stat -L -c '%s' "$LLAMA_ARG_SPEC_DRAFT_MODEL" 2>/dev/null
  } | sha256sum | cut -c1-16
}

# Save every slot to a tmp file and keep it only if the server wrote all of it.
save() {
  k=$(key) || return 0
  i=0
  while [ "$i" -lt "$N" ]; do
    tmp="$k-$i.$1.tmp"
    out=$(curl -sS -m 120 -w ' %{http_code}' -X POST "$URL/slots/$i?action=save" \
      -H 'Content-Type: application/json' -d "{\"filename\":\"$tmp\"}" 2>/dev/null)
    code=${out##* }
    saved=$(printf '%s' "${out% *}" | sed -n 's/.*"n_saved":\([0-9]*\).*/\1/p')
    written=$(printf '%s' "${out% *}" | sed -n 's/.*"n_written":\([0-9]*\).*/\1/p')
    size=$(stat -c %s "$DIR/$tmp" 2>/dev/null)
    if [ "$code" = 200 ] && [ "${saved:-0}" -gt 0 ] && [ "$size" = "$written" ]; then
      mv "$DIR/$tmp" "$DIR/$k-$i.bin"
      log "saved slot $i, $saved tokens"
    else
      rm -f "$DIR/$tmp"
      log "slot $i not saved (code ${code:-none}, tokens ${saved:-0})"
    fi
    i=$((i + 1))
  done
}

restore() {
  mkdir -p "$DIR"
  rm -f "$DIR/.stopping" "$DIR/.lock"
  waited=0
  until curl -sf -m 5 "$URL/health" >/dev/null 2>&1; do
    waited=$((waited + 5))
    if [ "$waited" -ge 900 ]; then
      log "server not healthy after 900s, skipping restore"
      return 0
    fi
    sleep 5
  done
  k=$(key) || return 0
  rm -f "$DIR"/*.tmp
  for f in "$DIR"/*.bin; do
    case $f in "$DIR/$k-"*) ;; *) rm -f "$f" ;; esac
  done
  i=0
  while [ "$i" -lt "$N" ]; do
    if [ -s "$DIR/$k-$i.bin" ]; then
      out=$(curl -sS -m 300 -X POST "$URL/slots/$i?action=restore" \
        -H 'Content-Type: application/json' -d "{\"filename\":\"$k-$i.bin\"}" 2>/dev/null)
      log "restore slot $i: $out"
    fi
    i=$((i + 1))
  done
}

case $1 in
  restore) restore ;;
  prestop)
    touch "$DIR/.stopping"
    save prestop
    ;;
esac
exit 0
