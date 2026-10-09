#!/bin/sh
# Save and restore the llama-server slot KV cache across pod rotations.
# Usage: slot-cache.sh restore | prestop | loop. Always exits 0, so a failure only means a cold start.
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
  rm -f "$DIR/.stopping"
  rmdir "$DIR/.lock" 2>/dev/null
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
  # A marker without its file is stale.
  for m in "$DIR"/.restoring-*; do
    [ -e "$m" ] && { [ -e "$DIR/$k-${m##*-}.bin" ] || rm -f "$m"; }
  done
  # Restore the largest prompt into the lowest slot. The server evicts the highest of the never-used slots first,
  # so a request that matches nothing then takes the slot with the smallest prompt.
  # The lock keeps a periodic save from overwriting a file before the loop reads it. The next start clears a stale one.
  mkdir "$DIR/.lock" 2>/dev/null && locked=1
  slot=0
  files=$(for f in "$DIR/$k-"*.bin; do [ -e "$f" ] && echo "$(stat -c %s "$f") $f"; done | sort -rn | cut -d' ' -f2)
  for f in $files; do
    i=${f##*-}
    i=${i%.bin}
    if [ -e "$DIR/.restoring-$i" ]; then
      # The last restore of this file killed the server, so a broken file would crash it again on every start.
      rm -f "$f" "$DIR/.restoring-$i"
      log "dropped file $i after a restore that crashed the server"
    elif [ -s "$f" ] && [ "$slot" -lt "$N" ]; then
      touch "$DIR/.restoring-$i"
      out=$(curl -sS -m 300 -w ' %{http_code}' -X POST "$URL/slots/$slot?action=restore" \
        -H 'Content-Type: application/json' -d "{\"filename\":\"${f##*/}\"}" 2>/dev/null)
      # Keep the marker if the server did not answer, because it probably crashed.
      case ${out##* } in 200 | 400) rm -f "$DIR/.restoring-$i" ;; esac
      log "restore file $i into slot $slot: ${out% *}"
      slot=$((slot + 1))
    fi
  done
  [ -n "$locked" ] && rmdir "$DIR/.lock" 2>/dev/null
}

# Token counters change only when the server handled a request.
counters() {
  curl -sf -m 5 "$URL/metrics" 2>/dev/null | grep -E '^llamacpp:(prompt_tokens_total|tokens_predicted_total) ' | cut -d' ' -f2 | tr '\n' ' '
}

# Save when a request finished since the last save and no slot is busy. The lock keeps prestop's save out of the way.
tick() {
  [ -e "$DIR/.stopping" ] && return
  now=$(counters)
  [ -n "$now" ] && [ "$now" != "$last" ] || return
  slots=$(curl -sf -m 5 "$URL/slots") || return
  case $slots in *'"is_processing":true'*) return ;; esac
  mkdir "$DIR/.lock" 2>/dev/null || return
  last=$now
  [ -e "$DIR/.stopping" ] || save sidecar
  rmdir "$DIR/.lock" 2>/dev/null
}

# Never exits on error: a crash loop would make the pod NotReady. SIGTERM removes the tmp file and releases the lock after the running curl ends.
loop() {
  trap 'rm -f "$DIR"/*.sidecar.tmp; rmdir "$DIR/.lock" 2>/dev/null; exit 0' TERM
  rmdir "$DIR/.lock" 2>/dev/null
  until curl -sf -m 5 "$URL/health" >/dev/null 2>&1; do sleep 5; done
  last=$(counters)
  while true; do
    sleep "${SAVE_INTERVAL:-300}" &
    wait $!
    tick
  done
}

case $1 in
  restore) restore ;;
  prestop)
    touch "$DIR/.stopping"
    # Wait for a running periodic save, so the saves below do not queue behind it.
    waited=0
    while [ -d "$DIR/.lock" ] && [ "$waited" -lt 240 ]; do
      sleep 2
      waited=$((waited + 2))
    done
    save prestop
    ;;
  loop) loop ;;
esac
exit 0
