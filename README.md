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
crystallographic growing model. A native Windows/Linux/macOS Qt/PySide GUI
with an embedded crystallographic scene is being developed as a separate
front end while retaining `job_options.txt` and the existing shell runners.

## Saved options and refinement stopping

`COMPLETESTRUCT` is the canonical complete-CIF option written by the GUI and
read by both runners. Existing option files containing the former
`COMPLETECIF` name are still accepted for compatibility.

For Gaussian/ORCA/Tonto HAR, the runner also detects a stationary SCF
wavefunction when the SCF RMSD is small and the energy either repeats directly
or enters a stable two-cycle oscillation. This handles precision-limited CIF
coordinate cycles. It stops the HAR loop and continues to the normal final
residual-density calculation. The thresholds can be overridden with
`HAR_ENERGY_REPEAT_TOL` and `HAR_SCF_RMSD_TOL`.

## Tonto `oc-crystal23` Fourier kernel

The companion Tonto `Lolo_CP2K` change preserves a fresh density and fresh
atomic form-factor calculation at every refinement step. It only evaluates
the Fourier identity `exp(i k.r) = cos(k.r) + i sin(k.r)` with separate real
accumulators, avoiding a general complex exponential and complex multiply in
the innermost grid-point/reflection loop.
