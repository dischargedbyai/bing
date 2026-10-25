# Bing Wallpaper Downloader

A lightweight, robust Bash script to fetch and archive unique daily Bing wallpapers across international markets with an in-place block progress bar.

---

## Features

- **4 Unique Wallpapers Daily**: Fetches up to 4 distinct high-resolution wallpapers every day.
- **Global Region Sampling**: Queries 12 international Bing markets (`en-US`, `en-GB`, `en-AU`, `en-CA`, `en-IN`, `ja-JP`, `zh-CN`, `de-DE`, `fr-FR`, `it-IT`, `es-ES`, `pt-BR`) to find localized wallpapers.
- **Smart Deduplication**: Extracts unique image keys to ensure wallpapers shared across multiple regions are never downloaded twice.
- **Automatic Archive Fallback**: If global regions share the same image on a given day, the script automatically backfills unique wallpapers from adjacent archive days to always fulfill the 4-wallpaper target.
- **Clean Block Progress Bar**: Displays an in-place animated progress bar using unicode block characters (`█` and `░`).
- **Atomic Downloads**: Writes to hidden temporary files first before moving, preventing corrupted or incomplete image files.
- **Idempotent**: Safely re-runnable without re-downloading existing wallpapers.

---

## Prerequisites

The script requires standard Linux/macOS command-line utilities:

- **Bash** (v4.0+)
- **curl** (for API requests and image downloads)
- **jq** (for JSON parsing)

Install prerequisites on Debian/Ubuntu:
```bash
sudo apt update && sudo apt install -y curl jq
```

Install prerequisites on Fedora/RHEL:
```bash
sudo dnf install -y curl jq
```

Install prerequisites on Arch Linux:
```bash
sudo pacman -S curl jq
```

---

## Quick Start

1. Clone or navigate to the directory:
   ```bash
   cd ~/Documents/savebingwall
   ```

2. Make the script executable:
   ```bash
   chmod +x get-bing-wallpapers.sh
   ```

3. Run the script:
   ```bash
   ./get-bing-wallpapers.sh
   ```

---

## Usage Examples

When launched, the script prompts for a date or relative day count:

```text
Enter date (YYYY-MM-DD) or days ago (0=today, 1=yesterday, default 0):
```

### 1. Download Today's Wallpapers
Press **Enter** (default is `0`):
```bash
./get-bing-wallpapers.sh
```

### 2. Download by Days Ago
Enter `1` for yesterday, `2` for two days ago, etc. (up to 7 days):
```bash
./get-bing-wallpapers.sh <<< "1"
```

### 3. Download by Specific Date
Enter a date in `YYYY-MM-DD` format:
```bash
./get-bing-wallpapers.sh <<< "2026-10-24"
```

---

## Destination Structure

Wallpapers are saved organized by date under `~/Pictures/Bing Wallpapers/`:

```text
~/Pictures/Bing Wallpapers/
├── 2026-10-24/
│   ├── bing-wallpaper-1.jpg
│   ├── bing-wallpaper-2.jpg
│   ├── bing-wallpaper-3.jpg
│   └── bing-wallpaper-4.jpg
└── 2026-10-25/
    ├── bing-wallpaper-1.jpg
    ├── bing-wallpaper-2.jpg
    ├── bing-wallpaper-3.jpg
    └── bing-wallpaper-4.jpg
```

---

## Progress Bar Preview

```text
Fetching 4 unique wallpapers for 2026-10-25 (idx=0)...
████████████████░░░░░░░░░░░░░░░░  50% [2/4] Saved: The clock strikes back
```

---

## Automated Daily Downloads (Cron)

To automatically download daily wallpapers every day at 09:00 AM, add a cron job:

```bash
crontab -e
```

Add the following line:
```cron
0 9 * * * /home/priyanshu/Documents/savebingwall/get-bing-wallpapers.sh <<< "0" >/dev/null 2>&1
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Priyanshu
