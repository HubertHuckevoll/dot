#!/bin/bash
# dotgen.sh - "dot" static site generator (container version)

set -euo pipefail
set -x

commando="${1:-}"
shift || true

# Help
if [ -z "$commando" ]; then
  echo
  echo "[DOT - a tiny static blog generator]"
  echo
  echo "Usage:"
  echo "./dotgen.sh init        <blogDir>"
  echo "./dotgen.sh newArticle  <blogDir> <slug>"
  echo "./dotgen.sh newPage     <blogDir> <slug>"
  echo "./dotgen.sh build       <blogDir> <templateDir>"
  exit 0
fi

# --- init ---
if [ "$commando" == "init" ]; then
  projectD="$1"
  mkdir -p "$projectD/articles"
  mkdir -p "$projectD/pages"
  mkdir -p "${projectD}.published/articles"
  mkdir -p "${projectD}.published/pages"
  exit 0
fi

# --- newArticle ---
if [ "$commando" == "newArticle" ]; then
  projectD="$1"
  slug="$2"
  timestamp=$(date +'%Y_%m_%d_%H_%M')
  folder="$projectD/articles/${timestamp}_${slug}"
  mkdir -p "$folder"

  {
    echo "## $(echo "$slug" | tr '-' ' ' | sed 's/.*/\u&/')"
    echo
    echo "First paragraph of your article goes here."
    echo
  } > "$folder/article.md"

  exit 0
fi

# --- newPage ---
if [ "$commando" == "newPage" ]; then
  projectD="$1"
  slug="$2"
  folder="$projectD/pages/$slug"
  mkdir -p "$folder"

  {
    echo "## $(echo "$slug" | tr '-' ' ' | sed 's/.*/\u&/')"
    echo
    echo "This is the $slug page."
    echo
  } > "$folder/article.md"

  exit 0
fi

# --- build ---
if [ "$commando" == "build" ]; then
  if [ $# -lt 2 ]; then
    echo "Usage: dotgen.sh build <blogDir> <templateDir>"
    exit 1
  fi

  projectD="$1"
  templateBase="$2"
  templateD="$templateBase/html"
  assetsSrcD="$templateBase/assets"

  publishedD="${projectD}.published"
  mkdir -p "$publishedD/articles" "$publishedD/pages" "$publishedD/assets"

  indexF="$publishedD/index.html"
  tempF="$publishedD/temp.html"

  templateF="$templateD/article.html"
  indexHeaderF="$templateD/indexPre.html"
  indexItemF="$templateD/indexItem.html"
  indexFooterF="$templateD/indexPost.html"

  # Clean published HTMLs
  rm -f "$publishedD/"*.html > /dev/null 2>&1

  # Start index
  cat "$indexHeaderF" > "$tempF"

  # === Process Articles ===
  shopt -s nullglob
  articleDirs=("$projectD/articles/"*/)
  echo "Found articleDirs:"
  printf ' - %s\n' "${articleDirs[@]}"


  IFS=$'\n' sortedArticleDirs=($(printf "%s\n" "${articleDirs[@]}" | sort -r))

  for dir in "${sortedArticleDirs[@]}"; do
    markdownF="${dir}article.md"
    [ -f "$markdownF" ] || continue

    folderName=$(basename "$dir")
    date_time=$(echo "$folderName" | awk -F_ '{print $1 "-" $2 "-" $3 "T" $4 ":" $5}')
    dmod=$(date -d "$date_time" +"%Y-%m-%d %H:%M")

    articleF="$publishedD/articles/${folderName}.html"

    content=$(markdown "$markdownF")
    headline="$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)"
    summary="$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)"
    firstImage="$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)"

    if [ -n "$firstImage" ]; then
      firstImage="\"@type\": \"imageObject\", \"url\": \"$firstImage\""
    fi

    /root/rdrtpl.sh "$templateF" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$firstImage" \
      CONTENT_B64="$(printf '%s' "$content" | base64 -w0)" \
      | hxnormalize -e -l 85 > "$articleF"

    # Render index item for article (not for pages!)
    /root/rdrtpl.sh "$indexItemF" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$firstImage" \
      ARTICLEF="articles/$(basename "$articleF")" \
      >> "$tempF"
  done

  # === Process Pages ===
  pageDirs=()
  for dir in "$projectD/pages/"*/; do
    [ -d "$dir" ] && pageDirs+=("$dir")
  done

  for dir in "${pageDirs[@]}"; do
    markdownF="${dir}article.md"
    [ -f "$markdownF" ] || continue

    folderName=$(basename "$dir")
    dmod=$(date -d "@$(stat -c '%Y' "$markdownF")" +"%Y-%m-%d %H:%M")
    articleF="$publishedD/pages/${folderName}.html"

    content=$(markdown "$markdownF")
    headline="$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)"
    summary="$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)"
    firstImage="$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)"

    if [ -n "$firstImage" ]; then
      firstImage="\"@type\": \"imageObject\", \"url\": \"$firstImage\""
    fi

    /root/rdrtpl.sh "$templateF" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$firstImage" \
      CONTENT_B64="$(printf '%s' "$content" | base64 -w0)" \
      | hxnormalize -e -l 85 > "$articleF"
  done

  # Finalize index
  cat "$indexFooterF" >> "$tempF"
  hxnormalize -e -l 85 "$tempF" > "$indexF"
  rm "$tempF"

  # Copy assets
  rsync -a "$assetsSrcD/" "$publishedD/assets/"
fi
