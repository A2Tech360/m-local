"""Mirror only generated application source; never touch the runtime .jac store."""
from pathlib import Path
import shutil
import sys


def sync(source: Path, target: Path) -> None:
    source, target = source.resolve(), target.resolve()
    if source == target or not (source / "main.jac").is_file():
        raise ValueError("Expected distinct source checkout and phone runtime")
    # Validate both trees before deleting or copying any generated source.
    directories = ("services", "client", "data", "public", "assets")
    for root in (source, target):
        for name in directories:
            tree = root / name
            if tree.is_symlink() or any(path.is_symlink() for path in tree.rglob("*")):
                raise ValueError("Application source must not contain symlinks")
    # These directories contain application source/resources, never runtime .jac.
    for name in directories:
        origin, destination = source / name, target / name
        if not origin.exists() and not destination.exists():
            continue
        destination.mkdir(parents=True, exist_ok=True)
        for old in sorted(destination.rglob("*"), reverse=True):
            relative = old.relative_to(destination)
            if old.is_file() and not (origin / relative).is_file():
                old.unlink()
            elif old.is_dir() and not any(old.iterdir()):
                old.rmdir()
        if origin.exists():
            shutil.copytree(origin, destination, dirs_exist_ok=True)


if __name__ == "__main__":
    sync(Path(sys.argv[1]), Path(sys.argv[2]))
