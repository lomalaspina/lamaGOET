# lamaGOET

lamaGOET runs **Hirshfeld Atom Refinement** (HAR): a crystal structure
refinement in which the atomic scattering factors are computed from a quantum
chemical calculation on the actual molecule, rather than looked up in a table
for isolated spherical atoms.

That difference matters most for hydrogen. A table-based refinement puts H
atoms at the maximum of their electron density, which sits inside the bond, so
X–H distances come out systematically too short. HAR places them where the
nucleus actually is, close to what neutron diffraction gives.

lamaGOET is the piece that drives the loop: it prepares input for a
quantum-chemistry program, feeds the resulting density to
[Tonto](https://github.com/dylan-jayatilaka/tonto) for the partitioning and the
least-squares refinement, and repeats until the geometry stops changing.

## What you need

**Always:** Tonto, and Python 3.10 or newer for the interface.

**One of these** for the wavefunction, depending on what you are doing:
Tonto itself, Gaussian, ORCA, OCC, CP2K, Crystal23, ELMOdb or GAMESS-US.

lamaGOET does not install these; see [docs/INSTALL.md](docs/INSTALL.md).

## Getting started

```bash
cd /the/directory/holding/your/cif/and/hkl
bash /path/to/lamaGOET/lamaGOET_qt.sh
```

Fill in the form, press **OK**, and the refinement runs in that directory.
Results collect in `<job name>.lst`.

There are worked examples with published reference numbers in
[examples/](examples/) — start with `1-epoxide`, which needs only Tonto and
takes about ten seconds.

## The four commands

| Command | What it does |
|---|---|
| `lamaGOET_qt.sh` | set a job up and run it on this computer |
| `GUI_lamaGOET_qt.sh` | set a job up and submit it to a PBS cluster |
| `lamaGOET` | run the `job_options.txt` in the current directory |
| `RUN_lamaGOET` | what a cluster node runs; you do not call this yourself |

On Windows use the `.cmd` files; on macOS you can double-click the `.command`
files from Finder.

The interface and the runners communicate through a single plain-text file,
`job_options.txt`. You can edit it by hand and run `lamaGOET` without opening
the interface at all, which is what the examples and the tests do.

## Supported platforms

| | Set up a job | Run it here | Submit to a cluster |
|---|---|---|---|
| **Linux** | yes | yes | yes |
| **macOS** | yes | yes, with GNU tools from Homebrew | yes |
| **WSL** | yes | yes | yes |
| **Windows, natively** | yes | no — use WSL | yes |

Native Windows cannot run a refinement locally because the runners need a Unix
shell. Everything else works. The Windows paths are not routinely tested.

## Growing the structure first

HAR runs a quantum chemical calculation on the molecule, so it needs a
chemically complete one. If your asymmetric unit holds only part of a molecule
— a third of NH₃, a quarter of urea — you must complete it first, or the
calculation is meaningless.

Two ways, and they are not the same thing:

- **Tick "Complete molecule(s) in the CIF with Tonto".** Tonto does the
  completion during the run. This is the one that affects the refinement.
- **Choose a grow mode beside the structure view and press Apply.** The
  interface does the completion itself, for the picture and for exporting a
  starting geometry. Pressing *Export* without pressing *Apply* first writes
  the structure out unchanged; the interface warns you if you try.

## Documentation

| | |
|---|---|
| [docs/WORKSHOP.md](docs/WORKSHOP.md) | a guided introduction, with two worked examples |
| [docs/INSTALL.md](docs/INSTALL.md) | prerequisites and installation, per platform |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | how the pieces fit together |
| [docs/TESTING.md](docs/TESTING.md) | running the tests |
| [docs/TONTO_COMPATIBILITY.md](docs/TONTO_COMPATIBILITY.md) | which Tonto to build, and what has changed |
| [docs/CRYSTAL23_BSE_FORMAT_AUDIT_20260905.md](docs/CRYSTAL23_BSE_FORMAT_AUDIT_20260905.md) | CRYSTAL23 external-basis format, overlap diagnosis and `TOLINTEG` handling |
| [docs/PERIODIC_WAVEFUNCTION_EXPORT.md](docs/PERIODIC_WAVEFUNCTION_EXPORT.md) | exact CP2K/Crystal23 TREXIO export and finite `.47`/WFN/WFX cluster recalculation |
| [docs/HIRSHFELD_ATOM_CUBES.md](docs/HIRSHFELD_ATOM_CUBES.md) | per-independent-atom density cubes from the live Hirshfeld partition |
| [docs/OBSERVED_DENSITY_RECONSTRUCTION.md](docs/OBSERVED_DENSITY_RECONSTRUCTION.md) | ADP-aware constrained observed-density reconstruction and its legacy alternative |
| [docs/PERIODIC_XCW.md](docs/PERIODIC_XCW.md) | fixed-geometry periodic XCW and sequential HAR+XCW (XWR) |
| [CLAUDE.md](CLAUDE.md) | what to know before changing the code |
| [examples/](examples/) | worked examples with published numbers |

## Credit and licence

lamaGOET was written by Lorraine Andrade Malaspina. The method is described in
Capelli, Bürgi, Dittrich, Grabowsky and Jayatilaka, *IUCrJ* **2014**, *1*,
361–379.

Licensed under the terms in [LICENSE](LICENSE).
