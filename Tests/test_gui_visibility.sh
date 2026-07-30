#!/bin/bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

assert_visibility() {
    local xml=$1
    local variable=$2
    local expected=$3
    python3 - "$xml" "$variable" "$expected" <<'PY'
import sys
import re

path, variable, expected = sys.argv[1:]
matches = []
last_visible = None
for line in open(path, encoding="utf-8"):
    visible = re.search(r'<vbox\s+visible="([^"]+)"', line)
    if visible:
        last_visible = visible.group(1).lower()
    if f"<variable>{variable}</variable>" in line:
        matches.append(last_visible or "true")
if matches != [expected]:
    raise SystemExit(
        f"{path}: {variable} visibility is {matches!r}, expected {[expected]!r}"
    )
PY
}

run_case() {
    local frontend=$1
    local name=$2
    local options=${3:-}
    local case_dir="$tmp_root/${frontend%.sh}-$name"
    local xml="$case_dir/gui.xml"

    mkdir -p "$case_dir"
    cp "$repo_dir/GUI_lamaGOET_release.sh" "$case_dir/"
    cp "$repo_dir/lamaGOET.sh" "$case_dir/"
    if [[ -n "$options" ]]; then
        cp "$options" "$case_dir/job_options.txt"
    fi
    (
        cd "$case_dir"
        LAMAGOET_DUMP_GUI_XML=true bash "$frontend"
    ) > "$xml"

    case "$name" in
        gaussian)
            assert_visibility "$xml" METHOD_OPTIONS true
            assert_visibility "$xml" EXTERNAL_BASIS_OPTIONS true
            assert_visibility "$xml" TONTO_BASIS_OPTIONS false
            assert_visibility "$xml" LEGACY_SCF_OPTIONS true
            assert_visibility "$xml" ELMODB_OPTIONS false
            assert_visibility "$xml" BASIS_DIRECTORY_OPTIONS false
            assert_visibility "$xml" INITADP_OPTIONS false
            ;;
        cp2k)
            assert_visibility "$xml" METHOD_OPTIONS false
            assert_visibility "$xml" EXTERNAL_BASIS_OPTIONS false
            assert_visibility "$xml" TONTO_BASIS_OPTIONS false
            assert_visibility "$xml" LEGACY_SCF_OPTIONS false
            assert_visibility "$xml" ELMODB_OPTIONS false
            assert_visibility "$xml" BASIS_DIRECTORY_OPTIONS false
            assert_visibility "$xml" INITADP_OPTIONS false
            ;;
        crystal)
            assert_visibility "$xml" METHOD_OPTIONS true
            assert_visibility "$xml" EXTERNAL_BASIS_OPTIONS true
            assert_visibility "$xml" TONTO_BASIS_OPTIONS false
            assert_visibility "$xml" LEGACY_SCF_OPTIONS false
            assert_visibility "$xml" ELMODB_OPTIONS false
            assert_visibility "$xml" BASIS_DIRECTORY_OPTIONS false
            assert_visibility "$xml" INITADP_OPTIONS false
            ;;
        tonto)
            assert_visibility "$xml" METHOD_OPTIONS true
            assert_visibility "$xml" EXTERNAL_BASIS_OPTIONS false
            assert_visibility "$xml" TONTO_BASIS_OPTIONS true
            assert_visibility "$xml" LEGACY_SCF_OPTIONS true
            assert_visibility "$xml" ELMODB_OPTIONS false
            assert_visibility "$xml" BASIS_DIRECTORY_OPTIONS true
            assert_visibility "$xml" INITADP_OPTIONS false
            ;;
        elmodb)
            assert_visibility "$xml" METHOD_OPTIONS true
            assert_visibility "$xml" EXTERNAL_BASIS_OPTIONS true
            assert_visibility "$xml" TONTO_BASIS_OPTIONS false
            assert_visibility "$xml" LEGACY_SCF_OPTIONS true
            assert_visibility "$xml" ELMODB_OPTIONS true
            assert_visibility "$xml" BASIS_DIRECTORY_OPTIONS true
            assert_visibility "$xml" INITADP_OPTIONS true
            ;;
    esac
}

for frontend in GUI_lamaGOET_release.sh lamaGOET.sh; do
    run_case "$frontend" gaussian
    run_case "$frontend" cp2k "$repo_dir/Tests/job_options_cp2k_gui_sample"
    run_case "$frontend" crystal "$repo_dir/Tests/job_options_crystal_gui_sample"

    printf '%s\n' 'SCFCALCPROG="Tonto"' > "$tmp_root/tonto-options"
    run_case "$frontend" tonto "$tmp_root/tonto-options"

    printf '%s\n' 'SCFCALCPROG="elmodb"' > "$tmp_root/elmodb-options"
    run_case "$frontend" elmodb "$tmp_root/elmodb-options"
done

for frontend in "$repo_dir/GUI_lamaGOET_release.sh" "$repo_dir/lamaGOET.sh"; do
    for program in Gaussian Orca OCC Tonto elmodb CP2K Crystal14 optgaussian optorca; do
        selection_action="echo $program >"
        if [[ "$program" == "Crystal14" ]]; then
            selection_action="echo Crystal14 >"
        fi
        block=$(awk -v marker="$selection_action" '
            index($0, marker) {capture=1}
            capture {print}
            capture && /<\/radiobutton>/ {exit}
        ' "$frontend")
        for variable in METHOD_OPTIONS EXTERNAL_BASIS_OPTIONS \
            TONTO_BASIS_OPTIONS ELMODB_OPTIONS BASIS_DIRECTORY_OPTIONS \
            INITADP_OPTIONS; do
            if ! grep -Eq "(show|hide):$variable" <<< "$block"; then
                echo "$(basename "$frontend"): $program does not update $variable" >&2
                exit 1
            fi
        done
    done
done

echo "GUI visibility tests passed"
