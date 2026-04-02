#!/usr/bin/env bash

set -euo pipefail

if ! osascript -e 'id of app "iTerm"' >/dev/null 2>&1; then
    echo "iTerm2 not found" >&2
    exit 1
fi

bootstrap_command='exec ~/.local/bin/iterm2-tmux.sh'

osascript <<APPLESCRIPT
tell application "iTerm"
    activate
    try
        create window with profile "etabli"
    on error
        create window with default profile
    end try
    delay 0.1
    tell current session of current window
        write text "$bootstrap_command"
    end tell
end tell
APPLESCRIPT
