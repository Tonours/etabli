def remediation: "fix review_round/round_outcome or open a new review run (workflow/skills/review-rounds.md)";

def next_rounds($round; $outcome; $d_units):
  if $round == "T1" then (if $outcome == "clean" then ["F1"] else ["T2"] end)
  elif $round == "T2" then (if $outcome == "clean" then ["F1"] else ["D1"] end)
  elif $round == "D1" then
    (if $outcome == "clean" then ["F1"] elif $outcome == "findings" then ["D2"] else "blocked" end)
  elif $round == "D2" then (if $outcome == "widening" then "blocked" else ["F1"] end)
  elif $round == "F1" then
    (if $outcome == "clean" then "validated" elif $d_units < 2 then ["FD"] else "blocked" end)
  elif $round == "FD" then (if $outcome == "widening" then "blocked" else ["F2"] end)
  else (if $outcome == "clean" then "validated" else "blocked" end)
  end;

def admitted: if (.next | length) > 0 then .next | join(" or ") else "none" end;

def code_adversaries($events; $from; $to):
  [$events[$from:$to][] | select(.event == "adversary_completed" and .detail.mode == "code_diff") | .detail];

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
          | reduce ($reviews[$first:] | to_entries[]) as $entry (
            {err: null, next: ["T1"], spent: [], d: 0, state: "open", since: $start, last: null};
            if .err != null then .
            else
              ($entry.key + 1) as $rank
              | $entry.value.detail as $review
              | code_adversaries($events; .since; $entry.value.at) as $adversaries
              | if ($review | has("review_round")) | not
                then .err = "review_completed #\($rank) after activation has no review_round; admitted next: \(admitted): \(remediation)"
                else
                  $review.review_round as $round
                  | if $entry.value.version != "2"
                    then .err = "review round \($round) (#\($rank)) must be a schema_version 2 review_completed; admitted next: \(admitted): \(remediation)"
                    elif .state != "open"
                    then .err = "review round \($round) (#\($rank)) follows a \(.state) review budget; admitted next: \(admitted): \(remediation)"
                    elif (.spent | index($round)) != null
                    then .err = "review round \($round) (#\($rank)) is already spent; admitted next: \(admitted): \(remediation)"
                    elif (.next | index($round)) == null
                    then .err = "review round \($round) (#\($rank)) is not allowed here; admitted next: \(admitted): \(remediation)"
                    elif ($round | IN("T1", "T2", "F1", "F2")) and ($adversaries | length) == 0
                    then .err = "review round \($round) (#\($rank)) has no code_diff adversary_completed since the previous round; admitted next: \(admitted): \(remediation)"
                    elif $review.round_outcome == "clean"
                      and ($review.status == "BLOCK" or any($adversaries[]; (.verdict | IN("GO", "GO WITH NOTES") | not) or .accepted_findings != []))
                    then .err = "review round \($round) (#\($rank)) is declared clean but its review is BLOCK or an adversary of the round is not GO/GO WITH NOTES with an empty accepted_findings array; admitted next: \(admitted): \(remediation)"
                    else
                      (if $round | IN("D1", "D2", "FD") then .d + 1 else .d end) as $d
                      | next_rounds($round; $review.round_outcome; $d) as $after
                      | .since = $entry.value.at + 1
                      | .last = "\($round) (#\($rank))"
                      | .spent += [$round]
                      | .d = $d
                      | if ($after | type) == "string" then .state = $after | .next = [] else .next = $after end
                    end
                end
            end)
          | if .err != null then .err
            elif .state == "validated" and (code_adversaries($events; .since; $events | length) | length) > 0
            then "code_diff adversary_completed after the closing clean round \(.last); admitted next: \(admitted): \(remediation)"
            elif any($events[]; .event == "completed") and .state != "validated"
            then "completed requires a clean final F1 or F2 review round (budget is \(.state)); admitted next: \(admitted): \(remediation)"
            else null end
        end
    end;

envelope_error // round_error // empty
