import fcntl
import os
import sys

fd = os.open(sys.argv[1], os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
try:
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    print("BUSY", flush=True)
    sys.exit(1)
print("OWNED", flush=True)
while sys.stdin.buffer.read(1):
    pass
os.close(fd)
