# Troubleshooting

Diagnose the earliest failed layer. A Tonto error caused by malformed external
input cannot be repaired by changing the final refinement threshold, and a Qt
platform failure occurs before any scientific input is read.

## Collect a minimal diagnostic bundle

Before changing settings, copy rather than edit the failing directory and
retain:

```text
job_options.txt
JOBNAME.lst
stdin and stdout
the first failing external-program input and output
JOBNAME.archive.cif and JOBNAME.archive.fcf, if present
the original CIF and reflection file
```

Also record:

```bash
git -C /path/to/lamaGOET rev-parse HEAD
/path/to/tonto --version 2>&1 || true
python3 --version
```

For a periodic failure, add GRED/KRED or CP2K native matrix/orbital files and
the exact program revision. Do not delete the first failing cycle; later
cycles may have overwritten the evidence.

## The GUI does not open

Run the launcher from a terminal:

```bash
bash /path/to/lamaGOET/lamaGOET_qt.sh
```

### WSL: Wayland/xcb platform errors

Messages such as `Failed to create wl_display`, `Could not load the Qt
platform plugin "wayland"`, or an xcb-cursor requirement indicate a display or
system-library problem, not a CIF problem. Re-run `install.sh`; it installs the
documented Qt/X11/Wayland runtime packages on supported Debian/Ubuntu systems.
Then shut WSL down from PowerShell and restart it:

```powershell
wsl --shutdown
```

Do not permanently set `QT_QPA_PLATFORM=offscreen` for interactive use; that
mode is for tests and intentionally shows no window. If the problem remains,
capture the complete launcher output and the values of `DISPLAY`,
`WAYLAND_DISPLAY`, and `XDG_RUNTIME_DIR` without altering them.

### The window is present only as `[WARN:COPY MODE]`

Windows Terminal copy mode can intercept keyboard/mouse input and make the
window appear unresponsive. Press `Esc` in the terminal, then activate the Qt
window. A persistent non-maximizable preview is usually a WSL window-manager
integration problem. Restart WSL and use the repository launcher, which sets
the application metadata before constructing the main window.

### Penguin rather than lamaGOET taskbar icon

The window icon and the Windows taskbar application identity are separate in
WSLg. Re-run `install.sh`, confirm that the generated desktop entry and icon
exist, shut WSL down completely, and launch through `lamaGOET_qt.sh`. If the
penguin persists, report the Windows and WSLg versions; a correct Qt window
icon cannot force grouping behavior in every WSLg release.

### Missing Python packages

Do not activate a virtual environment manually for normal use. The launcher
creates/updates `.venv-qt` and installs `requirements-qt.txt`. To repair it:

```bash
cd /path/to/lamaGOET
rm -rf .venv-qt   # only this repository-local environment
bash install.sh
```

Preserve your calculation directory; the environment is disposable, the job
outputs are not.

## The GUI starts with the wrong panel

With no `job_options.txt`, the default SCF program is Gaussian and the radio
selection and dependent panels should be refreshed together. If a different
panel appears, check for a hidden/stale `job_options.txt` in the current
working directory. Move it aside and start again. When a file exists, its
`SCFCALCPROG` value deliberately overrides the default.

The GUI writes every canonical option, including values for currently hidden
controls, because the runner's conditionals require a complete contract.
Missing variables indicate an outdated GUI/runner pair.

## Shell errors or no visible output

### DOS line endings

An error containing `$'\r'` or a syntax error on apparently valid lines means
the script has CRLF line endings. A normal Git checkout should preserve the
repository's LF policy. For a copied file only:

```bash
sed -i 's/\r$//' copied_script.sh
```

Do not mass-rewrite scientific input files without checking their format.

### `fort.7` contains a GNU-option error

`Error in COMMAND_LINE:process_options ... use '--v' instead of '-v'` comes
from invoking Tonto's option parser with a legacy short flag. Current
lamaGOET probes use GNU long options and redirect diagnostic probes away from
the job directory. If it recurs, search the exact installed launcher and any
local wrapper for `tonto -v`; do not merely delete `fort.7` and ignore the
underlying call.

### `ls: No match.`

This often comes from an external vendor wrapper using csh-style globbing.
It may be harmless if the external output is complete, but it must not mask a
nonzero exit or missing density file. Inspect the program output and the
first explicit `ERROR` in `JOBNAME.lst`.

## Reflection-file problems

### Fixed-width SHELX columns run together

SHELX HKL files may place the `l` index and intensity in adjoining fixed-width
columns. Tonto's whitespace reader cannot infer the boundary from a joined
token. Preserve the source file and create a converted copy with explicit
separation. Confirm the observation count, index extrema, negative
intensities, and standard uncertainties before use.

### Unexpected reflection count or 222 retained in Diamond

The order is:

1. start from the immutable unmerged measurements;
2. apply the weak-observation cut to individual measurements;
3. merge according to the selected MERG rule;
4. prune systematic/model-zero reflections using the model appropriate to
   that stage.

For IAM, pruning must use IAM calculated factors. For an aspherical partition,
it must use the new aspherical factors and repeat after every new partition so
a reflection can leave or re-enter. The final residual calculation repeats
the same lifecycle. Compare `stdout` counts at every stage rather than only
the final FCF row count.

## Basis-set and method failures

### `gen` is treated as a Tonto basis name

`GEN` tells Gaussian/Crystal23 that an external block follows; it is not a
basis available under `tonto/basis_sets`. The runner must carry the external
basis definition or exact paired Tonto sidecar into every consumer, including
periodic TREXIO export. Update both lamaGOET and the compatible Tonto if an
export log says `could not find basis 'gen'`.

### Gaussian external basis crashes

Gaussian's general-basis block must have no blank line between element blocks
and exactly one final `****` terminator after the last element. lamaGOET
normalizes Basis Set Exchange output to that form. Inspect the generated input
if it was edited or produced by an older release.

### Crystal23 `UNIT CELL NOT NEUTRAL`

An all-electron Crystal23 external basis requires a formal shell charge
(`CHE`) distribution whose sum equals the element's electron count. A raw
Gaussian-format Basis Set Exchange block supplies exponents/contractions but
not this Crystal23 bookkeeping. Use the lamaGOET converter and inspect the
shell headers; never repair neutrality by changing the physical cell charge.

### Crystal23 `BASIS SET LINEARLY DEPENDENT`

This is a numerical property of the periodic overlap matrix, not necessarily
a formatting error. Check, in order:

1. no shell or element block is duplicated and only one final `99 0` exists;
2. separate S and P contractions have not been incorrectly converted to an SP
   shell (or vice versa);
3. `CHE` totals and atom/basis ordering are correct;
4. the intended `TOLINTEG`/auto policy was actually written;
5. the basis is appropriate for a periodic solid.

If `auto` and a documented screening set both fail, use a periodic-optimized
basis or remove the genuinely diffuse/dependent function only with a recorded
overlap-eigenvalue analysis. Tightening thresholds is not guaranteed to cure
a physically redundant basis.

### Gaussian PBE names and Tonto functionals

Gaussian route names `PBEPBE`, `uPBEPBE`, `PBE1PBE`, and `uPBE1PBE` map to
restricted/unrestricted PBE and PBE0 cases. They must not silently map to the
B3LYP exchange/correlation pair in Tonto. Use a current options schema and
runner; inspect both the Gaussian route and generated Tonto `kind`, exchange,
and correlation keywords.

## Periodic interface failures

### Crystal23 GRED/KRED

GRED contains the exact retained direct-lattice density anchor used by
periodic HAR. KRED contains complex Bloch orbitals used by periodic XCW. A
finite k mesh does not make a KRED-only inverse transform identical to GRED;
do not substitute one for the other. The files must come from the same cell,
basis, k mesh, spin state, and converged calculation.

At λ = 0, require agreement with the static reference before attempting XCW.
A different AO count, overlap, cell transform, or orbital phase convention is
a hard failure, not a reason to relax the XCW convergence threshold.

### CP2K native interface

The native path requires all of the following from the same CP2K run:

- exact MOKP basis/orbital data;
- direct-lattice density and overlap matrices;
- KS/Fock matrix data;
- k points, weights, translations, cell, atom labels, and basis ordering.

Missing KS/Fock input must stop the native path. It must not silently use an
occupied-only approximation or fall back to XML. Use **Legacy XML bridge**
explicitly when reproducing an older calculation.

### `A cif atom is not found among the XML atoms`

The external density and crystallographic structure disagree in labels,
ordering, symmetry expansion, or cell setting. Compare atomic numbers and
Cartesian coordinates after the explicit cell transformation; do not solve
this by pairing atoms only by row number. Diamond and other primitive-cell
conversions require mapping back to the crystallographic cell before Tonto
fits the experimental model.

## Crystal23 execution problems

### MPI wrapper reports usage

Crystal23 serial and parallel wrappers have different argument conventions.
The runner uses the configured `runcry23`/`runprop23` utilities and supplies
processor counts in the vendor-supported form. Do not prepend a second
`mpirun` to a wrapper that already launches MPI. Capture `JOBNAME.out` and the
wrapper path if the installed vendor distribution differs.

### `ILA DIMENSION EXCEEDED` despite `ILASIZE` in `.d12`

`ILASIZE` and `BIPOSIZE` are runtime/storage controls understood only in the
correct Crystal23 input section and only up to limits compiled into the
executable. Confirm that the output echoes the requested values. If it still
reports a larger required `ILASIZE`, the input value is insufficient or the
binary's compile-time maximum is lower; changing lamaGOET cannot enlarge a
vendor binary.

Crystal23 wrapper chatter is redirected to the external output so the terminal
continues to show the high-level `Running Crystal, cycle number J` progress.

## Refinement does not stop

A cycle can oscillate because a CIF writes fewer digits than the internal
geometry. Current stall detection compares normalized geometries and detects a
two-cycle repeat in addition to the ordinary maximum shift/e.s.d. threshold.
Never stop solely because two printed CIFs look identical: confirm energy,
wavefunction, scale/extinction, and full-precision parameter behavior. A stall
stop proceeds to the final residual calculation and is recorded in the
listing.

## Tonto build failures

### Build is killed near 47% / exit 137

Exit 137 normally means the operating system killed a memory-intensive Foo
generation or compilation process. Reduce parallelism before changing source:

```bash
cmake .. -DCMAKE_Fortran_COMPILER=gfortran-14 \
  -DCMAKE_BUILD_TYPE=release
make -j1
```

Then increase to `-j2` or `-j4` only if memory permits. A faster CMake version
does not reduce compiler memory use.

### Missing `external/dftd3-lib/lib/api.f90`

The source checkout lacks a required submodule. From the Tonto repository:

```bash
git submodule update --init --recursive
```

Do not create an empty file or remove the target; that yields an incomplete
scientific executable.

### CMake compatibility error in an external project

For an old bundled project with `cmake_minimum_required` below the policy
floor, first use the compatibility option recommended by CMake for that
checkout. Do not globally rewrite separators or generated Foo syntax: such a
change can alter every contributor's build. Record any local policy override
in the build provenance.

## Clone fails on Windows with `invalid path`

Older repository history contains a Unix filename with Windows-reserved
characters under a bundled gtkdialog tree. The current `cleanup` tip must not
track such names. If a fresh clone still fails, record the exact offending
path and commit, then test with:

```powershell
git clone --no-checkout https://github.com/lomalaspina/lamaGOET.git
cd lamaGOET
git checkout cleanup
```

Do not delete unrelated current files to fix a historical path. Repair the
smallest tracked offending path while preserving the working GUI and runners,
then verify a clean Windows checkout.

## Escalation checklist

When reporting a problem, state:

- the first failing command and its exit status;
- the first scientific/program error, not only the runner's final summary;
- whether the failure reproduces in a fresh copied directory;
- whether it is GUI-only or also occurs with `--run-job-options`;
- whether the native and legacy periodic paths agree for the same input;
- exact revisions and all relevant files from the diagnostic bundle.

This is enough to distinguish presentation, orchestration, external-program,
format, and scientific-model failures without guessing.
