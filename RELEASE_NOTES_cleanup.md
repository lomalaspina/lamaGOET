# cleanup Qt release candidate

This release candidate keeps the established shell calculation paths and adds
the cross-platform Qt/PySide interface as an optional front end. It is prepared
for review on the `cleanup` branch; no release tag is implied by this file.

## Included behavior

- `lamaGOET_qt.sh` runs locally, writes `job_options.txt`, and starts the
  monolithic `lamaGOET.sh`. It never writes PBS input or invokes `qsub`.
- `GUI_lamaGOET_qt.sh` is the submitting-computer launcher. It writes the full
  option schema, stages the selected inputs, creates PBS input, and invokes the
  existing cluster-side `RUN_lamaGOET` command.
- Every option is serialized even when its widget is hidden for the selected
  SCF program. Per-program executable, method, and basis values survive program
  switches and restarts.
- The embedded CIF view provides rotatable Uij probability ellipsoids,
  draggable panel sizing, cumulative contact/molecule growth, protected CIF
  export with the original symmetry retained, and live following of new Tonto
  CIF output.
- Repeated SCF energies stop precision-limited Gaussian/ORCA/OCC and CP2K HAR
  cycles and continue to final residual density. RMSD remains diagnostic; a
  normally terminated calculation with confirmed identical energies is not
  kept running solely because its printed RMSD exceeds the warning threshold.
- CP2K retains visible terminal output, imports a fresh periodic density, and
  recalculates atomic form factors in every Tonto refinement cycle.
- CP2K and Crystal23 now offer an explicit choice between their imported
  theoretical density and Tonto's experimental `oc-observed` prototype. The
  GUI exposes shrinkage, minimum thermal-factor, and zero-phase controls only
  for the observed-density choice, while the stockholder selector remains
  specific to imported periodic density.

## Scientific comparison note

The supplied `nh3_gaussian_CC_BLYP_def2TZVP.zip` stops during the initial
Gaussian stage and `nh3_tonto_CC_BLYP_def2TZVP.zip` stops after the first native
Tonto SCF. They do not contain two final-refinement GOF values that can be
compared reproducibly. The runner also uses different top-level Tonto paths:
an imported Gaussian wavefunction enters `ha_fit`, while native Tonto SCF uses
`refine_hirshfeld_atoms`. Similar final coordinates therefore do not by
themselves prove identical calculated structure factors. A controlled GOF
comparison needs two completed jobs with the same reflection set, weights,
cutoff, basis contraction/spherical convention, cluster-charge model, and
final archive CIFs.

## Validation

- Shell syntax: `lamaGOET.sh`, `RUN_lamaGOET_release.sh`, and both Qt launchers.
- Python compilation and unit tests for CIF/CP2K alignment, option round-trip,
  cluster staging, crystal growth, Basis Set Exchange, runner contracts, and
  the off-screen Qt interface.
- Real isolated NH3 ORCA regression using ORCA 5.0.4 and Tonto
  `26.07.26-a8ea1092`: the reported repeated energy sequence stopped at cycle
  10 and proceeded to final residual density.
- Real isolated NH3 CP2K/Tonto regression: CP2K cycles 1 and 2 terminated
  normally, the first roughly 12-minute Tonto `F_pred` calculation completed
  a Hirshfeld fit with maximum shift/esd 2.846443, and the CIF/XML atom mapping
  error did not recur. The run was intentionally stopped before a second full
  `F_pred`; replaying all 14 reported cycles would take hours on one core.
- A deterministic test of the actual `CP2K_RUN_HAR` shell function confirms
  that repeated CP2K energies stop before another Tonto fit, reuse the density
  already calculated at the final geometry, and invoke final residuals once.

See `QT_GUI_TESTING.md` for installation, safe dry-run commands, manual checks,
and the current model-editing limitations.
