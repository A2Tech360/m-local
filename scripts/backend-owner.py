"""Verify the existing Jac listener belongs to the configured phone checkout."""
from hashlib import sha256
from pathlib import Path
import sys

checkout = str(Path(sys.argv[1]).resolve())
runtime = Path.home() / ".local/share/m-local/phone-demos" / sha256(checkout.encode()).hexdigest()[:16]
matches = []
listening_inodes = set()
for table in ("/proc/net/tcp", "/proc/net/tcp6"):
    for line in Path(table).read_text().splitlines()[1:]:
        fields = line.split()
        if int(fields[1].split(":")[-1], 16) == 8200 and fields[3] == "0A":
            listening_inodes.add(fields[9])
for process in Path("/proc").iterdir():
    if not process.name.isdigit():
        continue
    try:
        args = (process / "cmdline").read_bytes().split(b"\0")
        has_port = any(args[i:i+2] == [b"--port", b"8200"] for i in range(len(args)-1))
        owns_socket = any(
            fd.readlink().as_posix() in {f"socket:[{inode}]" for inode in listening_inodes}
            for fd in (process / "fd").iterdir()
        ) if has_port else False
        if owns_socket and (process / "cwd").resolve() == runtime and any(b"jac" in arg for arg in args[:2]):
            matches.append(process)
    except (OSError, PermissionError):
        continue
if len(matches) != 1:
    raise SystemExit("Port 8200 is not a verified backend for the configured checkout")
marker = runtime / ".jac/hosted-revision"
print(marker.read_text().strip() if marker.exists() else "legacy")
