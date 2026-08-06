#!/bin/bash
# Helpers shared by the shell tests.
#
# The tests pull individual functions out of the runners and source them in
# isolation.  The obvious way to write that is
#
#     source <(awk '...' "$script")
#
# but process substitution is not available in the bash 3.2 that macOS ships,
# so that form fails with "command not found" for every extracted function.
# Extract to a temporary file and source that instead.

# extract_function <script> <awk-program> [name]
#
# Runs <awk-program> over <script>, writes the result to a temporary file and
# sources it in the caller's shell.  Fails loudly if nothing was extracted,
# so a renamed function shows up as a test failure rather than as a silently
# empty source.
extract_function() {
    local script=$1
    local program=$2
    local name=${3:-function}
    local extracted

    if [ ! -f "$script" ]; then
        echo "extract_function: no such script: $script" >&2
        return 1
    fi

    extracted=$(mktemp "${TMPDIR:-/tmp}/lamagoet-extract.XXXXXX") || return 1
    awk "$program" "$script" > "$extracted"

    if [ ! -s "$extracted" ]; then
        rm -f "$extracted"
        echo "extract_function: extracted no $name from $script" >&2
        return 1
    fi

    # shellcheck disable=SC1090
    source "$extracted"
    rm -f "$extracted"
}
