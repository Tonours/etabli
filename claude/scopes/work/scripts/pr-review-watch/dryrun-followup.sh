#!/bin/bash
set -uo pipefail
umask 077
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../pr-council-review/lib.sh" || exit 1

# Snapshot once, rejecting links, special files and oversized artifacts. The
# digest binds the exact bytes the private reviewer will read.
snapshot() {
  perl -MFcntl=O_RDONLY,O_NOFOLLOW,O_NONBLOCK,S_ISREG -MDigest::SHA=sha256_hex -e '
    sysopen my $in, $ARGV[0], O_RDONLY|O_NOFOLLOW|O_NONBLOCK or exit 1;
    my @s=stat $in; S_ISREG($s[2]) && $s[4] == $< && ($s[2] & 077) == 0 && $s[7] <= $ARGV[2] or exit 1;
    my $bytes; my $n=read $in, $bytes, $ARGV[2]+1; defined $n && $n <= $ARGV[2] or exit 1;
    open my $out, ">", $ARGV[1] or exit 1; print $out $bytes; close $out or exit 1;
    print sha256_hex($bytes);
  ' "$@"
}

valid_findings() {
  jq -e -s --arg repo "$REPO" --argjson number "$NUMBER" --arg sha "$1" '
    length == 1 and (.[0] |
      type == "object" and .version == 1 and
      (.repo | type == "string") and (.repo | ascii_downcase) == ($repo | ascii_downcase) and
      .number == $number and .sha == $sha and
      (.findings | type == "number") and .findings >= 0 and .findings == (.findings|floor) and
      (.body | type == "string") and (.comments | type == "array") and
      all(.comments[]; (.path|type)=="string" and (.path|test("\\S")) and
        (.body|type)=="string" and (.body|test("\\S")) and
        (.line|type)=="number" and .line>=1 and .line==(.line|floor)))' "$2" >/dev/null
}

eligible_findings() {
  case "$1" in
    full)
      jq -e 'if .findings == 0 then .body == "" and .comments == []
        else (.comments|length) >= .findings end' "$2" >/dev/null ;;
    incremental)
      jq -e '.basis == "incremental" and
        .findings == ((.comments|length) + (if .body == "" then 0 else 1 end))' "$2" >/dev/null ;;
    *) return 1 ;;
  esac
}

record_receipt() {
  local directory digest temp basis header base_ref merge_base base_oid meta
  directory="$(mktemp -d "${TMPDIR:-/tmp}/pr-private-record.XXXXXX")" || return 1
  digest="$(snapshot "$OUT" "$directory/findings.json" 262144)" &&
    valid_findings "$SHA" "$directory/findings.json" || { rm -rf "$directory"; return 1; }
  basis="$(jq -r '.basis // "full"' "$directory/findings.json")"
  if ! eligible_findings "$basis" "$directory/findings.json"; then
    rm -f "$KEY.dryrun-last"
    rm -rf "$directory"
    echo '=== private baseline unavailable: findings are not completely represented'
    return 0
  fi
  header="$(grep -E '^COUNCIL_BASE ref=[^[:space:]]+ merge_base=[a-f0-9]{40} base_oid=[a-f0-9]{40}$' "$REPORT")" || { rm -rf "$directory"; return 1; }
  [[ "$header" != *$'\n'* ]] || { rm -rf "$directory"; return 1; }
  read -r _ base_ref merge_base base_oid <<<"$header"
  base_ref="${base_ref#ref=}" merge_base="${merge_base#merge_base=}" base_oid="${base_oid#base_oid=}"
  meta="$(gh pr view "$NUMBER" --repo "$REPO" --json state,isDraft,headRefOid,baseRefName,baseRefOid,author)" &&
    printf '%s' "$meta" | jq -e --arg sha "$SHA" --arg base "$base_ref" --arg oid "$base_oid" --arg actor "$ME" '
      .state=="OPEN" and .isDraft==false and .headRefOid==$sha and
      .baseRefName==$base and .baseRefOid==$oid and (.author.login|ascii_downcase)==$actor' >/dev/null || {
        rm -rf "$directory"; return 1;
      }
  temp="$(mktemp "$KEY.dryrun-last.XXXXXX")" || { rm -rf "$directory"; return 1; }
  jq -n --arg repo "$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')" --argjson number "$NUMBER" \
    --arg sha "$SHA" --arg actor "$ME" --arg digest "$digest" --arg basis "$basis" \
    --arg base "$base_ref" --arg merge_base "$merge_base" \
    '{version:1,repo:$repo,number:$number,sha:$sha,actor:$actor,digest:$digest,basis:$basis,base_ref:$base,merge_base:$merge_base}' >"$temp" &&
    mv "$temp" "$KEY.dryrun-last"
  local rc=$?
  rm -f "$temp"; rm -rf "$directory"
  return "$rc"
}

record=0
if [ "${1:-}" = record ]; then record=1; shift; fi
REPO="${1:?}" NUMBER="${2:?}" SHA="${3:?}" ME="${4:?}" KEY="${5:?}" OUT="${6:?}"
REPORT="${7:-}"
ME="$(printf '%s' "$ME" | tr '[:upper:]' '[:lower:]')"
if [ "$record" = 1 ]; then record_receipt; exit $?; fi

# 2 means no reusable baseline; 6 means a valid but uncertain private verdict.
# The caller may run one full council for those cases, never for transport errors.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-private-$NUMBER.XXXXXX")" || exit 1
WORKTREE="$WORK_DIR/tree"
cleanup() {
  [ ! -d "$WORKTREE" ] || git worktree remove --force "$WORKTREE" >/dev/null 2>&1
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'stop_children; exit 143' TERM
trap 'stop_children; exit 130' INT
trap 'stop_children; exit 129' HUP
snapshot "$KEY.dryrun-last" "$WORK_DIR/receipt.json" 4096 >/dev/null || exit 2
PREVIOUS="$(jq -er -s --arg repo "$REPO" --argjson number "$NUMBER" --arg actor "$ME" '
  select(length==1) | .[0] | select(type=="object") |
  select(keys == ["actor","base_ref","basis","digest","merge_base","number","repo","sha","version"]) |
  select(.version==1 and (.repo|ascii_downcase)==($repo|ascii_downcase) and .number==$number and .actor==$actor) |
  select(.basis|IN("full","incremental")) |
  select(.digest|type=="string" and test("^[a-f0-9]{64}$")) |
  select(.base_ref|type=="string" and test("\\S")) |
  select(.merge_base|type=="string" and test("^[a-f0-9]{40}$")) |
  .sha | select(type=="string" and test("^[a-f0-9]{40}$"))' "$WORK_DIR/receipt.json")" || exit 2
[ "$PREVIOUS" != "$SHA" ] || exit 2
source_file="$(dirname "$OUT")/${REPO//\//_}-$NUMBER-${PREVIOUS:0:8}-findings.json"
digest="$(snapshot "$source_file" "$WORK_DIR/source.json" 262144)" || exit 2
[ "$digest" = "$(jq -r .digest "$WORK_DIR/receipt.json")" ] || exit 2
valid_findings "$PREVIOUS" "$WORK_DIR/source.json" || exit 2
eligible_findings "$(jq -r .basis "$WORK_DIR/receipt.json")" "$WORK_DIR/source.json" || exit 2

target_current() {
  local meta
  meta="$(gh pr view "$NUMBER" --repo "$REPO" --json state,isDraft,headRefOid,baseRefName,baseRefOid,author)" || return 1
  printf '%s' "$meta" | jq -e --arg sha "$SHA" --arg actor "$ME" '
    .headRefOid==$sha and .state=="OPEN" and .isDraft==false and
    (.author.login|ascii_downcase)==$actor and (.baseRefName|type)=="string" and .baseRefName!="" and
    (.baseRefOid|type=="string" and test("^[a-f0-9]{40}$"))' >/dev/null || return 1
  [ -z "$BASE_REF" ] || [ "$(printf '%s' "$meta" | jq -r .baseRefName)" = "$BASE_REF" ] || return 1
  [ -z "$BASE_OID" ] || [ "$(printf '%s' "$meta" | jq -r .baseRefOid)" = "$BASE_OID" ] || return 1
  printf '%s' "$meta" | jq -r '[.baseRefName,.baseRefOid]|@tsv'
}
BASE_REF='' BASE_OID=''
base_info="$(target_current)" || exit $?
IFS=$'\t' read -r BASE_REF BASE_OID <<<"$base_info"
[ "$BASE_REF" = "$(jq -r .base_ref "$WORK_DIR/receipt.json")" ] || exit 2
git fetch -q origin "+refs/pull/$NUMBER/head:refs/remotes/origin/pr/$NUMBER" \
  "+refs/heads/$BASE_REF:refs/remotes/origin/$BASE_REF" || exit 1
[ "$(git rev-parse "refs/remotes/origin/pr/$NUMBER")" = "$SHA" ] || exit 1
[ "$(git rev-parse "refs/remotes/origin/$BASE_REF")" = "$BASE_OID" ] || exit 1
git cat-file -e "$PREVIOUS^{commit}" 2>/dev/null || exit 2
history=0
git merge-base --is-ancestor "$PREVIOUS" "$SHA" || history=$?
case "$history" in 0) ;; 1) exit 2 ;; *) exit 1 ;; esac
merges="$(git rev-list --merges "$PREVIOUS..$SHA")" || exit 1
[ -z "$merges" ] || exit 2
MERGE_BASE="$(git merge-base "$BASE_OID" "$SHA")" || exit 1
[ "$MERGE_BASE" = "$(jq -r .merge_base "$WORK_DIR/receipt.json")" ] || exit 2
printf 'COUNCIL_BASE ref=%s merge_base=%s base_oid=%s\n' "$BASE_REF" "$MERGE_BASE" "$BASE_OID"
git worktree add -q --detach "$WORKTREE" "$SHA" || exit 1
git -C "$WORKTREE" reset -q --soft "$PREVIOUS" || exit 1
neutralize_author_config "$WORKTREE" "$PREVIOUS" "$MERGE_BASE" || exit 1
git -C "$WORKTREE" diff --cached --no-color >"$WORK_DIR/delta.patch" || exit 1
jq '[if .body!="" then {kind:"body",value:.body} else empty end] +
  [.comments[]|{kind:"comment",value:.}]' "$WORK_DIR/source.json" >"$WORK_DIR/items.json" || exit 1
COUNT="$(jq length "$WORK_DIR/items.json")"
PROMPT="$(render_template "$HERE/dryrun-prompt.md" REPO="$REPO" PR_NUMBER="$NUMBER" \
  SOURCE_SHA="$PREVIOUS" HEAD_SHA="$SHA" SOURCE_ITEMS="$WORK_DIR/items.json" \
  DELTA="$WORK_DIR/delta.patch" COUNT="$COUNT")" || exit 1
SCHEMA='{"type":"object","additionalProperties":false,"required":["source_sha","sha","complete","confident","verdicts","new_findings"],"properties":{"source_sha":{"type":"string"},"sha":{"type":"string"},"complete":{"type":"boolean"},"confident":{"type":"boolean"},"verdicts":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["source_index","settled","evidence"],"properties":{"source_index":{"type":"integer","minimum":0},"settled":{"type":"boolean"},"evidence":{"type":"string","minLength":1}}}},"new_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line","body","severity","verification"],"properties":{"path":{"type":"string","minLength":1},"line":{"type":"integer","minimum":1},"body":{"type":"string","minLength":1},"severity":{"type":"string","enum":["high","medium","low"]},"verification":{"type":"string","enum":["confirmed","unverified"]}}}}}}'
echo "=== private follow-up ${PREVIOUS:0:8}..${SHA:0:8}: verify $COUNT source items and the complete delta"
(cd "$WORKTREE" && claude_pass private-followup "$WORK_DIR/session.json" read-only "$PROMPT" \
  --model "${PR_REVIEW_WATCH_VERIFY_MODEL:-opus}" --effort "${PR_REVIEW_WATCH_VERIFY_EFFORT:-low}" \
  --tools Read,Grep,Glob --json-schema "$SCHEMA" "${ISOLATED_SETTINGS[@]}" >/dev/null) || exit $?
jq -ce --arg source "$PREVIOUS" --arg sha "$SHA" --argjson count "$COUNT" '
  .structured_output | select(type=="object") |
  select(.source_sha==$source and .sha==$sha and (.complete|type)=="boolean" and (.confident|type)=="boolean") |
  select((.verdicts|type)=="array" and (.new_findings|type)=="array") |
  select(all(.verdicts[]; (.source_index|type)=="number" and .source_index>=0 and
    .source_index<$count and .source_index==(.source_index|floor) and
    (.settled|type)=="boolean" and (.evidence|type)=="string" and (.evidence|test("\\S")))) |
  select((.verdicts|map(.source_index)|unique|length)==(.verdicts|length)) |
  select((.complete|not) or ((.verdicts|map(.source_index)|sort)==[range($count)])) |
  select(all(.new_findings[]; (.path|type)=="string" and (.path|test("\\S")) and
    (.body|type)=="string" and (.body|test("\\S")) and
    (.line|type)=="number" and .line>=1 and .line==(.line|floor) and
    (.severity|IN("high","medium","low")) and (.verification|IN("confirmed","unverified"))))
' "$WORK_DIR/session.json" >"$WORK_DIR/verdict.json" || exit "$REVIEW_INCOMPLETE_RC"
jq -e '.complete and .confident and all(.new_findings[]; .verification=="confirmed")' \
  "$WORK_DIR/verdict.json" >/dev/null || exit 6
# Keep the per-item evidence in the private per-head report, before temporary
# worktree/session cleanup. It is not a validator or approval run marker.
cat "$WORK_DIR/verdict.json"
jq -n --arg repo "$REPO" --argjson number "$NUMBER" --arg sha "$SHA" --arg source "$PREVIOUS" \
  --slurpfile items "$WORK_DIR/items.json" --slurpfile verdict "$WORK_DIR/verdict.json" '
  [$verdict[0].verdicts[]|select(.settled|not)|.source_index] as $open |
  [$items[0]|to_entries[]|select(.key as $i|$open|index($i))|.value] as $kept |
  ([$kept[]|select(.kind=="body")|.value]|join("\n\n")) as $body |
  ([$kept[]|select(.kind=="comment")|.value|
    .body=("Still open from "+$source+" (original line): "+.body)] +
   [$verdict[0].new_findings[]|{path,line,body}]) as $comments |
  {version:1,repo:$repo,number:$number,sha:$sha,basis:"incremental",
   findings:(($comments|length)+(if $body=="" then 0 else 1 end)),body:$body,comments:$comments}
' >"$WORK_DIR/findings.json" || exit 1
[ "$(wc -c <"$WORK_DIR/findings.json")" -le 262144 ] || exit "$REVIEW_INCOMPLETE_RC"
target_current >/dev/null || exit $?
temp="$(mktemp "$OUT.XXXXXX")" || exit 1
if ! cat "$WORK_DIR/findings.json" >"$temp" || ! mv "$temp" "$OUT"; then rm -f "$temp"; exit 1; fi
echo "=== private follow-up: $(jq .findings "$OUT") findings; nothing posted, no approval"
