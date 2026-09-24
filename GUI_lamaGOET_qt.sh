#!/usr/bin/env bash
set -euo pipefail

script_source=${BASH_SOURCE[0]}
while [[ -L "$script_source" ]]; do
    source_dir=$(cd -P "$(dirname "$script_source")" && pwd)
    script_source=$(readlink "$script_source")
    [[ "$script_source" = /* ]] || script_source="$source_dir/$script_source"
done
script_dir=$(cd -P "$(dirname "$script_source")" && pwd)

if [[ -n "${LAMAGOET_QT_PYTHON:-}" ]]; then
    python_command=$LAMAGOET_QT_PYTHON
elif [[ -x "$script_dir/.venv-qt/bin/python" ]]; then
    python_command="$script_dir/.venv-qt/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    python_command=python3
elif command -v python >/dev/null 2>&1; then
    python_command=python
else
    echo "lamaGOET Qt requires Python 3.10 or newer." >&2
    exit 2
fi

exec "$python_command" "$script_dir/GUI_lamaGOET_qt.py" --mode cluster "$@"
