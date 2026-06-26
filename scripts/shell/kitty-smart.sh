#!/usr/bin/env sh
set -eu

output_count="$(niri msg --json outputs | jq 'length')"

if [ "${output_count}" -ge 2 ]; then
  exec kitty --override font_size=12
else
  exec kitty --override font_size=14
fi
