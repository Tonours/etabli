claude_physical_dir() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  (cd -P -- "$1" 2>/dev/null && pwd -P)
}

claude_login_home() {
  command -v perl >/dev/null 2>&1 || return 1
  perl -e 'my $home = (getpwuid($<))[7]; exit 1 unless defined $home && length $home; print $home'
}

claude_config_dir_override() {
  local config_dir home_dir default_dir login_home

  [ -n "${CLAUDE_CONFIG_DIR:-}" ] || return 1
  config_dir="$(claude_physical_dir "$CLAUDE_CONFIG_DIR")" || return 1
  home_dir="$(claude_physical_dir "$HOME")" || return 1
  [ "$config_dir" != "$home_dir/.claude" ] || return 1
  if default_dir="$(claude_physical_dir "$HOME/.claude")"; then
    [ "$config_dir" != "$default_dir" ] || return 1
  fi
  if [ "${config_dir#"$home_dir"/}" != "$config_dir" ]; then
    printf '%s\n' "$config_dir"
    return 0
  fi
  login_home="$(claude_login_home)" || return 1
  login_home="$(claude_physical_dir "$login_home")" || return 1
  [ "$home_dir" = "$login_home" ] || return 1
  printf '%s\n' "$config_dir"
}

claude_effective_dir() {
  claude_config_dir_override || printf '%s/.claude\n' "${HOME%/}"
}
