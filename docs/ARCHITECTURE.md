# How lamaGOET works

## The shape of it

```
      ┌───────────────────────────────┐
      │  Qt interface                 │
      │  lamagoet_qt/                 │
      │  Python and PySide6           │
      └───────────────┬───────────────┘
                      │  writes
                      ▼
      ┌───────────────────────────────┐
      │  job_options.txt              │
      │  ~170 shell assignments       │
      └───────────────┬───────────────┘
                      │  read by
                      ▼
      ┌───────────────────────────────┐
      │  shell runners                │
      │  lamaGOET.sh                  │
      │  RUN_lamaGOET_release.sh      │
      └───────────────┬───────────────┘
                      │  drive
                      ▼
      ┌───────────────────────────────┐
      │  Tonto                        │
      │  with one of:                 │
      │    Gaussian   ORCA   OCC      │
      │    CP2K       Crystal23       │
      │    ELMOdb     GAMESS-US       │
      └───────────────────────────────┘
```

The interface never computes anything. It writes `job_options.txt` and starts a
shell script. Everything after that is shell, and the shell can be driven
without the interface at all — which is how the tests and the examples work.

## The contract

`job_options.txt` is the only thing connecting the two halves. It is a plain
list of shell assignments, alphabetical, quoted:

```sh
BASISSETT="STO-3G"
CIF="./epoxide.cif"
FCUT="4"
JOBNAME="my_job"
```

**Every option is written every time**, including ones for controls hidden for
the selected program. This is not tidiness. The runners contain tests like

```sh
[[ "$SOMETHING" == "false" ]]
```

and an absent variable is an empty string, not `false`. Omitting a key does not
give the default; it takes a different branch, silently, and the refinement
produces a different answer with no error.

`lamagoet_qt/options_schema.py` holds the canonical list and is the source of
truth. `complete_job_options()` fills in anything the interface did not set.

Adding or renaming an option means changing three places: the schema, the
widget binding in `main_window.py`, and every consumer in the runners.

## Starting a job

**On this computer.** `main_window.py` writes the file and runs

```sh
bash lamaGOET.sh --run-job-options /path/to/job_options.txt
```

**On a cluster.** `cluster.py` writes `lamaGOET.pbs`, whose body invokes
`RUN_lamaGOET`, and submits it with `qsub`.

## The two runners

| | |
|---|---|
| `lamaGOET.sh` | this computer. Also holds the CP2K backend and the command-line helpers. |
| `RUN_lamaGOET_release.sh` | a cluster node. |

They contain the same ~50 functions and are about **98% identical**. This is
the single worst thing about the codebase: every bug fixed in one and not the
other has produced a cluster job returning wrong numbers without complaint, and
that has happened at least three times. `Tests/test_runner_parity.py` fails when
a known fix is present in one and missing from the other.

One deliberate asymmetry: the cluster runner hands CP2K jobs straight back to
`lamaGOET.sh`, so `SCFCALCPROG` is never `CP2K` past its first fifty lines and
its CP2K branches are unreachable. They are kept, with a comment, because
deleting them would enlarge the diff for no gain.

## The refinement loop

1. Read the CIF; complete the molecule if asked.
2. Compute a wavefunction with the chosen program.
3. Tonto partitions that density into aspherical atoms (Hirshfeld) and Fourier
   transforms them into scattering factors.
4. Tonto least-squares refines positions and displacement parameters against
   the measured reflections.
5. The geometry changed, so the density is stale — go back to 2.

With **Tonto** as the SCF program, Tonto performs the whole loop internally and
lamaGOET invokes it once. With **Gaussian, ORCA or CP2K**, lamaGOET alternates
between programs itself, one directory per cycle: `1.tonto_cycle.<job>`,
`2.…`. A single cycle directory is normal for Tonto and does not mean the loop
stopped early.

## Files a run produces

| | |
|---|---|
| `stdin` | the Tonto input lamaGOET generated |
| `stdout` | Tonto's full output — everything is in here |
| `<job>.lst` | lamaGOET's summary, assembled from `stdout` |
| `<job>.archive.cif` | the refined structure |
| `<job>.residual_density,cell.cube` | for VESTA |
| `<N>.tonto_cycle.<job>/` | a snapshot of each cycle |

`<job>.lst` is built by copying blocks out of `stdout`, matched by heading. That
makes it fragile: when Tonto renames a heading, lamaGOET keeps running and
quietly produces an incomplete summary. See
[TONTO_COMPATIBILITY.md](TONTO_COMPATIBILITY.md).

## The Python side

| | |
|---|---|
| `GUI_lamaGOET_qt.py` | entry point; `--mode local` or `--mode cluster` |
| `bootstrap.py` | builds the private `.venv-qt` and re-executes inside it |
| `options_schema.py` | the canonical option list |
| `job_options.py` | reads and writes `job_options.txt` |
| `main_window.py` | the whole interface: one class, ~2400 lines |
| `crystal.py` | CIF parsing, symmetry, growing, displacement ellipsoids |
| `viewer.py` | the 3D view, drawn with QPainter — no OpenGL |
| `cluster.py` | PBS script generation |
| `basis_exchange.py` | Basis Set Exchange lookups |

`main_window.py` binds about 170 options across `load_options` and
`_current_values`, which are maintained by hand and mirror each other. That
pair is the most likely place for a bug. Splitting the class risks dropping
options silently, so don't without a plan for verifying the binding.

## The shell environment

Both runners source `lamagoet_shell_env.sh` first. On macOS it points `sed`,
`awk` and `realpath` at `gsed`, `gawk` and `grealpath`; on Linux it defines
nothing, so Linux behaviour cannot change. It also provides `_upper` and
`_lower`, because macOS ships bash 3.2, which has no `${var^^}`.

It tests whether a tool is GNU rather than whether it exists: a Mac with
Homebrew's coreutils on `PATH` already has a GNU `realpath` but a BSD `sed`.
