#!/bin/bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_dir/Tests/lib/shell_test_helpers.sh"

load_detector() {
    local script=$1
    extract_function "$script" '
        /^_har_abs_diff_le\(\)/ { copy = 1 }
        /^CHECK_ENERGY\(\)/ { copy = 0 }
        copy { print }
    ' "stall detector"
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

test_repeated_energy_stops_after_normal_scf_even_with_high_rmsd() {
    unset HAR_ENERGY_LAST HAR_ENERGY_PREV2
    unset HAR_DIRECT_REPEAT_COUNT HAR_PERIOD2_REPEAT_COUNT
    HAR_WAVEFUNCTION_STALLED=false

    CHECK_WAVEFUNCTION_STALL -40.0 1.0e-03
    CHECK_WAVEFUNCTION_STALL -40.0 1.0e-03
    CHECK_WAVEFUNCTION_STALL -40.0 1.0e-03

    [[ "$HAR_WAVEFUNCTION_STALLED" == "true" ]]
}

test_repeated_refined_geometry_stops_despite_energy_jitter() {
    unset HAR_ENERGY_LAST HAR_ENERGY_PREV2
    unset HAR_DIRECT_REPEAT_COUNT HAR_PERIOD2_REPEAT_COUNT
    unset HAR_GEOMETRY_LAST HAR_GEOMETRY_PREV2
    unset HAR_GEOMETRY_DIRECT_REPEAT_COUNT HAR_GEOMETRY_PERIOD2_REPEAT_COUNT
    HAR_WAVEFUNCTION_STALLED=false

    local geometry
    geometry=$(mktemp)
    printf '%s\n' 'data_test' '_atom_site_label N1' > "$geometry"

    CHECK_WAVEFUNCTION_STALL -225.972329568128 0.0 "$geometry"
    CHECK_WAVEFUNCTION_STALL -225.972330783360 0.0 "$geometry"
    CHECK_WAVEFUNCTION_STALL -225.972329891069 0.0 "$geometry"

    [[ "$HAR_WAVEFUNCTION_STALLED" == "true" ]]
    rm -f "$geometry"
}

for script in "$repo_dir/lamaGOET.sh" "$repo_dir/RUN_lamaGOET_release.sh"; do
    load_detector "$script"
    test_period_two_series
    test_direct_repeat_series
    test_repeated_energy_stops_after_normal_scf_even_with_high_rmsd
    test_repeated_refined_geometry_stops_despite_energy_jitter

    grep -q 'HAR_WAVEFUNCTION_STALLED:-false' "$script"
    if grep -q 'SAME=$(diff temp1 temp2)' "$script"; then
        echo "Obsolete CIF text-difference convergence test remains in $script" >&2
        exit 1
    fi
done

extract_function "$repo_dir/lamaGOET.sh" '
        /^CP2K_RUN_HAR\(\)/ { copy = 1 }
        copy { print }
        copy && /^}$/ { exit }
' "CP2K_RUN_HAR"

test_cp2k_stationary_energy_stops_before_another_tonto_fit() {
    unset HAR_ENERGY_LAST HAR_ENERGY_PREV2
    unset HAR_DIRECT_REPEAT_COUNT HAR_PERIOD2_REPEAT_COUNT
    HAR_WAVEFUNCTION_STALLED=false
    HAR_ENERGY_REPEAT_TOL=1.0e-10
    HAR_SCF_RMSD_TOL=1.0e-8
    JOBNAME=stall_test
    I=0
    J=0
    MAXSHIFT=1.0
    CONVTOL=0.01
    MAXCYCLE=20
    cp2k_calls=0
    tonto_fits=0
    final_residuals=0
    fit_rows=0

    CP2K_VALIDATE_LAMAGOET_MODE() { return 0; }
    _cp2k_log() { return 0; }
    _cp2k_float_gt() {
        awk -v left="$1" -v right="$2" 'BEGIN { exit !(left > right) }'
    }
    TONTO_TO_CP2K() {
        cp2k_calls=$((cp2k_calls + 1))
        I=$cp2k_calls
    }
    CP2K_CHECK_ENERGY() {
        case "$cp2k_calls" in
            1) ENERGIA2=-223.50 ;;
            *) ENERGIA2=-223.75 ;;
        esac
        RMSD2=0.0
    }
    SCF_TO_TONTO() {
        tonto_fits=$((tonto_fits + 1))
        J=$((J + 1))
        MAXSHIFT=1.0
    }
    CP2K_ASSERT_TONTO_FIT() { return 0; }
    CP2K_CAPTURE_FIT_ROW() { CP2K_FIT_ROW_PENDING=true; }
    CP2K_WRITE_FIT_ROW() {
        [[ "${CP2K_FIT_ROW_PENDING:-false}" == "true" ]] || return 1
        fit_rows=$((fit_rows + 1))
        CP2K_FIT_ROW_PENDING=false
    }
    CP2K_APPEND_STARTING_GEOMETRY() { return 0; }
    CP2K_APPEND_FINAL_GEOMETRY() { return 0; }
    CP2K_FINAL_RESIDUALS() {
        final_residuals=$((final_residuals + 1))
    }

    CP2K_RUN_HAR
    [[ "$HAR_WAVEFUNCTION_STALLED" == "true" ]]
    [[ "$cp2k_calls" -eq 4 ]]
    [[ "$tonto_fits" -eq 3 ]]
    [[ "$fit_rows" -eq 3 ]]
    [[ "$final_residuals" -eq 1 ]]
}

test_cp2k_stationary_energy_stops_before_another_tonto_fit

cp2k_body=$(awk '/^CP2K_RUN_HAR\(\)/,/^}/' "$repo_dir/lamaGOET.sh")
[[ $(grep -c 'CHECK_WAVEFUNCTION_STALL "$ENERGIA2" "$RMSD2"' <<< "$cp2k_body") -ge 2 ]]
[[ $(grep -c 'CHECK_WAVEFUNCTION_STALL "$ENERGIA2" "$RMSD2" "${JOBNAME}.fractional.cif1"' <<< "$cp2k_body") -ge 2 ]]
grep -q 'Reusing the current converged CP2K density for final residuals' <<< "$cp2k_body"
grep -q 'CP2K_CAPTURE_FIT_ROW' <<< "$cp2k_body"
[[ $(grep -c 'CP2K_WRITE_FIT_ROW "$I"' <<< "$cp2k_body") -ge 2 ]]

echo "HAR stationary-wavefunction tests passed"
