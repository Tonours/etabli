# MFE QA flows

Expected rendered state + what each flow exercises. Reach it, screenshot, assert zero console errors.

## user-settings-mfe

Entry: avatar (top-right) → **Account settings** → mounts at `/user-settings`.

| Flow | Steps | Expected | Exercises |
|---|---|---|---|
| Mount | open `/user-settings` | 2FA section + Application tokens list render | MFE mounts, no dual-React error |
| Token item (a11y) | click a token row | navigates to `/user-settings/application-tokens/:id`, token details render | native `<button>` (was `<div role=button>`) — click + keyboard |
| Breadcrumb | on token detail, click "Application tokens" | back to `/user-settings` | Breadcrumb renderLink + navigation |
| 2FA setup — QR | Enable 2FA → instructions → "Set up" → `/two-factor-authentication/setup` | **QR code image renders** | merged `qrCode` state, `.then` branch |
| 2FA input | type `abc123def456` in the code field | field shows `123456` (letters stripped, capped at 6), Enable button enables | hoisted `NON_DIGIT` / `SIX_DIGITS` regex |

Do NOT click the final "Enable two-factor authentication" — it mutates the real account.

## notes-listing-mfe

Entry: open a populated project → sidebar chat/collaboration icon → `/collaboration`.

| Flow | Steps | Expected | Exercises |
|---|---|---|---|
| Mount | open `/collaboration` | sidebar with Notes (Created N / Mentions N counts) | MFE mounts |
| Created | click "Created" | `/collaboration/messages/created`, grid of note cards + pagination | CreatedList feature |
| Mentions | click "Mentions" | `/collaboration/messages/mentions`, grid of mention cards | MentionsList feature |

## Not reliably testable via this skill

- **Theme sync** (dark mode → portal): the Night Mode toggle is on the projects page, and the sync targets portalized dialogs — needs a dialog open in dark mode. Skip unless a dialog flow makes it reachable.
- Any flow gated behind a real mutation (2FA enable, token delete, note create).
