#!/bin/bash
# Usage: render_template.sh template_file output_file VAR1=value1 VAR2=value2 ...

template_file="$1"
output_file="$2"
shift 2

awk_script='{
    line = $0
'

# Loop through key=value pairs and append substitution rules
for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"

    # Escape double quotes and backslashes in the value
    safe_val=$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')

    awk_script+="
    gsub(/\\{\\{$key\\}\\}/, \"$safe_val\", line)
"
done

awk_script+='
    print line
}'

awk "$awk_script" "$template_file" | hxnormalize -e -l 85 > "$output_file"
