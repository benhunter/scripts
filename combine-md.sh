#!/usr/bin/env bash
# combine-md.sh
# Combine all Markdown files in the current directory into one file

set -euo pipefail

# Output file name
OUTPUT_FILE="combined.md"

# Empty or create the output file
> "$OUTPUT_FILE"

# Loop through all markdown files in the directory
for file in *.md; do
    # Skip the output file if it already exists in the directory
    [[ "$file" == "$OUTPUT_FILE" ]] && continue

    echo "Adding $file..."
    
    # Add filename as a header
    echo -e "\n\n# File: $file\n" >> "$OUTPUT_FILE"
    
    # Append file contents
    cat "$file" >> "$OUTPUT_FILE"
    
    # Add a newline for separation
    echo -e "\n" >> "$OUTPUT_FILE"
done

echo "✅ Combined Markdown files into $OUTPUT_FILE"
