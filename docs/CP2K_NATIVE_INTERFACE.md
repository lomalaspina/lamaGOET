# Native CP2K periodic-HAR interface

The CP2K settings in the Qt GUI now include a **Density interface** selector:

- **Native CP2K (density, overlap and Fock)**, saved as
  `CP2K_DENSITY_INTERFACE=native`, asks Tonto to read CP2K outputs directly.
- **Legacy XML bridge**, saved as `CP2K_DENSITY_INTERFACE=xml`, keeps the
  existing `.kp` + `.mokp` Python-to-XML conversion for compatibility.

The default is `native`. It requires a Tonto build containing
`process_cif_and_cp2k_native` and a CP2K build supporting `MO_KP` and the
real-space CSR matrix print keys. Selecting `xml` is an explicit compatibility
choice: a native import failure never silently switches interfaces.

## Files and input

For every CP2K cycle, lamaGOET requests:

1. `MO_KP`, with `AO_EXPORT_TYPE GTO_BASIS`, containing the exact Gaussian
   basis, cell, atoms and complex k-point orbital metadata;
2. CP2K's normal output, retained as `I.JOBNAME.cp2k.out`;
3. the real-space density `P(R)`, overlap `S(R)` and Kohn-Sham/Fock `KS(R)`
   matrices, in CP2K's formatted CSR output.

All three CSR families use `REAL_SPACE T`, `BINARY F`,
`UPPER_TRIANGULAR F` and `THRESHOLD 0.0`. Thus lamaGOET does not deliberately
discard small matrix entries or supply only a triangular half. CP2K may still
apply its own internal numerical thresholds during the calculation.
`FILENAME ./native` and `COMMON_ITERATION_LEVELS 100` give predictable,
per-image names, for example `native-KS_SPIN_1_R_1.csr`. An exact-name
`FILENAME =native` must **not** be used: it would overwrite different lattice
images. The final print replaces earlier snapshots rather than appending them.

The generated Tonto input uses:

```text
cp2k_mokp_file_name= /path/to/cycle/JOBNAME.mokp
cp2k_output_file_name= /path/to/cycle/I.JOBNAME.cp2k.out
cp2k_csr_prefix= /path/to/cycle/native-
process_cif_and_cp2k_native
```

The trailing hyphen is part of `cp2k_csr_prefix`. Tonto constructs its exact
`cp2k-native` Gaussian basis library from the CP2K metadata; lamaGOET therefore
does not try to load that library before the first native import. The Slater
pro-atom reference library is staged alongside it as before. Native HAR does
not consume the CP2K binary `.kp` restart, although the restart remains useful
for initializing the next CP2K cycle.

The initial native contract is restricted, closed-shell, all-electron GAPW,
with the explicit full k-point grid (including an explicit `&KPOINTS` section
for a 1×1×1 grid). The existing GUI functional choices remain BLYP and PBE.
The supplied KS matrices are the self-consistent DFT effective one-electron
operator often called the Fock matrix; they are not a Hartree-Fock exchange
matrix. Missing P, S or KS exports stop the job before refinement. Tonto also
validates the complete native datasets during import.

## Compatibility and scope

Both local `lamaGOET_qt.sh` and cluster `GUI_lamaGOET_qt.sh` save the option.
The cluster runner already delegates CP2K jobs to the monolithic
`lamaGOET.sh`, so both routes use the same implementation. Existing Tonto XML
keywords and the legacy Python bridge have not been removed.

This removes the **density-to-XML bridge from the native HAR path**; it does
not remove Python from lamaGOET entirely. The existing CIF-to-CP2K geometry
helper, Qt GUI, Basis Set Exchange and optional wavefunction exporters still
use Python. Importing the CP2K Fock matrix does not by itself add a validated
CP2K-only periodic-XCW reference: that separate workflow still builds its
Crystal23 GRED+KRED reference as documented in `PERIODIC_XCW.md`.

Developer input-generation and compatibility checks:

```bash
python3 -m unittest Tests.test_cp2k_native_interface Tests.test_runner_regressions Tests.test_qt_job_options
bash -n lamaGOET.sh
bash -n RUN_lamaGOET_release.sh
QT_QPA_PLATFORM=offscreen .venv-qt/bin/python Tests/test_qt_gui_smoke.py
```

These checks exercise the shell/GUI contracts, not the scientific equivalence
of native and XML densities. Retain and compare the actual Tonto predictions,
refinement outputs and native matrix validation logs for the NH3 and Diamond
integration tests before treating a new build as validated.
