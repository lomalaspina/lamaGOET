#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lamagoet_shell_env.sh
source "$repo_dir/lamagoet_shell_env.sh"

[[ "$(_lamagoet_crystal_tolinteg auto true)" == "8 8 8 8 16" ]]
[[ -z "$(_lamagoet_crystal_tolinteg auto false)" ]]
[[ -z "$(_lamagoet_crystal_tolinteg default true)" ]]
[[ "$(_lamagoet_crystal_tolinteg '10 10 10 10 20' true)" == \
    "10 10 10 10 20" ]]

if _lamagoet_crystal_tolinteg '8 8 bad 8 16' true >/dev/null 2>&1; then
    echo "invalid non-numeric TOLINTEG was accepted" >&2
    exit 1
fi
if _lamagoet_crystal_tolinteg '8 8 8 16' true >/dev/null 2>&1; then
    echo "four-component TOLINTEG was accepted" >&2
    exit 1
fi
if _lamagoet_crystal_tolinteg '8 8 8 8 0' true >/dev/null 2>&1; then
    echo "zero TOLINTEG component was accepted" >&2
    exit 1
fi

for runner in "$repo_dir/lamaGOET.sh" "$repo_dir/RUN_lamaGOET_release.sh"; do
    grep -q 'CRYSTAL_TOLINTEG:-auto' "$runner"
    grep -q 'echo "TOLINTEG"' "$runner"
    grep -q 'RHOLSK.*BASIS SET LINEARLY DEPENDENT' "$runner"

    crystal_line=$(grep -n 'echo "Crystal cycle number \$I ended"' "$runner" | head -1 | cut -d: -f1)
    failure_line=$(grep -n "grep -q 'SCF ENDED - CONVERGENCE ON ENERGY'" "$runner" | head -1 | cut -d: -f1)
    properties_line=$(grep -n 'echo "Running Crystal properties, cycle number \$I"' "$runner" | head -1 | cut -d: -f1)
    [[ "$crystal_line" -lt "$failure_line" ]]
    [[ "$failure_line" -lt "$properties_line" ]]
done
