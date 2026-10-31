#!/usr/bin/env bash
# ==============================================================================
# Script: get-bing-wallpapers.sh
# Description: Fetches and downloads 4 unique Bing wallpapers for a given date
#              or number of days ago across global Bing regional markets.
# Features:
#   - Global Region Sampling: Queries 12 international markets for localized images.
#   - Deduplication: Extracts base image IDs to prevent saving duplicate pictures.
#   - Archive Fallback: Automatically falls back to adjacent archive days if a
#     single day does not offer 4 unique wallpapers worldwide.
#   - Clean Block Progress Bar: In-place animated progress bar (█ and ░).
#   - Safe Downloads: Writes to temporary files before moving to prevent partial files.
# ==============================================================================

# Enable strict error handling:
# -E: ERR trap is inherited by functions and subshells
# -e: Exit immediately if a command exits with a non-zero status
# -u: Treat unset variables as an error
# -o pipefail: Pipeline returns status of the last command to exit with a non-zero status
set -Eeuo pipefail

# ------------------------------------------------------------------------------
# 1. User Input & Date Parsing
# ------------------------------------------------------------------------------
# Prompt the user for either an absolute date (YYYY-MM-DD) or relative days ago (0-7).
read -rp "Enter date (YYYY-MM-DD) or days ago (0=today, 1=yesterday, default 0): " USER_INPUT
USER_INPUT="${USER_INPUT:-0}"

# If input is a pure integer, treat it as "days ago" (e.g., 0 = today, 1 = yesterday)
if [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
    IDX="$USER_INPUT"
    DATE="$(date -d "$IDX days ago" +%F)"
else
    # Parse input as a date string (YYYY-MM-DD)
    if TARGET_DATE="$(date -d "$USER_INPUT" +%F 2>/dev/null)"; then
        TODAY_DATE="$(date +%F)"
        TARGET_SEC="$(date -d "$TARGET_DATE" +%s)"
        TODAY_SEC="$(date -d "$TODAY_DATE" +%s)"

        # Calculate difference in days. Adding 43200s (12h) guards against daylight saving shifts.
        DIFF_DAYS=$(( (TODAY_SEC - TARGET_SEC + 43200) / 86400 ))

        if (( DIFF_DAYS < 0 )); then
            echo "Error: Cannot fetch wallpapers for future dates." >&2
            exit 1
        fi
        IDX="$DIFF_DAYS"
        DATE="$TARGET_DATE"
    else
        echo "Error: Invalid date format. Use YYYY-MM-DD or a number (0-7)." >&2
        exit 1
    fi
fi

# Warn if requesting older than Bing's usual 7-day archive window
if (( IDX > 7 )); then
    echo "Warning: Bing typically only archives up to 7 days of wallpapers." >&2
fi

# ------------------------------------------------------------------------------
# 2. Configuration & Directory Setup
# ------------------------------------------------------------------------------
PICTURES_DIR="$HOME/Pictures/Bing Wallpapers"
DEST_DIR="$PICTURES_DIR/$DATE"
TARGET_COUNT=4

# Top Bing markets that frequently feature unique localized daily wallpapers:
# US, UK, Australia, Canada, India, Japan, China, Germany, France, Italy, Spain, Brazil
MARKETS=("en-US" "en-GB" "en-AU" "en-CA" "en-IN" "ja-JP" "zh-CN" "de-DE" "fr-FR" "it-IT" "es-ES" "pt-BR")

# Ensure the destination directory exists
mkdir -p "$DEST_DIR"

# Clean up any leftover temporary download files on script exit/abort
trap 'rm -f "$DEST_DIR"/.wallpaper.* 2>/dev/null || true' EXIT

echo "Fetching $TARGET_COUNT unique wallpapers for $DATE (idx=$IDX)..."

# ------------------------------------------------------------------------------
# 3. Terminal Progress Bar Component
# ------------------------------------------------------------------------------
# Renders an in-place progress bar using filled (█) and unfilled (░) blocks.
# Arguments:
#   $1 - current count (0..total)
#   $2 - total count
#   $3 - short status message
show_progress() {
    local current="$1"
    local total="$2"
    local status="${3:-}"

    # Detect terminal columns dynamically (defaulting to 80 if unavailable)
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    cols="${cols:-80}"

    # Choose a compact bar width so the entire line never exceeds terminal width
    local width=20
    if (( cols >= 100 )); then
        width=28
    fi

    local pct=$(( current * 100 / total ))
    local num_filled=$(( current * width / total ))
    local num_empty=$(( width - num_filled ))
    local bar=""

    # Build the bar graphic
    for (( i = 0; i < num_filled; i++ )); do bar+="█"; done
    for (( i = 0; i < num_empty; i++ )); do bar+="░"; done

    # Dynamically budget status length based on terminal width to avoid line wrapping
    # Fixed prefix: width + 1 (space) + 4 (pct) + 1 (space) + 5 (count) + 1 (space) + 2 (margin)
    local max_status_len=$(( cols - width - 14 ))
    if (( max_status_len < 10 )); then
        max_status_len=10
    fi

    if (( ${#status} > max_status_len )); then
        status="${status:0:max_status_len-3}..."
    fi

    # \r returns to start of line; \033[K clears to end of line without causing line wraps
    printf "\r\033[K%s %3d%% [%d/%d] %s" "$bar" "$pct" "$current" "$total" "$status"
}

# ------------------------------------------------------------------------------
# 4. Wallpaper Retrieval & Fallback Strategy
# ------------------------------------------------------------------------------
# Associative array to track unique photo base identifiers (prevents duplicate images)
declare -A SEEN_KEYS=()
index=1

show_progress 0 "$TARGET_COUNT" "Starting..."

# Build priority list of archive indices:
# Primary date ($IDX) comes first. If global markets don't yield 4 unique images,
# we search adjacent days (IDX+1 .. 7, then IDX-1 .. 0) to fulfill the target.
candidate_indices=("$IDX")
for (( i = IDX + 1; i <= 7; i++ )); do
    candidate_indices+=("$i")
done
for (( i = IDX - 1; i >= 0; i-- )); do
    candidate_indices+=("$i")
done

# Outer loop: traverse archive days
for check_idx in "${candidate_indices[@]}"; do
    if (( index > TARGET_COUNT )); then
        break
    fi

    # Update status when querying adjacent archive days
    if (( check_idx != IDX )); then
        show_progress "$((index - 1))" "$TARGET_COUNT" "Searching archive (idx=$check_idx)..."
    fi

    # Inner loop: query regional markets for the current day index
    for market in "${MARKETS[@]}"; do
        if (( index > TARGET_COUNT )); then
            break
        fi

        # Query the Bing Image Archive JSON API
        api_url="https://www.bing.com/HPImageArchive.aspx?format=js&idx=${check_idx}&n=1&mkt=${market}"
        feed="$(curl -fsSL --retry 2 "$api_url" 2>/dev/null || true)"

        [[ -z "$feed" ]] && continue

        # Extract image relative path and title from JSON response
        img_rel_url="$(jq -r '.images[0].url // empty' <<< "$feed")"
        img_title="$(jq -r '.images[0].title // empty' <<< "$feed")"

        [[ -z "$img_rel_url" ]] && continue

        # Extract the base photo identifier (e.g., 'OHR.SitovoWaterfall' from 'OHR.SitovoWaterfall_EN-US...')
        # to ensure that pictures shared across regions are not downloaded twice.
        img_id="${img_rel_url#*id=}"
        img_id="${img_id%%&*}"
        photo_key="${img_id%%_*}"

        if [[ -n "${SEEN_KEYS[$photo_key]:-}" ]]; then
            continue
        fi
        SEEN_KEYS["$photo_key"]=1

        # Format full image URL (handle both relative and absolute URLs)
        [[ "$img_rel_url" == https://* ]] && img_url="$img_rel_url" || img_url="https://www.bing.com$img_rel_url"

        image_file="$DEST_DIR/bing-wallpaper-$index.jpg"
        desc="${img_title:-$market}"

        # If file is already downloaded and non-empty, skip re-downloading
        if [[ -s "$image_file" ]]; then
            show_progress "$index" "$TARGET_COUNT" "Already exists: $market"
            ((index++))
            continue
        fi

        # Download to a temporary hidden file first to prevent partial/corrupted files
        show_progress "$((index - 1))" "$TARGET_COUNT" "Downloading: $desc"
        temp_file="$(mktemp "$DEST_DIR/.wallpaper.XXXXXX")"

        if curl -fsSL --retry 2 --connect-timeout 15 "$img_url" -o "$temp_file" && [[ -s "$temp_file" ]]; then
            mv "$temp_file" "$image_file"
            show_progress "$index" "$TARGET_COUNT" "Saved: $desc"
            ((index++))
        else
            rm -f "$temp_file"
            show_progress "$((index - 1))" "$TARGET_COUNT" "Failed: $market"
        fi
    done
done

# ------------------------------------------------------------------------------
# 5. Completion Summary
# ------------------------------------------------------------------------------
show_progress "$((index - 1))" "$TARGET_COUNT" "Complete!"
echo ""
echo "Done! Saved $((index - 1)) wallpapers in: $DEST_DIR"
