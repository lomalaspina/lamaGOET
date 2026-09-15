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

_lamagoet_gaussian_method_keyword() {
    local method=${1:-}
    case "$(_lower "$method")" in
        pbe|pbepbe)       printf '%s' PBEPBE ;;
        upbe|upbepbe)     printf '%s' uPBEPBE ;;
        pbe0|pbe1pbe)     printf '%s' PBE1PBE ;;
        upbe0|upbe1pbe)   printf '%s' uPBE1PBE ;;
        *)                printf '%s' "$method" ;;
    esac
}

# Resolve CRYSTAL23's five TOLINTEG values.  Molecular bases exported by BSE
# can contain diffuse functions whose periodic overlap matrix is sensitive to
# CRYSTAL's integral-screening accuracy.  ``auto`` keeps the program default
# for built-in/periodic bases, but uses 8 8 8 8 16 as a conservative screening
# baseline for an explicitly supplied basis.  This changes only numerical
# screening: it does not delete, reorder, recontract, or guarantee linear
# independence of the basis functions.
_lamagoet_crystal_tolinteg() {
    local requested=${1:-auto}
    local external_basis=${2:-false}
    local resolved field

    case "$(_lower "$requested")" in
        auto)
            case "$(_lower "$external_basis")" in
                true|yes|1) resolved="8 8 8 8 16" ;;
                *) return 0 ;;
            esac
            ;;
        default|none|off) return 0 ;;
        *) resolved=$requested ;;
    esac

    # Deliberately use shell word splitting after rejecting every character
    # except digits and whitespace.  This remains compatible with macOS bash
    # 3.2 and prevents an option file from injecting CRYSTAL records.
    case "$resolved" in
        *[!0-9[:space:]]*)
            printf 'lamaGOET: invalid CRYSTAL_TOLINTEG: %s (expected five positive integers, auto, or default)\n' "$requested" >&2
            return 2
            ;;
    esac
    # shellcheck disable=SC2086
    set -- $resolved
    if [ "$#" -ne 5 ]; then
        printf 'lamaGOET: invalid CRYSTAL_TOLINTEG: %s (expected five positive integers, auto, or default)\n' "$requested" >&2
        return 2
    fi
    for field in "$@"; do
        if [ "$field" -lt 1 ] || [ "$field" -gt 99 ]; then
            printf 'lamaGOET: invalid CRYSTAL_TOLINTEG component: %s (allowed range 1-99)\n' "$field" >&2
            return 2
        fi
    done
    printf '%s %s %s %s %s\n' "$1" "$2" "$3" "$4" "$5"
}

# Validate and append CRYSTAL23's optional LDREMO overlap-eigenvector removal
# threshold.  CRYSTAL interprets integer n as n x 10^-5.  This is deliberately
# opt-in: unlike TOLINTEG, LDREMO changes the effective variational space by
# removing low-overlap directions.  A blank (or explicit default/none/off)
# value leaves CRYSTAL's normal behaviour untouched.
_lamagoet_write_crystal_ldremo() {
    local output_file=${1:-}
    local requested=${2:-}

    case "$(_lower "$requested")" in
        ""|default|none|off) return 0 ;;
    esac
    case "$requested" in
        *[!0-9]*)
            printf 'lamaGOET: invalid CRYSTAL_LDREMO: %s (expected an integer from 1 to 99, or blank)\n' \
                "$requested" >&2
            return 2
            ;;
    esac
    if [ "$requested" -lt 1 ] || [ "$requested" -gt 99 ]; then
        printf 'lamaGOET: invalid CRYSTAL_LDREMO: %s (allowed range 1-99, or blank)\n' \
            "$requested" >&2
        return 2
    fi
    printf 'LDREMO\n%s\n' "$requested" >> "$output_file"
}

# Validate and append an optional positive-integer CRYSTAL23 size control.
# Empty values deliberately produce no input record, leaving CRYSTAL's own
# compiled default in force.  Restrict the keyword name as well as the value
# because job_options.txt is user-editable and this helper writes input text.
_lamagoet_write_crystal_size() {
    local output_file=${1:-}
    local keyword=${2:-}
    local requested=${3:-}

    [ -n "$requested" ] || return 0
    case "$keyword" in
        BIPOSIZE|ILASIZE) ;;
        *)
            printf 'lamaGOET: invalid CRYSTAL23 size keyword: %s\n' "$keyword" >&2
            return 2
            ;;
    esac
    case "$requested" in
        *[!0-9]*|"")
            printf 'lamaGOET: invalid %s: %s (expected a positive integer or blank)\n' \
                "$keyword" "$requested" >&2
            return 2
            ;;
        *[1-9]*) ;;
        *)
            printf 'lamaGOET: invalid %s: %s (expected a positive integer or blank)\n' \
                "$keyword" "$requested" >&2
            return 2
            ;;
    esac
    printf '%s\n%s\n' "$keyword" "$requested" >> "$output_file"
}

# Resolve an executable supplied either as a command name or as a path.  This
# is kept separate from the Crystal launcher so it can be exercised with
# harmless stub runners in the regression tests.
_lamagoet_command_path() {
    local requested=${1:-}
    local resolved=""

    [ -n "$requested" ] || return 1
    case "$requested" in
        */*)
            [ -x "$requested" ] || return 1
            resolved=$requested
            ;;
        *)
            resolved=$(command -v "$requested" 2>/dev/null) || return 1
            ;;
    esac
    printf '%s\n' "$resolved"
}

# Find the CRYSTAL23 parallel driver corresponding to the configured serial
# driver.  CRYSTAL_BIN remains runcry23 because that is the correct one-CPU
# interface; a multi-CPU calculation must invoke runPcry23 *once* and pass the
# processor count as its first argument.  Launching N copies of runcry23 under
# mpirun starts N independent serial wrappers and is never correct.
_lamagoet_crystal_parallel_runner() {
    local configured=${1:-}
    local configured_path configured_dir configured_name parallel_name candidate

    if [ -n "${CRYSTAL_PARALLEL_BIN:-}" ]; then
        if candidate=$(_lamagoet_command_path "$CRYSTAL_PARALLEL_BIN"); then
            printf '%s\n' "$candidate"
            return 0
        fi
        printf 'lamaGOET: Crystal23 parallel runner was not found: %s\n' \
            "$CRYSTAL_PARALLEL_BIN" >&2
        return 2
    fi

    if ! configured_path=$(_lamagoet_command_path "$configured"); then
        printf 'lamaGOET: Crystal23 runner was not found: %s\n' "$configured" >&2
        return 2
    fi
    configured_dir=$(dirname "$configured_path")
    configured_name=$(basename "$configured_path")

    case "$configured_name" in
        runcry23)       parallel_name=runPcry23 ;;
        runcry23OMP)    parallel_name=runPcry23OMP ;;
        runPcry23|runPcry23OMP|runMPPcry23|runMPPcry23OMP)
            printf '%s\n' "$configured_path"
            return 0
            ;;
        *)
            printf '%s\n' \
                "lamaGOET: cannot infer a parallel Crystal23 driver from '$configured'." \
                "Set CRYSTAL_PARALLEL_BIN to runPcry23 (or the site's equivalent)." >&2
            return 2
            ;;
    esac

    candidate=$configured_dir/$parallel_name
    if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    if candidate=$(_lamagoet_command_path "$parallel_name"); then
        printf '%s\n' "$candidate"
        return 0
    fi
    printf 'lamaGOET: %s was not found beside %s or on PATH.\n' \
        "$parallel_name" "$configured_path" >&2
    return 2
}

# Some CRYSTAL23 runPcry23 distributions force a machines.LINUX file even for
# a single-host MPI run.  Respect a site-provided file; otherwise make a small
# job-local file.  PBS allocations retain their actual host/slot counts, while
# an interactive Linux/WSL run uses the requested number of localhost slots.
_lamagoet_prepare_crystal_machinefile() {
    local parallel_runner=${1:-}
    local nproc=${2:-}
    local machine_dir machine_file

    case "$nproc" in
        *[!0-9]*|""|0|1) return 0 ;;
    esac
    [ -r "$parallel_runner" ] || return 0
    grep -q 'CRY23P_MACH/machines.LINUX' "$parallel_runner" 2>/dev/null || return 0
    if [ -n "${CRY23P_MACH:-}" ] && [ -s "$CRY23P_MACH/machines.LINUX" ]; then
        return 0
    fi

    machine_dir=$PWD/.lamagoet_crystal_mpi
    machine_file=$machine_dir/machines.LINUX
    mkdir -p "$machine_dir" || {
        printf 'lamaGOET: cannot create Crystal23 MPI host-file directory: %s\n' \
            "$machine_dir" >&2
        return 2
    }
    if [ -n "${PBS_NODEFILE:-}" ] && [ -s "$PBS_NODEFILE" ]; then
        # One PBS_NODEFILE row represents one allocated slot.  Collapse rows
        # into Open MPI's unambiguous "host slots=N" form without reordering
        # the hosts selected by the scheduler.
        awk '
            !seen[$1]++ { order[++n] = $1 }
            { slots[$1]++ }
            END { for (i = 1; i <= n; i++) print order[i], "slots=" slots[order[i]] }
        ' "$PBS_NODEFILE" > "$machine_file"
    else
        printf 'localhost slots=%s\n' "$nproc" > "$machine_file"
    fi
    if [ ! -s "$machine_file" ]; then
        printf 'lamaGOET: Crystal23 MPI host file is empty: %s\n' "$machine_file" >&2
        return 2
    fi
    CRY23P_MACH=$machine_dir
    export CRY23P_MACH
}

# CRYSTAL's vendor drivers duplicate short launcher-status messages to standard
# output and to their own output files.  Keep a successful HAR cycle quiet so
# lamaGOET's "Running ..." / "... ended" markers remain easy to follow.  Leave
# standard error live for MPI/shell failures; if a driver returns an error,
# replay its captured standard output before returning the same status.
_lamagoet_run_crystal_driver_quietly() {
    local capture_file=${1:-}
    local command_status

    shift || true
    [ -n "$capture_file" ] && [ "$#" -gt 0 ] || {
        printf 'lamaGOET: Crystal23 quiet launcher received incomplete arguments.\n' >&2
        return 2
    }
    if ! mkdir -p "$(dirname "$capture_file")"; then
        printf 'lamaGOET: could not create the Crystal23 launcher-log directory.\n' >&2
        return 2
    fi
    if "$@" >"$capture_file"; then
        command_status=0
    else
        command_status=$?
        if [ -s "$capture_file" ]; then
            cat "$capture_file" >&2
        fi
    fi
    return "$command_status"
}

# Run one CRYSTAL23 SCF calculation using the driver's actual command-line
# contract.  The optional fourth argument is the restart prefix used by GUESSP.
_lamagoet_run_crystal23() {
    local configured=${1:-}
    local nproc=${2:-1}
    local job_name=${3:-}
    local restart_name=${4:-}
    local runner

    case "$nproc" in
        *[!0-9]*|""|0)
            printf 'lamaGOET: invalid Crystal23 processor count: %s\n' "$nproc" >&2
            return 2
            ;;
    esac
    [ -n "$job_name" ] || {
        printf 'lamaGOET: Crystal23 job name is empty.\n' >&2
        return 2
    }

    if [ "$nproc" -eq 1 ]; then
        if ! runner=$(_lamagoet_command_path "$configured"); then
            printf 'lamaGOET: Crystal23 runner was not found: %s\n' "$configured" >&2
            return 2
        fi
        if [ -n "$restart_name" ]; then
            _lamagoet_run_crystal_driver_quietly \
                ".lamagoet_crystal_mpi/$job_name.scf-wrapper.log" \
                "$runner" "$job_name" "$restart_name"
        else
            _lamagoet_run_crystal_driver_quietly \
                ".lamagoet_crystal_mpi/$job_name.scf-wrapper.log" \
                "$runner" "$job_name"
        fi
        return $?
    fi

    runner=$(_lamagoet_crystal_parallel_runner "$configured") || return $?
    _lamagoet_prepare_crystal_machinefile "$runner" "$nproc" || return $?
    if grep -Eq 'set[[:space:]]+MPIDIR[[:space:]]*=[[:space:]]*/usr/bin' \
        "$runner" 2>/dev/null && [ ! -x /usr/bin/mpirun ]; then
        printf '%s\n' \
            "lamaGOET: $runner requires /usr/bin/mpirun, but it is not installed." \
            "Run lamaGOET's install.sh (or install Ubuntu's openmpi-bin package)," \
            "then retry the Crystal23 calculation." >&2
        return 2
    fi
    if [ -n "$restart_name" ]; then
        _lamagoet_run_crystal_driver_quietly \
            ".lamagoet_crystal_mpi/$job_name.scf-wrapper.log" \
            "$runner" "$nproc" "$job_name" "$restart_name"
    else
        _lamagoet_run_crystal_driver_quietly \
            ".lamagoet_crystal_mpi/$job_name.scf-wrapper.log" \
            "$runner" "$nproc" "$job_name"
    fi
}

_lamagoet_crystal_properties_runner() {
    local configured=${1:-}
    local parallel=${2:-false}
    local configured_path configured_dir candidate runner_name

    if ! configured_path=$(_lamagoet_command_path "$configured"); then
        printf 'lamaGOET: Crystal23 runner was not found: %s\n' "$configured" >&2
        return 2
    fi
    configured_dir=$(dirname "$configured_path")
    if [ "$parallel" = true ]; then
        runner_name=runPprop23
    else
        runner_name=runprop23
    fi
    candidate=$configured_dir/$runner_name
    if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    if candidate=$(_lamagoet_command_path "$runner_name"); then
        printf '%s\n' "$candidate"
        return 0
    fi
    printf 'lamaGOET: Crystal23 properties runner was not found: %s\n' \
        "$runner_name" >&2
    return 2
}

# Run CRYSTAL23 properties.  The parallel driver has the same leading NPROC
# convention as runPcry23; the serial driver has no processor-count argument.
_lamagoet_run_crystal23_properties() {
    local configured=${1:-}
    local nproc=${2:-1}
    local input_name=${3:-}
    local wavefunction_name=${4:-}
    local runner parallel_runner

    case "$nproc" in
        *[!0-9]*|""|0)
            printf 'lamaGOET: invalid Crystal23 properties processor count: %s\n' \
                "$nproc" >&2
            return 2
            ;;
    esac
    if [ "$nproc" -eq 1 ]; then
        runner=$(_lamagoet_crystal_properties_runner "$configured" false) || return $?
        _lamagoet_run_crystal_driver_quietly \
            ".lamagoet_crystal_mpi/$input_name.properties-wrapper.log" \
            "$runner" "$input_name" "$wavefunction_name"
        return $?
    fi

    parallel_runner=$(_lamagoet_crystal_parallel_runner "$configured") || return $?
    _lamagoet_prepare_crystal_machinefile "$parallel_runner" "$nproc" || return $?
    runner=$(_lamagoet_crystal_properties_runner "$parallel_runner" true) || return $?
    _lamagoet_run_crystal_driver_quietly \
        ".lamagoet_crystal_mpi/$input_name.properties-wrapper.log" \
        "$runner" "$nproc" "$input_name" "$wavefunction_name"
}

export -f _upper _lower _lamagoet_gaussian_method_keyword \
    _lamagoet_crystal_tolinteg _lamagoet_write_crystal_ldremo \
    _lamagoet_write_crystal_size \
    _lamagoet_command_path _lamagoet_crystal_parallel_runner \
    _lamagoet_prepare_crystal_machinefile \
    _lamagoet_run_crystal_driver_quietly _lamagoet_run_crystal23 \
    _lamagoet_crystal_properties_runner _lamagoet_run_crystal23_properties

LAMAGOET_SHELL_ENV_LOADED=1
export LAMAGOET_SHELL_ENV_LOADED
