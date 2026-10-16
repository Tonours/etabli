def remediation: "fix review_round/round_outcome or open a new review run (workflow/skills/review-rounds.md)";

def legacy_round: IN("F1", "F2", "FD");

# Former T→F machine, kept only for ledgers that already hold an F1/F2/FD round.
def legacy_next($round; $outcome; $d_units):
  if $round == "T1" then (if $outcome == "clean" then ["F1"] else ["T2"] end)
  elif $round == "T2" then (if $outcome == "clean" then ["F1"] else ["D1"] end)
  elif $round == "D1" then
    (if $outcome == "clean" then ["F1"] elif $outcome == "findings" then ["D2"] else "blocked" end)
  elif $round == "D2" then (if $outcome == "widening" then "blocked" else ["F1"] end)
  elif $round == "F1" then
    (if $outcome == "clean" then "validated" elif $d_units < 2 then ["FD"] else "blocked" end)
  elif $round == "FD" then (if $outcome == "widening" then "blocked" else ["F2"] end)
  else (if $outcome == "clean" then "validated" else "blocked" end)
  end
  | if type == "string" then {state: ., next: []} else {state: "open", next: .} end;

def unspent($kinds; $spent): [$kinds[] | select(. as $kind | $spent | index($kind) | not)][:1];

# $spent already holds $round. Clean validates and still admits the next D (fold)
# and the next T (larger delta); widening on a T round counts as findings.
def next_rounds($round; $outcome; $spent):
  if $outcome == "clean" then {state: "validated", next: (unspent(["D1", "D2"]; $spent) + unspent(["T1", "T2"]; $spent))}
  elif $round == "T1" then {state: "open", next: ["T2"]}
  elif ($round | IN("D1", "D2")) and $outcome == "widening" then {state: "open", next: unspent(["T1", "T2"]; $spent)}
  else {state: "open", next: unspent(["D1", "D2"]; $spent)}
  end
  | if .state == "open" and .next == [] then .state = "blocked" else . end;

def admitted: if (.next | length) > 0 then .next | join(" or ") else "none" end;

def code_adversaries($events; $from; $to):
  [$events[$from:$to][] | select(.event == "adversary_completed" and .detail.mode == "code_diff") | .detail];

# At least one code_diff adversary after the last file_changed of the window.
def fresh_adversary($events; $from; $to):
  ([range($from; $to) | select($events[.].event == "file_changed")] | last // ($from - 1)) as $last_change
  | any(range($last_change + 1; $to); $events[.].event == "adversary_completed" and $events[.].detail.mode == "code_diff");

# Contractual surfaces of review-rounds.md § Delta re-review.
def contractual_path:
  test("(^|[/\\s,])(workflow|scripts|tests|skills|docs|\\.github|claude/scopes)/|(^|[/\\s,])(AGENTS\\.md|PLAN_TEMPLATE[^/\\s,]*\\.md|\\.mcp\\.json|[^/\\s,]*\\.policy\\.json|([^/\\s,]*[._-])?lock(b|file)?([._-][^/\\s,]*)?)($|[\\s,])");

def contractual_change($events; $from; $to):
  any($events[$from:$to][] | select(.event == "file_changed") | .detail | objects | (.path, .paths[]?) | strings; contractual_path);

# Missing or legacy-shaped findings are never blocking-free.
def blocking_free: (.accepted_findings | type == "array") and all(.accepted_findings[]; type == "object" and .blocking == false);

def canonical_envelope:
  (.schema_version | IN(null, 1, 2, "1", "2")) and (.event | type == "string" and test("\\A[a-z_]+\\z"));

def envelope_error:
  [to_entries[] | select(.value | canonical_envelope | not) | .key + 1] | first
  | if . == null then null
    else "line \(.): non-canonical event envelope (schema_version must be absent, 1 or 2; event must be lowercase letters and underscores only)" end;

def round_error:
  map(.schema_version = (.schema_version | tostring)) as $events
  | ([$events | to_entries[] | select(.value.schema_version == "2" and .value.event == "route_decided" and (.value.detail.route == "plan-implement" or (.value.detail.route == "review" and .value.detail.contract_path == "pi/durable"))) | .key] | first) as $route_at
  | if $route_at == null
    then null
    else
      [$events | to_entries[] | select(.value.event == "review_completed") | {at: .key, version: .value.schema_version, detail: .value.detail}] as $reviews
      | ($reviews | map(.detail | has("review_round")) | index(true)) as $first
      | if $first == null then null
        else
          ([$route_at + 1, (if $first > 0 then $reviews[$first - 1].at + 1 else 0 end)] | max) as $start
          # On append the candidate is the last event: it never selects the legacy machine,
          # so a first F round lands in the new machine and is refused there.
          | ($ARGS.named.append == true) as $append
          | any($reviews[$first:][]; (.detail.review_round | legacy_round) and (($append | not) or .at < ($events | length) - 1)) as $legacy
          | reduce ($reviews[$first:] | to_entries[]) as $entry (
            {err: null, next: ["T1"], spent: [], d: 0, state: "open", since: $start, last: null, outcome: null};
            if .err != null then .
            else
              ($entry.key + 1) as $rank
              | $entry.value.detail as $review
              | code_adversaries($events; .since; $entry.value.at) as $adversaries
              | if ($review | has("review_round")) | not
                then .err = "review_completed #\($rank) after activation has no review_round; admitted next: \(admitted): \(remediation)"
                else
                  $review.review_round as $round
                  | (if $legacy then $round | IN("T1", "T2", "F1", "F2")
                     else ($round | IN("T1", "T2")) or .outcome != "clean" or contractual_change($events; .since; $entry.value.at) end) as $needs_adversary
                  | if $entry.value.version != "2"
                    then .err = "review round \($round) (#\($rank)) must be a schema_version 2 review_completed; admitted next: \(admitted): \(remediation)"
                    elif .state == "blocked" or ($legacy and .state != "open")
                    then .err = "review round \($round) (#\($rank)) follows a \(.state) review budget; admitted next: \(admitted): \(remediation)"
                    elif (.spent | index($round)) != null
                    then .err = "review round \($round) (#\($rank)) is already spent; admitted next: \(admitted): \(remediation)"
                    elif (.next | index($round)) == null
                    then .err = "review round \($round) (#\($rank)) is not allowed here; admitted next: \(admitted): \(remediation)"
                    elif $needs_adversary and ($adversaries | length) == 0
                    then .err = "review round \($round) (#\($rank)) has no code_diff adversary_completed since the previous round; admitted next: \(admitted): \(remediation)"
                    elif $needs_adversary and ($legacy | not) and (fresh_adversary($events; .since; $entry.value.at) | not)
                    then .err = "review round \($round) (#\($rank)) has no code_diff adversary_completed after the last file_changed of its round; admitted next: \(admitted): \(remediation)"
                    elif $review.round_outcome == "clean"
                      and ($review.status == "BLOCK" or any($adversaries[]; (.verdict | IN("GO", "GO WITH NOTES") | not) or (if $legacy then .accepted_findings != [] else blocking_free | not end)))
                    then .err = "review round \($round) (#\($rank)) is declared clean but its review is BLOCK or an adversary of the round is not GO/GO WITH NOTES \(if $legacy then "with an empty accepted_findings array" else "with an accepted_findings array free of blocking findings" end); admitted next: \(admitted): \(remediation)"
                    else
                      (if $round | IN("D1", "D2", "FD") then .d + 1 else .d end) as $d
                      | (.spent + [$round]) as $spent
                      | (if $legacy then legacy_next($round; $review.round_outcome; $d)
                         else next_rounds($round; $review.round_outcome; $spent) end) as $after
                      | .since = $entry.value.at + 1
                      | .last = "\($round) (#\($rank))"
                      | .spent = $spent
                      | .d = $d
                      | .outcome = $review.round_outcome
                      | .state = $after.state
                      | .next = $after.next
                    end
                end
            end)
          | any($events[]; .event == "completed") as $completed
          | if .err != null then .err
            elif .state == "validated" and ($legacy or $completed or .next == []) and (code_adversaries($events; .since; $events | length) | length) > 0
            then "code_diff adversary_completed after the closing clean round \(.last); admitted next: \(admitted): \(remediation)"
            elif $completed and .state != "validated"
            then "completed requires a clean closing review round (budget is \(.state)); admitted next: \(admitted): \(remediation)"
            else null end
        end
    end;

envelope_error // round_error // empty
