#!/bin/bash
# dotgen.sh - "dot" static site generator (container version)

set -euo pipefail
trap 'echo "Error at line $LINENO: $BASH_COMMAND"' ERR

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
templatePage="$templateHTML/page.html"
templateIndexPre="$templateHTML/indexPre.html"
templateIndexItem="$templateHTML/indexItem.html"
templateIndexPost="$templateHTML/indexPost.html"

# Output
indexFile="$publishedRoot/index.html"
indexTemp="$publishedRoot/index.temp.html"

# Tools
tplTool="/usr/local/bin/rdrtpl.php"
markdownFile="article.md"

# Helpers
sanitize_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
           | sed 's/[^a-z0-9]/-/g' \
           | sed 's/-\{2,\}/-/g' \
           | sed 's/^-//' | sed 's/-$//'
}

base64_encode() {
  printf '%s' "$1" | base64 -w0
}

# command extraction
commando="${1:-}"
shift || true

if [ -z "$commando" ]; then
  echo "[DOT - a tiny static blog generator]"
  echo
  echo "Usage:"
  echo "dot init     ~/blog"
  echo "dot article  ~/blog slug"
  echo "dot page     ~/blog slug"
  echo "dot build    ~/blog [~/theme]"
  exit 0
fi

# init
if [ "$commando" == "init" ]; then
  mkdir -p "$articlesDir" "$pagesDir"
  mkdir -p "$publishedArticles" "$publishedPages" "$publishedAssets"
  exit 0
fi

# new article
if [ "$commando" == "article" ]; then
  raw_slug="$2"
  slug=$(sanitize_slug "$raw_slug")
  timestamp=$(date +'%Y_%m_%d_%H_%M')
  folder="$articlesDir/${timestamp}_${slug}"
  mkdir -p "$folder"
  {
    echo "## $(echo "$raw_slug" | tr '-' ' ' | sed 's/.*/\u&/')"
    echo
    echo "First paragraph of your article goes here."
  } > "$folder/$markdownFile"
  exit 0
fi

# new page
if [ "$commando" == "page" ]; then
  raw_slug="$2"
  slug=$(sanitize_slug "$raw_slug")
  folder="$pagesDir/$slug"
  mkdir -p "$folder"
  {
    echo "## $(echo "$raw_slug" | tr '-' ' ' | sed 's/.*/\u&/')"
    echo
    echo "This is the $slug page."
  } > "$folder/$markdownFile"
  exit 0
fi

# === BUILD ===
if [ "$commando" == "build" ]; then

  # make sure folders are empty but exist
  mkdir -p "$publishedArticles" "$publishedPages" "$publishedAssets"
  rm -f "$publishedRoot"/*.html > /dev/null 2>&1

  # fetch some variables
  siteTitle=$(jq -r '.siteTitle' ${blogRoot}/prefs.json)
  authorName=$(jq -r '.author' ${blogRoot}/prefs.json)

  # generate articles / pages
  indexEntries=()
  for kind in article page; do
    if [ "$kind" == "article" ]; then
      sourceFolders=("$articlesDir/"*/)
      targetBase="$publishedArticles"
      template="$templateArticle"
    else
      sourceFolders=("$pagesDir/"*/)
      targetBase="$publishedPages"
      template="$templatePage"
    fi

    for dir in "${sourceFolders[@]}"; do
      file="$dir$markdownFile"
      [ -f "$file" ] || continue

      folderName=$(basename "$dir")
      if [ "$kind" == "article" ]; then
        dmod=$(date -d "$(echo "$folderName" | awk -F_ '{print $1 "-" $2 "-" $3 "T" $4 ":" $5}')" +"%Y-%m-%d %H:%M")
      else
        dmod=$(date -d "@$(stat -c '%Y' "$file")" +"%Y-%m-%d %H:%M")
      fi

      htmlFile="$targetBase/$folderName.html"
      assetFolder="$targetBase/$folderName"

      # Resolve markdown and recode
      content=$(cat "$file" | recode utf8..html | markdown)

      # extract some variables
      headline=$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null || true)
      summary=$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null || true)
      image=$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null || true)
      [ -n "$image" ] && image="\"@type\": \"imageObject\", \"url\": \"$image\""

      $tplTool "$template" \
        SITETITLE="$(base64_encode "$siteTitle")" \
        AUTHOR="$(base64_encode "$authorName")" \
        HEADLINE="$(base64_encode "$headline")" \
        SUMMARY="$(base64_encode "$summary")" \
        DMOD="$(base64_encode "$dmod")" \
        IMAGE="$(base64_encode "$image")" \
        CONTENT="$(base64_encode "$content")" > "$htmlFile"

      hxnormalize -e -l 85 "$htmlFile" | sponge "$htmlFile"

      # Copy assets into /articleName/
      mkdir -p "$assetFolder"
      rsync -a --exclude="$markdownFile" "$dir" "$assetFolder/"

      if [ "$kind" == "article" ]; then
        indexEntries+=("$folderName|$headline|$summary|$dmod|$image")
      fi
    done
  done

  # index page intro
  cat "$templateIndexPre" > "$indexFile"

  # generate index items (REVERSED order)
  numArts=${#indexEntries[@]}
  for (( idx=${#indexEntries[@]}-1 ; idx>=0 ; idx-- )); do
    entry="${indexEntries[idx]}"
    IFS='|' read -r name headline summary dmod image <<< "$entry"
    $tplTool "$templateIndexItem" \
      HEADLINE="$(base64_encode "$headline")" \
      SUMMARY="$(base64_encode "$summary")" \
      DMOD="$(base64_encode "$dmod")" \
      IMAGE="$(base64_encode "$image")" \
      ARTICLEF="$(base64_encode "articles/$name.html")" >> "$indexFile"
  done

  # add index page outro
  cat "$templateIndexPost" >> "$indexFile"

  # now resolve template elements and remove temp file
  $tplTool "$indexFile" \
    SITETITLE="$(base64_encode "$siteTitle")" \
    NUMARTS="$(base64_encode "$numArts")" | sponge "$indexFile"

  # normalize index file
  hxnormalize -e -l 85 "$indexFile" | sponge "$indexFile"

  # rsync assets into published folder
  rsync -a "$assetsSrcD/" "$publishedAssets/"

  # done
  exit 0
fi
