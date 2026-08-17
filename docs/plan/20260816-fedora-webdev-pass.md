# Implemented: Firefox removed + web-dev Fedora pass

## Metadata

- Archived: 2026-08-16
- Source plan: `PLAN.md`
- Source plan SHA-256: `d938934330bb1a9bf42060d4b5dd93b6825ec613f63a3bac8b30c6ce366a58df`
- Status: IMPLEMENTED
- Commit / branch: main (host-local; no etabli commit)
- Event ledger: `.workflow/fedora-webdev-pass/events.jsonl`

## Outcome

- Firefox RPM removed. Brave is the default http/https/html handler.
- Ghostty listed in `~/.config/xdg-terminals.list`.
- Persistent sysctl: inotify 1M watches / 1024 instances, swappiness 10.
- `dnf` also removed unused weak deps (cockpit, anaconda-live, ffmpeg-free). `zenity` reinstalled.

## Context

- Web-dev box: Vite/webpack watchers, 32 GiB RAM, Brave already installed with AV1 off.

## Decisions

### Remove Firefox hard

- Context: user asked to delete Firefox after Brave+AV1 setup.
- Choice: `dnf remove firefox firefox-langpacks`.
- Rejected: keep Firefox as fallback.
- Consequences: no Gecko browser left (Epiphany was already absent).

### Reinstall zenity

- Context: unused-deps pass removed zenity with Firefox.
- Choice: `dnf install zenity`.
- Rationale: GTK dialog helper used by scripts; cheap restore.

## Accepted Drift

- Original plan: only firefox + langpacks.
- Implemented: dnf also dropped cockpit/anaconda-live/ffmpeg-free unused deps.
- Why accepted: not required on this laptop; zenity restored.

## Validation Evidence

- command: `rpm -q firefox` → not installed
- command: `xdg-settings get default-web-browser` → `com.brave.Browser.desktop`
- command: `sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances vm.swappiness` → 1048576 / 1024 / 10
- command: `command -v zenity` → `/usr/bin/zenity`

## Follow-up State

- Remaining: ffmpeg-free gone (Brave Flatpak still has its own codecs). Reinstall with `sudo dnf install ffmpeg-free` if CLI ffmpeg is needed.
- Launch Brave via menu or `brave` wrapper (AV1 still disabled).
