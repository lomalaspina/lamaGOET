#!/bin/bash
# Make the lamaGOET shell scripts behave identically on Linux and macOS.
#
# The runners are written for GNU sed, GNU awk and GNU coreutils.  macOS ships
# the BSD versions, which differ in ways that matter here:
#
#   * BSD `sed -i` requires a backup suffix, so `sed -i 's/a/b/' file` eats the
#     next argument instead of editing in place.
#   * BSD sed has no `first~step` line addressing and no one-line `i\` / `a\`.
#   * BSD awk lacks the gawk extensions the scripts rely on.
#
# None of these fail loudly.  They corrupt the Tonto input files the scripts
# generate, and the refinement then produces a wrong answer without complaint.
#
# Rather than rewrite the several hundred call sites, this file points `sed`,
# `awk` and `realpath` at their GNU equivalents on macOS.  On Linux it defines
# nothing at all, so behaviour there cannot change.
#
# Source it as the first thing any entry point does:
#
#     source "$LAMAGOET_DIR/lamagoet_shell_env.sh"

# Sourcing twice is free.
if [ -n "${LAMAGOET_SHELL_ENV_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Where does lamaGOET live?
#
# install.sh symlinks the runners into /usr/local/bin, so ${BASH_SOURCE[0]} is
# often a symlink and dirname alone would point at /usr/local/bin rather than
# at the checkout.  Follow the links by hand: this runs before the GNU tools
# have been located, so it cannot use readlink -f, which BSD lacks anyway.
_lamagoet_resolve_dir() {
    local source=$1
    local dir
    while [ -L "$source" ]; do
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(ls -l "$source" | sed -e 's/^.*[[:space:]]->[[:space:]]//')
        case $source in
            /*) ;;
            *) source=$dir/$source ;;
        esac
    done
    (cd -P "$(dirname "$source")" && pwd)
}

if [ -z "${LAMAGOET_DIR:-}" ]; then
    LAMAGOET_DIR=$(_lamagoet_resolve_dir "${BASH_SOURCE[0]}")
fi
export LAMAGOET_DIR

# ---------------------------------------------------------------------------
# Locate GNU tools.
#
# Test for GNU-ness rather than for presence.  On a Mac with Homebrew's
# coreutils on PATH, plain `realpath` is already GNU while plain `sed` is not,
# so "does the command exist" is the wrong question.
_lamagoet_is_gnu() {
    "$1" --version 2>/dev/null | head -1 | grep -q GNU
}

# _lamagoet_find_gnu <variable> <friendly name> <candidate>...
_lamagoet_find_gnu() {
    local variable=$1 friendly=$2
    shift 2
    local candidate found=""
    for candidate in "$@"; do
        if command -v "$candidate" >/dev/null 2>&1 && _lamagoet_is_gnu "$candidate"; then
            found=$candidate
            break
        fi
    done
    if [ -z "$found" ]; then
        _lamagoet_missing_tool "$friendly" "$@"
        return 1
    fi
    eval "$variable=\$found"
    return 0
}

_lamagoet_missing_tool() {
    local friendly=$1
    shift
    {
        echo
        echo "lamaGOET: could not find GNU $friendly."
        echo
        echo "lamaGOET's shell scripts rely on GNU sed, GNU awk and GNU"
        echo "coreutils.  The versions macOS ships behave differently in ways"
        echo "that silently corrupt the input files Tonto reads, so lamaGOET"
        echo "refuses to run rather than produce a wrong answer."
        echo
        case $(uname -s) in
            Darwin)
                echo "    brew install gnu-sed gawk coreutils"
                ;;
            *)
                echo "    sudo apt-get install gawk coreutils sed"
                echo "    # or: sudo dnf install gawk coreutils sed"
                ;;
        esac
        echo
        echo "You do not need to change your PATH; lamaGOET calls gsed, gawk"
        echo "and grealpath directly once they are installed."
        echo
        echo "Looked for: $*"
        echo
    } >&2
}

_lamagoet_find_gnu SED      sed      gsed      sed      || exit 2
_lamagoet_find_gnu AWK      awk      gawk      awk      || exit 2
_lamagoet_find_gnu REALPATH realpath grealpath realpath || exit 2
export SED AWK REALPATH

# On macOS the bare names are the BSD tools, so shadow them.  On Linux they are
# already GNU and nothing is defined, which keeps Linux behaviour identical.
if [ "$SED" != "sed" ];           then sed()      { command "$SED" "$@"; };      export -f sed;      fi
if [ "$AWK" != "awk" ];           then awk()      { command "$AWK" "$@"; };      export -f awk;      fi
if [ "$AWK" != "gawk" ];          then gawk()     { command "$AWK" "$@"; };      export -f gawk;     fi
if [ "$REALPATH" != "realpath" ]; then realpath() { command "$REALPATH" "$@"; }; export -f realpath; fi

# ---------------------------------------------------------------------------
# Case conversion.
#
# macOS ships bash 3.2, which has no ${var^^} or ${var,,}.  Using them there
# raises "bad substitution" and, because the scripts do not stop on error, the
# caller can be left with empty output and a zero exit status.
#
# Explicit a-z / A-Z ranges rather than [:lower:] / [:upper:]: these convert
# chemistry identifiers such as PBE, uB3LYP and Crystal14, and a Turkish locale
# would otherwise turn "i" into a dotless capital.
_upper() { printf '%s' "${1:-}" | tr 'a-z' 'A-Z'; }
_lower() { printf '%s' "${1:-}" | tr 'A-Z' 'a-z'; }
export -f _upper _lower

LAMAGOET_SHELL_ENV_LOADED=1
export LAMAGOET_SHELL_ENV_LOADED
