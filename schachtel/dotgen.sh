#!/bin/bash
# "dot" - a tiny static blog generator written with bash and linux tools
# wrapped up in a container

# exit on any error
set -euo pipefail
set -x

# store command
commando=$1

# help if no commando given
if [ -z "$commando" ]; then
  echo;
  echo "[DOT - a tiny static blog generator]"
  echo;
  echo "Usage:";
  echo "./dot init  ~/blogname";
  echo "./dot new   ~/blogname articleName";
  echo "./dot build ~/blogname ~/themeDir";
  echo;
  exit 0
fi

# init a new project structure
if [ $commando == "init" ]; then

  projectD=$2
  publishedD=$projectD".published/"
  assetsD=$publishedD"assets/"

  mkdir -p "$projectD"
  mkdir -p "$publishedD"
  mkdir -p "$assetsD"

  exit 0
fi

# init a new article
if [ $commando == "new" ]; then
  folderName="${2}"/"$(date +'%Y_%m_%d_%H_%M')_${3}"
  fname=$folderName"/article.md"
  mkdir -p $folderName
  touch $fname
  exit 0
fi

# build everything
if [ $commando == "build" ]; then

  if [ $# -lt 3 ]; then
    echo "Usage: dot build <blogDir> <templateDir>"
    exit 1
  fi

  # folders
  projectD=$2
  templateD=$3"/html/"
  assetsSrcD=$3"/assets/"

  publishedD=$projectD".published/"
  assetsD=$publishedD"assets/"

  # set up target files
  indexF="$publishedD""index.html"
  tempF="$publishedD""temp.html"

  # set up source template files
  templateF="$templateD""article.html"
  indexHeaderF="$templateD""indexPre.html"
  indexItemF="$templateD""indexItem.html"
  indexFooterF="$templateD""indexPost.html"

  # make sure html folder is clean before we re-create
  rm "$publishedD"*.html > /dev/null 2>&1

  # add preample to index
  cat "$indexHeaderF" > "$tempF"

  # read markdown article folders
  shopt -s nullglob
  articleDirs=("$projectD"*/)

  # sort newest first (reverse)
  IFS=$'\n' sortedArticleDirs=($(printf "%s\n" "${articleDirs[@]}" | sort -r))

  for dir in "${sortedArticleDirs[@]}"; do
    markdownF="${dir}article.md"

    # skip if article.md not found
    [ -f "$markdownF" ] || continue

    echo "Processing '$markdownF'"

    # filename is the folder name without trailing slash
    folderName=$(basename "$dir")

    # determine if it's a page (starts with '_')
    isPage=${folderName:0:1}

    if [ "$isPage" != "_" ]; then
      # extract date and time from folder name (e.g. 2025_05_17_14_36)
      year=${folderName:0:4}
      month=${folderName:5:2}
      day=${folderName:8:2}
      hour=${folderName:11:2}
      minute=${folderName:14:2}
      dmod=$(date -d "$year-$month-$day $hour:$minute" +"%Y-%m-%d %H:%M")
    else
      dmod=$(date -d "@$(stat -c '%Y' "$markdownF")" +"%Y-%m-%d %H:%M")
    fi

    # output file
    articleF="$publishedD${folderName}.html"

    # do the md => html conversion
    content=$(markdown "$markdownF")

    # extract headline and summary
    headline="$(echo "$content" | xml2asc | xmllint --html --xpath "//h2[1]/text()" - 2>/dev/null)"
    summary="$(echo "$content" | xml2asc | xmllint --html --xpath "//p[1]/text()" - 2>/dev/null)"
    firstImage="$(echo "$content" | xml2asc | xmllint --html --xpath "string(//img[1]/@src)" - 2>/dev/null)"

    if [ -n "$firstImage" ]; then
      firstImage="\"@type\": \"imageObject\", \"url\": \"$firstImage\""
    fi

    # render article page
    /root/rdrtpl.sh "$templateF" \
      HEADLINE="$headline" \
      SUMMARY="$summary" \
      DMOD="$dmod" \
      IMAGE="$firstImage" \
      CONTENT="$content" \
      | hxnormalize -e -l 85 > "$articleF"

    # update index if not a "page"
    if [ "$isPage" != "_" ]; then
      /root/rdrtpl.sh "$indexItemF" \
        HEADLINE="$headline" \
        SUMMARY="$summary" \
        DMOD="$dmod" \
        IMAGE="$firstImage" \
        ARTICLEF="$(basename "$articleF")" \
        >> "$tempF"
    fi
done

  # add postample to index
  cat "$indexFooterF" >> "$tempF"

  # beautify index file
  hxnormalize -e -l 85 "$tempF" > "$indexF"

  # copy assets from theme dir to publish
  # adds the ability to process images, styles & scripts
  # before putting them into the published folder
  rsync -a "$assetsSrcD" "$assetsD"

  # clean up
  rm "$tempF"
fi