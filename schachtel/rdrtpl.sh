#!/bin/bash
# Usage: rdrtpl.sh template_file VAR1=value1 VAR2=value2 ...

template_file="$1"
shift

awk_script='{
    line = $0
'

for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"

    # Escape for awk
    safe_val=$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')

    awk_script+="
    gsub(/\\{\\{$key\\}\\}/, \"$safe_val\", line)
"
done

awk_script+='
    print line
}'

awk "$awk_script" "$template_file"
