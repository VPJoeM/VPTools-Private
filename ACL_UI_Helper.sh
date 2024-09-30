#!/bin/bash

# Filename: ACL_UI_Help.sh

# Prompt the user to paste the input and then press Ctrl+D to end input
echo "Please paste the input and then press Ctrl+D to finish:"

# Read all input into a variable
input=$(</dev/stdin)

# Extract and print numbers following 'g' in hostnames only
echo "$input" | grep -o 'g[0-9]\{1,\}\.voltagepark\.net' | sed -E 's/g([0-9]+)\.voltagepark\.net/\1/'
