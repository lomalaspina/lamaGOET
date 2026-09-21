# Installation and first calculation

## What lamaGOET installs

lamaGOET provides a PySide6 interface, local and PBS-cluster launchers, input
translation, cycle control, structure visualization, and result collection.
It creates a private Python environment on first launch. It does **not**
install Tonto or licensed/free external electronic-structure programs.

At minimum, install a compatible Tonto executable. Install only the external
programs required for the selected workflow. The practical dependency matrix
is:

| Workflow | Required electronic-structure program |
|---|---|
| Tonto HAR, IAM, molecular XCW, plots | Tonto |
| Gaussian HAR / SCCC | Tonto + Gaussian |
| ORCA HAR / SCCC | Tonto + ORCA |
| OCC HAR | Tonto + OCC |
| ELMOdb HAR | Tonto + ELMOdb; optionally GAMESS-US |
| Crystal23 periodic HAR | Tonto + Crystal23 |
| CP2K periodic HAR | Tonto + all-electron CP2K |
| Periodic XCW | compatible Tonto + Crystal23 |
| CP2K-HAR followed by periodic XCW | Tonto + CP2K + Crystal23 |

## Linux and WSL

From the repository root, run the installer as the ordinary user:

```bash
./install.sh
```

The installer invokes `sudo` only for system packages and desktop integration.
It installs the XCB/Wayland/OpenGL libraries needed by Qt, then creates and
tests `.venv-qt`. On Windows 11, WSLg normally displays the GUI directly. On
Windows 10, configure an X server before launch.

To verify the interface environment without starting a job:

```bash
python3 GUI_lamaGOET_qt.py --check-install
```

## macOS

Install GNU userland tools and a current Python:

```bash
brew install gnu-sed gawk coreutils python
```

Run `lamaGOET_qt.command` from Finder or `bash lamaGOET_qt.sh` from Terminal.
The shell runners deliberately use the GNU variants because BSD `sed` and
`awk` differ in input-rewriting behavior.

## Native Windows

Double-click `lamaGOET_qt.cmd` to prepare a job or submit it to a PBS cluster.
Local refinement is not supported natively because the scientific runners are
Unix shell programs. Use WSL for local execution.

## Launch modes

Run the interface **from the directory that will hold the calculation**:

```bash
cd /path/to/calculation
bash /path/to/lamaGOET/lamaGOET_qt.sh
```

The four public launchers have different responsibilities:

| Launcher | Purpose |
|---|---|
| `lamaGOET_qt.sh` / `.command` / `.cmd` | local GUI; writes `job_options.txt` and runs locally on Unix/WSL |
| `GUI_lamaGOET_qt.sh` / `.command` / `.cmd` | submission GUI; writes `job_options.txt` and a PBS script, then calls `qsub` |
| `lamaGOET.sh --run-job-options FILE` | local non-interactive runner |
| `RUN_lamaGOET_release.sh` | cluster-node runner called by the PBS script |

The two GUIs use the same controls. The cluster form alone shows the
notification-email field. The local launcher never writes a PBS file and the
cluster launcher never starts the HAR on the submitting computer.

## Required starting files

Place or select:

1. a CIF containing the unit cell, space group, atoms, coordinates, and (ideally) ADPs;
2. a reflection file readable by Tonto (ideally 5 collumns) or an fcf file; and
3. if not running a pure IAM refinement: any external basis definition or program-specific
   restart file requested by the chosen workflow.

SHELX fixed-width HKL data can contain adjoining columns. lamaGOET/Tonto input
must delimit `h`, `k`, `l`, intensity (or Fs), and uncertainty unambiguously.
Validate the number of observations and index limits printed by Tonto before accepting
the refinement.

## First controlled run

Use the epoxide teaching data in `examples/1-epoxide`:

1. choose **Tonto**;
2. set RHF/def2-SVP, wavelength 0.71073 Å, MERG 2, and F/σ cutoff 4;
3. select **Start with Tonto IAM**; and
4. press **OK - run locally**.

With the packaged unmerged reflection file, the current control gives IAM
`R(F)=0.035630`, `wR(F²)=0.073136`, 1,313 reflections, and 44 parameters,
followed by HAR `R(F)=0.030272`, `wR(F²)=0.053130`, 1,313 reflections, and
64 parameters. Treat this as an installation check, not a general validation
of a basis or method. The retained calculation behind the older lecture table
used an already merged file and a cutoff of 2; those different preprocessing
choices must not be mixed with the packaged control.

## Before a production calculation

- Verify that the starting geometry refines well for an IAM against the starting hkl
  file, this prevents errors of for example different unit cell setting or hkl in F or I.
- Make sure that the dataset contains chemical information left in the residual density
  map after a regular IAM to justify the need for an improved refinement.
- Complete a chemically meaningful fragment for a molecular calculation.
- Check that the basis is all-electron. For periodic programs it must also be
  numerically suitable for the lattice; all-electron alone is insufficient.
- Record the program versions, executable paths, basis source, integration
  grids, k mesh, reflection preprocessing, and all non-default controls.
- Preserve `job_options.txt`, all cycle directories, the final `.lst`, CIF,
  FCF/FCO, and relevant external-program outputs.
