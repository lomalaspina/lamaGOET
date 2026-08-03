# lamaGOET Qt preview

The Qt front end is an additive test version. It does not remove the
established `GUI_lamaGOET_release.sh`, `RUN_lamaGOET_release.sh`, or
`lamaGOET.sh` workflows. It reads and writes the same shell-compatible
`job_options.txt`. Every established GUI/runner variable is written on every
save, including controls hidden for the selected program. The assignments are
alphabetical, and unknown site-specific assignments are retained unchanged.

## Automatic first-run setup

Use Python 3.10 or newer. The launchers now create `.venv-qt` and install
`requirements-qt.txt` automatically on first use. They update that private
environment whenever the requirements file changes, so users do not activate
the environment or run pip manually.

Only the system Python is a prerequisite:

- **WSL/Debian/Ubuntu:** `python3` and `python3-venv`. The repository's
  `install.sh` installs both, along with the common Qt/XCB runtime libraries.
- **Windows:** Python 3.10 or newer from python.org, with the `py` launcher and
  pip/venv options enabled.
- **macOS:** Python 3.10 or newer from python.org or Homebrew.

The first launch downloads PySide6, Basis Set Exchange, and NumPy and can take
a few minutes. Later launches use the existing environment immediately. A
checkout shared between Windows and WSL keeps separate platform-specific
environments instead of overwriting an incompatible `.venv-qt`.

For an installation-only check without opening the GUI:

```bash
python3 GUI_lamaGOET_qt.py --setup-only
```

Set `LAMAGOET_QT_VENV=/custom/path` to put the private environment elsewhere,
`LAMAGOET_QT_REINSTALL=true` to repair/reinstall it, or
`LAMAGOET_QT_NO_BOOTSTRAP=true` for an administrator-managed Python setup.

## Start it

For a calculation on the current computer, run from the calculation directory
so the interface finds that directory's `job_options.txt`:

```bash
bash /path/to/lamaGOET/lamaGOET_qt.sh
```

On native Windows, double-click `lamaGOET_qt.cmd` or run it from Command
Prompt. On macOS, double-click `lamaGOET_qt.command` (or use the `.sh`
launcher from Terminal).

Local **OK** saves `job_options.txt` and starts the existing monolithic
`lamaGOET.sh --run-job-options` path. It does not create `lamaGOET.pbs`, does
not call `qsub`, and does not show the cluster-only email field.

For the submitting computer connected to the PBS cluster, use:

```bash
bash /path/to/lamaGOET/GUI_lamaGOET_qt.sh
```

The corresponding native launchers are `GUI_lamaGOET_qt.cmd` on Windows and
`GUI_lamaGOET_qt.command` on macOS.

Or name an options file and mode explicitly:

```bash
python /path/to/lamaGOET/GUI_lamaGOET_qt.py \
  --mode cluster /path/to/calc/job_options.txt
```

If the file does not exist, the SCF program starts as Gaussian.

The **Settings** tab holds the Tonto, Gaussian, ORCA, OCC, Crystal23, ELMOdb,
GAMESS-US, Jana and CP2K executable paths plus the relevant basis/library
directories. `SCFCALC_BIN` is derived from the selected program on every save;
the per-program paths remain stored so switching programs cannot reuse the
previous executable. The HAR, Advanced HAR, ELMO advanced, XCW and Plots tabs
map to the original runner variables.

The separator between the job form and structure view has a wide highlighted
mouse handle and can be dragged toward either side. When the viewer is made
very narrow, its control rows scroll horizontally instead of locking the
separator. The viewer supports perspective/orthographic projection, optional
depth cueing, atom labels, the unit-cell outline and probability-scaled Uij
ellipsoids.

## Test the manual structure grow

1. Open a CIF from the job panel or toolbar.
2. Rotate with left-drag, zoom with the wheel, and pan with right-drag.
3. Choose a grow mode:
   - **Asymmetric unit** restores only the input atom sites.
   - **Complete unit cell** applies the explicit CIF symmetry operations.
   - **Complete fragment(s)/molecule(s)** mirrors Tonto defragment: it starts
     with the CIF fragment and recursively follows Tonto's CCDC covalent-bond
     connections into symmetry/translation images. Extended covalent networks
     are reported instead of being presented as truncated molecules.
   - **Short contacts** includes images within the selected distance.
   - **van der Waals radii** includes contacts within summed element-specific
     van der Waals radii plus the selected tolerance.
   - **Within radius of selected atom** first requires clicking an atom.
   - **Neighbouring cells (3×3×3)** makes a complete bounded pack.
   - Molecule completion, short contacts, van der Waals contacts, and radius
     growth are cumulative. Each command starts from every atom currently on
     screen, so a VdW pack can be completed into whole molecular fragments
     without returning to the input asymmetric unit. The asymmetric-unit,
     unit-cell, and 3×3×3 choices intentionally reset to those bounded views.
4. Click an atom to select it. Click the same atom again, or press **Escape**,
   to clear the selection.
5. Select **Export grown CIF**. A new CIF is written; the source CIF cannot be
   overwritten.
6. When prompted, choose whether the new CIF should become the `CIF` value in
   `job_options.txt`, then save the options.

The export retains the source cell, space-group name/number, explicit symmetry
operations, occupancies, and available Uiso/Uij values. The extra displayed
atoms are written as the molecular starting fragment; Tonto retains its normal
asymmetric-unit refinement behavior. Restraints, disorder/assembly metadata,
and arbitrary non-coordinate CIF tables are not copied, so retain the original
experimental CIF and review the exported atom list before a HAR.
This first Qt version does not reproduce Olex2's full crystallographic model
editor, refinement constraints, disorder editing, or `.ins/.res` history.

Select **ADP ellipsoids** to convert the CIF Uij tensor into Cartesian
displacement space and display its rotating probability ellipsoid. The
probability percentage is adjustable from 1–99% (default 50%); Uiso sites are
shown as isotropic probability spheres. The rendering follows MoleCoolQt's
crystallographic construction: diagonalize Ucart, orient a sphere along the
three eigenvectors, scale its axes by the square roots of the eigenvalues and
the selected three-dimensional probability radius, apply smooth fixed
lighting, and draw the three principal-axis rings with rear portions hidden.
During mouse movement a lower-cost smooth surface is used for responsive
rotation; the full per-pixel normal lighting is restored on mouse release.
Non-positive displacement tensors cannot define an ellipsoid and fall back to
the ordinary atom sphere.

## Basis sets

The ordinary method and basis fields remain editable. Their suggestions change
with Gaussian, ORCA, OCC, Tonto, ELMOdb or Crystal23. CP2K basis names are read
from the basis headers in the CP2K file selected on the Settings tab, rather
than from a hard-coded subset.

**Basis Set Exchange...** requires the `basis_set_exchange` package installed
by `requirements-qt.txt`. It creates one selector per element in the opened CIF
and filters out any basis that supplies an ECP for that element. Mixed-element
definitions are written as `basis_gen.txt` in Gaussian, ORCA, Crystal23 or CP2K
format. Tonto/ELMOdb and OCC use their native installed basis mechanisms, for
which Basis Set Exchange has no directly interchangeable input format; use the
editable native basis name/directory or the external-definition editor as
appropriate and review the generated program input.

**Follow latest Tonto CIF** starts only after the user-selected starting CIF
has loaded. It ignores unrelated/old CIFs and watches only newly created or
updated files named for the current job:
`JOBNAME.latest_tonto.cif`, `JOBNAME.cartesian.cif2`,
`JOBNAME.fractional.cif1`, `JOBNAME.archive.cif`, and their numbered
Tonto-cycle copies. A PBS job created by cluster **OK** publishes
`JOBNAME.latest_tonto.cif` from node-local scratch after every completed Tonto
fit. This uses non-interactive `scp` on port 2244, matching the existing
staging script. If live copying is unavailable, the runner warns but does not
abort the refinement.

## Test cluster submission

In `GUI_lamaGOET_qt.sh`, **OK** is exclusively a cluster action. It copies
selected input files into the calculation directory when necessary, writes
`job_options.txt`, writes `lamaGOET.pbs`, and calls `qsub`. The PBS node
command remains `RUN_lamaGOET`.

For a safe interface test without submitting:

```bash
LAMAGOET_QT_DRY_RUN=true bash /path/to/lamaGOET/GUI_lamaGOET_qt.sh
```

Click **OK** and verify that `job_options.txt` and `lamaGOET.pbs` were written.

Local mode can be checked independently:

```bash
LAMAGOET_QT_DRY_RUN=true bash /path/to/lamaGOET/lamaGOET_qt.sh
```

Local **OK** must write `job_options.txt` without creating `lamaGOET.pbs`.

## Automated checks

The CIF growth and options round-trip tests do not require Qt:

```bash
python -m unittest \
  Tests.test_qt_bootstrap \
  Tests.test_qt_crystal_grow \
  Tests.test_qt_job_options \
  Tests.test_qt_cluster \
  Tests.test_qt_basis_exchange \
  Tests.test_cp2k_cif_alignment \
  Tests.test_runner_regressions
bash Tests/test_live_cif_publish.sh
```

An off-screen Qt smoke test is also provided and runs automatically when
PySide6 is installed:

```bash
python Tests/test_qt_gui_smoke.py
```

`Tests/prepare_nh3_regressions.py` creates new, isolated test directories from
the six supplied NH3 archives; it does not alter the archived failed runs. Full
scientific regression runs additionally require each external chemistry
program and its licensed/runtime environment.
