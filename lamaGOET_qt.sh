#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
python_command=${LAMAGOET_QT_PYTHON:-python3}

exec "$python_command" "$script_dir/GUI_lamaGOET_qt.py" --mode local "$@"
