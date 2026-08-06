# Testing lamaGOET

```bash
bash Tests/run_all.sh
```

Runs everything and prints a summary. Works on macOS (bash 3.2, BSD userland)
and Linux. Exits non-zero if anything fails; tests that skip do not fail the
run.

To run one Python test on its own:

```bash
PYTHONPATH=. .venv-qt/bin/python Tests/test_qt_job_options.py
```

`Tests/` is not a Python package, so `python -m unittest discover` does **not**
work. Run the files directly with `PYTHONPATH` set to the repository root.

## What each test covers

### Shell

| | |
|---|---|
| `test_shell_portability.sh` | every shell file parses under the running bash, and none uses bash 4 syntax. This is what keeps macOS working. |
| `test_gui_cp2k_helpers.sh` | the `--list-*` and `--grow-cif` command-line helpers |
| `test_har_stall_detection.sh` | detecting a stationary wavefunction, including a two-cycle oscillation |
| `test_live_cif_publish.sh` | publishing intermediate CIFs from a cluster node |

### Python

| | |
|---|---|
| `test_runner_parity.py` | the two runners have not drifted apart |
| `test_runner_regressions.py` | contracts both runners must satisfy |
| `test_qt_job_options.py` | reading and writing `job_options.txt` |
| `test_qt_crystal_grow.py` | symmetry expansion and molecule completion |
| `test_qt_cluster.py` | PBS script generation |
| `test_qt_bootstrap.py` | the private Python environment |
| `test_qt_basis_exchange.py` | Basis Set Exchange lookups |
| `test_qt_file_dialogs.py` | macOS can reach `/usr/local/bin` in a file dialog |
| `test_qt_export_guard.py` | exporting before growing warns |
| `test_windows_support.py` | `.cmd` encoding, Windows paths, the local-run guard |
| `test_qt_gui_smoke.py` | the interface builds off-screen |
| `test_cp2k_cif_alignment.py` | CP2K and CIF geometries agree |

## What is not tested

**No refinement is run.** Nothing in the suite calls Tonto, so nothing checks
that the numbers are right. The suite passing means the machinery is intact,
not that the science is.

For that, use the worked examples in [../examples/](../examples/), which carry
published reference values. The quickest is epoxide:

```bash
cd examples/1-epoxide
bash /path/to/lamaGOET/lamaGOET.sh --run-job-options ./job_options.txt
grep -A8 "IAM refinement" my_job.lst
```

Expect `R(F) 0.035630` with 44 parameters, against a published 0.0355. Takes
about ten seconds and needs only Tonto.

Also untested: anything on a cluster (no `qsub` here), anything on Windows, and
whether the interface paints correctly on any platform — the off-screen smoke
test builds the widgets but cannot tell you they look right.

## Writing a test

Static checks over the shell source are worth more than they sound. Several
real bugs — an always-true comparison, a file nothing creates, a heading Tonto
no longer writes — are visible by reading the source and were caught that way.

If you fix something in one runner, add a test asserting it is present in both.
That is what `test_runner_parity.py` is for, and it is the only defence against
the two files drifting apart again.

When you add a test, check it can fail. Reintroduce the bug, watch it go red,
then put it back. Two tests here were written that way and one of them was
vacuous until corrected.
