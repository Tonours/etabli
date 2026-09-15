#!/bin/sh
set -eu

tmp_dir="$(mktemp -d -t etabli-privacy-smoke.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT INT TERM HUP
repo_root="$(git rev-parse --show-toplevel)"
brain_root="${PRIVACY_BRAIN_ROOT:-$repo_root/../brain}"
obvault_root="${PRIVACY_OBVAULT_ROOT:-$repo_root/../obvault}"

printf '%s\n' 'PRD-none #1 Greptile /Users/example/Library/Application Support/app' > "$tmp_dir/public.md"
if scripts/public-privacy-scan --paths "$tmp_dir/public.md" >/dev/null 2>&1; then
  echo 'expected scanner rejection' >&2
  exit 1
fi
for fixture in \
  'pr-issue|PR-123' \
  'commit|aBcdef1' \
  'opaque|abcdef0123456789abcdef0123456789' \
  'path|src/private.ts' \
  'provider|gpt-9' \
  'work-stack|employer' \
  'campaign|R-123'; do
  kind="${fixture%%|*}"
  token="${fixture#*|}"
  printf '%s\n' "$token" > "$tmp_dir/$kind.md"
  if scripts/public-privacy-scan --report-only --redact-tokens --paths "$tmp_dir/$kind.md" > "$tmp_dir/$kind.out" 2>&1; then
    echo "expected $kind scanner rejection" >&2
    exit 1
  fi
  rg -q "\\\"class\\\": \\\"$kind\\\"" "$tmp_dir/$kind.out" || {
    echo "scanner did not report class $kind" >&2
    exit 1
  }
done
if scripts/public-privacy-scan >/dev/null 2>&1; then
  echo 'expected missing-path rejection' >&2
  exit 1
fi
printf '%s\n' '{"schema_version":1,"synthetic_ids":["not-a-fixture"],"opaque_sha256":[]}' > "$tmp_dir/bad-allowlist.json"
if scripts/public-privacy-scan --paths "$tmp_dir/public.md" --allowlist "$tmp_dir/bad-allowlist.json" >/dev/null 2>&1; then
  echo 'expected allowlist-schema rejection' >&2
  exit 1
fi

cp .workflow/self-improvement-privacy-20260914/classification.json "$tmp_dir/manifest.json"
cp .workflow/self-improvement-privacy-20260914/local-artifacts.json "$tmp_dir/local-artifacts.json"
generated_manifest="$tmp_dir/generated-manifest.json"
scripts/privacy-classification-check --generate --root . --output "$generated_manifest" >/dev/null
node - "$generated_manifest" <<'NODE'
const fs = require('fs')
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const ranges = new Set(manifest.units.map((unit) => `${unit.source_file}:${unit.start_line}-${unit.end_line}:${unit.classification}`))
for (const expected of [
  'workflow/self-improvement/reviewer-eval-corpus.md:413-416:public-safe',
  'workflow/self-improvement/reviewer-eval-corpus.md:417-417:Brain',
  'workflow/self-improvement/reviewer-eval-corpus.md:418-423:public-safe',
  'workflow/self-improvement/review-metrics.md:9-16:public-safe',
  'workflow/self-improvement/review-metrics.md:17-19:public-safe',
  'workflow/self-improvement/review-metrics.md:76-78:Brain',
  'workflow/self-improvement/review-metrics.md:79-79:public-safe',
]) if (!ranges.has(expected)) throw new Error(`missing generated atomic range: ${expected}`)
const committed = JSON.parse(fs.readFileSync('.workflow/self-improvement-privacy-20260914/classification.json', 'utf8'))
const normalize = (units) => units
  .filter((unit) => unit.source_state === 'tracked-head')
  .sort((left, right) => `${left.source_file}:${left.start_line}:${left.end_line}`.localeCompare(`${right.source_file}:${right.start_line}:${right.end_line}`))
  .map((unit) => ({ ...unit }))
if (JSON.stringify(normalize(manifest.units)) !== JSON.stringify(normalize(committed.units))) throw new Error('generated tracked manifest diverges from committed manifest')
NODE
PRIVACY_PHASE=post-delete scripts/privacy-classification-check --manifest "$tmp_dir/manifest.json" --local-artifacts "$tmp_dir/local-artifacts.json" --root . >/dev/null
node - "$tmp_dir/manifest.json" <<'NODE'
const fs = require('fs')
const path = process.argv[2]
const manifest = JSON.parse(fs.readFileSync(path, 'utf8'))
const unit = manifest.units.find((entry) => entry.unit_id === 'unit-002')
unit.classification = 'Obvault'
unit.destination_repo = 'Tonours/obvault'
unit.destination_note = 'kb/etabli-self-improvement-harness-contract.md'
fs.writeFileSync(path, JSON.stringify(manifest))
NODE
if PRIVACY_PHASE=post-delete scripts/privacy-classification-check --manifest "$tmp_dir/manifest.json" --local-artifacts "$tmp_dir/local-artifacts.json" --root . >"$tmp_dir/routing.out" 2>"$tmp_dir/routing.err"; then
  echo 'expected context-routing rejection' >&2
  exit 1
fi
rg -q 'wrong destination|context basis mismatch|Obvault classification requires etabli context' "$tmp_dir/routing.err" || {
  echo 'context-routing rejection had an unexpected reason' >&2
  exit 1
}

cp .workflow/self-improvement-privacy-20260914/classification.json "$tmp_dir/manifest.json"
PRIVACY_PHASE=post-delete scripts/privacy-classification-check --manifest "$tmp_dir/manifest.json" --local-artifacts "$tmp_dir/local-artifacts.json" --root . >/dev/null
node - "$tmp_dir/manifest.json" <<'NODE'
const fs = require('fs')
const cp = require('child_process')
const path = process.argv[2]
const manifest = JSON.parse(fs.readFileSync(path, 'utf8'))
const unit = manifest.units.find((entry) => entry.unit_id === 'unit-001')
const source = cp.execFileSync('git', ['show', `HEAD:${unit.source_file}`], { encoding: 'utf8' })
const line = source.split(/\r?\n/).find((entry) => entry.length >= 40)
unit.rationale = `prefix-${line}-suffix`
fs.writeFileSync(path, JSON.stringify(manifest))
NODE
if PRIVACY_PHASE=post-delete scripts/privacy-classification-check --manifest "$tmp_dir/manifest.json" --local-artifacts "$tmp_dir/local-artifacts.json" --root . >"$tmp_dir/metadata.out" 2>"$tmp_dir/metadata.err"; then
  echo 'expected metadata-copy rejection' >&2
  exit 1
fi
rg -q 'metadata copies source text' "$tmp_dir/metadata.err" || {
  echo 'metadata-copy rejection had an unexpected reason' >&2
  exit 1
}

cp .workflow/self-improvement-privacy-20260914/classification.json "$tmp_dir/gap-manifest.json"
node - "$tmp_dir/gap-manifest.json" <<'NODE'
const fs = require('fs')
const cp = require('child_process')
const crypto = require('crypto')
const path = process.argv[2]
const data = JSON.parse(fs.readFileSync(path, 'utf8'))
const unit = data.units.find((entry) => entry.unit_id === 'unit-001')
unit.end_line -= 1
const source = cp.execFileSync('git', ['show', `HEAD:${unit.source_file}`])
const offsets = [0]
for (let index = 0; index < source.length; index += 1) if (source[index] === 10) offsets.push(index + 1)
unit.source_slice_sha256 = crypto.createHash('sha256').update(source.subarray(offsets[unit.start_line - 1], offsets[unit.end_line] ?? source.length)).digest('hex')
fs.writeFileSync(path, JSON.stringify(data))
NODE
if PRIVACY_PHASE=post-delete scripts/privacy-classification-check --manifest "$tmp_dir/gap-manifest.json" --local-artifacts "$tmp_dir/local-artifacts.json" --root . >"$tmp_dir/gap.out" 2>&1; then
  echo 'expected primary gap rejection' >&2
  exit 1
fi
rg -q 'gap in primary coverage' "$tmp_dir/gap.out" || { echo 'gap fixture failed for an unexpected reason' >&2; exit 1; }
cp .workflow/self-improvement-privacy-20260914/classification.json "$tmp_dir/overlap-manifest.json"
node - "$tmp_dir/overlap-manifest.json" <<'NODE'
const fs = require('fs')
const cp = require('child_process')
const crypto = require('crypto')
const path = process.argv[2]
const data = JSON.parse(fs.readFileSync(path, 'utf8'))
const first = data.units.find((entry) => entry.unit_id === 'unit-001')
const second = data.units.find((entry) => entry.unit_id === 'unit-002')
second.start_line = first.end_line
const source = cp.execFileSync('git', ['show', `HEAD:${second.source_file}`])
const offsets = [0]
for (let index = 0; index < source.length; index += 1) if (source[index] === 10) offsets.push(index + 1)
second.source_slice_sha256 = crypto.createHash('sha256').update(source.subarray(offsets[second.start_line - 1], offsets[second.end_line] ?? source.length)).digest('hex')
fs.writeFileSync(path, JSON.stringify(data))
NODE
if PRIVACY_PHASE=post-delete scripts/privacy-classification-check --manifest "$tmp_dir/overlap-manifest.json" --local-artifacts "$tmp_dir/local-artifacts.json" --root . >"$tmp_dir/overlap.out" 2>&1; then
  echo 'expected primary overlap rejection' >&2
  exit 1
fi
rg -q 'overlapping ranges' "$tmp_dir/overlap.out" || { echo 'overlap fixture failed for an unexpected reason' >&2; exit 1; }

cp .workflow/self-improvement-privacy-20260914/classification.json "$tmp_dir/unsafe-manifest.json"
node - "$tmp_dir/unsafe-manifest.json" <<'NODE'
const fs = require('fs')
const path = process.argv[2]
const data = JSON.parse(fs.readFileSync(path, 'utf8'))
data.units.find((entry) => entry.classification === 'Brain').destination_note = '../escape.md'
fs.writeFileSync(path, JSON.stringify(data))
NODE
if scripts/privacy-destination-check --manifest "$tmp_dir/unsafe-manifest.json" --receipts .workflow/self-improvement-privacy-20260914/receipts.json --brain-root "$brain_root" --obvault-root "$obvault_root" >/dev/null 2>&1; then
  echo 'expected unsafe destination rejection' >&2
  exit 1
fi
cp .workflow/self-improvement-privacy-20260914/classification.json "$tmp_dir/marker-manifest.json"
node - "$tmp_dir/marker-manifest.json" <<'NODE'
const fs = require('fs')
const path = process.argv[2]
const data = JSON.parse(fs.readFileSync(path, 'utf8'))
data.units.find((entry) => entry.classification === 'Brain').source_slice_sha256 = 'a'.repeat(64)
fs.writeFileSync(path, JSON.stringify(data))
NODE
if scripts/privacy-destination-check --manifest "$tmp_dir/marker-manifest.json" --receipts .workflow/self-improvement-privacy-20260914/receipts.json --brain-root "$brain_root" --obvault-root "$obvault_root" >/dev/null 2>&1; then
  echo 'expected marker/hash mismatch rejection' >&2
  exit 1
fi

first_receipts="$tmp_dir/first-receipts.json"
scripts/privacy-destination-check --manifest .workflow/self-improvement-privacy-20260914/classification.json --receipts "$first_receipts" --brain-root "$brain_root" --obvault-root "$obvault_root" --generate-receipts --receipt-action created >/dev/null
node - "$first_receipts" <<'NODE'
const fs = require('fs')
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
if (data.receipts.length !== 91 || data.receipts.some((receipt) => receipt.action !== 'created')) throw new Error('first-pass receipts must be created')
NODE
scripts/privacy-destination-check --manifest .workflow/self-improvement-privacy-20260914/classification.json --receipts "$first_receipts" --brain-root "$brain_root" --obvault-root "$obvault_root" --generate-receipts --receipt-action created >/dev/null
node - "$first_receipts" <<'NODE'
const fs = require('fs')
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
if (data.receipts.length !== 91 || data.receipts.some((receipt) => receipt.action !== 'created')) throw new Error('same-file first-pass retry must remain created')
NODE
unlink "$first_receipts"
retry_receipts="$tmp_dir/retry-receipts.json"
scripts/privacy-destination-check --manifest .workflow/self-improvement-privacy-20260914/classification.json --receipts "$retry_receipts" --brain-root "$brain_root" --obvault-root "$obvault_root" --generate-receipts --receipt-action already-present >/dev/null
node - "$retry_receipts" <<'NODE'
const fs = require('fs')
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
if (data.receipts.length !== 91 || data.receipts.some((receipt) => receipt.action !== 'already-present')) throw new Error('retry receipts must be already-present')
NODE
scripts/privacy-destination-check --manifest .workflow/self-improvement-privacy-20260914/classification.json --receipts "$retry_receipts" --brain-root "$brain_root" --obvault-root "$obvault_root" --generate-receipts --receipt-action already-present >/dev/null
node - "$retry_receipts" <<'NODE'
const fs = require('fs')
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
if (data.receipts.length !== 91 || data.receipts.some((receipt) => receipt.action !== 'already-present')) throw new Error('same-file retry must remain already-present')
NODE
node - "$retry_receipts" <<'NODE'
const fs = require('fs')
const path = process.argv[2]
const data = JSON.parse(fs.readFileSync(path, 'utf8'))
data.receipts[0].action = 'already-present'
data.receipts.reverse()
fs.writeFileSync(path, JSON.stringify(data))
NODE
scripts/privacy-destination-check --manifest .workflow/self-improvement-privacy-20260914/classification.json --receipts "$retry_receipts" --brain-root "$brain_root" --obvault-root "$obvault_root" --generate-receipts >/dev/null
node - "$retry_receipts" <<'NODE'
const fs = require('fs')
const path = process.argv[2]
const data = JSON.parse(fs.readFileSync(path, 'utf8'))
data.receipts[0] = data.receipts[1]
fs.writeFileSync(path, JSON.stringify(data))
NODE
if scripts/privacy-destination-check --manifest .workflow/self-improvement-privacy-20260914/classification.json --receipts "$retry_receipts" --brain-root "$brain_root" --obvault-root "$obvault_root" --generate-receipts >/dev/null 2>&1; then
  echo 'expected duplicate-and-missing receipt rejection' >&2
  exit 1
fi

repo_dir="$tmp_dir/repo"
control_dir="$tmp_dir/control"
mkdir -p "$repo_dir" "$control_dir"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email smoke@example.invalid
git -C "$repo_dir" config user.name smoke
printf '%s\n' safe > "$repo_dir/safe.md"
printf '%s\n' ignored.txt > "$repo_dir/.gitignore"
printf '%s\n' '{"schema_version":1,"etabli":[],"brain":[],"obvault":[],"planned_creations":["planned.txt"],"planned_deletions":[]}' > "$control_dir/allowlist.json"
git -C "$repo_dir" add safe.md .gitignore
git -C "$repo_dir" commit -qm baseline
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output before.json
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output unchanged.json
scripts/privacy-worktree-check compare --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --before before.json --after unchanged.json
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope brain --allowlist-file allowlist.json --output planned-brain-before.json
printf '%s\n' planned > "$repo_dir/planned.txt"
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output planned-etabli-after.json
scripts/privacy-worktree-check compare --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --before before.json --after planned-etabli-after.json
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope brain --allowlist-file allowlist.json --output planned-brain-after.json
if scripts/privacy-worktree-check compare --repo "$repo_dir" --control-root "$control_dir" --scope brain --allowlist-file allowlist.json --before planned-brain-before.json --after planned-brain-after.json >/dev/null 2>&1; then
  echo 'expected cross-scope planned-path rejection' >&2
  exit 1
fi
unlink "$repo_dir/planned.txt"
printf '%s\n' before > "$repo_dir/ignored.txt"
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output ignored-before.json
printf '%s\n' after > "$repo_dir/ignored.txt"
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output ignored-after.json
if scripts/privacy-worktree-check compare --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --before ignored-before.json --after ignored-after.json >/dev/null 2>&1; then
  echo 'expected ignored-file mutation rejection' >&2
  exit 1
fi
unlink "$repo_dir/ignored.txt"
printf '%s\n' changed > "$repo_dir/safe.md"
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output after.json
if scripts/privacy-worktree-check compare --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --before before.json --after after.json >/dev/null 2>&1; then
  echo 'expected out-of-allowlist rejection' >&2
  exit 1
fi

git -C "$repo_dir" checkout -q -- safe.md
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output deletion-before.json
unlink "$repo_dir/safe.md"
scripts/privacy-worktree-check snapshot --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --output deletion-after.json
if scripts/privacy-worktree-check compare --repo "$repo_dir" --control-root "$control_dir" --scope etabli --allowlist-file allowlist.json --before deletion-before.json --after deletion-after.json >/dev/null 2>&1; then
  echo 'expected undeclared deletion rejection' >&2
  exit 1
fi

echo 'privacy migration negative smoke: ok'
