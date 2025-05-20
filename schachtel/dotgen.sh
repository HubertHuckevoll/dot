#!/bin/bash
# dotgen.sh - "dot" static site generator (container version)

set -euo pipefail
set -x

# Base mount points inside container
blogRoot="/mnt/blog"
publishedRoot="/mnt/published"
themeRoot="/mnt/theme"

# Subfolders
articlesDir="$blogRoot/articles"
pagesDir="$blogRoot/pages"
publishedArticles="$publishedRoot/articles"
publishedPages="$publishedRoot/pages"
publishedAssets="$publishedRoot/assets"

# Templates
templateHTML="$themeRoot/html"
assetsSrcD="$themeRoot/assets"

templateArticle="$templateHTML/article.html"
templateIndexPre="$templateHTML/indexPre.html"
templateIndexItem="$templateHTML/indexItem.html"
templateIndexPost="$templateHTML/indexPost.html"

# Index output
indexFile="$publishedRoot/index.html"
indexTemp="$publishedRoot/index.temp.html"

# External tools
tplTool="/usr/local/bin/rdrtpl.sh"

# Markdown content
markdownFile="article.md"

# Command
commando="${1:-}"
shift || true

if [ -z "$commando" ]; then
  echo
  echo "[DOT - a tiny static blog generator]"
  echo
  echo "Usage:"
  echo "./dotgen.sh init        /blog"
  echo "./dotgen.sh newArticle  /blog slug"
  echo "./dotgen.sh newPage     /blog slug"
  echo "./dotgen.sh build       /blog /theme"
  exit 0
fi

# === INIT ===
if [ "$commando" == "init" ]; then
  mkdir -p "$articlesDir" "$pagesDir"
  mkdir -p "$publishedArticles" "$publishedPages" "$publishedAssets"
  exit 0
fi

# === NEW ARTICLE ===
if [ "$commando" == "newArticle" ]; then
  slug="$2"
  timestamp=$(date +'%Y_%m_%d_%H_%M')
  folder="$articlesDir/${timestamp}_${slug}"
  mkdir -p "$folder"
  {
    echo "## $(echo "$slug" | tr '-' ' ' | sed 's/.*/\u&/')"
    echo
    echo "First paragraph of your article goes here."
  } > "$folder/$markdownFile"
  exit 0
fi

# === NEW PAGE ===
if [ "$commando" == "newPage" ]; then
  slug="$2"
  folder="$pagesDir/$slug"
  mkdir -p "$folder"
  {
    echo "## $(echo "$slug" | tr '-' ' ' | sed 's/.*/\u&/')"
    echo
    echo "This is the $slug page."
  } > "$folder/$markdownFile"
  exit 0
fi

# === BUILD ===
if [ "$commando" == "build" ]; then
  mkdir -p "$publishedArticles" "$publishedPages" "$publishedAssets"
  rm -f "$publishedRoot"/*.html > /dev/null 2>&1
  cat "$templateIndexPre" > "$indexTemp"

  shopt -s nullglob
  articleFolders=("$articlesDir/"*/)
  IFS=$'\n' sortedArticles=($(printf "%s\n" "${articleFolders[@]}" | sort -r))

  for dir in "${sortedArticles[@]}"; do
    file="$dir$markdownFile"
    [ -f "$file" ] || continue

    folderName=$(basename "$dir")
    dmod=$(date -d "$(echo "$folderName" | awk -F_ '{print $1 "-" $2 "-" $3 "T" $4 ":" $5}')" +"%Y-%m-%d %H:%M")
    outputFile="$publishedArticles/$folderName.html"

    content=$(markdown "$file")
    headline=$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)
    summary=$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)
    image=$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)
    [ -n "$image" ] && image="\"@type\": \"imageObject\", \"url\": \"$image\""

    $tplTool "$templateArticle" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$image" \
      CONTENT_B64="$(printf '%s' "$content" | base64 -w0)" \
      | hxnormalize -e -l 85 > "$outputFile"

    $tplTool "$templateIndexItem" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$image" \
      ARTICLEF="articles/$(basename "$outputFile")" \
      >> "$indexTemp"

    rsync -a --exclude="$markdownFile" "$dir" "$publishedArticles/$folderName/"
  done

  # === PAGES ===
  pageFolders=("$pagesDir/"*/)
  for dir in "${pageFolders[@]}"; do
    file="$dir$markdownFile"
    [ -f "$file" ] || continue

    folderName=$(basename "$dir")
    dmod=$(date -d "@$(stat -c '%Y' "$file")" +"%Y-%m-%d %H:%M")
    outputFile="$publishedPages/$folderName.html"

    content=$(markdown "$file")
    headline=$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)
    summary=$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)
    image=$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)
    [ -n "$image" ] && image="\"@type\": \"imageObject\", \"url\": \"$image\""

    $tplTool "$templateArticle" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$image" \
      CONTENT_B64="$(printf '%s' "$content" | base64 -w0)" \
      | hxnormalize -e -l 85 > "$outputFile"

    rsync -a --exclude="$markdownFile" "$dir" "$publishedPages/$folderName/"
  done

  cat "$templateIndexPost" >> "$indexTemp"
  hxnormalize -e -l 85 "$indexTemp" > "$indexFile"
  rm "$indexTemp"
  rsync -a "$assetsSrcD/" "$publishedAssets/"

  exit 0
fi