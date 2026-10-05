import json, os, re, subprocess, sys
R = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../..")); CFG = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
out = {}
b = json.load(open(f"{R}/workflow/runtime/context-budget.json"))
for k, v in b["surfaces"].items():
    out[f"surface_{k}_chars"] = sum(len(open(f"{R}/{f}", encoding="utf-8").read()) for f in v["files"] if os.path.exists(f"{R}/{f}"))
claude_start = [f"{R}/claude/CLAUDE.md", f"{R}/claude/RTK.md", f"{R}/CLAUDE.md", f"{R}/AGENTS.md", f"{R}/pi/AGENTS.md", f"{R}/workflow/agent-quick-card.md"]
out["claude_session_start_instruction_chars"] = sum(len(open(f, encoding="utf-8").read()) for f in claude_start)
def desc(p):
    t = open(p, errors="ignore").read()
    m = re.search(r"^description:\s*(.*?)(?=^\w[\w-]*:|^---)", t, re.S | re.M)
    return (m.group(1).strip() if m else ""), ("disable-model-invocation: true" in t)
live = json.load(open(os.environ.get("LEAN_BENCH_SETTINGS") or f"{CFG}/settings.json")).get("skillOverrides", {})
def discover(root):
    found = []
    for entry in sorted(os.listdir(root)):
        path = os.path.join(root, entry)
        if not os.path.isdir(path): continue
        if os.path.isfile(os.path.join(path, "SKILL.md")): found.append(path); continue
        for nested in sorted(os.listdir(path)):
            npath = os.path.join(path, nested)
            if os.path.isdir(npath) and os.path.isfile(os.path.join(npath, "SKILL.md")): found.append(npath)
    return found
def declared(path):
    m = re.search(r"^name:\s*[\"']?([a-z0-9][a-z0-9-]*)", open(os.path.join(path, "SKILL.md"), errors="ignore").read(), re.M)
    return m.group(1) if m else os.path.basename(path)
vis = n = 0
for path in discover(f"{CFG}/skills"):
    name = declared(path); ds, dmi = desc(os.path.join(path, "SKILL.md")); st = live.get(name, "on")
    if dmi or st in ("user-invocable-only", "off"): continue
    if st == "name-only": vis += len(name) + 20; n += 1; continue
    vis += len(name) + len(ds) + 20; n += 1
out["claude_live_listing_skills"] = n; out["claude_live_listing_chars"] = vis
pv = pn = 0
pd = os.path.expanduser("~/.pi/agent/skills")
for d in sorted(os.listdir(pd)):
    p = f"{pd}/{d}/SKILL.md"
    if not os.path.isfile(p): continue
    ds, dmi = desc(p)
    if dmi: continue
    pv += len(d) + len(ds) + 20; pn += 1
out["pi_listing_skills"] = pn; out["pi_listing_chars"] = pv
lc = subprocess.run([f"{R}/scripts/claude-skill-load-check"], capture_output=True, text=True, cwd=R, env={**os.environ, "CLAUDE_SKILL_LOAD_CLAUDE_DIR": CFG})
m = re.search(r"index_chars=(\d+)", lc.stdout); out["load_check_profile_index_chars"] = int(m.group(1)) if m else -1
out["load_check_exit"] = lc.returncode
out["load_check_fail_lines"] = lc.stderr.count("FAIL:")
out["load_check_warn_lines"] = lc.stdout.count("WARN:")
hooks = json.load(open(f"{CFG}/settings.json")).get("hooks", {}).get("PreToolUse", [])
cmds = [h["command"] for e in hooks if "Bash" in e.get("matcher", "") for h in e.get("hooks", []) if "rtk" in h.get("command", "")]
data = disp = drw = dsp = 0
for line in open(os.path.join(os.path.dirname(__file__), "rtk-corpus.txt")).read().strip().split("\n"):
    kind, c = line.split("\t"); payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": c}})
    new = c
    for hc in cmds:
        r = subprocess.run(hc, shell=True, input=payload, capture_output=True, text=True, cwd=R)
        try: new = json.loads(r.stdout).get("hookSpecificOutput", {}).get("updatedInput", {}).get("command", c)
        except Exception: pass
    ch = new != c
    if kind == "data": data += 1; drw += ch
    else: disp += 1; dsp += ch
def unsupported_violations(hook_commands, lines):
    rewritten = outputs = errors = 0
    for c in lines:
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": c}})
        new = c
        for hc in hook_commands:
            r = subprocess.run(hc, shell=True, input=payload, capture_output=True, text=True, cwd=R)
            outputs += r.stdout != "" or r.stderr != ""
            errors += r.returncode != 0
            try: new = json.loads(r.stdout).get("hookSpecificOutput", {}).get("updatedInput", {}).get("command", c)
            except Exception: pass
        rewritten += new != c
    return rewritten, outputs, errors
unsupported = open(os.path.join(os.path.dirname(__file__), "rtk-unsupported.txt")).read().strip().split("\n")
urw, uout, uerr = unsupported_violations(cmds, unsupported)
out["claude_rtk_unsupported_rewritten"] = f"{urw}/{len(unsupported)}"
out["claude_rtk_unsupported_hook_outputs"] = uout
out["claude_rtk_unsupported_hook_errors"] = uerr
controls = {
    "stdout_error": ("sh -c 'echo \"{}\"; exit 1'", 1, 1),
    "blank_stdout": ("sh -c 'echo \" \"'", 1, 0),
    "stderr_only": ("sh -c 'echo warn >&2'", 1, 0),
}
missed = [name for name, (hook, want_out, want_err) in controls.items() if unsupported_violations([hook], unsupported[:1])[1:] != (want_out, want_err)]
out["claude_rtk_unsupported_negative_control"] = "detected" if not missed else "missed:" + ",".join(missed)
out["claude_rtk_hooks"] = len(cmds)
out["claude_rtk_data_commands_rewritten"] = f"{drw}/{data}"; out["claude_rtk_display_commands_rewritten"] = f"{dsp}/{disp}"
for k, v in out.items(): print(f"{k}={v}")
