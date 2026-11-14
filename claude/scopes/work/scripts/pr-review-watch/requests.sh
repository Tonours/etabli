#!/bin/bash

write_review_request_ready() (
  umask 077
  local dir="$STATE_DIR/requests" temp
  [ ! -L "$dir" ] || return 1
  mkdir -p "$dir" || return 1
  temp="$(mktemp "$dir/.ready.XXXXXX")" || return 1
  # Line 1 is the v1 format Fleet already parses; line 2 announces protocol v2 (mode: post|dry-run).
  printf '1\t%s\t%s\nv2\n' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" "$(date +%s)" >"$temp" && mv "$temp" "$dir/ready"
)

review_request_receipt() (
  umask 077
  local path="$1" value="$2" temp
  [ ! -L "$path" ] || return 1
  temp="$(mktemp "${path%/*}/.receipt.XXXXXX")" || return 1
  printf '%s\n' "$value" >"$temp" && mv "$temp" "$path"
)

ingest_review_requests() {
  local me dir record id receipt repo number sha login mode snapshot reason listed key actor registered_sha count=0
  me="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  dir="$STATE_DIR/requests"
  [ ! -L "$dir" ] && [ ! -f "$KILL_SWITCH" ] || return 0
  mkdir -p "$dir" || return 1
  for record in "$dir/"*.json; do
    [ ! -f "$KILL_SWITCH" ] || return 0
    [ -e "$record" ] || [ -L "$record" ] || continue
    count=$((count + 1)); [ "$count" -le 64 ] || break
    id="${record##*/}"; id="${id%.json}"
    [[ "$id" =~ ^w-[0-9a-f]{32}$ ]] || { log 'request rejected: invalid filename'; rm -f "$record"; continue; }
    receipt="$dir/$id.receipt"
    if [ -f "$receipt" ] && [ ! -L "$receipt" ]; then rm -f "$record"; continue; fi
    reason=''
    if [ -L "$record" ] || [ ! -f "$record" ] || [ "$(perl -e 'print((stat shift)[7] // 9999)' "$record")" -gt 1024 ] || ! jq -e --arg id "$id" '
      ((.version == 1 and (keys|sort) == ["id","login","number","repo","sha","version"])
        or (.version == 2 and (keys|sort) == ["id","login","mode","number","repo","sha","version"] and (.mode == "post" or .mode == "dry-run")))
      and .id == $id
      and (.repo|type == "string" and test("^[a-z0-9_.-]+/[a-z0-9_.-]+$"))
      and (.number|type == "number" and . > 0 and . <= 2147483647 and . == floor)
      and (.sha|type == "string" and test("^[0-9a-f]{40}$"))
      and (.login|type == "string" and test("^[a-z0-9][a-z0-9-]*$"))' "$record" >/dev/null 2>&1; then
      reason=malformed
    else
      IFS=$'\t' read -r repo number sha login mode < <(jq -r '[.repo,.number,.sha,.login,(.mode // "post")]|@tsv' "$record")
      if [ "$login" != "$me" ]; then reason=account
      else
        snapshot="$(gh pr view "$number" --repo "$repo" --json author,state,headRefOid,isDraft 2>/dev/null)" || continue
        if ! printf '%s' "$snapshot" | jq -e '
          (.state|type=="string") and (.isDraft|type=="boolean")
          and (.headRefOid|type=="string" and test("^[0-9a-f]{40}$"))
          and (.author.login|type=="string" and test("^[A-Za-z0-9][A-Za-z0-9-]*$"))' >/dev/null; then continue
        elif [ "$(printf '%s' "$snapshot" | jq -r .state)" != OPEN ]; then reason=closed
        elif [ "$(printf '%s' "$snapshot" | jq -r .isDraft)" = true ]; then reason=draft
        elif [ "$(printf '%s' "$snapshot" | jq -r .headRefOid)" != "$sha" ]; then reason=stale
        elif [ "$(printf '%s' "$snapshot" | jq -r '.author.login|ascii_downcase')" = "$me" ]; then
          # An own PR is only ever dry-run; a dry-run of another author's PR has no use.
          [ "$mode" = dry-run ] || reason=own
        elif [ "$mode" = dry-run ]; then reason=malformed
        fi
      fi
      if [ -z "$reason" ] && [ "$mode" = dry-run ]; then
        # No registration: a dry-run grants no review or approval authority.
        if [ ! -f "$KILL_SWITCH" ]; then
          listed="$(awk -F'\t' -v r="$repo" -v n="$number" 'tolower($1)==r && $2==n {print $1;exit}' "$WATCHED")"
          repo="${listed:-$repo}"; key="$(run_key "$repo" "$number")"
          [ -n "$listed" ] || printf '%s\t%s\n' "$repo" "$number" >>"$WATCHED" || continue
          review_request_receipt "$key.dryrun" "$sha"$'\t'"$me" || continue
          review_request_receipt "$key.requested" "$sha"$'\t'"$me" || continue
        fi
      elif [ -z "$reason" ]; then
        listed="$(awk -F'\t' -v r="$repo" -v n="$number" 'tolower($1)==r && $2==n {print $1;exit}' "$WATCHED")"
        repo="${listed:-$repo}"; key="$(run_key "$repo" "$number")"
        if [ -e "$key.registered" ] || [ -L "$key.registered" ]; then
          registered_sha='' actor=''
          if [ -f "$key.registered" ] && [ ! -L "$key.registered" ] && [ "$(perl -e 'print((stat shift)[7] // 9999)' "$key.registered")" -le 256 ]; then
            IFS=$'\t' read -r registered_sha actor <"$key.registered" || true
          fi
          [ "$actor" = "$me" ] || reason=registered-other-account
        fi
        if [ -z "$reason" ] && [ ! -f "$KILL_SWITCH" ]; then
          [ -n "$listed" ] || printf '%s\t%s\n' "$repo" "$number" >>"$WATCHED" || continue
          review_request_receipt "$key.requested" "$sha"$'\t'"$me" || continue
          [ -e "$key.registered" ] || printf '%s\t%s\n' "$sha" "$me" >"$key.registered" || continue
        fi
      fi
    fi
    [ ! -f "$KILL_SWITCH" ] || return 0
    if [ -n "$reason" ]; then
      review_request_receipt "$receipt" $'rejected\t'"$reason" || continue
      log "review request rejected: $reason"
    else review_request_receipt "$receipt" $'accepted\t'"$sha" || continue
    fi
    rm -f "$record"
  done
  find "$dir" -type f -name 'w-*.receipt' -mtime +7 -delete 2>/dev/null
}
