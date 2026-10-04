#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
plugin_dir=$(dirname "$script_dir")

lua "$script_dir/mise_env.lua" "$plugin_dir"
