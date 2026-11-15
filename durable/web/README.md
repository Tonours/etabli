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

Paste the token from the daemon's private `api.token` file into the login
form. It is cleared after the bootstrap request; the app uses no browser
storage, offline API cache, URL credentials or third-party scripts. Signing
out clears the displayed run data. An unavailable session requires login
again. This is an online app; the service worker only handles notifications.

Open a run to see its live stream and plan, send an instruction, or abort it.
Schedules use five numeric cron fields in UTC at minute resolution. Missed
times coalesce into one recoverable overdue run rather than a backlog. The
schedules interface requires the S6 backend.

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

Done and blocked runs send an empty signed Web Push request with a one-hour
TTL and high urgency. The worker displays generic text, with no task, result,
plan, token or identity in the notification. Tap it to open the app. Invalid
404/410 subscriptions and removed identities are pruned. Transient provider
failures retain the subscription. Delivery uses the existing at-most-once
notification claim: a crash after claiming can lose the attempt; delivery is
not retried for the same terminal event. The command notification is still
attempted independently. Aborted runs do not send Web Push.

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
synthetic identity. Its public synthetic token is `F` repeated 43 times. Trust
that certificate only in a disposable browser profile. SIGTERM cleans the
fixture up. This checks real browser flows but is not phone or live Web Push
qualification.
