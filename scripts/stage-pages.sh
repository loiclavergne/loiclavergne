#!/bin/bash
#
#  stage-pages.sh
#  Loic Engineer Portfolio
#
#  Created by Loïc Lavergne on 28/03/2026
#  Copyright © 2026 Loïc Lavergne. All rights reserved.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/.pages-dist}"

PUBLIC_PATHS=(
  "404.html"
  "CNAME"
  ".nojekyll"
  "about"
  "assets"
  "css"
  "feed.xml"
  "fr"
  "index.html"
  "js"
  "library"
  "projects"
  "robots.txt"
  "search-index.json"
  "site.webmanifest"
  "sitemap.xml"
  "work"
  "writing"
)

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for path in "${PUBLIC_PATHS[@]}"; do
  source_path="$ROOT_DIR/$path"
  destination_path="$OUTPUT_DIR/$path"

  if [[ ! -e "$source_path" ]]; then
    echo "Missing public path: $path" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$destination_path")"
  cp -R "$source_path" "$destination_path"
done

echo "Staged static site in $OUTPUT_DIR"
