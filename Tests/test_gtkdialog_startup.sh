#!/bin/bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
gtk_timeout=${LAMAGOET_GTK_TIMEOUT:-4}
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

if ! command -v gtkdialog >/dev/null 2>&1; then
    echo "gtkdialog is not installed; startup parser test skipped" >&2
    exit 77
fi

run_case() {
    local frontend=$1
    local name=$2
    local options=${3:-}
    local case_dir="$tmp_root/$name"
    local status

    mkdir -p "$case_dir"
    cp "$repo_dir/GUI_lamaGOET_release.sh" "$case_dir/"
    cp "$repo_dir/lamaGOET.sh" "$case_dir/"
    if [[ -n "$options" ]]; then
        cp "$options" "$case_dir/job_options.txt"
    fi

    set +e
    (
        cd "$case_dir"
        timeout "${gtk_timeout}s" bash "$frontend"
    ) >"$case_dir/stdout.log" 2>"$case_dir/stderr.log"
    status=$?
    set -e

    if [[ $status -ne 124 && $status -ne 0 ]]; then
        echo "GTKDialog startup case '$name' failed with status $status" >&2
        cat "$case_dir/stderr.log" >&2
        return 1
    fi
    if grep -Eq 'gtkdialog: Error|syntax error|Trace/breakpoint trap' \
        "$case_dir/stderr.log"; then
        echo "GTKDialog parser error in startup case '$name'" >&2
        cat "$case_dir/stderr.log" >&2
        return 1
    fi
}

for frontend in GUI_lamaGOET_release.sh lamaGOET.sh; do
    prefix=${frontend%.sh}
    run_case "$frontend" "$prefix-no-options"
    run_case "$frontend" "$prefix-saved-gaussian" \
        "$repo_dir/Tests/job_options_gaussian_gui_sample"
    run_case "$frontend" "$prefix-saved-cp2k" \
        "$repo_dir/Tests/job_options_cp2k_gui_sample"
    run_case "$frontend" "$prefix-saved-crystal" \
        "$repo_dir/Tests/job_options_crystal_gui_sample"
done

echo "GTKDialog startup parser tests passed"
