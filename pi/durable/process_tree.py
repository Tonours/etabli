"""Process identities only: no arguments, environment, files or credentials."""
import ctypes
import errno
import os
import select
import signal
import sys
import time


class ProcessTree:
    def __init__(self):
        self.known, self.owned, self.watched = {}, set(), set()
        self.forked, self.uncertain, self.tracking_failed = False, False, False
        if sys.platform == 'darwin':
            self.lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
            self.lib.proc_listpids.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_int]
            self.lib.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int]
            self.queue = select.kqueue()
        elif sys.platform.startswith('linux'):
            if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
                raise OSError('Cannot establish command subreaper; execution refused')
            self.queue = None
        else:
            raise OSError('Command descendant supervision is unavailable on this platform')
        self.baseline = self.scan()
        self.known.update(self.baseline)

    def info(self, pid):
        if sys.platform == 'darwin':
            # XNU PROC_PIDUNIQIDENTIFIERINFO (17), versioned 56-byte shape.
            buf = ctypes.create_string_buffer(56)
            size = self.lib.proc_pidinfo(pid, 17, 1, buf, len(buf))
            if size == 0 and ctypes.get_errno() in (errno.ESRCH, errno.ENOENT):
                return None
            if size != 56:
                raise OSError('Process birth identity unavailable; preserve uncertain effect')
            identity = int.from_bytes(buf.raw[16:24], sys.byteorder)
            parent = int.from_bytes(buf.raw[24:32], sys.byteorder)
            return {'pid': pid, 'id': identity, 'parent': parent}
        try:
            text = open(f'/proc/{pid}/stat').read().rsplit(')', 1)[1].split()
            return {'pid': pid, 'id': (pid, int(text[19])), 'parent': int(text[1])}
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            return None

    def scan(self):
        if sys.platform == 'darwin':
            size = max(4096, self.lib.proc_listpids(4, os.getuid(), None, 0) + 4096)
            while True:
                buf = (ctypes.c_int * (size // 4))()
                count = self.lib.proc_listpids(4, os.getuid(), buf, size)
                if count <= 0:
                    raise OSError('Cannot enumerate command process identities')
                if count < size:
                    pids = list(buf[:count // 4]); break
                size *= 2
        else:
            pids = [int(name) for name in os.listdir('/proc') if name.isdigit()]
        rows = [self.info(pid) for pid in pids if pid > 0]
        return {row['id']: row for row in rows if row}

    def attach(self, pid):
        root = self.info(pid)
        if not root:
            raise OSError('Command exited before supervision was established')
        self.root = root['id']; self.owned.add(self.root); self.known[self.root] = root
        self.refresh()

    def refresh(self):
        live = self.scan(); self.known.update(live)
        if self.queue:
            for event in self.queue.control([], 1024, 0):
                if event.fflags & select.KQ_NOTE_FORK:
                    self.forked = True
        previous = -1
        while previous != len(self.owned):
            previous = len(self.owned)
            owned_pids = {live[key]['pid'] for key in self.owned if key in live}
            for key, row in (self.known if self.queue else live).items():
                if (self.queue and row['parent'] in self.owned) or (not self.queue and row['parent'] in owned_pids | {os.getpid()}):
                    self.owned.add(key)
        if self.queue:
            # An unobserved short-lived intermediate can hide a double-fork.
            # Refuse unqualified success, and never signal an unattributed PID.
            def unattributed(key):
                visited = set()
                while key not in self.baseline and key not in self.owned:
                    if key in visited or key not in self.known: return True
                    visited.add(key); key = self.known[key]['parent']
                return False
            self.uncertain = self.uncertain or self.tracking_failed or (self.forked and any(unattributed(key) for key in live))
            for key in self.owned - self.watched:
                row = live.get(key)
                if row:
                    try:
                        self.queue.control([select.kevent(row['pid'], filter=select.KQ_FILTER_PROC, flags=select.KQ_EV_ADD, fflags=select.KQ_NOTE_FORK | select.KQ_NOTE_EXIT)], 0, 0)
                        self.watched.add(key)
                    except ProcessLookupError:
                        pass
                    except OSError:
                        self.tracking_failed = self.uncertain = True
        self.live = {key: row for key, row in live.items() if key in self.owned}
        return self.live

    def signal(self, sig):
        for key, row in self.refresh().items():
            if self.info(row['pid']) == row:
                try: os.kill(row['pid'], sig)
                except ProcessLookupError: pass

    def drain(self):
        # Freeze attributable forks first; their birth identities survive reparenting.
        for _ in range(2): self.signal(signal.SIGSTOP)
        self.signal(signal.SIGKILL)
        end = time.monotonic() + 2
        while self.refresh() and time.monotonic() < end:
            while True:
                try:
                    if os.waitpid(-1, os.WNOHANG)[0] == 0: break
                except ChildProcessError: break
            time.sleep(.01)
        if self.live: self.uncertain = True

    def close(self):
        if self.queue: self.queue.close()
