#!/bin/bash
# Usage: rdrtpl.sh template_file VAR=value ...

template_file="$1"; shift

awk_script='{
  line = $0'
for pair in "$@"; do
  key="${pair%%=*}"
  val="${pair#*=}"

  if [[ "$key" == *_B64 ]]; then
    key="${key%_B64}"
    val_decoded="$(printf '%s' "$val" | base64 -d)"
  else
    val_decoded="$val"
  fi

  # Escape everything safely
  val_escaped=$(printf '%s' "$val_decoded" | sed ':a;N;$!ba;s/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')

  awk_script+="
  gsub(/\\{\\{$key\\}\\}/, \"$val_escaped\", line)"
done
awk_script+='
  print line
}'

awk "$awk_script" "$template_file"
