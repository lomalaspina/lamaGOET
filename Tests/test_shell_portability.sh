#!/usr/bin/env bash
# Guard the constructs that break on macOS.
#
# macOS ships bash 3.2 and the BSD versions of sed and awk.  The failures are
# not loud: a bad substitution can leave a script producing empty output with a
# zero exit status, and a BSD sed can rewrite a Tonto input file incorrectly
# rather than refusing.  Anyone developing on Linux will not notice, so these
# checks stand in for the platform.

set -uo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

failures=0
report() {
    echo "$1" >&2
    failures=$((failures + 1))
}

shell_files=$(find . -name '*.sh' -not -path './.venv-qt/*' -not -path './.git/*')

# Everything except this file and the shim, both of which mention the very
# constructs they exist to forbid.
scan_files=$(printf '%s\n' $shell_files \
    | grep -v 'Tests/test_shell_portability.sh' \
    | grep -v 'lamagoet_shell_env.sh' \
    | grep -v 'Tests/lib/shell_test_helpers.sh')

# 1. Every shell file must parse under whatever bash is running the tests.
#    On macOS that is bash 3.2, which is the point.
for file in $shell_files; do
    if ! bash -n "$file" 2>/dev/null; then
        report "Syntax error under bash ${BASH_VERSION}: $file"
    fi
done

# 2. No bash 4 case conversion.  Use _upper / _lower from lamagoet_shell_env.sh.
if grep -nE '\$\{[A-Za-z_][A-Za-z_0-9]*(\^\^|,,)\}' $scan_files; then
    report "Found \${var^^} or \${var,,}: bash 3.2 on macOS reports 'bad substitution'."
fi

# 3. No process substitution.  bash 3.2 does not have it, and the failure mode
#    is every sourced function silently undefined.
if grep -nE '(source|\.)[[:space:]]+<\(' $scan_files; then
    report "Found 'source <(...)': not available in the bash 3.2 macOS ships."
fi

# 4. Other bash 4 constructs.
if grep -nE '^[[:space:]]*(declare|local)[[:space:]]+-A[[:space:]]|^[[:space:]]*(mapfile|readarray)[[:space:]]' $scan_files; then
    report "Found declare -A, mapfile or readarray: not available in bash 3.2."
fi

# 5. Both runners must load the environment shim, or none of the above helps.
for runner in lamaGOET.sh RUN_lamaGOET_release.sh; do
    if ! grep -q 'lamagoet_shell_env.sh' "$runner"; then
        report "$runner does not source lamagoet_shell_env.sh"
    fi
done

# 6. The shim must actually deliver GNU tools here.
if source ./lamagoet_shell_env.sh 2>/dev/null; then
    for pair in "sed:$SED" "awk:$AWK" "realpath:$REALPATH"; do
        name=${pair%%:*}
        tool=${pair#*:}
        if ! "$tool" --version 2>/dev/null | head -1 | grep -q GNU; then
            report "Resolved $name to '$tool', which is not GNU."
        fi
    done
    printf 'x' | grep -q x && [ "$(_upper ab)" = "AB" ] || report "_upper is wrong"
    [ "$(_lower AB)" = "ab" ] || report "_lower is wrong"
    [ "$(_lamagoet_gaussian_method_keyword pbe)" = "PBEPBE" ] \
        || report "legacy Gaussian PBE mapping is wrong"
    [ "$(_lamagoet_gaussian_method_keyword upbe0)" = "uPBE1PBE" ] \
        || report "legacy unrestricted Gaussian PBE0 mapping is wrong"
else
    echo "GNU tools are not installed; skipping the tool checks." >&2
    echo "  macOS: brew install gnu-sed gawk coreutils" >&2
    exit 77
fi

if [ "$failures" -ne 0 ]; then
    echo "$failures portability check(s) failed" >&2
    exit 1
fi
echo "Shell portability checks passed (bash ${BASH_VERSION}, $(uname -s))"
