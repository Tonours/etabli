#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SANDBOX="$ROOT_DIR/scripts/security-audit-sandbox"
TMP_DIR="$(mktemp -d)"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
trap 'rm -rf "$TMP_DIR"' EXIT
SCRATCH="$TMP_DIR/run/agents/h1/scratch"
TARGET="$TMP_DIR/target"
mkdir -p "$SCRATCH" "$TARGET" "$TMP_DIR/fake"

failures=0
check() {
  local label="$1"
  shift
  if "$@"; then printf 'ok   %s\n' "$label"; else printf 'FAIL %s\n' "$label"; failures=$((failures + 1)); fi
}

cat >"$TMP_DIR/fake/docker" <<'DOCKER'
#!/bin/bash
case "$1" in
  run)
    printf '%s\n' "$@" >"$FAKE_ARGV"
    if [ -n "${FAKE_LATE:-}" ]; then
      sleep 2; : >"$FAKE_ARGV.created"
      while [ ! -e "$FAKE_ARGV.killed" ]; do sleep 0.2; done
    fi
    echo fake-run ;;
  kill) [ -e "$FAKE_ARGV.created" ] && : >"$FAKE_ARGV.killed" || exit 1 ;;
  inspect) [ "$3" = '{{.State.Running}}' ] && echo false || echo "0 false" ;;
esac
exit 0
DOCKER
chmod +x "$TMP_DIR/fake/docker"
FAKE_ARGV="$TMP_DIR/argv"
export FAKE_ARGV

fake() { PATH="$TMP_DIR/fake:$PATH" SECRET_HOST_VALUE=leak "$SANDBOX" "$@" >/dev/null 2>&1; }
refuses() {
  rm -f "$FAKE_ARGV"
  PATH="$TMP_DIR/fake:$PATH" "$SANDBOX" "$@" >/dev/null 2>&1
  [ $? -eq 2 ] && [ ! -e "$FAKE_ARGV" ]
}
argv_has() { grep -Fxq -- "$1" "$FAKE_ARGV"; }

fake --scratch "$SCRATCH" --target "$TARGET" -- true
for flag in --network none --ipc none --log-driver none --read-only --cap-drop ALL no-new-privileges 65534:65534 \
  --pull never /dev/mqueue:ro,size=4k "$SCRATCH:/seed:ro" "$TARGET:/target:ro" /usr/bin/env -i; do
  check "argv: $flag" argv_has "$flag"
done
check "argv: tmpfs scratch with a size cap" grep -Eq '^/scratch:rw,exec,size=[0-9]+,mode=1777$' "$FAKE_ARGV"
check "argv: memory equals memory-swap" eval '[ "$(grep -A1 -x -- --memory "$FAKE_ARGV" | tail -1)" = "$(grep -A1 -x -- --memory-swap "$FAKE_ARGV" | tail -1)" ]'
check "argv: no host env, no docker socket" eval '! grep -Eq "SECRET_HOST_VALUE|docker.sock|^-e$|^--env$" "$FAKE_ARGV"'

ln -s "$TMP_DIR/run" "$TMP_DIR/link"
mkdir -p "$TMP_DIR/run/agents/h1/other" "$TMP_DIR/run/agents/Bad/scratch"
check "refuses a scratch not named scratch" refuses --scratch "$TMP_DIR/run/agents/h1/other" -- true
check "refuses a scratch outside agents/<id>" refuses --scratch "$TMP_DIR/run/agents/Bad/scratch" -- true
check "refuses a scratch behind a symlink" refuses --scratch "$TMP_DIR/link/agents/h1/scratch" -- true
check "refuses a relative scratch" eval '(cd "$TMP_DIR/run/agents/h1" && refuses --scratch scratch -- true)'
check "refuses / as target" refuses --scratch "$SCRATCH" --target / -- true
check "refuses the home directory as target" refuses --scratch "$SCRATCH" --target "$(cd "$HOME" && pwd -P)" -- true
check "refuses a target that holds the scratch" refuses --scratch "$SCRATCH" --target "$TMP_DIR/run" -- true
mkdir -p "$TMP_DIR/run/agents/h2/scratch" "$TMP_DIR/run/agents/h2/artifacts"
check "refuses another agent's scratch as target" refuses --scratch "$SCRATCH" --target "$TMP_DIR/run/agents/h2/scratch" -- true
check "refuses another agent's root as target" refuses --scratch "$SCRATCH" --target "$TMP_DIR/run/agents/h2" -- true
check "refuses another agent's artifacts as target" refuses --scratch "$SCRATCH" --target "$TMP_DIR/run/agents/h2/artifacts" -- true
check "refuses a limit over its cap" refuses --scratch "$SCRATCH" --memory 4g -- true
check "refuses a size that overflows to zero" refuses --scratch "$SCRATCH" --memory 17179869184g -- true
check "refuses a size with a leading zero" refuses --scratch "$SCRATCH" --memory 0512m -- true
check "refuses an env that overrides a sandbox variable" refuses --scratch "$SCRATCH" --env PATH=/target/bin -- true
check "refuses an env that preloads a library" refuses --scratch "$SCRATCH" --env LD_PRELOAD=/target/x.so -- true
check "refuses an image override" refuses --scratch "$SCRATCH" --image alpine -- true
check "refuses a wall clock over its cap" refuses --scratch "$SCRATCH" --timeout 99999 -- true
check "refuses a malformed env" refuses --scratch "$SCRATCH" --env "1BAD=x" -- true
check "refuses a workdir outside the mounts" refuses --scratch "$SCRATCH" --workdir /etc -- true
check "refuses a workdir with .." refuses --scratch "$SCRATCH" --workdir /scratch/../etc -- true
check "refuses a missing scratch" refuses -- true
check "accepts a fixture env" fake --scratch "$SCRATCH" --env FIXTURE_TOKEN=dummy -- true

rm -f "$FAKE_ARGV"
LATE_START=$SECONDS
FAKE_LATE=1 PATH="$TMP_DIR/fake:$PATH" perl -e 'alarm 20; exec @ARGV' "$SANDBOX" --scratch "$SCRATCH" --timeout 1 -- true >/dev/null 2>&1
LATE_RC=$?
check "watchdog kills a container created after the deadline" eval '[ "$LATE_RC" -eq 124 ] && [ $((SECONDS - LATE_START)) -lt 15 ]'
rm -f "$FAKE_ARGV" "$FAKE_ARGV.created" "$FAKE_ARGV.killed"

live_ready() { command -v docker >/dev/null 2>&1 && "$SANDBOX" --check >/dev/null 2>&1; }
if ! live_ready; then
  if [ "${SANDBOX_SMOKE_REQUIRE:-0}" = 1 ]; then
    printf 'FAIL live probes: Docker or the image is not ready (%s)\n' "$("$SANDBOX" --check 2>&1)"
    exit 1
  fi
  printf 'skip live probes: Docker or the image is not ready\n'
  [ "$failures" -eq 0 ] || { printf 'security-audit-sandbox smoke test: %d failure(s)\n' "$failures"; exit 1; }
  printf 'security-audit-sandbox smoke test: ok (guards only)\n'
  exit 0
fi

run() { "$SANDBOX" --scratch "$SCRATCH" --target "$TARGET" "$@" 2>&1; }
echo seed >"$SCRATCH/seed.txt"
echo target >"$TARGET/t.txt"
cat >"$SCRATCH/net.js" <<'JS'
const net = require("net"), dns = require("dns"), http = require("http");
const tries = [["1.1.1.1", 443], ["1.1.1.1", 80], ["2606:4700:4700::1111", 443], ["192.168.65.1", 53], ["192.168.65.254", 80], ["host.docker.internal", 80]];
const connect = ([host, port]) => new Promise((done) => {
  const s = net.connect({ host, port, timeout: 3000 });
  s.on("connect", () => { s.destroy(); done(`OPEN ${host}:${port}`); });
  s.on("error", () => done("closed")); s.on("timeout", () => { s.destroy(); done("closed"); });
});
const lookup = (name) => new Promise((done) => dns.lookup(name, (err) => done(err ? "closed" : `RESOLVED ${name}`)));
const resolve = (name) => new Promise((done) => new dns.Resolver({ timeout: 2000, tries: 1 }).resolve4(name, (err) => done(err ? "closed" : `DNS ${name}`)));
const loopback = () => new Promise((done) => {
  const server = http.createServer((q, r) => r.end("pong")).listen(0, "127.0.0.1", () => {
    http.get(`http://127.0.0.1:${server.address().port}`, (r) => { let b = ""; r.on("data", (c) => (b += c)); r.on("end", () => { server.close(); done(`loopback ${b}`); }); });
  });
});
(async () => {
  const out = await Promise.all([...tries.map(connect), lookup("example.com"), lookup("host.docker.internal"), resolve("example.com"), loopback()]);
  console.log(out.join("\n"));
})();
JS
NET="$(run -- node net.js)"
check "network: no egress, no DNS, no host route" eval '! grep -Eq "^(OPEN|RESOLVED|DNS)" <<<"$NET"'
check "network: isolated loopback works" grep -q "^loopback pong$" <<<"$NET"

WRITES="$(run -- sh -c 'for p in / /etc /tmp /var/tmp /run /dev/shm /dev/mqueue /target /seed /usr/local/bin; do touch "$p/w" 2>/dev/null && echo "WRITABLE $p"; done; touch /scratch/w && echo scratch-ok')"
check "fs: writes only land in /scratch" eval '[ "$WRITES" = scratch-ok ]'
check "fs: host scratch is never written" eval '[ ! -e "$SCRATCH/w" ] && [ ! -e "$SCRATCH/.sandbox" ]'
check "fs: seed and target are visible" eval '[ "$(run -- cat /scratch/seed.txt /target/t.txt)" = "$(printf "seed\ntarget")" ]'

ENV_OUT="$(run --env FIXTURE_TOKEN=dummy -- env | grep -Ev '^(PWD|OLDPWD|SHLVL|_)=' | LC_ALL=C sort | tr '\n' ' ')"
EXPECTED="CI=1 FIXTURE_TOKEN=dummy HOME=/scratch/.sandbox/home LANG=C.UTF-8 NO_COLOR=1 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin PIP_CACHE_DIR=/scratch/.sandbox/cache/pip PIP_NO_INDEX=1 PYTHONDONTWRITEBYTECODE=1 TMPDIR=/scratch/.sandbox/tmp XDG_CACHE_HOME=/scratch/.sandbox/cache npm_config_cache=/scratch/.sandbox/cache/npm npm_config_offline=true npm_config_update_notifier=false "
check "env: exactly the allowlist" eval '[ "$ENV_OUT" = "$EXPECTED" ]'
check "identity: nobody, no capabilities" eval '[ "$(run -- sh -c "id -u; grep CapEff /proc/self/status")" = "$(printf "65534\nCapEff:\t0000000000000000")" ]'

CGROUP="$(run --memory 256m --pids 64 --cpus 1 -- sh -c 'cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/pids.max /sys/fs/cgroup/cpu.max')"
check "cgroup: memory, pids and cpu limits" eval '[ "$CGROUP" = "$(printf "268435456\n64\n100000 100000")" ]'

run --disk 16m --file-size 16m -- sh -c 'for i in 1 2 3; do dd if=/dev/zero of=/scratch/f$i bs=1M count=8 2>/dev/null || exit 7; done' >/dev/null
check "limit: disk cap gives ENOSPC" [ $? -eq 7 ]
run --file-size 1m -- dd if=/dev/zero of=/scratch/big bs=1M count=2 >/dev/null
check "limit: file-size cap stops the write" [ $? -ne 0 ]
FORKS="$(run --pids 32 -- python3 -c 'import os, time
n = 0
try:
    for _ in range(64):
        if os.fork() == 0:
            time.sleep(5)
            os._exit(0)
        n += 1
except OSError:
    print("fork refused after", n)')"
check "limit: pids cap holds" grep -Eq "^fork refused after ([0-9]|[12][0-9]|3[01])$" <<<"$FORKS"
MEM="$(run --memory 64m -- node -e 'const a = []; for (;;) a.push(Buffer.alloc(16 << 20, 1))')"
check "limit: memory cap kills with an OOM report" grep -q "out of memory" <<<"$MEM"
run --timeout 2 -- sleep 30 >/dev/null
check "limit: wall clock exits 124" [ $? -eq 124 ]
run --output 4k -- sh -c 'yes' >/dev/null
check "limit: output cap exits 120" [ $? -eq 120 ]
QUIET_START=$SECONDS
run --output 4k --timeout 30 -- sh -c 'head -c 8192 /dev/zero; sleep 60' >/dev/null
QUIET_RC=$?
check "limit: output cap stops a quiet producer at once" eval '[ "$QUIET_RC" -eq 120 ] && [ $((SECONDS - QUIET_START)) -lt 20 ]'
dd if=/dev/zero of="$SCRATCH/huge" bs=1M count=20 2>/dev/null
run --disk 8m --file-size 8m -- true >/dev/null
check "setup: a seed over the disk cap exits 121" [ $? -eq 121 ]
rm -f "$SCRATCH/huge"
check "cleanup: no container left" eval '[ -z "$(docker ps -aq --filter name=security-audit-sandbox-)" ]'

[ "$failures" -eq 0 ] || { printf 'security-audit-sandbox smoke test: %d failure(s)\n' "$failures"; exit 1; }
printf 'security-audit-sandbox smoke test: ok\n'
