#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
export ETABLI_SKIP_LIVE_CHECKS=1
# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/lib/install-main.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
original_path="$PATH"

smoke_repo_dir="$(cd "$BOOTSTRAP_DIR/.." >/dev/null 2>&1 && pwd)"
smoke_agent_home="$tmp_dir/agent-home"
smoke_personal_target="$tmp_dir/personal-agent.md"
mkdir -p "$smoke_agent_home/.claude/agents"
printf '%s\n' 'personal agent' >"$smoke_personal_target"
ln -s "$smoke_repo_dir/claude/agents/removed-agent.md" \
  "$smoke_agent_home/.claude/agents/removed-agent.md"
ln -s "$smoke_personal_target" \
  "$smoke_agent_home/.claude/agents/personal.md"
managed_surface_prune_stale_claude_agents install "$smoke_repo_dir" "$smoke_agent_home"
if [ -L "$smoke_agent_home/.claude/agents/removed-agent.md" ]; then
  print_error "stale managed Claude agent link was not removed"
  exit 1
fi
if [ ! -L "$smoke_agent_home/.claude/agents/personal.md" ]; then
  print_error "personal Claude agent link was removed"
  exit 1
fi

smoke_command_home="$tmp_dir/command-home"
smoke_external_command="$tmp_dir/external-command.md"
mkdir -p "$smoke_command_home/.claude/commands"
printf '%s\n' 'personal command' >"$smoke_command_home/.claude/commands/recap.md"
printf '%s\n' 'external command' >"$smoke_external_command"
ln -s "$smoke_external_command" \
  "$smoke_command_home/.claude/commands/commit.md"
ln -s "$smoke_repo_dir/claude/commands/plan.md" \
  "$smoke_command_home/.claude/commands/plan.md"
managed_surface_remove_exact_link install \
  "$smoke_command_home/.claude/commands/plan.md" \
  "stale Claude command plan.md" \
  "$smoke_repo_dir/claude/commands/plan.md" \
  "$smoke_repo_dir/claude/scopes/shared/commands/plan.md"
managed_surface_remove_exact_link install \
  "$smoke_command_home/.claude/commands/commit.md" \
  "stale Claude command commit.md" \
  "$smoke_repo_dir/claude/commands/commit.md" \
  "$smoke_repo_dir/claude/scopes/shared/commands/commit.md"
managed_surface_remove_exact_link install \
  "$smoke_command_home/.claude/commands/recap.md" \
  "stale Claude command recap.md" \
  "$smoke_repo_dir/claude/commands/recap.md" \
  "$smoke_repo_dir/claude/scopes/shared/commands/recap.md"
if [ -L "$smoke_command_home/.claude/commands/plan.md" ]; then
  print_error "stale managed Claude command link was not removed"
  exit 1
fi
if [ ! -L "$smoke_command_home/.claude/commands/commit.md" ]; then
  print_error "external Claude command link was removed"
  exit 1
fi
if [ ! -f "$smoke_command_home/.claude/commands/recap.md" ]; then
  print_error "personal Claude command file was removed"
  exit 1
fi

smoke_skill_home="$tmp_dir/skill-home"
smoke_unmanaged_skill="$tmp_dir/unmanaged-skill"
mkdir -p "$smoke_skill_home/.claude/skills" "$smoke_unmanaged_skill"
ln -s "$smoke_repo_dir/claude/scopes/shared/skills/removed-skill" \
  "$smoke_skill_home/.claude/skills/removed-scope-skill"
ln -s "$smoke_repo_dir/vendor/mattpocock/skills/engineering/removed-skill" \
  "$smoke_skill_home/.claude/skills/removed-vendor-skill"
ln -s "$smoke_repo_dir/pi/skills/removed-skill" \
  "$smoke_skill_home/.claude/skills/removed-pi-skill"
ln -s "$smoke_repo_dir/skills/shared/removed-skill" \
  "$smoke_skill_home/.claude/skills/removed-tree-skill"
ln -s "$smoke_unmanaged_skill" \
  "$smoke_skill_home/.claude/skills/unmanaged-skill"
smoke_relative_target="$smoke_skill_home/.shared/skills/relative-live"
mkdir -p "$smoke_relative_target"
ln -s "../../.shared/skills/relative-live" \
  "$smoke_skill_home/.claude/skills/relative-live"
ln -s "../../.shared/skills/relative-gone" \
  "$smoke_skill_home/.claude/skills/relative-dangling"
smoke_relative_managed_root="$smoke_skill_home/relative-repo/pi/skills"
mkdir -p "$smoke_relative_managed_root"
ln -s "../../relative-repo/pi/skills/relative-managed-gone" \
  "$smoke_skill_home/.claude/skills/relative-managed-dangling"
for smoke_live_skill in \
  "skills/shared/plan-loop" \
  "vendor/mattpocock/skills/engineering/research" \
  "skills/shared/review"; do
  ln -s "$smoke_repo_dir/$smoke_live_skill" \
    "$smoke_skill_home/.claude/skills/$(basename "$smoke_live_skill")"
done

for smoke_other_surface in .pi/agent/skills; do
  mkdir -p "$smoke_skill_home/$smoke_other_surface"
  ln -s "$smoke_repo_dir/vendor/mattpocock/skills/engineering/removed-skill" \
    "$smoke_skill_home/$smoke_other_surface/removed-vendor-skill"
  ln -s "$smoke_repo_dir/vendor/mattpocock/skills/engineering/research" \
    "$smoke_skill_home/$smoke_other_surface/research"
done

managed_surface_prune_stale_skill_links install "$smoke_repo_dir" "$smoke_skill_home"

for smoke_other_surface in .pi/agent/skills; do
  if [ -L "$smoke_skill_home/$smoke_other_surface/removed-vendor-skill" ]; then
    print_error "stale vendor skill link survived in $smoke_other_surface"
    exit 1
  fi
  if [ ! -L "$smoke_skill_home/$smoke_other_surface/research" ]; then
    print_error "live vendor skill link was removed from $smoke_other_surface"
    exit 1
  fi
done

for smoke_stale_skill in removed-scope-skill removed-vendor-skill removed-pi-skill removed-tree-skill; do
  if [ -L "$smoke_skill_home/.claude/skills/$smoke_stale_skill" ]; then
    print_error "stale managed Claude skill link '$smoke_stale_skill' was not removed"
    exit 1
  fi
done
if [ ! -L "$smoke_skill_home/.claude/skills/unmanaged-skill" ]; then
  print_error "unmanaged Claude skill link was removed"
  exit 1
fi
for smoke_relative_link in relative-live relative-dangling relative-managed-dangling; do
  if [ ! -L "$smoke_skill_home/.claude/skills/$smoke_relative_link" ]; then
    print_error "relative link '$smoke_relative_link' was removed by an unrelated repo root"
    exit 1
  fi
done

managed_surface_prune_stale_skill_links install "$smoke_skill_home/relative-repo" "$smoke_skill_home"

if [ -L "$smoke_skill_home/.claude/skills/relative-managed-dangling" ]; then
  print_error "stale relative link under a managed root was not removed"
  exit 1
fi

smoke_symlinked_repo="$tmp_dir/symlinked-repo"
ln -s "$smoke_skill_home/relative-repo" "$smoke_symlinked_repo"
ln -s "$smoke_symlinked_repo/pi/skills/symlinked-gone" \
  "$smoke_skill_home/.claude/skills/symlinked-repo-dangling"
managed_surface_prune_stale_skill_links install "$smoke_skill_home/relative-repo" "$smoke_skill_home"
if [ -L "$smoke_skill_home/.claude/skills/symlinked-repo-dangling" ]; then
  print_error "stale link reached through a symlinked repo path was not removed"
  exit 1
fi

smoke_wholesale_repo="$tmp_dir/wholesale-repo"
mkdir -p "$smoke_wholesale_repo/pi/skills" "$smoke_wholesale_repo/claude/scopes" \
  "$smoke_wholesale_repo/vendor/gone-vendor/skills/orphan"
ln -s "$smoke_wholesale_repo/vendor/gone-vendor/skills/orphan" \
  "$smoke_skill_home/.claude/skills/wholesale-orphan"
ln -s "$tmp_dir/outside-any-repo/skills/keep-me" \
  "$smoke_skill_home/.claude/skills/outside-repo-dangling"
rm -rf "$smoke_wholesale_repo/vendor/gone-vendor"
managed_surface_prune_stale_skill_links install "$smoke_wholesale_repo" "$smoke_skill_home"
if [ -L "$smoke_skill_home/.claude/skills/wholesale-orphan" ]; then
  print_error "stale link under a wholesale-removed vendor tree was not removed"
  exit 1
fi
if [ ! -L "$smoke_skill_home/.claude/skills/outside-repo-dangling" ]; then
  print_error "dangling link outside every managed repo root was removed"
  exit 1
fi
for smoke_relative_link in relative-live relative-dangling; do
  if [ ! -L "$smoke_skill_home/.claude/skills/$smoke_relative_link" ]; then
    print_error "unmanaged relative link '$smoke_relative_link' was removed"
    exit 1
  fi
done
for smoke_kept_skill in plan-loop research review; do
  if [ ! -L "$smoke_skill_home/.claude/skills/$smoke_kept_skill" ]; then
    print_error "live managed Claude skill link '$smoke_kept_skill' was removed"
    exit 1
  fi
done

PATH="/tmp/asdf-shims:/usr/bin"
append_path_entry "/tmp/local-bin"
if [ "$PATH" != "/tmp/asdf-shims:/usr/bin:/tmp/local-bin" ]; then
  print_error "append_path_entry did not preserve existing PATH precedence"
  exit 1
fi

append_path_entry "/tmp/local-bin"
if [ "$PATH" != "/tmp/asdf-shims:/usr/bin:/tmp/local-bin" ]; then
  print_error "append_path_entry duplicated an existing PATH entry"
  exit 1
fi

PATH=""
append_path_entry "/tmp/local-bin"
if [ "$PATH" != "/tmp/local-bin" ]; then
  print_error "append_path_entry did not initialize an empty PATH"
  exit 1
fi
PATH="$original_path"

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
[ "$smoke_pi_spec" = "@earendil-works/pi-coding-agent@1.0.3" ] || {
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
"${NODE_CMD[@]}" - "$smoke_home/.pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const sources = settings.packages.map((entry) => typeof entry === "string" ? entry : entry.source);
if (!sources.includes("npm:@tintinweb/pi-tasks@0.7.1")) {
  throw new Error("settings sync did not add a pinned tracked source");
}
if (sources.some((source) => source === "npm:@agwab/pi-workflow" || source.startsWith("npm:@agwab/pi-workflow@"))) {
  throw new Error("settings sync kept a removed pi-workflow source");
}
if (!sources.includes("npm:@agwab/pi-workflow-helper")) {
  throw new Error("settings sync removed a similarly named user package");
}
if (
  !settings.enabledModels.includes("custom/personal-model") ||
  !settings.enabledModels.includes("zai/glm-5.3")
) {
  throw new Error("settings sync did not preserve the user model and add tracked model pins");
}
if (settings.defaultProvider !== "custom" || settings.defaultModel !== "personal-model" || settings.defaultThinkingLevel !== "low") {
  throw new Error("settings sync overwrote personal Pi defaults");
}
NODE

if ! managed_surface_skill_is_shadowed adr "shared work"; then
  print_error "adr must be shadowed while scope work is active"
  exit 1
fi
if managed_surface_skill_is_shadowed adr "shared personal"; then
  print_error "adr must deploy when scope work is not active"
  exit 1
fi
if managed_surface_skill_is_shadowed adr "shared"; then
  print_error "adr must deploy on a shared-only machine"
  exit 1
fi
if managed_surface_skill_is_shadowed conventions "shared work"; then
  print_error "only listed skills are shadowed"
  exit 1
fi

smoke_shadow_home="$tmp_dir/shadow-home"
smoke_shadow_target="$smoke_repo_dir/skills/shared/adr"
mkdir -p "$smoke_shadow_home/.claude/skills"
ln -sfn "$smoke_shadow_target" "$smoke_shadow_home/.claude/skills/adr"
managed_surface_remove_exact_link install \
  "$smoke_shadow_home/.claude/skills/adr" \
  "shadowed Claude skill 'adr'" \
  "$smoke_shadow_target" >/dev/null
if [ -L "$smoke_shadow_home/.claude/skills/adr" ]; then
  print_error "a shadowed skill's installed link was not removed"
  exit 1
fi

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
