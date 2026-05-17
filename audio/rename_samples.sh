#!/bin/bash

# Check if a suffix was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <suffix>"
    exit 1
fi

# Store the suffix (e.g., "Soft")
SUFFIX="$1"
DIR="."

# Loop through all matching files (.wav, .asd, .reapeaks)
for file in "$DIR"/*.{wav,asd,reapeaks}; do
    # Skip if no matching files are found (prevents errors)
    [ -e "$file" ] || continue

    # Extract the base name without the directory path
    filename=$(basename "$file")

    # Check if the suffix is already present in the filename
    if [[ "$filename" == *"$SUFFIX"* ]]; then
        echo "Skipping (already contains '$SUFFIX'): $filename"
        continue
    fi

    # Extract the first word (assumes filenames start with a single word followed by a space)
    first_word=$(echo "$filename" | awk '{print $1}')
    rest_of_name=$(echo "$filename" | cut -d' ' -f2-)

    # Construct the new filename with the format: "Kick Soft-Drum Samples 230102-039.wav"
    new_filename="${first_word} ${SUFFIX}-${rest_of_name}"

    # Rename the file
    mv "$file" "$DIR/$new_filename"
    echo "Renamed: $filename -> $new_filename"
done

echo "Batch rename completed!"

