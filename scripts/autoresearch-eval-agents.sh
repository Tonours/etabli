#!/usr/bin/env bash
# autoresearch-eval-agents.sh — Evaluate AGENTS.md / CLAUDE.md profile alignment
# Outputs structured METRIC lines for autoresearch parsing
set -euo pipefail

PASS=0
FAIL=0
TOTAL_RULES=0
TOTAL_WORDS=0

# --- Helpers ---
count_actionable_rules() {
  local file="$1"
  # Count lines that look like rules: start with - or * or are numbered directives
  # Exclude blank lines, headers, pure prose paragraphs
  local rules
  rules=$(grep -cE '^\s*[-*]\s+\S' "$file" 2>/dev/null || echo 0)
  echo "$rules"
}

count_words() {
  local file="$1"
  wc -w < "$file" | tr -d ' '
}

check_no_contradictions() {
  local f1="$1" f2="$2"
  # Check that key terms don't appear with opposite directives
  # e.g. "any" allowed vs "no any" — simplistic but catches obvious conflicts
  local conflicts=0
  
  # Check "any" policy consistency
  local any_strict_1 any_strict_2
  any_strict_1=$(grep -ciE 'no\s+any|any.*forbidden|any.*interdit|interdit.*any' "$f1" 2>/dev/null || true)
  any_strict_2=$(grep -ciE 'no\s+any|any.*forbidden|any.*interdit|interdit.*any' "$f2" 2>/dev/null || true)
  any_strict_1=${any_strict_1:-0}
  any_strict_2=${any_strict_2:-0}

  # Check language consistency (fr/en)
  local lang_1 lang_2
  lang_1=$(grep -ciE 'fran.ais.*communication|french.*communication' "$f1" 2>/dev/null || true)
  lang_2=$(grep -ciE 'fran.ais.*communication|french.*communication' "$f2" 2>/dev/null || true)
  lang_1=${lang_1:-0}
  lang_2=${lang_2:-0}
  
  if [ "$lang_1" -eq 0 ] && [ "$lang_2" -gt 0 ]; then
    conflicts=$((conflicts + 1))
  fi
  
  echo "$conflicts"
}

check_pi_compat() {
  local file="$1"
  local compat=0
  
  # Must reference extensions or skills or pi structure
  if grep -qE 'pi/extensions|pi/skills|extensions|skills' "$file" 2>/dev/null; then
    compat=$((compat + 1))
  fi
  
  # Must reference workflow or ticket format
  if grep -qE 'workflow|ticket|ticket-template' "$file" 2>/dev/null; then
    compat=$((compat + 1))
  fi
  
  # Must reference commit format
  if grep -qE 'commit|feat|fix|refactor' "$file" 2>/dev/null; then
    compat=$((compat + 1))
  fi
  
  echo "$compat"
}

check_profile_keywords() {
  local file="$1"
  local score=0
  
  # ADHD-compatible / cognitive load
  if grep -qiE 'cognitiv|charge.*cognitiv|ADHD|interruption|reprendre|reprise|resume' "$file"; then
    score=$((score + 2))
  fi
  
  # Proof-first / artifact-first
  if grep -qiE 'proof|preuve|artifact|artefact|repo.*state|log.*evidence' "$file"; then
    score=$((score + 2))
  fi
  
  # Direct communication / no filler
  if grep -qiE 'direct|concret|no filler|pas.*remplissage|concis|low.*noise|bas.*bruit' "$file"; then
    score=$((score + 2))
  fi
  
  # Feedback style
  if grep -qiE 'feedback|correction|push.*back|challenge|contre-argument' "$file"; then
    score=$((score + 1))
  fi
  
  # Small reversible steps
  if grep -qiE 'reversible|small.*step|petit.*pas|atomique|atom' "$file"; then
    score=$((score + 2))
  fi
  
  # Close loops / no open-ended
  if grep -qiE 'close.*loop|fermer.*boucle|next.*action|prochaine.*action|loop.*ouvert' "$file"; then
    score=$((score + 2))
  fi
  
  # One recommended default
  if grep -qiE 'one.*default|recommand.*d.fault|d.faut.*recommand' "$file"; then
    score=$((score + 1))
  fi
  
  # YAGNI / KISS / DRY
  if grep -qiE 'YAGNI|KISS|DRY|simplicit' "$file"; then
    score=$((score + 1))
  fi
  
  # Anti-sycophancy / contrarian (must be kept)
  if grep -qiE 'sycophan|contrarian|challenge|anti-syco' "$file"; then
    score=$((score + 2))
  fi
  
  # TypeScript strict / no any
  if grep -qiE 'typescript.*strict|no.*any|strict.*type' "$file"; then
    score=$((score + 1))
  fi
  
  echo "$score"
}

# --- Main evaluation ---
GLOBAL_AGENTS="pi/AGENTS.md"
CLAUDE_MD="claude/CLAUDE.md"
REPO_AGENTS="AGENTS.md"

# Check all files exist
for f in "$GLOBAL_AGENTS" "$CLAUDE_MD" "$REPO_AGENTS"; do
  if [ ! -f "$f" ]; then
    echo "METRIC profile_alignment_score=0"
    echo "METRIC status=crash"
    echo "ERROR: $f not found"
    exit 1
  fi
done

# 1. Count actionable rules per file
rules_global=$(count_actionable_rules "$GLOBAL_AGENTS")
rules_claude=$(count_actionable_rules "$CLAUDE_MD")
rules_repo=$(count_actionable_rules "$REPO_AGENTS")
total_rules=$((rules_global + rules_claude + rules_repo))

# 2. Count words per file
words_global=$(count_words "$GLOBAL_AGENTS")
words_claude=$(count_words "$CLAUDE_MD")
words_repo=$(count_words "$REPO_AGENTS")
total_words=$((words_global + words_claude + words_repo))

# 3. Density = rules / words (higher = better, target > 0.06)
if [ "$total_words" -gt 0 ]; then
  density=$((total_rules * 1000 / total_words))
else
  density=0
fi

# 4. Profile keyword score per file
profile_global=$(check_profile_keywords "$GLOBAL_AGENTS")
profile_claude=$(check_profile_keywords "$CLAUDE_MD")
profile_repo=$(check_profile_keywords "$REPO_AGENTS")
total_profile=$((profile_global + profile_claude + profile_repo))

# 5. Contradiction checks
contra_1=$(check_no_contradictions "$GLOBAL_AGENTS" "$CLAUDE_MD")
contra_2=$(check_no_contradictions "$GLOBAL_AGENTS" "$REPO_AGENTS")
contra_3=$(check_no_contradictions "$CLAUDE_MD" "$REPO_AGENTS")
total_contra=$((contra_1 + contra_2 + contra_3))

# 6. Pi compatibility per file
compat_global=$(check_pi_compat "$GLOBAL_AGENTS")
compat_claude=$(check_pi_compat "$CLAUDE_MD")
compat_repo=$(check_pi_compat "$REPO_AGENTS")
total_compat=$((compat_global + compat_claude + compat_repo))

# 7. Composite score (0-100)
# Weight: profile 40%, density 20%, compat 20%, no-contradiction 20%
profile_pct=$((total_profile * 100 / 48))       # max 16 per file * 3 = 48 (2+2+2+1+2+2+1+1+2+1)
density_pct=$((density * 100 / 60))              # target 0.06 = 60 per mille
compat_pct=$((total_compat * 100 / 9))           # max 3 per file * 3 = 9
contra_pct=$(( (3 - total_contra) * 100 / 3 ))   # max 3 pairs, 0 contradictions = 100

# Clamp to 0-100
profile_pct=$((profile_pct > 100 ? 100 : profile_pct))
density_pct=$((density_pct > 100 ? 100 : density_pct))
compat_pct=$((compat_pct > 100 ? 100 : compat_pct))
contra_pct=$((contra_pct > 100 ? 100 : contra_pct))
contra_pct=$((contra_pct < 0 ? 0 : contra_pct))

composite=$(( (profile_pct * 40 + density_pct * 20 + compat_pct * 20 + contra_pct * 20) / 100 ))

echo "METRIC profile_alignment_score=$composite"
echo "METRIC density_permille=$density"
echo "METRIC total_actionable_rules=$total_rules"
echo "METRIC total_words=$total_words"
echo "METRIC profile_keywords=$total_profile"
echo "METRIC contradictions=$total_contra"
echo "METRIC pi_compat=$total_compat"
echo "METRIC profile_global=$profile_global"
echo "METRIC profile_claude=$profile_claude"
echo "METRIC profile_repo=$profile_repo"
echo "DETAIL density_pct=$density_pct profile_pct=$profile_pct compat_pct=$compat_pct contra_pct=$contra_pct"
