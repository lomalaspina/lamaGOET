# Working on lamaGOET

lamaGOET runs Hirshfeld Atom Refinement. It drives Tonto and a
quantum-chemistry program (Gaussian, ORCA, CP2K, Crystal, ELMOdb, OCC,
GAMESS) round a refinement loop until the structure stops changing.

Two parts:

- `lamagoet_qt/` and `GUI_lamaGOET_qt.py` — the graphical interface, Python
  and Qt.
- `lamaGOET.sh` and `RUN_lamaGOET_release.sh` — the scripts that do the
  actual work. Bash, and large.

---

## The one thing that connects them

The interface and the scripts talk through a single file: `job_options.txt`.

The interface writes it, then runs `bash lamaGOET.sh --run-job-options <file>`.
The script reads it. That is the entire connection.

**Every option must be written every time, even the ones the user cannot
see.** The scripts test values like this:

    [[ "$SOMETHING" == "false" ]]

If the interface leaves an option out, that test does not see "false" — it
sees nothing, takes the wrong branch, and says nothing. The refinement runs
and quietly produces a different answer.

So if you add or rename an option you must change all three of:

1. `lamagoet_qt/options_schema.py` — the list of every option name
2. `lamagoet_qt/main_window.py` — the box the user types into
3. the script that reads it

Changing only one or two fails silently. There is no error message.

---

## There are two copies of the runner

`lamaGOET.sh` runs jobs on this computer. `RUN_lamaGOET_release.sh` runs them
on a cluster. They contain the same ~50 functions, and are about 98% identical.

**Never fix a bug in one without checking the other.** This has gone wrong
repeatedly, and every time the result was a cluster job that produced wrong
numbers without complaining. The worst example: cluster jobs using
self-consistent cluster charges were reading a file that is never created, so
the point charges were silently dropped from every calculation.

Merging the two files would prevent this, but it would make the change too
large to review. They stay separate for now.

---

## macOS needs GNU tools

The scripts are written for GNU `sed` and GNU `awk`. macOS ships the BSD
versions, which differ in ways that corrupt Tonto input files rather than
failing outright.

`lamagoet_shell_env.sh` handles this: on macOS it points `sed` at `gsed` and
`awk` at `gawk`. On Linux it does nothing. Write GNU syntax freely.

**macOS also ships bash 3.2, from 2007.** Do not use anything newer:

- no `${var^^}` or `${var,,}` — use the `_upper` / `_lower` helpers
- no `declare -A`, no `mapfile`, no `source <(...)`

These fail with "bad substitution" and, worse, the script can then carry on
and exit 0, so nothing downstream knows it failed.
`Tests/test_shell_portability.sh` checks for this.

---

## Running the tests

    bash Tests/run_all.sh

Note `Tests/` is not a Python package, so `python -m unittest discover` does
not work. Run a single Python test directly:

    PYTHONPATH=. .venv-qt/bin/python Tests/test_qt_job_options.py

`.venv-qt/` is generated, not source. Delete it and it rebuilds itself.

---

## Do not change these

**`Crystal14`.** The interface says "Crystal23" but writes the value
`Crystal14`, and about eight places compare against that exact string.
Changing it would break every saved `job_options.txt` on every user's disk
and on the cluster.

**The unreachable CP2K code in `RUN_lamaGOET_release.sh`.** That script hands
CP2K jobs straight to `lamaGOET.sh`, so some of its CP2K branches can never
run. They stay, with a comment, because deleting them makes the change harder
to review and gains nothing.

**The structure of `lamagoet_qt/main_window.py`.** It is one 2400-line class
that binds about 170 options. Splitting it risks dropping options silently —
see the first section. Ask before restructuring.

**The `sed` commands that rewrite CIF and xyz files.** Tonto reads those files
by position. A tidier `sed` that shifts a column produces a wrong structure,
not an error.

**`$[ ... ]` arithmetic.** Old-fashioned, but it works on both bash 3.2 and
bash 5, and there are hundreds of them.

---

## Known to be broken

**Powder refinement / Jana.** It calls two Python scripts,
`powderHARstart.py` and `powderHARcifrewrite.py`, which have never been
distributed with lamaGOET and exist on no branch. The path is guarded and
reports this rather than failing halfway through a run. Do not try to
implement it.

---

## More detail

- `docs/CLEANUP_PLAN.md` — what this branch is changing, and why
- `docs/ARCHITECTURE.md` — how the pieces fit together
- `docs/TESTING.md` — what each test covers
- `docs/INSTALL.md` — prerequisites per platform
