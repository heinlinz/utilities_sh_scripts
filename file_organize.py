#!/usr/bin/env python3

import os 
import shutil
from pathlib import Path

SOURCE_DIR = Path.home() / "Downloads"

DEST_MAP = {
    # images
    ".png": Path.home() / "Pictures",
    ".jpg": Path.home() / "Pictures",
    ".jpeg": Path.home() / "Pictures",
    ".svg": Path.home() / "Pictures",
    ".webp": Path.home() / "Pictures",
    ".gif": Path.home() / "Pictures",

    # audio 
    ".mp3": Path.home() / "Music",
    ".wav": Path.home() / "Music",
    ".flac": Path.home() / "Music",
    ".m4a": Path.home() / "Music",

    # Documents
    ".md": Path.home() / "Documents",
    ".txt": Path.home() / "Documents",
    ".pdf": Path.home() / "Documents",
    ".doc": Path.home() / "Documents",
    ".docx": Path.home() / "Documents",

    # Archives
    ".zip": Path.home() / "Archives",
    ".tar": Path.home() / "Archives",
    ".gz": Path.home() / "Archives",
    ".rar": Path.home() / "Archives",
    ".7z": Path.home() / "Archives",

    # other 
    ".iso": Path.home() / "ISOs",
}

OTHER_DIR = Path.home() / "Downloads" / "Other"

def get_unique_path(destination_dir: Path, file_path: Path) -> Path:

    new_dest_path = destination_dir / file_path.name

    if not new_dest_path.exists():
        return new_dest_path

    basename = file_path.stem
    extension = file_path.suffix
    counter = 1

    while new_dest_path.exists():
        new_name = f"{basename}_{counter}{extension}"
        new_dest_path = destination_dir / new_name
        counter += 1
    
    return new_dest_path

def main():
    print(f"Scanning {SOURCE_DIR}...")

    for file_path in SOURCE_DIR.iterdir():

        if file_path.is_file():
            extension = file_path.suffix.lower()
            dest_dir = DEST_MAP.get(extension)

            if not dest_dir and OTHER_DIR:
                dest_dir = OTHER_DIR

            if dest_dir:
                try:
                    dest_dir.mkdir(parents=True, exist_ok=True)
                    final_dest_path = get_unique_path(dest_dir, file_path)
                    shutil.move(str(file_path), str(final_dest_path))

                    relative_path = os.path.relpath(final_dest_path, Path.home())
                    print(f" Moved: {file_path.name} -> ~/{relative_path}")

                except Exception as e:
                    print(f"Error moving {file_path.name}: {e}")

    print("Downloaded files organization complete.")

if __name__ == "__main__":
    main()

