# Splice Sound Sorter — Design Spec

## Problem
Splice downloads audio files into `~/splice/sounds/packs/<pack-name>/...` with deep nested folder structures. Files need to be automatically sorted into category folders (`kicks/`, `snares/`, `hats/`, `bass/`, `fx/`, `keys/`, `perc/`, `vox/`) under `~/splice/sounds/`.

## Solution
A Python script + macOS launchd watcher that auto-sorts files as they arrive.

## Files
- `~/god/tools/splice_sorter.py` — sorting script
- `~/god/tools/com.god.splicesorter.plist` — launchd config

## Sorting Logic

### Keyword Matching
Scan audio files (`.wav`, `.mp3`, `.aif`, `.aiff`, `.flac`, `.ogg`) recursively in `packs/`. Match the **full relative path** (folder names + filename) case-insensitively against keyword lists.

### Category Keywords (priority order)
1. **kicks**: `kick`, `kck`, `kik`, `bd_`, `bassdrum`
2. **snares**: `snare`, `snr`, `sd_`, `clap`, `clp`, `rim`
3. **hats**: `hat`, `hh_`, `hihat`, `hi-hat`, `oh_`, `ch_`, `cymbal`, `cym`, `ride`, `crash`, `open_hat`, `closed_hat`
4. **bass**: `bass`, `808`, `sub_`, `sub `
5. **perc**: `perc`, `shaker`, `tamb`, `conga`, `bongo`, `tom_`, `tom `, `clave`, `woodblock`, `cowbell`, `triangle`
6. **vox**: `vox`, `vocal`, `voice`, `acapella`, `adlib`, `chant`
7. **keys**: `key`, `piano`, `organ`, `synth`, `chord`, `pad_`, `pad `, `melodic`, `melody`, `pluck`, `arp`, `lead_`, `lead `
8. **fx**: default catch-all for anything unmatched

### Specificity Scoring
If a filename matches keywords from multiple categories, the category with the most keyword hits wins. Ties broken by priority order above.

## File Operations
- **Move** files flat into `~/splice/sounds/<category>/`
- **Delete** empty directories left behind in `packs/`
- **Skip** files already present in destination (same name)
- **Append** log entries to `~/god/tools/splice_sort.log`

## CLI Interface
```
python3 splice_sorter.py              # run sorter
python3 splice_sorter.py --dry-run    # preview without moving
python3 splice_sorter.py --install    # install launchd watcher
python3 splice_sorter.py --uninstall  # remove launchd watcher
```

## Launchd Watcher
- `WatchPaths`: `~/splice/sounds/packs/`
- `ThrottleInterval`: 3 seconds (wait for downloads to settle)
- Plist installed to `~/Library/LaunchAgents/`
- Runs the sorter script on any change in packs directory

## Edge Cases
- Duplicate filenames across packs: append `_2`, `_3` etc.
- Non-audio files: ignore
- Partially downloaded files: the 3s throttle handles this; also skip 0-byte files
- Symlinks: ignore
