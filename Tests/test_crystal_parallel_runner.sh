#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lamagoet_shell_env.sh
source "$repo_dir/lamagoet_shell_env.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/work"
log_file=$tmp_dir/driver.log
export LAMAGOET_CRYSTAL_TEST_LOG=$log_file

make_stub() {
    local path=$1
    local label=$2
    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf 'printf "%%s:%%s\\n" %q "$*" >> "$LAMAGOET_CRYSTAL_TEST_LOG"\n' "$label"
        printf 'if [[ "${LAMAGOET_CRYSTAL_TEST_NOISE:-}" == %q ]]; then printf %q; fi\n' \
            "$label" "$label launcher chatter\n"
        printf 'if [[ "${LAMAGOET_CRYSTAL_TEST_FAIL:-}" == %q ]]; then printf %q >&2; exit 23; fi\n' \
            "$label" "$label driver failure\n"
    } > "$path"
    chmod +x "$path"
}

make_stub "$tmp_dir/bin/runcry23" runcry23
make_stub "$tmp_dir/bin/runPcry23" runPcry23
make_stub "$tmp_dir/bin/runprop23" runprop23
make_stub "$tmp_dir/bin/runPprop23" runPprop23
PATH=$tmp_dir/bin:$PATH
export PATH
unset CRYSTAL_PARALLEL_BIN CRY23P_MACH PBS_NODEFILE
cd "$tmp_dir/work"

_lamagoet_run_crystal23 runcry23 1 my_job
[[ "$(cat "$log_file")" == "runcry23:my_job" ]]

: > "$log_file"
_lamagoet_run_crystal23 runcry23 1 my_job my_job
[[ "$(cat "$log_file")" == "runcry23:my_job my_job" ]]

: > "$log_file"
_lamagoet_run_crystal23 runcry23 2 my_job
[[ "$(cat "$log_file")" == "runPcry23:2 my_job" ]]

: > "$log_file"
_lamagoet_run_crystal23 runcry23 4 my_job my_job
[[ "$(cat "$log_file")" == "runPcry23:4 my_job my_job" ]]

# Successful vendor-wrapper chatter is captured instead of obscuring
# lamaGOET's concise cycle markers.  The capture remains available for support.
: > "$log_file"
LAMAGOET_CRYSTAL_TEST_NOISE=runPcry23
export LAMAGOET_CRYSTAL_TEST_NOISE
terminal_output=$(_lamagoet_run_crystal23 runcry23 2 my_job 2>&1)
[[ -z "$terminal_output" ]]
grep -q '^runPcry23 launcher chatter$' \
    .lamagoet_crystal_mpi/my_job.scf-wrapper.log
[[ "$(cat "$log_file")" == "runPcry23:2 my_job" ]]

: > "$log_file"
LAMAGOET_CRYSTAL_TEST_NOISE=runPprop23
terminal_output=$(_lamagoet_run_crystal23_properties \
    runcry23 2 GenerateXML my_job 2>&1)
[[ -z "$terminal_output" ]]
grep -q '^runPprop23 launcher chatter$' \
    .lamagoet_crystal_mpi/GenerateXML.properties-wrapper.log
[[ "$(cat "$log_file")" == "runPprop23:2 GenerateXML my_job" ]]
unset LAMAGOET_CRYSTAL_TEST_NOISE

# A real driver failure remains visible and retains the exact exit status.
LAMAGOET_CRYSTAL_TEST_NOISE=runPcry23
export LAMAGOET_CRYSTAL_TEST_NOISE
LAMAGOET_CRYSTAL_TEST_FAIL=runPcry23
export LAMAGOET_CRYSTAL_TEST_FAIL
set +e
terminal_output=$(_lamagoet_run_crystal23 runcry23 2 my_job 2>&1)
driver_status=$?
set -e
[[ "$driver_status" -eq 23 ]]
grep -q 'runPcry23 launcher chatter' <<< "$terminal_output"
grep -q 'runPcry23 driver failure' <<< "$terminal_output"
grep -q '^runPcry23:2 my_job$' "$log_file"
unset LAMAGOET_CRYSTAL_TEST_NOISE LAMAGOET_CRYSTAL_TEST_FAIL

: > "$log_file"
_lamagoet_run_crystal23_properties runcry23 1 GenerateXML my_job
[[ "$(cat "$log_file")" == "runprop23:GenerateXML my_job" ]]

: > "$log_file"
_lamagoet_run_crystal23_properties runcry23 2 GenerateXML my_job
[[ "$(cat "$log_file")" == "runPprop23:2 GenerateXML my_job" ]]

# A site can explicitly select a differently named parallel driver.
make_stub "$tmp_dir/bin/site_crystal_parallel" site_parallel
CRYSTAL_PARALLEL_BIN=$tmp_dir/bin/site_crystal_parallel
export CRYSTAL_PARALLEL_BIN
: > "$log_file"
_lamagoet_run_crystal23 runcry23 3 my_job
[[ "$(cat "$log_file")" == "site_parallel:3 my_job" ]]
unset CRYSTAL_PARALLEL_BIN

# Only wrappers that force CRY23P_MACH receive a generated host file.
machine_runner=$tmp_dir/bin/machinefile_runner
{
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' '# CRY23P_MACH/machines.LINUX'
    printf '%s\n' 'exit 0'
} > "$machine_runner"
chmod +x "$machine_runner"
unset CRY23P_MACH PBS_NODEFILE
_lamagoet_prepare_crystal_machinefile "$machine_runner" 4
[[ "$(cat "$CRY23P_MACH/machines.LINUX")" == "localhost slots=4" ]]

pbs_nodes=$tmp_dir/pbs_nodes
printf '%s\n' node-a node-a node-b > "$pbs_nodes"
PBS_NODEFILE=$pbs_nodes
export PBS_NODEFILE
unset CRY23P_MACH
_lamagoet_prepare_crystal_machinefile "$machine_runner" 3
[[ "$(sed -n '1p' "$CRY23P_MACH/machines.LINUX")" == "node-a slots=2" ]]
[[ "$(sed -n '2p' "$CRY23P_MACH/machines.LINUX")" == "node-b slots=1" ]]

set +e
terminal_output=$(_lamagoet_run_crystal23 runcry23 0 my_job 2>&1)
invalid_status=$?
set -e
if [[ "$invalid_status" -eq 0 ]]; then
    echo "zero Crystal23 processors were accepted" >&2
    exit 1
fi
[[ "$invalid_status" -eq 2 ]]
grep -q 'invalid Crystal23 processor count' <<< "$terminal_output"

for runner in "$repo_dir/lamaGOET.sh" "$repo_dir/RUN_lamaGOET_release.sh"; do
    grep -q '_lamagoet_run_crystal23.*SCFCALC_BIN.*NUMPROC' "$runner"
    grep -q '_lamagoet_run_crystal23_properties.*SCFCALC_BIN.*NUMPROC' "$runner"
    if grep -q 'mpirun -n .*SCFCALC_BIN' "$runner"; then
        echo "legacy MPI launch of the serial Crystal23 wrapper remains in $runner" >&2
        exit 1
    fi
    if grep -q 'cp fort\.9 .*JOBNAME\.f9\|cp fort\.98 .*JOBNAME\.f98' "$runner"; then
        echo "parallel Crystal23 path can overwrite fresh named wavefunctions in $runner" >&2
        exit 1
    fi
done
