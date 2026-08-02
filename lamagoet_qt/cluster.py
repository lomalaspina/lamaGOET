"""PBS submission contract shared by the Qt front end and its tests."""

from __future__ import annotations

from pathlib import Path
import re
from typing import Mapping


class SubmissionError(RuntimeError):
    pass


def validate_submission_options(values: Mapping[str, object]) -> None:
    job_name = str(values.get("JOBNAME", "")).strip()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", job_name):
        raise SubmissionError(
            "Job name must contain only letters, numbers, dot, underscore, or hyphen."
        )
    if not str(values.get("CIF", "")).strip():
        raise SubmissionError("Select a CIF/PDB input before submitting.")
    memory = str(values.get("MEMPBS", "1gb")).strip()
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)?(?:kb|mb|gb|tb)", memory, re.I):
        raise SubmissionError("PBS memory must include a unit, for example 1gb.")


def build_pbs_script(values: Mapping[str, object]) -> str:
    """Reproduce the established GUI_lamaGOET PBS/qsub workflow."""

    validate_submission_options(values)
    program = str(values.get("SCFCALCPROG", "Gaussian"))
    processors = (
        values.get("NUMPROCTONTO", 1)
        if program == "Tonto"
        else values.get("NUMPROC", 1)
    )
    memory = str(values.get("MEMPBS", "1gb"))
    email = str(values.get("EMAIL", ""))
    job_name = str(values["JOBNAME"])
    lines = [
        "#!/bin/sh",
        "",
        "#PBS -V",
        (
            f"#PBS -l nodes=1:RUN_lamaGOET:ppn={processors}"
            if program == "Tonto"
            else f"#PBS -l nodes=1:g09:RUN_lamaGOET:ppn={processors}"
        ),
        "#PBS -j eo",
        "#PBS -q batch",
        f"#PBS -l pmem={memory}",
        "#PBS -l walltime=999:00:00",
        "#PBS -m bea",
        "################ PLEASE PUT YOUR EMAIL AND JOBNAME HERE",
        f"#PBS -M {email}",
        f"#PBS -N {job_name}",
        "",
        "echo Working directory on Server: $PBS_O_WORKDIR",
        "",
        "SERVER=$PBS_O_HOST",
        "WORKDIR=/scratch/$USER/PBS_$PBS_JOBID",
        "SCP=/usr/bin/scp",
        "SSH=/usr/bin/ssh",
        "",
        "SERVERPERMDIR=${SERVER}:$PBS_O_WORKDIR",
        'export LAMAGOET_LIVE_CIF_SERVER="$SERVER"',
        'export LAMAGOET_LIVE_CIF_DIRECTORY="$PBS_O_WORKDIR"',
        "export LAMAGOET_LIVE_CIF_PORT=2244",
        "",
        "mkdir /scratch/$USER/PBS_$PBS_JOBID",
        "#PBS -o /scratch/$USER/PBS_$PBS_JOBID/$PBS_JOBNAME.o",
        "",
        'echo "--------------------STAGEIN-------------------------"',
        "cd ${WORKDIR}",
        "${SCP} -P 2244 ${SERVERPERMDIR}/* $WORKDIR",
        "ls -l",
        "",
        'echo "----------------STARTING PROGRAMRUN-----------------"',
        "export PATH=/opt/openmpi3/bin/:$PATH",
        "export LD_LIBRARY_PATH=/opt/openmpi3/lib:/opt/openmpi3/lib/openmpi:$LD_LIBRARY_PATH",
        "export LD_RUN_PATH=/opt/openmpi3/lib/openmpi:$LD_RUN_PATH",
        "RUN_lamaGOET",
        'echo "----------------ENDING PROGRAMRUN-------------------"',
        "",
        'echo "-------------------STAGEOUT-------------------------"',
        "cd ${WORKDIR}",
        "$SCP -r -P 2244 $WORKDIR/ $SERVERPERMDIR",
        "if [ $? = 0 ]; then",
        "    rm -r $WORKDIR /home/$USER/$PBS_JOBNAME.*",
        "else",
        '    echo "Error during copying back files; they remain on the run node"',
        "fi",
        "$SCP -P 2244 /home/$USER/$PBS_JOBNAME.* $SERVERPERMDIR",
        "",
        "exit",
        "",
    ]
    return "\n".join(lines)


def write_pbs_script(path: str | Path, values: Mapping[str, object]) -> Path:
    output = Path(path)
    output.write_text(build_pbs_script(values), encoding="utf-8", newline="\n")
    return output.resolve()
