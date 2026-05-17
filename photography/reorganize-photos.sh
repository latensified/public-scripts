#!/bin/bash

# Reorganizes files by capture date by MOVING originals and sidecars.
# Intended for my own workflow.
# Test on copies first.

set -euo pipefail
IFS=$'\n\t'

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 source_folder destination_parent_folder"
    exit 1
fi

SRC_DIR="$1"
DST_PARENT="$2"

SIDECAR_EXTENSIONS=("xmp" "dop" "pp3" "aae" "on1" "xml")

find "$SRC_DIR" -type f -print0 | while IFS= read -r -d '' FILE; do
    DATE=$(exiftool -d '%Y-%m-%d' -DateTimeOriginal -s3 "$FILE")

    if [[ -z "$DATE" ]]; then
        echo "[SKIP] No capture date: '$FILE'"
        continue
    fi

    YEAR=${DATE:0:4}
    DEST_FOLDER="$DST_PARENT/$YEAR/$DATE"
    mkdir -p "$DEST_FOLDER"

    BASENAME=$(basename "$FILE")
    FILENAME="${BASENAME%.*}"

    # Move main file
    if [[ -e "$DEST_FOLDER/$BASENAME" ]]; then
        echo "[SKIP] Exists: '$DEST_FOLDER/$BASENAME'"
    else
        echo "[MOVE] '$FILE' → '$DEST_FOLDER/'"
        mv "$FILE" "$DEST_FOLDER/"
    fi

    # Move associated sidecar files
    for EXT in "${SIDECAR_EXTENSIONS[@]}"; do
        SIDECAR="$(dirname "$FILE")/$FILENAME.$EXT"
        SIDE_BASENAME=$(basename "$SIDECAR")
        if [[ -f "$SIDECAR" ]]; then
            if [[ -e "$DEST_FOLDER/$SIDE_BASENAME" ]]; then
                echo "[SKIP SIDECAR] Exists: '$DEST_FOLDER/$SIDE_BASENAME'"
                continue
            fi
            echo "[MOVE SIDECAR] '$SIDECAR' → '$DEST_FOLDER/'"
            mv "$SIDECAR" "$DEST_FOLDER/" || true
        fi
    done
done

