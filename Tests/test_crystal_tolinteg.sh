#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lamagoet_shell_env.sh
source "$repo_dir/lamagoet_shell_env.sh"

size_input=$(mktemp)
trap 'rm -f -- "$size_input"' EXIT
_lamagoet_write_crystal_size "$size_input" BIPOSIZE ""
[[ ! -s "$size_input" ]]
_lamagoet_write_crystal_size "$size_input" BIPOSIZE "6340350"
_lamagoet_write_crystal_size "$size_input" ILASIZE "12000"
[[ "$(cat "$size_input")" == $'BIPOSIZE\n6340350\nILASIZE\n12000' ]]
for bad_value in 0 -1 '6000 extra' '1;STOP'; do
    if _lamagoet_write_crystal_size "$size_input" ILASIZE "$bad_value" \
        >/dev/null 2>&1; then
        echo "invalid Crystal size value was accepted: $bad_value" >&2
        exit 1
    fi
done
if _lamagoet_write_crystal_size "$size_input" EXCHSIZE 1000 \
    >/dev/null 2>&1; then
    echo "unsupported Crystal size keyword was accepted" >&2
    exit 1
fi

ldremo_input=$(mktemp)
trap 'rm -f -- "$size_input" "$ldremo_input"' EXIT
_lamagoet_write_crystal_ldremo "$ldremo_input" ""
_lamagoet_write_crystal_ldremo "$ldremo_input" default
[[ ! -s "$ldremo_input" ]]
_lamagoet_write_crystal_ldremo "$ldremo_input" 4
[[ "$(cat "$ldremo_input")" == $'LDREMO\n4' ]]
for bad_value in 0 -1 100 '4 extra' '4;STOP'; do
    if _lamagoet_write_crystal_ldremo "$ldremo_input" "$bad_value" \
        >/dev/null 2>&1; then
        echo "invalid Crystal LDREMO value was accepted: $bad_value" >&2
        exit 1
    fi
done

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
    grep -q '_lamagoet_write_crystal_ldremo.*JOBNAME.d12' "$runner"
    grep -q '_lamagoet_write_crystal_size.*BIPOSIZE.*BIPOSIZE' "$runner"
    grep -q '_lamagoet_write_crystal_size.*ILASIZE.*ILASIZE' "$runner"
    grep -q 'RHOLSK.*BASIS SET LINEARLY DEPENDENT' "$runner"
    grep -q 'TOLINTEG=auto provides a screening baseline but cannot condition every molecular basis' "$runner"

    biposize_line=$(grep -n '_lamagoet_write_crystal_size.*BIPOSIZE.*BIPOSIZE' "$runner" | head -1 | cut -d: -f1)
    ilasize_line=$(grep -n '_lamagoet_write_crystal_size.*ILASIZE.*ILASIZE' "$runner" | head -1 | cut -d: -f1)
    shrink_line=$(grep -n 'echo "SHRINK"' "$runner" | head -1 | cut -d: -f1)
    tol_line=$(grep -n 'echo "TOLINTEG"' "$runner" | head -1 | cut -d: -f1)
    ldremo_line=$(grep -n '_lamagoet_write_crystal_ldremo.*JOBNAME.d12' "$runner" | head -1 | cut -d: -f1)
    toldee_line=$(grep -n 'echo "TOLDEE"' "$runner" | head -1 | cut -d: -f1)
    [[ "$biposize_line" -lt "$ilasize_line" ]]
    [[ "$ilasize_line" -lt "$shrink_line" ]]
    [[ "$shrink_line" -lt "$tol_line" ]]
    [[ "$tol_line" -lt "$ldremo_line" ]]
    [[ "$ldremo_line" -lt "$toldee_line" ]]

    crystal_line=$(grep -n 'echo "Crystal cycle number \$I ended"' "$runner" | head -1 | cut -d: -f1)
    failure_line=$(grep -n "grep -q 'SCF ENDED - CONVERGENCE ON ENERGY'" "$runner" | head -1 | cut -d: -f1)
    properties_line=$(grep -n 'echo "Running Crystal properties, cycle number \$I"' "$runner" | head -1 | cut -d: -f1)
    [[ "$crystal_line" -lt "$failure_line" ]]
    [[ "$failure_line" -lt "$properties_line" ]]
done
