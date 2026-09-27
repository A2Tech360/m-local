"""Refuse demo setup against an existing workspace or occupied local ports."""
from pathlib import Path
import socket
import sys


def validate_workspace(target: Path, source: Path) -> None:
    if target.resolve() == source.resolve():
        raise ValueError('The demo must not use the source checkout.')
    if target.exists() and (not target.is_dir() or any(target.iterdir())):
        raise ValueError('The demo directory must be empty; existing data will not be reused.')


def validate_ports(port: int) -> None:
    if not 1 <= port <= 65534:
        raise ValueError('Choose a frontend port between 1 and 65534.')
    sockets = []
    try:
        for candidate in (port, port + 1):
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sockets.append(sock)
            if hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            try:
                sock.bind(('0.0.0.0', candidate))
            except OSError as exc:
                raise ValueError(f'Demo port {candidate} is in use or unavailable; refusing to contact an existing server.') from exc
    finally:
        for sock in sockets:
            sock.close()


if __name__ == '__main__':
    try:
        target, source = Path(sys.argv[1]), Path(sys.argv[2])
        validate_workspace(target, source)
        validate_ports(int(sys.argv[3]))
        target.mkdir(parents=True, exist_ok=True)
    except (ValueError, OSError) as exc:
        raise SystemExit(str(exc)) from exc
