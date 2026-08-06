# Installing lamaGOET

lamaGOET itself needs almost nothing: Python 3.10 or newer, and — on macOS and
Linux — the GNU command-line tools. The quantum-chemistry programs it drives
are separate and must be installed yourself.

## macOS

```bash
brew install gnu-sed gawk coreutils
```

The shell runners are written for GNU `sed` and `awk`. The BSD versions macOS
ships differ in ways that corrupt the input files Tonto reads rather than
failing outright, so lamaGOET refuses to start without the GNU ones and tells
you this. You do not need to change your `PATH`; it calls `gsed` and `gawk`
directly.

Python 3.10+ from [python.org](https://www.python.org/downloads/) or Homebrew.
Check with `python3 --version` — note that the `/usr/bin/python3` Apple ships
is 3.9, which is too old.

Nothing else to install. Run `lamaGOET_qt.sh`, or double-click
`lamaGOET_qt.command` in Finder. The first launch builds a private Python
environment and takes a few minutes.

`install.sh` is for Debian-family systems only and will refuse to run here.

## Linux (Debian, Ubuntu)

```bash
sudo apt-get update
sudo ./install.sh
```

Safe to run more than once. It installs the GNU tools, Python, the Qt runtime
libraries, and `zenity`; puts the four commands on your `PATH`; and builds the
private Python environment.

If you would rather not use it, the equivalent is:

```bash
sudo apt-get install gawk coreutils sed python3 python3-venv python3-pip
sudo apt-get install libxcb-cursor0 libxkbcommon-x11-0 libegl1 zenity
```

then run `lamaGOET_qt.sh` directly from the checkout.

## Windows

**Through WSL — recommended.** Everything then behaves as on Linux.

```powershell
wsl --install
```

Reboot, open Ubuntu, and follow the Linux instructions above. On Windows 11
WSLg displays Linux windows directly; on Windows 10 you need an X server such
as [VcXsrv](https://sourceforge.net/projects/vcxsrv/) or MobaXterm. (Older lab
notes recommend Xming; WSLg has since made that unnecessary on Windows 11.)

**Natively.** Install Python 3.10+ from python.org with the `py` launcher, then
double-click `lamaGOET_qt.cmd`. You can set jobs up and submit them to a
cluster, but you cannot run a refinement on the machine itself: the runners
need a Unix shell. lamaGOET says so rather than failing halfway.

The Windows paths are not routinely tested.

## Tonto

lamaGOET needs a Tonto that understands the keywords it writes. **Not every
branch does** — see [TONTO_COMPATIBILITY.md](TONTO_COMPATIBILITY.md) for which
to build and how to check.

```bash
git clone --recurse-submodules https://github.com/dylan-jayatilaka/tonto.git
cd tonto
mkdir build && cd build
cmake .. -DCMAKE_Fortran_COMPILER=gfortran -DCOMPILE_LAPACK=ON
make -j
```

Allow about half an hour. Two failures are common:

- `Policy "CMP0110" is not known to this version of CMake` — comment out line 9
  of `CMakeLists.txt`.
- `gfortran: unrecognized command line option '-fallow-invalid-boz'` — delete
  that flag from line 30 of `cmake/SetFortranFlags.cmake`.

lamaGOET finds Tonto by itself in the usual places, so the **Settings** tab is
normally already filled in when you open it. It looks for a build tree
(`~/tonto/release/tonto` and similar) and for an installed copy, and derives
the basis-set directory from wherever it found the binary — beside it, one
level up, or under `share/tonto`. Anything you type yourself is never
overwritten.

If it does not find yours, set both on the **Settings** tab. The two layouts
are:

| | binary | basis sets |
|---|---|---|
| built in place, the usual case | `<tonto>/release/tonto` | `<tonto>/basis_sets` |
| after `make install` | `<prefix>/bin/tonto` | `<prefix>/share/tonto/basis_sets` |

Tonto's README does not mention `make install`, so the first row is what most
people have.

## The other programs

Gaussian, ORCA, OCC, CP2K, Crystal23, ELMOdb and GAMESS-US are all optional and
all installed separately; several need a licence. Give lamaGOET the path to
each on the **Settings** tab. You only need the one you intend to use — the
examples in [../examples/](../examples/) need Tonto alone.

For viewing results, [VESTA](https://jp-minerals.org/vesta/en/download.html)
reads the residual-density cube lamaGOET writes.

## Checking it works

```bash
cd examples/1-epoxide
bash /path/to/lamaGOET/lamaGOET_qt.sh
```

Set the SCF program to Tonto, HF/STO-3G, wavelength 0.71073 Å, F/σ cutoff 4,
tick *Start refinement with a Tonto IAM*, and press OK. It takes about ten
seconds. `my_job.lst` should contain

```
IAM refinement                R(F) 0.035630   44 parameters
```

matching the published figure of 0.0355. If it does, your installation is
sound.
