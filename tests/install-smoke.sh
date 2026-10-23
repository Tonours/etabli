#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
export ETABLI_SKIP_LIVE_CHECKS=1
# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/lib/install-main.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/fake-df"
cat >"$tmp_dir/fake-df/df" <<'EOF'
#!/bin/sh
if [ "$1" = "-kP" ]; then
  printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/mapper/vg-long-home 1000 900 100 90%% /home\n'
else
  printf 'Filesystem 1K-blocks Used Available Use%% Mounted on\n/dev/mapper/vg-long-home\n 1000 900 100 90%% /home\n'
fi
EOF
chmod +x "$tmp_dir/fake-df/df"
if (PATH="$tmp_dir/fake-df:$PATH" check_disk_space) >/dev/null 2>&1; then
  print_error "check_disk_space missed low space on a wrapped df line"
  exit 1
fi
mkdir -p "$tmp_dir/fake-rtk"
for rtk_version in 0.38.9 0.39.0 0.40.1 1.0.1 0.39 v1.0.0 "0.39.0 (abc1234)"; do
  printf '#!/bin/sh\n[ "$1" = --version ] && echo "rtk %s"\nexit 0\n' "$rtk_version" >"$tmp_dir/fake-rtk/rtk"
  chmod +x "$tmp_dir/fake-rtk/rtk"
  if (PATH="$tmp_dir/fake-rtk:$PATH" has_valid_rtk) >"$tmp_dir/rtk.out" 2>&1; then rtk_ok=1; else rtk_ok=0; fi
  grep -Fq -- "rtk $rtk_version" "$tmp_dir/rtk.out" || {
    print_error "has_valid_rtk did not log rtk --version for $rtk_version"
    exit 1
  }
  if [ "$rtk_version" = 0.38.9 ]; then expected_ok=0; else expected_ok=1; fi
  [ "$rtk_ok" -eq "$expected_ok" ] || {
    print_error "has_valid_rtk returned $rtk_ok for rtk $rtk_version"
    exit 1
  }
done
original_path="$PATH"

PATH="/tmp/asdf-shims:/usr/bin"
prepend_path_entry "/tmp/local-bin"
if [ "$PATH" != "/tmp/local-bin:/tmp/asdf-shims:/usr/bin" ]; then
  print_error "prepend_path_entry did not put the entry first"
  exit 1
fi

PATH="/tmp/asdf-shims:/tmp/local-bin:/usr/bin:/tmp/local-bin"
prepend_path_entry "/tmp/local-bin"
if [ "$PATH" != "/tmp/local-bin:/tmp/asdf-shims:/usr/bin" ]; then
  print_error "prepend_path_entry left a later copy of the entry"
  exit 1
fi

PATH=""
prepend_path_entry "/tmp/local-bin"
if [ "$PATH" != "/tmp/local-bin" ]; then
  print_error "prepend_path_entry did not initialize an empty PATH"
  exit 1
fi
PATH="$original_path"

(PATH="/tmp/odd[a]/bin:/usr/bin:/tmp/odd[a]/bin" && prepend_path_entry "/tmp/odd[a]/bin" && [ "$PATH" = "/tmp/odd[a]/bin:/usr/bin" ]) &
glob_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$glob_pid" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$glob_pid" 2>/dev/null; then
  kill "$glob_pid"
  print_error "prepend_path_entry looped on a PATH entry with glob characters"
  exit 1
fi
wait "$glob_pid" || {
  print_error "prepend_path_entry treated glob characters as a pattern"
  exit 1
}

rcfile="$tmp_dir/zshrc"
printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >"$rcfile"
ensure_local_bin_shell_path "$rcfile"
desired_rc_line='case ":${PATH:-}:" in *":$HOME/.local/bin:"*) ;; *) export PATH="${PATH:+$PATH:}$HOME/.local/bin" ;; esac'
if ! grep -Fxq "$desired_rc_line" "$rcfile"; then
  print_error "ensure_local_bin_shell_path did not install the order-preserving PATH line"
  exit 1
fi
if grep -Fxq 'export PATH="$HOME/.local/bin:$PATH"' "$rcfile"; then
  print_error "ensure_local_bin_shell_path kept the legacy PATH-prepending line"
  exit 1
fi

symlink_target="$tmp_dir/linked-zshrc-target"
symlink_rc="$tmp_dir/linked-zshrc"
printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >"$symlink_target"
ln -s "$symlink_target" "$symlink_rc"
ensure_local_bin_shell_path "$symlink_rc"
if [ ! -L "$symlink_rc" ]; then
  print_error "ensure_local_bin_shell_path replaced an rcfile symlink"
  exit 1
fi
if ! grep -Fxq "$desired_rc_line" "$symlink_target"; then
  print_error "ensure_local_bin_shell_path did not update the symlink target"
  exit 1
fi

smoke_grok_home="$tmp_dir/grok-home"
mkdir -p "$smoke_grok_home/.grok/bin" "$smoke_grok_home/.local/bin"
printf 'grok-bin\n' >"$smoke_grok_home/.grok/bin/grok-macos"
ln -s grok-macos "$smoke_grok_home/.grok/bin/grok"
ln -s grok-macos "$smoke_grok_home/.grok/bin/agent"
printf 'cursor-agent\n' >"$smoke_grok_home/.local/bin/agent"
prefer_cursor_agent_remove_grok_collision "$smoke_grok_home"
if [ -e "$smoke_grok_home/.grok/bin/agent" ] || [ -L "$smoke_grok_home/.grok/bin/agent" ]; then
  print_error "prefer_cursor_agent_remove_grok_collision left Grok's agent name"
  exit 1
fi
if [ ! -L "$smoke_grok_home/.grok/bin/grok" ]; then
  print_error "prefer_cursor_agent_remove_grok_collision removed Grok's grok launcher"
  exit 1
fi

smoke_custom_agent="$tmp_dir/custom-grok-agent"
mkdir -p "$smoke_custom_agent/.grok/bin"
printf 'custom-agent\n' >"$smoke_custom_agent/.grok/bin/agent"
printf 'grok-bin\n' >"$smoke_custom_agent/.grok/bin/grok"
prefer_cursor_agent_remove_grok_collision "$smoke_custom_agent"
if [ ! -f "$smoke_custom_agent/.grok/bin/agent" ]; then
  print_error "prefer_cursor_agent_remove_grok_collision removed a custom agent file"
  exit 1
fi

grok_rc="$tmp_dir/grok-zshrc"
printf '%s\n' 'export PATH="$HOME/.grok/bin:$PATH"' '# <<< grok installer <<<' >"$grok_rc"
prefer_cursor_agent_ensure_shell_hook "$grok_rc"
if ! grep -Fq "$prefer_cursor_agent_hook_begin" "$grok_rc"; then
  print_error "prefer_cursor_agent_ensure_shell_hook did not install the Cursor agent hook"
  exit 1
fi
if ! awk -v grok_end="$prefer_cursor_agent_grok_installer_end" -v begin="$prefer_cursor_agent_hook_begin" '
  $0 == grok_end { saw_grok = 1 }
  $0 == begin && saw_grok { found = 1 }
  END { exit !found }
' "$grok_rc"; then
  print_error "prefer_cursor_agent_ensure_shell_hook did not follow the Grok installer block"
  exit 1
fi
prefer_cursor_agent_ensure_shell_hook "$grok_rc"
if [ "$(grep -Fc "$prefer_cursor_agent_hook_begin" "$grok_rc")" -ne 1 ]; then
  print_error "prefer_cursor_agent_ensure_shell_hook duplicated the Cursor agent hook"
  exit 1
fi

symlink_hook_target="$tmp_dir/linked-hook-zshrc-target"
symlink_hook_rc="$tmp_dir/linked-hook-zshrc"
printf '%s\n' 'export PATH="$HOME/.grok/bin:$PATH"' >"$symlink_hook_target"
ln -s "$symlink_hook_target" "$symlink_hook_rc"
prefer_cursor_agent_ensure_shell_hook "$symlink_hook_rc"
if [ ! -L "$symlink_hook_rc" ]; then
  print_error "prefer_cursor_agent_ensure_shell_hook replaced an rcfile symlink"
  exit 1
fi
if ! grep -Fq "$prefer_cursor_agent_hook_begin" "$symlink_hook_target"; then
  print_error "prefer_cursor_agent_ensure_shell_hook did not update the symlink target"
  exit 1
fi

truncated_rc="$tmp_dir/truncated-zshrc"
printf '%s\n' 'keep-this-line' "$prefer_cursor_agent_hook_begin" 'export STAY=/should-remain' >"$truncated_rc"
if prefer_cursor_agent_ensure_shell_hook "$truncated_rc"; then
  print_error "prefer_cursor_agent_ensure_shell_hook accepted a hook with no end marker"
  exit 1
fi
if ! grep -Fxq 'keep-this-line' "$truncated_rc" || ! grep -Fxq 'export STAY=/should-remain' "$truncated_rc"; then
  print_error "prefer_cursor_agent_ensure_shell_hook destroyed a truncated rcfile"
  exit 1
fi
if grep -Fq "$prefer_cursor_agent_hook_end" "$truncated_rc"; then
  print_error "prefer_cursor_agent_ensure_shell_hook rewrote a truncated hook"
  exit 1
fi

smoke_home="$tmp_dir/home"
mkdir -p "$smoke_home/.pi/agent"
printf '%s\n' '{"defaultProvider":"custom","defaultModel":"personal-model","defaultThinkingLevel":"low","enabledModels":["custom/personal-model"],"packages":["npm:@agwab/pi-workflow",{"source":"npm:@agwab/pi-workflow@0.7.0"},{"source":"npm:@agwab/pi-workflow-helper"}]}' \
  >"$smoke_home/.pi/agent/settings.json"
# Resolve a real Node binary before HOME override. asdf shims exit 126 when HOME
# points at a disposable tree; that is unrelated to settings-sync portability.
smoke_node_bin="$("${NODE_CMD[@]}" -e 'process.stdout.write(process.execPath)' 2>/dev/null || true)"
if [ -z "$smoke_node_bin" ] || [ ! -x "$smoke_node_bin" ]; then
  smoke_node_bin="$(command -v node)"
fi
NODE_CMD=("$smoke_node_bin")
PATH="$(dirname "$smoke_node_bin"):$PATH"
HOME="$smoke_home"
REPO_DIR="$(cd "$BOOTSTRAP_DIR/.." >/dev/null 2>&1 && pwd)"
smoke_pi_spec="$(pi_coding_agent_spec)"
[ "$smoke_pi_spec" = "@earendil-works/pi-coding-agent@$(jq -r '.dependencies["@earendil-works/pi-coding-agent"]' "$REPO_DIR/pi/package.json")" ] || {
  print_error "fresh Pi install does not use the tracked exact version"
  exit 1
}
smoke_radius_skill="$(pi_agent_node_modules_dir "$smoke_home")/@earendil-works/pi-radius/skills/radius-api/SKILL.md"
mkdir -p "$(dirname "$smoke_radius_skill")"
printf -- '---\nname: radius-api\ndescription: fixture\n---\nbody\n' >"$smoke_radius_skill"
stamp_pi_specialist_skills >/dev/null
grep -q '^disable-model-invocation: true$' "$smoke_radius_skill" || {
  print_error "Pi installation did not restore Radius DMI"
  exit 1
}
printf -- '---\nname: [unterminated\n---\n' >"$smoke_radius_skill"
smoke_stamp_warning="$(stamp_pi_specialist_skills 2>&1)"
case "$smoke_stamp_warning" in
  *"visibility needs repair"*) ;;
  *) print_error "failed DMI repair must warn without aborting installation"; exit 1 ;;
esac
printf -- '---\nname: radius-api\ndescription: fixture\n---\nbody\n' >"$smoke_radius_skill"
stamp_pi_specialist_skills >/dev/null
converge_agent_surfaces >/dev/null
"${NODE_CMD[@]}" - "$smoke_home/.pi/agent/settings.json" "$REPO_DIR/pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const tracked = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const sourceOf = (entry) => typeof entry === "string" ? entry : entry.source;
if (!tracked.packages.length || !tracked.enabledModels.length) {
  throw new Error("tracked Pi settings list no package or no model to sync");
}
const sources = settings.packages.map(sourceOf);
if (!tracked.packages.map(sourceOf).every((source) => sources.includes(source))) {
  throw new Error("settings sync did not add every tracked source");
}
if (sources.some((source) => source === "npm:@agwab/pi-workflow" || source.startsWith("npm:@agwab/pi-workflow@"))) {
  throw new Error("settings sync kept a removed pi-workflow source");
}
if (!sources.includes("npm:@agwab/pi-workflow-helper")) {
  throw new Error("settings sync removed a similarly named user package");
}
if (
  !settings.enabledModels.includes("custom/personal-model") ||
  !tracked.enabledModels.every((model) => settings.enabledModels.includes(model))
) {
  throw new Error("settings sync did not preserve the user model and add tracked model pins");
}
if (settings.defaultProvider !== "custom" || settings.defaultModel !== "personal-model" || settings.defaultThinkingLevel !== "low") {
  throw new Error("settings sync overwrote personal Pi defaults");
}
NODE

smoke_converge_home="$tmp_dir/converge-home"
mkdir -p "$smoke_converge_home/.pi/agent" "$smoke_converge_home/.pi"
ln -s "$tmp_dir/missing-settings.json" "$smoke_converge_home/.pi/agent/settings.json"
HOME="$smoke_converge_home"
converge_agent_surfaces >/dev/null
if [ -L "$smoke_converge_home/.pi/agent/settings.json" ] || [ ! -f "$smoke_converge_home/.pi/agent/settings.json" ]; then
  print_error "agent convergence did not recover dangling Pi settings"
  exit 1
fi
if [ "$(readlink "$smoke_converge_home/.claude/statusline-command.sh")" != "$REPO_DIR/claude/statusline-command.sh" ]; then
  print_error "agent convergence did not install the Claude statusline"
  exit 1
fi

printf 'install smoke test: ok\n'
