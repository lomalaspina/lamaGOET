#!/bin/bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

load_detector() {
    local script=$1
    source <(
        awk '
            /^_har_abs_diff_le\(\)/ { copy = 1 }
            /^CHECK_ENERGY\(\)/ { copy = 0 }
            copy { print }
        ' "$script"
    )
}

test_period_two_series() {
    unset HAR_ENERGY_LAST HAR_ENERGY_PREV2
    unset HAR_DIRECT_REPEAT_COUNT HAR_PERIOD2_REPEAT_COUNT
    HAR_WAVEFUNCTION_STALLED=false

    CHECK_WAVEFUNCTION_STALL -56.5542666 6.984e-09
    CHECK_WAVEFUNCTION_STALL -56.5542757 6.984e-09
    CHECK_WAVEFUNCTION_STALL -56.5542666 6.984e-09
    CHECK_WAVEFUNCTION_STALL -56.5542757 6.984e-09

    [[ "$HAR_WAVEFUNCTION_STALLED" == "true" ]]
}

test_direct_repeat_series() {
    unset HAR_ENERGY_LAST HAR_ENERGY_PREV2
    unset HAR_DIRECT_REPEAT_COUNT HAR_PERIOD2_REPEAT_COUNT
    HAR_WAVEFUNCTION_STALLED=false

    CHECK_WAVEFUNCTION_STALL -40.123456789 1.0e-09
    CHECK_WAVEFUNCTION_STALL -40.123456790 1.0e-09
    CHECK_WAVEFUNCTION_STALL -40.123456789 1.0e-09

    [[ "$HAR_WAVEFUNCTION_STALLED" == "true" ]]
}

test_high_rmsd_does_not_stop() {
    unset HAR_ENERGY_LAST HAR_ENERGY_PREV2
    unset HAR_DIRECT_REPEAT_COUNT HAR_PERIOD2_REPEAT_COUNT
    HAR_WAVEFUNCTION_STALLED=false

    CHECK_WAVEFUNCTION_STALL -40.0 1.0e-03
    CHECK_WAVEFUNCTION_STALL -40.0 1.0e-03
    CHECK_WAVEFUNCTION_STALL -40.0 1.0e-03

    [[ "$HAR_WAVEFUNCTION_STALLED" == "false" ]]
}

for script in "$repo_dir/lamaGOET.sh" "$repo_dir/RUN_lamaGOET_release.sh"; do
    load_detector "$script"
    test_period_two_series
    test_direct_repeat_series
    test_high_rmsd_does_not_stop

    grep -q 'HAR_WAVEFUNCTION_STALLED:-false' "$script"
    if grep -q 'SAME=$(diff temp1 temp2)' "$script"; then
        echo "Obsolete CIF text-difference convergence test remains in $script" >&2
        exit 1
    fi
done

echo "HAR stationary-wavefunction tests passed"
