#!/usr/bin/env bash
# Run every lamaGOET test and print a summary.
#
# Works on macOS (bash 3.2, BSD userland) and Linux.  Exits non-zero if any
# test fails.  Tests that skip (exit 77) are reported but do not fail the run.
#
#   bash Tests/run_all.sh
#
# Tests/ is not a Python package, so `python -m unittest discover` cannot be
# used.  Each Python test file is run directly with PYTHONPATH set to the
# repository root.

set -uo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

# Prefer the private Qt environment; fall back to whatever python3 is around
# so the shell tests still run on a machine that has never launched the GUI.
if [ -x "$repo_dir/.venv-qt/bin/python" ]; then
    python_bin="$repo_dir/.venv-qt/bin/python"
elif [ -x "$repo_dir/.venv-qt/Scripts/python.exe" ]; then
    python_bin="$repo_dir/.venv-qt/Scripts/python.exe"
else
    python_bin=$(command -v python3 || command -v python || echo "")
fi

passed=0
failed=0
skipped=0
failures=""

run_one() {
    local label=$1
    shift
    local output rc
    output=$("$@" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '  ok      %s\n' "$label"
        passed=$((passed + 1))
    elif [ "$rc" -eq 77 ]; then
        printf '  skip    %s (%s)\n' "$label" "$(printf '%s' "$output" | tail -1)"
        skipped=$((skipped + 1))
    else
        printf '  FAIL    %s (exit %s)\n' "$label" "$rc"
        printf '%s\n' "$output" | sed 's/^/            /' | tail -12
        failed=$((failed + 1))
        failures="$failures $label"
    fi
}

echo "lamaGOET test suite"
echo "  repository: $repo_dir"
echo "  platform:   $(uname -s) $(uname -m)"
echo "  bash:       ${BASH_VERSION}"
echo "  python:     ${python_bin:-none found}"
echo

echo "Shell tests"
for test_file in Tests/test_*.sh; do
    [ -e "$test_file" ] || continue
    run_one "$(basename "$test_file")" bash "$test_file"
done

echo
echo "Python tests"
if [ -z "$python_bin" ]; then
    echo "  skip    all (no python interpreter found)"
    skipped=$((skipped + 1))
else
    for test_file in Tests/test_*.py; do
        [ -e "$test_file" ] || continue
        case $(basename "$test_file") in
            # Fixture generator, not a test.
            prepare_*) continue ;;
        esac
        run_one "$(basename "$test_file")" \
            env "PYTHONPATH=$repo_dir" "QT_QPA_PLATFORM=offscreen" \
            "$python_bin" "$test_file"
    done
fi

echo
echo "passed $passed, failed $failed, skipped $skipped"
if [ "$failed" -ne 0 ]; then
    echo "failing:$failures" >&2
    exit 1
fi
