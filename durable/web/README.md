# Browser control

The daemon serves this app when `api.webOrigin` is configured as its exact
HTTPS Tailscale Serve origin (without a trailing slash). Existing `api.port`
and `api.identities` are still required. Enabling it is a deployment change;
this slice does not change production configuration or Serve.

Navigation, the manifest, icons and service worker require the allowlisted
Tailscale identity. These exact static assets contain no run data. All API
requests still require both factors: identity plus bearer, or identity plus
a browser session created with that bearer. CLI bearer authentication is
unchanged. A browser session lasts 12 hours and is revoked on logout or a
daemon restart. Its `__Host-etabli` cookie is Secure, HttpOnly, SameSite=Strict
and Path=/. Exact Origin plus the fetch marker protects cookie requests,
including requests from sibling machines in the same tailnet. WebSockets
require the exact Origin and terminate when the session is revoked.

Cookies are shared across HTTPS ports on the same hostname. A separate Serve
port does not isolate the session secret. Use a dedicated hostname or ensure
every HTTPS backend on that hostname is trusted local code with no cookie
forwarding or logging. Funnel or Serve proxying to an untrusted remote backend
on the same hostname is incompatible with this browser session setup.

Paste the token from the daemon's private `api.token` file into the login
form. It is cleared after the bootstrap request; the app uses no browser
storage, offline API cache, URL credentials or third-party scripts. Signing
out clears the displayed run data. An unavailable session requires login
again. This is an online app; the service worker only handles notifications.

The run list puts the runs that need you first, with the next step for each
blocked run and its pull request when there is one. Open a run to see its
overview, activity, plan and instructions panels; send an instruction or abort
it from there. The URL hash holds only the open run's id, checked against the
run id format before any request; nothing else is kept in the URL.
Schedules use five numeric cron fields in UTC at minute resolution. Missed
times coalesce into one recoverable overdue run rather than a backlog. The
schedules interface requires the S6 backend.

## Build, update and rollback

The client is React, Tailwind and shadcn/ui sources in `durable/web-src`,
built with Vite into `durable/web/app.js` and `durable/web/style.css`. Both
files are git-ignored and built on the checkout the daemon serves (ADR-0047).
The build packages are pinned `devDependencies`; the daemon imports none of
them and nothing is fetched at run time.

Update, as one command line on the production checkout:

```bash
git pull && cd durable && bun install --frozen-lockfile && bun run build
```

No daemon restart is needed: the next page reload loads the new client, and
the TUI changes at its next start. The first pull that brings this client
deletes the tracked legacy `app.js` and `style.css`, so `/app.js` answers 400
and the page stays blank until the build ends (seconds). After later pulls the
previous bundle keeps running until the build replaces it. A reload during
the build can load a shell and a bundle of different versions; reload again
once it ends. The build replaces both files together and restores the
previous pair on a handled failure; an interrupted build can leave a mixed
pair, and running `bun run build` again recovers it.

Rollback: revert the merge commit and pull. The tracked legacy files return
over the ignored build outputs; nothing to build or restart.

## Installation and notifications

Install using the browser's app menu. On iPhone/iPad, choose Share → Add to
Home Screen and launch that installed app. The manifest uses standalone mode.
Tap Enable notifications in the installed app to request permission. If the
platform or permission is unavailable, the app explains that state.

The daemon creates an owned `0600` P-256 private key in `vapid.pem` on its first
web-enabled start and reuses it. Invalid or insecure key files fail startup;
never delete the key to troubleshoot a subscription without understanding
that existing subscriptions are bound to it. Subscription endpoints live in
the existing private SQLite store, are bound to the subscriber identity, and
are bounded to 64 devices. FCM, Mozilla and Apple endpoints are supported;
Windows WNS endpoints are outside this mobile slice. Disable notifications
removes the daemon subscription and unsubscribes this browser.

Notifications stay enabled after sign-out, session expiry and daemon restart.
Disable notifications needs a live session; without one, revoke the site's
notification permission or uninstall the app on the phone. This slice has no
remote revoke control for a lost device. If the daemon's VAPID key changes,
the app removes its obsolete subscription and asks you to enable notifications
again so it cannot report a stale subscription as working.

Done and blocked runs request an empty signed Web Push attempt with a one-hour
TTL and high urgency. One daemon runs at most two HTTPS requests globally,
with one active batch and one waiting batch. Waiting is limited to 15 seconds;
an active batch has a 10-second network budget. Additional terminal events
coalesce into the waiting generic attempt instead of creating more jobs.
Coalescence does not promise a separate notification or device delivery.

The worker displays generic text, with no task, result, plan, token or identity.
Requests use `Connection: close` and fresh TLS connections; retries and redirects
are disabled. Provider 404/410 responses and removed identities are pruned.
Transient failures retain subscriptions. A failed or timed-out request is
unconfirmed: the provider may already have accepted or delivered it. Provider
acceptance alone is not proof of device delivery.

The existing persisted at-most-once claim is kept before admission. A waiting
attempt that expires or is closed before starting makes no request; an active
execution timeout may leave partial or unconfirmed delivery. These outcomes and
coalesced counts are reported without subscription endpoints or credentials.
Claims are never reset or retried for overflow, expiry, shutdown or a crash.
The command notifier remains independent. Aborted runs do not send Web Push.
Shutdown closes admission, cancels the waiting attempt and drains the active
attempt under its remaining network budget before closing the native store.
Native store operations remain awaited rather than abandoned by timeout.

## Qualification recipe

Use isolated state and harmless tasks. Do not use existing production runs or
reset an in-use Serve mapping. After the final integrated-base Threat gate,
the deployment owner supplies a test HTTPS Serve origin and a real phone:

1. Record phone OS/browser and time. Install and launch the app; capture its
   standalone view. Desktop responsive emulation does not qualify.
2. Log in without putting the token in any URL, screenshot, report or log.
   List a test run, open the live stream, send an instruction, inspect its
   plan and abort. Confirm the run actually becomes aborted and idle.
3. Enable notifications from a tap. Background/lock the subscribed device.
   Finish one harmless run as done, then one as blocked. Record the actual
   device notifications and correlate with the terminal events. A push
   service HTTP success alone is not device-delivery evidence.
4. Disable notifications and verify subscription removal. Sign out and verify
   API/watch denial. Keep actual phone installation and subscribed-device
   delivery unchecked until these steps are observed.

Local fixture: `node durable/__tests__/fixtures/browser-daemon.ts` starts a
temporary faux daemon and a self-signed loopback HTTPS proxy that supplies a
synthetic identity. It seeds one run per state the clients explain: a live
answer run and a live plan run, a queued run, four recent blocked runs (one
with a pull request), an older blocked run, published, legacy answer and
aborted runs, and nine older published runs. It also opens the local socket
and prints the state path, so
`node durable/src/cli.ts --state <state> tui` shows the same runs. Its public synthetic token is `F` repeated 43 times. Trust
that certificate only in a disposable browser profile. SIGTERM cleans the
fixture up. This checks real browser flows but is not phone or live Web Push
qualification.
