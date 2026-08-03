#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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
