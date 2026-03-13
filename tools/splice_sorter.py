#!/usr/bin/env python3
"""Splice Sound Sorter — auto-sort downloads into category folders."""

import argparse
import logging
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path

SPLICE_SOUNDS = Path.home() / "Splice" / "sounds"
PACKS_DIR = SPLICE_SOUNDS / "packs"
LOG_FILE = Path(__file__).parent / "splice_sort.log"

AUDIO_EXTENSIONS = {".wav", ".mp3", ".aif", ".aiff", ".flac", ".ogg"}

# Priority order matters — earlier categories win ties
CATEGORIES = [
    ("kicks", ["kick", "kck", "kik", "bd_", "bassdrum"]),
    ("snares", ["snare", "snr", "sd_", "clap", "clp", "rim"]),
    ("hats", ["hat", "hh_", "hihat", "hi-hat", "oh_", "ch_", "cymbal", "cym",
              "ride", "crash", "open_hat", "closed_hat"]),
    ("bass", ["bass", "808", "sub_", "sub "]),
    ("perc", ["perc", "shaker", "tamb", "conga", "bongo", "tom_", "tom ",
              "clave", "woodblock", "cowbell", "triangle"]),
    ("vox", ["vox", "vocal", "voice", "acapella", "adlib", "chant"]),
    ("keys", ["key", "piano", "organ", "synth", "chord", "pad_", "pad ",
              "melodic", "melody", "pluck", "arp", "lead_", "lead "]),
]


def classify(file_path: Path) -> str:
    """Classify an audio file into a category based on its full path.

    Uses specificity scoring: category with most keyword hits wins.
    Ties broken by priority order (earlier in CATEGORIES wins).
    Falls back to 'fx' if no keywords match.
    """
    try:
        rel = file_path.relative_to(PACKS_DIR)
    except ValueError:
        rel = file_path
    text = str(rel).lower()

    scores = []
    for category, keywords in CATEGORIES:
        hits = sum(1 for kw in keywords if kw in text)
        if hits > 0:
            scores.append((hits, category))

    if not scores:
        return "fx"

    # Sort by hits descending; ties keep priority order (stable sort)
    scores.sort(key=lambda x: x[0], reverse=True)
    return scores[0][1]


def unique_dest(dest_dir: Path, filename: str) -> Path:
    """Generate a unique destination path, appending _2, _3 etc. for dupes."""
    dest = dest_dir / filename
    if not dest.exists():
        return dest
    stem = Path(filename).stem
    ext = Path(filename).suffix
    counter = 2
    while True:
        candidate = dest_dir / f"{stem}_{counter}{ext}"
        if not candidate.exists():
            return candidate
        counter += 1


def sort_files(dry_run: bool = False) -> int:
    """Scan packs/ and sort audio files into category folders.

    Returns the number of files moved.
    """
    if not PACKS_DIR.exists():
        logging.warning(f"Packs directory not found: {PACKS_DIR}")
        return 0

    moved = 0
    for file_path in sorted(PACKS_DIR.rglob("*")):
        if not file_path.is_file() or file_path.is_symlink():
            continue
        if file_path.stat().st_size == 0:
            continue
        if file_path.suffix.lower() not in AUDIO_EXTENSIONS:
            continue

        category = classify(file_path)
        dest_dir = SPLICE_SOUNDS / category
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = unique_dest(dest_dir, file_path.name)

        if dry_run:
            logging.info(f"[DRY RUN] {file_path.name} -> {category}/")
        else:
            shutil.move(str(file_path), str(dest))
            logging.info(f"{file_path.name} -> {category}/")
        moved += 1

    if not dry_run:
        cleanup_empty_dirs()

    return moved


def cleanup_empty_dirs():
    """Remove empty directories left behind in packs/."""
    if not PACKS_DIR.exists():
        return
    # Loop until no more empty dirs are found (handles nested empties)
    while True:
        removed = False
        for dirpath, dirnames, filenames in os.walk(str(PACKS_DIR), topdown=False):
            p = Path(dirpath)
            if p == PACKS_DIR:
                continue
            try:
                # Only .DS_Store and other junk left — clean them up
                contents = list(p.iterdir())
                real_files = [f for f in contents if f.name not in {".DS_Store", "Thumbs.db"}]
                if not real_files:
                    for junk in contents:
                        junk.unlink()
                    p.rmdir()
                    logging.info(f"Removed empty dir: {p.name}")
                    removed = True
            except OSError:
                pass
        if not removed:
            break


def setup_logging(dry_run: bool = False):
    """Configure logging to both stdout and log file."""
    handlers = [logging.StreamHandler(sys.stdout)]
    if not dry_run:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(str(LOG_FILE), mode="a"))

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=handlers,
    )


# --- launchd install/uninstall ---

PLIST_NAME = "com.genesis.splicesorter.plist"
PLIST_SOURCE = Path(__file__).parent / PLIST_NAME
LAUNCH_AGENTS = Path.home() / "Library" / "LaunchAgents"


def install_watcher():
    """Install launchd plist to ~/Library/LaunchAgents/ and load it."""
    LAUNCH_AGENTS.mkdir(parents=True, exist_ok=True)
    dest = LAUNCH_AGENTS / PLIST_NAME

    if not PLIST_SOURCE.exists():
        print(f"Error: plist not found at {PLIST_SOURCE}")
        sys.exit(1)

    shutil.copy2(str(PLIST_SOURCE), str(dest))
    os.system(f"launchctl load {dest}")
    print(f"Installed and loaded {PLIST_NAME}")
    print(f"Watching {PACKS_DIR} for new downloads.")


def uninstall_watcher():
    """Unload and remove launchd plist."""
    dest = LAUNCH_AGENTS / PLIST_NAME
    if dest.exists():
        os.system(f"launchctl unload {dest}")
        dest.unlink()
        print(f"Unloaded and removed {PLIST_NAME}")
    else:
        print("Watcher not installed.")


def main():
    parser = argparse.ArgumentParser(description="Sort Splice downloads into category folders.")
    parser.add_argument("--dry-run", action="store_true", help="Preview sorting without moving files")
    parser.add_argument("--install", action="store_true", help="Install launchd watcher")
    parser.add_argument("--uninstall", action="store_true", help="Remove launchd watcher")
    args = parser.parse_args()

    if args.install:
        install_watcher()
        return
    if args.uninstall:
        uninstall_watcher()
        return

    setup_logging(dry_run=args.dry_run)

    if args.dry_run:
        logging.info("=== DRY RUN ===")
    else:
        logging.info("=== Splice Sorter run ===")

    moved = sort_files(dry_run=args.dry_run)

    if moved == 0:
        logging.info("No files to sort.")
    else:
        logging.info(f"{'Would sort' if args.dry_run else 'Sorted'} {moved} files.")


if __name__ == "__main__":
    main()
