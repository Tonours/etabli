"""Private foreground receipt; never an OS sandbox or an external-effect proof."""
import json
import os
import selectors
import signal
import sys
import time

sys.dont_write_bytecode = True
from process_tree import ProcessTree

with open(sys.argv[1]) as source:
    data = json.load(source)
tree = ProcessTree()
gate_read, gate_write = os.pipe()
out_read, out_write = os.pipe()
err_read, err_write = os.pipe()
pid = os.fork()
if pid == 0:
    os.setsid()
    os.close(gate_write)
    if not os.read(gate_read, 1): os._exit(128)
    os.dup2(os.open(os.devnull, os.O_RDONLY), 0)
    os.dup2(out_write, 1); os.dup2(err_write, 2)
    os.closerange(3, int(os.sysconf('SC_OPEN_MAX')))
    os.chdir(data['cwd'])
    try: os.execvpe(data['argv'][0], data['argv'], os.environ)
    except OSError as error:
        os.write(2, str(error).encode()); os._exit(127)
os.close(gate_read); os.close(out_write); os.close(err_write)
interrupted, status, stopped = False, None, False
streams = {'stdout': bytearray(), 'stderr': bytearray()}
selector = selectors.DefaultSelector()
for fd, name in [(0, 'control'), (out_read, 'stdout'), (err_read, 'stderr')]:
    os.set_blocking(fd, False); selector.register(fd, selectors.EVENT_READ, name)
deadline = min(time.time() + data['timeoutMs'] / 1000, data.get('mission', {}).get('deadline', float('inf')) / 1000 if data.get('mission') else float('inf'))

def stop():
    global interrupted, stopped
    interrupted = True
    if stopped: return
    stopped = True
    tree.drain()

try:
    tree.attach(pid)
    if time.time() >= deadline: stop()
    else: os.write(gate_write, b'1')
    os.close(gate_write); gate_write = None
    while status is None or len(selector.get_map()) > (1 if any(key.data == 'control' for key in selector.get_map().values()) else 0):
        for key, _ in selector.select(.02):
            chunk = os.read(key.fd, 65536)
            if not chunk:
                selector.unregister(key.fd)
                if key.data == 'control': stop()
                else: os.close(key.fd)
            elif key.data != 'control': streams[key.data].extend(chunk)
        tree.refresh()
        if status is None:
            try:
                ended, value = os.waitpid(pid, os.WNOHANG)
                if ended: status = value
            except ChildProcessError: status = signal.SIGKILL
        if time.time() >= deadline and not stopped: stop()
        if stopped:
            # Unknown pipes cannot keep a cancelled operation alive indefinitely.
            for key in list(selector.get_map().values()):
                if key.data != 'control':
                    try:
                        while chunk := os.read(key.fd, 65536): streams[key.data].extend(chunk)
                    except BlockingIOError: tree.uncertain = True
                    selector.unregister(key.fd); os.close(key.fd)
    if tree.refresh(): stop()
    interrupted = interrupted or tree.uncertain
    receipt = {key: data[key] for key in ['inputHash', 'taskId', 'argv', 'cwd']}
    code = os.waitstatus_to_exitcode(status) if status is not None else 128
    receipt.update(exit=code if code >= 0 else 128 - code, interrupted=interrupted, finishedAt=int(time.time() * 1000), containment={'scope': 'observed-birth-lineage', 'platform': sys.platform, 'trackingComplete': not tree.uncertain})
    receipt.update({name: value.decode('utf-8', errors='replace') for name, value in streams.items()})
    pending = data['receipt'] + '.pending'
    fd = os.open(pending, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as output: json.dump(receipt, output); output.flush(); os.fsync(output.fileno())
    os.rename(pending, data['receipt'])
finally:
    if gate_write is not None: os.close(gate_write)
    try:
        if status is None: stop()
    finally: selector.close(); tree.close()
