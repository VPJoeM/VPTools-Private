#!/bin/bash


echo "Please paste the input and then press Ctrl+D to finish:"

input=$(</dev/stdin)

echo "$input" | grep -o 'g[0-9]\{1,\}\.voltagepark\.net' | sed -E 's/g([0-9]+)\.voltagepark\.net/\1/'
