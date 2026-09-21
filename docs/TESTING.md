# Testing lamaGOET

lamaGOET has three deliberately separate test layers:

1. the fast, licence-free software suite;
2. integrity checks for retained scientific archives;
3. opt-in live scientific regressions using locally installed programs.

Do not describe layer 1 or 2 as a freshly reproduced HAR.

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
| `test_crystal_parallel_runner.sh` | Crystal23 serial/parallel wrapper dispatch and quiet terminal behavior |
| `test_crystal_tolinteg.sh` | external-basis `TOLINTEG` policy and generated Crystal23 input |

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
| `test_cp2k_native_interface.py` | native CP2K density/overlap/Fock requirements and fail-closed dispatch |
| `test_finite_crystal_wavefunction.py` | finite-cluster analysis export is kept distinct from the exact periodic result |
| `test_install_script.py` | installer dependency/bootstrap contracts |
| `test_periodic_wavefunction_export.py` | Crystal23/CP2K periodic TREXIO input and external-basis handling |
| `test_qt_branding.py` | application icon/desktop identity setup |
| `test_qt_discovery.py` | executable and local dependency discovery |
| `test_documented_options.py` | every canonical `OPTION_DEFAULTS` key appears in the scientific manual |
| `test_scientific_archives.py` | retained historical cases and exact CIF values match the explicit archival manifest |
| `test_epoxide_control.py` | Epoxide control provenance, input hashes, documented settings, and optional live IAM→HAR numerical result |

The Epoxide file always checks its manifest and documentation contract. Its
live Tonto calculation is opt-in, so the licence-free default suite remains
fast. On 20 September 2026 the default suite completed 27 files: 27 passed,
0 failed, 0 skipped on Linux x86-64.

## What is not tested by the default suite

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

Use RHF/def2-SVP, MERG 2, and F/σ cutoff 4. Expect the IAM to give
`R(F)=0.035630`, `wR(F²)=0.073136`, 1,313 reflections, and 44 parameters; the
following HAR should give `R(F)=0.030272`, `wR(F²)=0.053130`, 1,313
reflections, and 64 parameters. On the validation machine the complete run
took about 20 seconds and needed only Tonto.

Run the guarded numerical regression explicitly with:

```bash
LAMAGOET_RUN_EPOXIDE=1 \
LAMAGOET_TONTO_BIN=/path/to/tonto \
LAMAGOET_TONTO_BASIS_DIR=/path/to/tonto/basis_sets \
PYTHONPATH=. .venv-qt/bin/python Tests/test_epoxide_control.py
```

The test stages a new temporary directory, checks the generated Tonto input,
and requires the HAR R factors to improve over the IAM. R, wR, and GoF are
accepted within an absolute `1×10⁻⁴`; reflection and parameter counts must
match exactly. The test never modifies the example directory.

Also untested: anything on a cluster (no `qsub` here), anything on Windows, and
whether the interface paints correctly on any platform — the off-screen smoke
test builds the widgets but cannot tell you they look right.

## Historical scientific archive

`Tests/inputs/run_tests.txt` names ten older molecular cases covering Gaussian,
Tonto, ELMOdb, cluster charges, and experimental-dispersion options. Their
retained outputs are described by `Tests/scientific_regressions.json`.
`test_scientific_archives.py` checks:

- that the manifest says explicitly that it is archival;
- exact agreement between the case list and retained directories;
- presence of `job_options.txt`, CIF, FCF, FCO and listing artifacts;
- the selected SCF program;
- exact recorded R/wR/GoF, residual-density and reflection-count CIF values;
- presence of the residual-density report in the listing.

This replaces the final comparison in the historical 1,381-line
`RUN_tests.sh`. That script was a fork of an old production runner and ended
with a malformed shell condition instead of a reliable numerical comparison.
It could therefore give a misleading status and is not restored as CI.

## Opt-in live scientific regressions

The live driver copies all fixtures to a new `mktemp` directory and invokes
the current monolithic runner. It is never called automatically because it can
require licensed programs and substantial computer time.

Run all retained cases:

```bash
bash Tests/run_scientific_regressions.sh
```

Run selected cases:

```bash
bash Tests/run_scientific_regressions.sh nh3-Tonto yellow-Tonto
```

Keep the staging directory for inspection:

```bash
LAMAGOET_KEEP_SCIENTIFIC_WORK=1 \
  bash Tests/run_scientific_regressions.sh nh3-Tonto
```

The driver currently checks process success and required final artifacts. A
fresh numerical comparison must record external-program versions and decide
tolerances appropriate to the scientific change; it must not silently reuse
the archival exact values as universal tolerances.

## Documentation validation

Build the searchable site and PDF with:

```bash
bash docs/build_manual.sh
```

For a warnings-as-errors HTML check:

```bash
.venv-docs/bin/python -m sphinx -W --keep-going \
  -b html docs/manual docs/_build/html
```

`test_documented_options.py` imports the canonical schema and fails if a GUI
or runner option is absent from `docs/manual/options-reference.md`. It checks
coverage, not the scientific correctness of prose; reviewers must still audit
changed definitions.

## Release evidence

Before a release or GitHub Pages publication, retain the output of:

```bash
bash Tests/run_all.sh
bash docs/build_manual.sh
git diff --check
```

Visually inspect representative and table-heavy PDF pages plus desktop/mobile
HTML layouts. If a scientific interface changed, add a fresh matched numerical
control and state whether it is a unit test, retained validation, or
publication-grade convergence study.

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
