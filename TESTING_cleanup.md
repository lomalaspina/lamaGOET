# cleanup branch testing

Run these checks from a disposable checkout or work directory before using
the updated branch for production refinements.

## 1. Start with no saved options

Run the GUI in a new test directory that does not contain `job_options.txt`:

```bash
cd lamaGOET-cleanup-test-v4
bash GUI_lamaGOET_release.sh
```

Gaussian should be selected immediately. The Gaussian executable, editable
method and basis dropdowns, extra Gaussian keywords, and cluster controls
should be visible. The CP2K panel should be hidden.

## 2. Check saved values

Choose Gaussian, type a non-default method such as `BLYP`, and type or select a
basis. Close with **OK**, then reopen the same GUI. The saved values should
remain selected rather than reverting to `rhf` or `STO-3G`.

Select ORCA and confirm that its method/basis suggestions replace the Gaussian
suggestions while the fields remain editable.

Select CP2K. The molecular method/basis, extra Gaussian keyword, and
cluster-charge controls should disappear.

Select Crystal23. Its editable method and basis dropdowns should remain
visible and should contain Crystal23-compatible suggestions. Extra Gaussian
keywords and cluster-charge controls should remain hidden.

The ELMO libraries and initial-ADP fields should appear only for elmodb. The
basis-set directory should appear only for Tonto or elmodb.

## 3. Check CP2K basis loading

Select the CP2K basis file first. The **Basis name** dropdown should contain
all aliases declared in that file. Save a basis name, reopen the GUI, and
confirm it is still selected.

`BASIS_AUG_MOLOPT` intentionally contains only a small all-electron set. The
dropdown does not mix in aliases from other CP2K basis files because those
aliases would be invalid with the selected `BASIS_SET_FILE_NAME`.

## 4. Check manual grow

Select a CIF, click **Manually grow to new CIF**, choose the output filename,
then select Olex2, Mercury, VESTA, Avogadro, Jmol, or another executable. If
the program is not on `PATH`, locate its executable in the next file selector.

Grow the structure, save the new CIF from the viewer, and close the viewer.
The GUI CIF field should now point to the new grown CIF. The original CIF must
remain unchanged.

## 5. Run automated checks

On Linux or WSL with GTKDialog 0.8.3:

```bash
bash -n lamaGOET.sh GUI_lamaGOET_release.sh RUN_lamaGOET_release.sh
bash Tests/test_gui_cp2k_helpers.sh
bash Tests/test_gui_visibility.sh
bash Tests/test_har_stall_detection.sh
python3 Tests/test_cp2k_cif_alignment.py
DISPLAY=:0 bash Tests/test_gtkdialog_startup.sh
```

The GTKDialog test briefly opens and automatically closes four startup states.
The visibility test checks five initial states in both frontends and verifies
that every SCF radio button updates all conditional panels.

For CP2K, `test_cp2k_cif_alignment.py` also verifies direct atom matching,
correction of an origin-equivalent periodic translation, and rejection of a
genuine non-translational geometry mismatch.

## 6. Check a real Gaussian/Tonto job

Use the GUI on the submitting computer to write `job_options.txt`, then run
`RUN_lamaGOET_release.sh` on the cluster as usual. If the energy repeats or
enters a stable two-cycle oscillation with a small SCF RMSD, the output should
say that the wavefunction stopped changing and should continue to the final
residual-density calculation.

The defaults are:

```text
HAR_ENERGY_REPEAT_TOL = CONVTOLE (or 0.000001 if unset)
HAR_SCF_RMSD_TOL      = 1.0e-7
```

They can be overridden in `job_options.txt` when needed.

## 7. Test the Tonto Fourier optimization separately

Use the companion Tonto `Lolo_CP2K` branch. It preserves a fresh atomic
form-factor calculation at every refinement step and changes only the
innermost Fourier evaluation.

Before comparing timings, use the same executable build type, MPI settings,
number of processes, input files, and reflection/grid settings. Compare the
resulting form factors/refinement output as well as wall-clock time.
