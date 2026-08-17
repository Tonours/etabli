# Implemented: Fedora MBP16,2 checkup + user-space tune

## Metadata

- Archived: 2026-08-16
- Source plan: `PLAN.md`
- Source plan SHA-256: `a0268e2707000bc30f70ee496848b6f6ff540449ba780a344ec85956ef9bf746`
- Status: IMPLEMENTED
- Commit / branch: main (no implementation commit; host-local settings only)
- Event ledger: `.workflow/fedora-mbp-tune/events.jsonl`

## Outcome

- Hardware checkup recorded for MacBookPro16,2 on Fedora 44 T2.
- GNOME trackpad tuned for less jumpy pointer (adaptive accel, speed -0.25, DWT 700 ms).
- `tuned` moved from server `throughput-performance` to laptop `balanced` (governor `powersave`, EPP `balance_performance`).
- NM wifi powersave persisted to `disable` on `Freebox-C9772E-BAS`; live `iw` still `on` until next reconnect (reapply refused).

## Context

- DMI MacBookPro16,2 / i7-1068NG7 / 31 GiB / Iris Plus G7 / kernel `7.1.8-200.t2.fc44`.
- Trackpad USB `05AC:027E` via T2 VHCI, `ID_INPUT_TOUCHPAD=1`.
- Battery design capacity 68.4%. Dual-boot APFS left untouched.
- `sudo` password required in the agent session; `/etc` writes were out of scope.

## Decisions

### User-space only

- Context: agent cannot enter sudo.
- Choice: `gsettings` + `nmcli` + `tuned-adm` (succeeded without password).
- Rejected: `/etc/libinput` quirk, pkexec, kernel/module edits.
- Rationale: smallest reversible change that matches the hardware.
- Consequences: live wifi powersave waits for reconnect; no custom libinput palm filter.

### Trackpad values

- Context: default speed 0.0 / accel default felt jumpy.
- Choice: speed `-0.25`, accel `adaptive`, click-method `fingers`, DWT 700 ms.
- Rejected: synaptics / extra daemons.
- Rationale: conservative first pass; revert with `gsettings reset-recursively org.gnome.desktop.peripherals.touchpad`.

## Accepted Drift

- Original plan/spec: live `iw` power_save off after apply.
- Implemented reality: NM profile is `disable`; `nmcli device reapply` cannot change live powersave; `iw set` needs CAP_NET_ADMIN.
- Why accepted: persistence is in place; live off happens on next wifi reconnect.

## Validation Evidence

- command: `gsettings get … touchpad speed/accel-profile/click-method/disable-while-typing`
  - result: `-0.25` / `adaptive` / `fingers` / `true` (2026-08-16)
- command: `tuned-adm active` + cpu0 governor/EPP
  - result: `balanced` / `powersave` / `balance_performance`
- command: `nmcli -g 802-11-wireless.powersave con show Freebox-C9772E-BAS`
  - result: `disable`
- command: `iw wlp229s0 get power_save`
  - result: still `on` (live); reconnect needed
- command: `systemctl --failed --no-pager`
  - result: 0 failed units

## Follow-up State

- Remaining risks: trackpad speed is taste; reconnect wifi to apply powersave; leftover kernel `6.19.12-210.t2.fc44` unused; `tiny-dfr` inactive; `brcmfmac` P2P/sleep journal noise unchanged.
- Parking lot: sudo `dnf install zsh` already separate; optional COPR Ghostty; optional `/etc/libinput` quirk for `05AC:027E`.
- Superseded docs/specs: none
- Next links: reconnect wifi, then `iw wlp229s0 get power_save` should read `off`.
