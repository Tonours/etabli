# Implemented: Fedora desktop tune + Brave

## Metadata

- Archived: 2026-08-16
- Source plan: `PLAN.md`
- Source plan SHA-256: `b8d2f53c68609517d9489fb9d0cf9545657648a8fd76fc1234df29cf5a1e8b7b`
- Status: IMPLEMENTED
- Commit / branch: main (host-local settings + system Flatpak; no etabli commit)
- Event ledger: `.workflow/fedora-perf-tune/events.jsonl`

## Outcome

- `tuned` profile `desktop` (was `balanced`).
- GNOME animations off; Software no longer auto-downloads updates.
- User `localsearch-3` masked (was indexing the switch-pack / SSH pubs).
- Brave 1.93.136 installed from Flathub (system), VAAPI Intel runtime pulled.

## Context

- Ice Lake i7-1068NG7, 31 GiB RAM, Iris Plus G7, Fedora 44 T2.
- RAM was already abundant; leftover kernel/wifi/trackpad work done earlier.
- `sudo -n` unavailable this turn; system `vm.swappiness=60` and `mesa-va-drivers` left for later.

## Decisions

### Brave over other Chromium forks

- Context: user asked for a good browser besides Firefox.
- Choice: Brave Flatpak (Chromium + shields, Wayland, VAAPI runtime).
- Rejected: another Firefox fork; RPM Chromium (not installed, needs dnf/sudo).
- Rationale: closest daily driver to Chrome with less telemetry; Firefox stays for fallback.

### Mask LocalSearch

- Context: indexer was walking Bureau switch-pack and SSH keys.
- Choice: `systemctl --user mask --now localsearch-3.service`.
- Rejected: keep indexing.
- Rationale: 32 GiB laptop does not need background FS crawl for Activities search.

## Accepted Drift

- Original plan: user Flatpak first.
- Implemented: system Flatpak (user remotes had no Flathub).
- Why accepted: same app id, already on the machine Flathub remote.

## Validation Evidence

- command: `tuned-adm active` → `desktop`
- command: `gsettings get org.gnome.desktop.interface enable-animations` → `false`
- command: `gsettings get org.gnome.software download-updates` → `false`
- command: `systemctl --user is-enabled localsearch-3.service` → `masked`
- command: `flatpak info --show-ref com.brave.Browser` → `app/com.brave.Browser/x86_64/stable`

## Follow-up State

- Remaining: `vm.swappiness=60` (sudo sysctl); `vainfo` / `mesa-va-drivers` for native VAAPI; Firefox kept.
- Revert LocalSearch: `systemctl --user unmask localsearch-3.service && systemctl --user start localsearch-3.service`
- Revert tuned: `tuned-adm profile balanced`
- Launch Brave: menu or `flatpak run com.brave.Browser`
