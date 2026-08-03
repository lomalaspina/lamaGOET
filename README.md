# lamaGOET

lamaGOET interfaces quantum-chemistry programs with iterative Tonto
Hirshfeld atom refinement. The root `lamaGOET.sh` is the monolithic launcher
and contains the periodic all-electron CP2K backend.

## GUI startup and CP2K fields

The current GUI uses gtkdialog. If `job_options.txt` is absent, Gaussian is
selected before the window is constructed and only Gaussian-relevant controls
are shown. If a saved options file exists, its `SCFCALCPROG` value is used for
the initial state.

The method and basis-set controls are editable dropdowns. Gaussian, ORCA,
OCC, and Crystal23 show program-specific suggestions; a saved or manually
typed value is kept as the first item, so custom basis files and less common
keywords remain usable. Elmodb keeps the fields editable without inventing a
predefined basis list. CP2K uses its own periodic method/basis panel.

Crystal23 keeps its method and basis fields visible while Gaussian-specific
keywords and molecular cluster-charge controls remain hidden. The ELMO
library and initial-ADP fields are visible only for elmodb; the Tonto basis
directory is visible only for Tonto or elmodb.

For CP2K:

- Select an all-electron CP2K basis file first.
- The **Basis name** dropdown is populated from every basis alias declared in
  that selected file. It remains editable for unusual/custom aliases. It does
  not show aliases from unrelated CP2K basis files, because the generated CP2K
  input names one basis file and an alias from another file would be invalid.
- The **XC functional** dropdown contains the non-hybrid shortcut values
  accepted by the current CP2K input generator. PBE and the other listed
  non-hybrid choices are valid for periodic HAR: Tonto imports the CP2K
  molecular density and uses its functional-independent Thakkar spherical
  pro-atoms for the stockholder weights. The legacy BLYP `scfdata` block only
  satisfies Tonto's common setup path and does not replace or mix the CP2K
  density.
- Before writing the Tonto XML, the bridge compares the complete CP2K atom
  list and cell with the CIF. If they differ only by one periodic origin
  translation, the XML atom coordinates are aligned to the CIF origin. Any
  composition, cell, or non-translational geometry mismatch stops before
  Tonto with a specific error.
- Full CP2K output is streamed to the terminal/cluster log with `tee` and also
  retained in the per-cycle output file. Set
  `CP2K_TERMINAL_VERBOSE=false` only when compact output is wanted.

### Density partition models

CP2K and Crystal23 always use their imported theoretical density through
`partition_model=oc-crystal23`. For those programs, the Qt GUI displays only
the finite-cluster versus periodic stockholder-denominator selector. It does
not offer the observed-density model.

The **Regularized observed density (experimental)** model is available only
when Tonto is selected as the SCF program. The Tonto density panel selects
between its standard `partition_model=oc-hirshfeld` path and
`partition_model=oc-observed`, which constructs the atomic form factors from
the observed diffraction data instead of a CP2K or Crystal23 density. Saved
legacy CP2K/Crystal23 options requesting `oc-observed` are safely normalized
back to `oc-crystal23` when the GUI saves or the runner generates Tonto input.

The observed-density controls correspond directly to Tonto input:

- **Residual-density shrinkage** (`observed_density_shrinkage`, default 0.5)
  is the fraction of reliability-weighted experimental residual density added
  to the IAM prior. It must be at least zero and smaller than one.
- **Minimum thermal factor** (`observed_density_min_TF`, default 0.1) limits
  the deconvolution of thermal motion when producing static atomic form
  factors.
- **Zero-model phase** (`observed_zero_phase_sign`, default 0) normally omits
  a coefficient whose model structure factor has no phase. Expert tests may
  select +1 or -1 for a symmetry-allowed sign hypothesis.

The experimental Tonto path requires a `Lolo_CP2K` build containing commit
`6f7fa8cf` or later. Older Tonto executables will reject these keywords.

## Manually grown starting geometry

gtkdialog 0.8.3 cannot embed an OpenGL/WebGL crystallographic scene. The
**Manually grow to new CIF** button therefore uses this workflow:

1. Choose a new output CIF filename. The original CIF is never overwritten.
2. lamaGOET copies the original structure to the new CIF.
3. lamaGOET asks whether to use Olex2, Mercury, VESTA, Avogadro, Jmol, or
   another executable. If the program is not on `PATH`, locate it in the file
   selector.
4. Grow the structure manually, save the new CIF, and close the viewer.
5. lamaGOET replaces the GUI's CIF field with the new file, so that geometry is
   the starting structure written to `job_options.txt`.

All provide interactive rotation. Symmetry expansion or molecule/crystal
growing depends on the selected viewer; Olex2 and Mercury provide the closest
workflow. The viewer must save the grown model as CIF before it is closed. Set
`LAMAGOET_STRUCTURE_VIEWER=/path/to/viewer` to choose a specific executable.

gtkdialog cannot embed those external programs or reproduce Olex2's full
crystallographic growing model.

An additive native Qt/PySide preview is now available as
`GUI_lamaGOET_qt.py`. It runs on Windows, Linux, and macOS, retains the same
`job_options.txt` and existing shell runners, and embeds a rotatable structure
view. Its manual modes show the asymmetric unit, complete unit cell, connected
molecules across cell boundaries, short contacts, van der Waals contacts, a
radius around a selected atom, or a 3x3x3 neighbouring-cell pack. The displayed
coordinates can be written to a new starting-geometry CIF while retaining the
original unit cell and symmetry operations; the source CIF is protected from
overwrite.

The Qt launchers automatically create a private `.venv-qt` and install or
update `requirements-qt.txt` on first use. No environment activation or
manual pip command is required. Use `lamaGOET_qt.sh`/`.command`/`.cmd` for a
local job and `GUI_lamaGOET_qt.sh`/`.command`/`.cmd` for cluster submission.
Python 3.10 or newer remains the only Python prerequisite; chemistry programs
and platform-level display/runtime libraries must still be installed by the
operating system or site administrator.

The Qt Settings tab retains separate executable paths for Tonto, Gaussian,
ORCA, OCC, Crystal23, ELMOdb, GAMESS-US, Jana and CP2K. Every save emits the
complete option schema in alphabetical order—even values for controls hidden
for the selected backend—so runner conditionals always receive explicit
values. `SCFCALC_BIN` is derived from the selected backend while the individual
program paths remain available when switching back.

Basis Set Exchange integration offers per-element, all-electron-only choices
for Gaussian, ORCA, Crystal23 and CP2K. Tonto/ELMOdb and OCC keep editable
native basis controls because their installed/native basis formats are not
direct Basis Set Exchange targets.

The Qt view converts CIF Uij values to their physical Cartesian displacement
tensors and draws probability ellipsoids which rotate with the structure.
The probability can be changed from 1–99%. After the user opens the starting
CIF, the viewer follows only that job's newly created or updated Tonto
cartesian/fractional/archive CIFs; unrelated CIFs already in the directory are
ignored. A PBS file generated in cluster mode exports the submitting
host/directory to the runner, which publishes
`JOBNAME.latest_tonto.cif` after each completed Tonto fit. If the cluster's
non-interactive SSH policy blocks that intermediate copy, the calculation
continues with a warning and the ordinary final stage-out remains available.

The two Qt launchers deliberately have different roles:

- `lamaGOET_qt.sh` is local mode. **OK** writes `job_options.txt` and starts
  `lamaGOET.sh --run-job-options`; it never creates PBS input or calls `qsub`.
- `GUI_lamaGOET_qt.sh` is cluster mode. **OK** writes `job_options.txt`,
  creates `lamaGOET.pbs` with the established `RUN_lamaGOET` node command, and
  submits it with `qsub`.

See `QT_GUI_TESTING.md` for installation, testing, and the current
model-editing limitations.

## Saved options and refinement stopping

`COMPLETESTRUCT` is the canonical complete-CIF option written by the GUI and
read by both runners. Existing option files containing the former
`COMPLETECIF` name are still accepted for compatibility.

For Gaussian/ORCA/OCC and CP2K HAR, the runner also detects a stationary SCF
wavefunction when the energy either repeats directly or enters a stable
two-cycle oscillation. This handles precision-limited CIF coordinate cycles.
The selected SCF program must still terminate normally; its reported density
RMSD is retained as a diagnostic, but does not veto a confirmed repeated
energy. The runner stops the HAR loop and continues to the normal final
residual-density calculation. The energy threshold can be overridden with
`HAR_ENERGY_REPEAT_TOL`; `HAR_SCF_RMSD_TOL` controls the diagnostic warning.

## Tonto `oc-crystal23` Fourier kernel

The companion Tonto `Lolo_CP2K` change preserves a fresh density and fresh
atomic form-factor calculation at every refinement step. It only evaluates
the Fourier identity `exp(i k.r) = cos(k.r) + i sin(k.r)` with separate real
accumulators, avoiding a general complex exponential and complex multiply in
the innermost grid-point/reflection loop.
