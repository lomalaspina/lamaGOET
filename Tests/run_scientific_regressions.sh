#!/usr/bin/env bash
# Opt-in end-to-end scientific regression driver.
#
# The normal Tests/run_all.sh suite never launches licensed or expensive
# electronic-structure programs. This script stages the historical cases in
# a temporary tree and invokes the current local runner. It is intentionally
# not called by CI. Set LAMAGOET_KEEP_SCIENTIFIC_WORK=1 to retain the staging
# directory after a run.

set -uo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
inputs_dir="$repo_dir/Tests/inputs"
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/lamagoet-scientific.XXXXXX")

cleanup() {
    if [ "${LAMAGOET_KEEP_SCIENTIFIC_WORK:-0}" = "1" ]; then
        printf 'Retained scientific regression work at %s\n' "$stage_dir"
    else
        rm -rf -- "$stage_dir"
    fi
}
trap cleanup EXIT HUP INT TERM

cp -R "$inputs_dir/." "$stage_dir/"

if [ "$#" -gt 0 ]; then
    cases="$*"
else
    cases=$(sed '/^[[:space:]]*$/d' "$inputs_dir/run_tests.txt")
fi

printf 'lamaGOET live scientific regressions\n'
printf '  staging directory: %s\n' "$stage_dir"
printf '  runner: %s/lamaGOET.sh\n\n' "$repo_dir"

failed=0
for case_name in $cases; do
    case_dir="$stage_dir/$case_name"
    if [ ! -f "$case_dir/job_options.txt" ]; then
        printf '  FAIL    %s (unknown case)\n' "$case_name" >&2
        failed=$((failed + 1))
        continue
    fi
    # The fixture contains retained outputs for the archive-integrity test.
    # Remove the final products before a live run so that a successful process
    # which failed to regenerate them cannot be reported as a passing case.
    rm -f -- \
        "$case_dir/my_job.archive.cif" \
        "$case_dir/my_job.archive.fcf" \
        "$case_dir/my_job.archive.fco" \
        "$case_dir/my_job.lst" \
        "$case_dir/live-run.log"
    printf '  run     %s\n' "$case_name"
    if (cd "$case_dir" && bash "$repo_dir/lamaGOET.sh" --run-job-options ./job_options.txt > live-run.log 2>&1); then
        if [ -s "$case_dir/my_job.archive.cif" ] && [ -s "$case_dir/my_job.lst" ]; then
            printf '  ok      %s\n' "$case_name"
        else
            printf '  FAIL    %s (expected final artifacts are absent)\n' "$case_name" >&2
            failed=$((failed + 1))
        fi
    else
        printf '  FAIL    %s (see %s/live-run.log)\n' "$case_name" "$case_dir" >&2
        failed=$((failed + 1))
    fi
done

if [ "$failed" -ne 0 ]; then
    printf '%s live scientific regression(s) failed\n' "$failed" >&2
    exit 1
fi
