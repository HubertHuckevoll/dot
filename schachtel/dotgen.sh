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
tplTool="/usr/local/bin/rdrtpl.php"

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
  echo "./dot init     ~/blog"
  echo "./dot article  ~/blog slug"
  echo "./dot page     ~/blog slug"
  echo "./dot build    ~/blog [~/theme]"
  exit 0
fi

# === INIT ===
if [ "$commando" == "init" ]; then
  mkdir -p "$articlesDir" "$pagesDir"
  mkdir -p "$publishedArticles" "$publishedPages" "$publishedAssets"
  exit 0
fi

# === NEW ARTICLE ===
if [ "$commando" == "article" ]; then
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
if [ "$commando" == "page" ]; then
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

# === BASE64 ENCODE ===
base64_encode() {
  printf '%s' "$1" | base64 -w0
}

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
    mkdir -p "$publishedArticles/$folderName"
    outputFile="$publishedArticles/$folderName/$folderName.html"

    content=$(markdown "$file")
    headline=$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)
    summary=$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)
    image=$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)
    [ -n "$image" ] && image="\"@type\": \"imageObject\", \"url\": \"$image\""

    $tplTool "$templateArticle" \
      HEADLINE="$(base64_encode "$headline")" \
      SUMMARY="$(base64_encode "$summary")" \
      DMOD="$(base64_encode "$dmod")" \
      IMAGE="$(base64_encode "$image")" \
      CONTENT="$(base64_encode "$content")" \
      | hxnormalize -e -l 85 > "$outputFile"

    $tplTool "$templateIndexItem" \
      HEADLINE="$(base64_encode "$headline")" \
      SUMMARY="$(base64_encode "$summary")" \
      DMOD="$(base64_encode "$dmod")" \
      IMAGE="$(base64_encode "$image")" \
      ARTICLEF="$(base64_encode "articles/$(basename "$outputFile")")" \
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
    mkdir -p "$publishedPages/$folderName"
    outputFile="$publishedPages/$folderName/$folderName.html"

    content=$(markdown "$file")
    headline=$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)
    summary=$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)
    image=$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)
    [ -n "$image" ] && image="\"@type\": \"imageObject\", \"url\": \"$image\""

    $tplTool "$templateArticle" \
      HEADLINE="$(base64_encode "$headline")" \
      SUMMARY="$(base64_encode "$summary")" \
      DMOD="$(base64_encode "$dmod")" \
      IMAGE="$(base64_encode "$image")" \
      CONTENT="$(base64_encode "$content")" \
      | hxnormalize -e -l 85 > "$outputFile"

    rsync -a --exclude="$markdownFile" "$dir" "$publishedPages/$folderName/"
  done

  cat "$templateIndexPost" >> "$indexTemp"
  hxnormalize -e -l 85 "$indexTemp" > "$indexFile"
  rm "$indexTemp"
  rsync -a "$assetsSrcD/" "$publishedAssets/"

  exit 0
fi