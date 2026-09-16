#!/usr/bin/env bash
# Build the searchable GitHub Pages site and the matching scientific manual.

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir="$repo_dir/docs/manual"
build_dir="$repo_dir/docs/_build"
output_dir="$repo_dir/output/pdf"

if [ -x "$repo_dir/.venv-docs/bin/python" ]; then
    python_bin="$repo_dir/.venv-docs/bin/python"
elif [ -x "$repo_dir/.venv-docs/Scripts/python.exe" ]; then
    python_bin="$repo_dir/.venv-docs/Scripts/python.exe"
else
    python_bin=$(command -v python3 || command -v python)
fi

"$python_bin" -m sphinx -W --keep-going -b html "$source_dir" "$build_dir/html"
"$python_bin" -m sphinx -W --keep-going -b latex \
    "$source_dir" "$build_dir/latex"
make -C "$build_dir/latex" all-pdf

mkdir -p "$output_dir" "$build_dir/html/downloads"
cp "$build_dir/latex/lamaGOET-Scientific-Manual.pdf" \
   "$output_dir/lamaGOET-Scientific-Manual.pdf"
cp "$output_dir/lamaGOET-Scientific-Manual.pdf" \
   "$build_dir/html/downloads/lamaGOET-Scientific-Manual.pdf"

printf 'HTML: %s\n' "$build_dir/html/index.html"
printf 'PDF:  %s\n' "$output_dir/lamaGOET-Scientific-Manual.pdf"
