<!--
Working document for the Qt-only / macOS+Linux cleanup.

Line numbers below are as of commit 2fcd309 and WILL drift as the commits in
this plan land. Treat them as pointers to the right neighbourhood, not as
addresses. The reasoning is the durable part.
-->

# lamaGOET cleanup: Qt-only GUI, macOS+Linux support, honest docs

## Context

lamaGOET is a bash + Qt front end that drives Tonto and QM programs (Gaussian,
ORCA, CP2K, Crystal, ELMOdb, OCC, GAMESS) through iterative Hirshfeld Atom
Refinement. It has accumulated two complete GUIs, two near-identical copies of
the runner, six overlapping documents, and a large amount of dead code. The
repo currently does not work on macOS at all.

The goal: one GUI, one runner story, documentation that tells the truth, and a
verified working install on both macOS and Linux.

Work happens on `macos-qt-fixes` in `~/lamaGOET` (`origin` = the
dylan-jayatilaka fork, `upstream` = lomalaspina). Branch is currently identical
to `cleanup` @ `2fcd309`.

### Decisions already made
1. **Delete the gtkdialog GUI entirely.** Qt becomes the only GUI.
2. **Keep Windows support** (`.cmd` launchers, `os.name == "nt"` paths).
3. **macOS portability via GNU tools from Homebrew** — resolve `$SED`/`$AWK`/
   `$REALPATH` once at startup. Do *not* rewrite to POSIX idioms.
4. **No restructuring of `main_window.py`** — dead code and docstrings only.

Decision 3 matches what the lab notes already prescribe: their Linux install
list includes `coreutils gawk tofrodos`, and the macOS section says to follow
the Linux steps "exchanging `sudo apt-get` by `brew`". Homebrew installs those
as `gsed`/`gawk`/`grealpath`, which is precisely what the shim resolves.

---

## Commit sequence

Each commit leaves the repo working.

### 1. Housekeeping and fossil removal

**Delete:** `.travis.yml` (dead since 2019, `branch: master`, default is now
`cleanup`), `put_cluster.sh` (18 hardcoded personal hostnames, referenced
nowhere), `RUN_tests.sh` (2018 fossil; its only caller was `.travis.yml`, and
its pass/fail check at `:1373` is malformed), `Tests/test.sh` (14-line scratch
loop), `README` (6-line leftover from the deleted `instalation_July19/`).

**`.gitignore`** — add `.DS_Store`, `job_options.txt`, `*.pbs`, `*.lst`,
`DISSBONDS`, `TAILORED`, `gtkdialog-0.8.3*`, and generated CIFs
(`*.latest_tonto.cif`, `*.cartesian.cif2`, `*.fractional.cif1`,
`*.archive.cif`). Several of these are already untracked-dirty in the working
tree from a GUI run.

**`.gitattributes`** — add `*.command text eol=lf` and `*.cmd text eol=crlf`.

### 2. Delete the gtkdialog GUI

**Delete:** `GUI_lamaGOET_release.sh` (2983 lines),
`Tests/test_gtkdialog_startup.sh`, `Tests/test_gui_visibility.sh` (it asserts
against the gtkdialog XML dump and dies with it).

**`lamaGOET.sh`** — remove the gtkdialog XML block (`:5405-7714`, ~2300 lines),
the `gtkdialog` invocations at `:7544` and `:7581`, the
`LAMAGOET_DUMP_GUI_XML` hook at `:7481`, and the `SPACEGROUPMENU` block
(`:1226-1837`) that exists only to feed the XML. Keep `--run-job-options`
(`:401-403`, `:7487-7495`) — that is the Qt contract — and all runner
functions. The file drops from 7714 to roughly 4800 lines and becomes
"CP2K backend + runner + CLI", with no GUI.

**Also remove** the now-unreachable `zenity` calls at `:1823`, `:1832`,
`:7595`, `:7615`, `:7617`, `:7699`, and the `MAIN_DIALOG` unsets (33 in
`RUN_lamaGOET_release.sh`) which were always gtkdialog residue in a headless
runner.

**`install.sh`** — drop the entire gtkdialog build (`:4-6`, `:14-27`), which
also removes the dangling `gtkdialog_pre_compiled` symlink bug. Repoint the
`lamaGOET` command at the Qt GUI, not the shell GUI: the lab notes teach users
to type `lamaGOET`, and that must keep working. Add `-f` to every `ln -s` so
re-running is idempotent (this is the real answer to the "run it twice"
folklore). Keep the closing `GUI_lamaGOET_qt.py --setup-only`.

### 3. macOS portability

**New file `lamagoet_portable.sh`**, sourced as the first statement of both
`lamaGOET.sh` and `RUN_lamaGOET_release.sh`. It:
- resolves `SED`, `AWK`, `REALPATH` — preferring `gsed`/`gawk`/`grealpath`,
  falling back to `sed`/`awk`/`realpath` only when those are GNU (probe with
  `sed --version 2>/dev/null | grep -q GNU`);
- exports them so subshells inherit;
- on failure prints one actionable message naming the platform's fix
  (`brew install gnu-sed gawk coreutils` / `sudo apt-get install gawk
  coreutils`) and exits non-zero rather than corrupting files silently.

**Mechanical substitution** across both runners: `sed ` → `"$SED" `,
`gawk ` → `"$AWK" `, `realpath` → `"$REALPATH"`. This covers the 63 + 61
`sed -i` sites, the GNU-only `1~3p` step addresses (`lamaGOET.sh:2527`,
`:3894`), the `i\`/`a\` one-liners (`:4657-4670`), `sed -n -i` (`:7500`), the
18 `gawk` sites, `awk -n` (`:2012`), and `realpath -m` (`:439`). Because GNU
tools are then guaranteed on both platforms, semantics stay identical — no
behavioural risk from rewriting idioms.

**`${var^^}` / `${var,,}`** — 11 sites (`lamaGOET.sh:65,67,322,482,491,530,
543,639,656,674,948`). macOS ships bash 3.2, where these are a hard
`bad substitution`. Verified failure: `lamaGOET.sh --list-cp2k-functionals PBE`
errors, falls through the `case` at `:381`, and tries to launch the GUI.
Replace with `$(printf '%s' "$var" | tr '[:lower:]' '[:upper:]')`. Add a
`case` fallthrough guard at `:381` so an unrecognised CLI flag exits with a
usage error instead of silently opening a GUI.

**`todos`** (`:2260-2261`, Debian tofrodos) — replace with a portable
`tr -d '\r'` or `$SED -e 's/$/\r/'`; there is no Homebrew `tofrodos`.

**Python** — `main_window.py:_choose_executable` (`:2305`) and
`_choose_directory` (`:2315`) pass `QFileDialog.Option.DontUseNativeDialog`,
so `/usr/local/bin`-style paths are reachable on macOS. (This is the Browse-
button problem; confirm first with ⌘⇧. in the native dialog.) Add
`/opt/homebrew/share/cp2k/data` and `/usr/local/Cellar` to
`_guess_cp2k_basis_file` (`:1353-1383`). Fix `kill_job` (`:2330-2340`) to
escalate `SIGTERM` → `SIGKILL` and `waitpid`, so the "already running" guard
at `:2064` cannot be fooled by a zombie.

### 4. Dead code

**Remove never-called functions:** `ATOMIC_NUMBERS()`
(`lamaGOET.sh:1838-1963`, 126 lines), `CHECKCONV()` (`:4064`), `SET_H_ISO()`
(`:3035`), `COMPLETECELLBLOCK()` (`:4571`), `REDUCECELLCLUSTER()` (`:4583`),
and the same four in `RUN_lamaGOET_release.sh` (`:2130`, `:1119`, `:2624`,
`:2636`).

**Remove the 102 `########`-prefixed commented-out code blocks** in each
runner (the same block copy-pasted six times) and the commented-out awk
pipelines at `lamaGOET.sh:2242-2253`, `RUN_lamaGOET_release.sh:326-335`.

**Powder/Jana:** `RUN_JANA()` (`:2257`) unconditionally calls
`/usr/local/bin/powderHARcifrewrite.py`, and `:4619-4620` calls
`powderHARstart.py`. Neither file exists on any branch, so this path is
broken at runtime today. Do not silently delete a scientific feature — make
it fail loudly with a clear "powder HAR requires powderHARstart.py, which is
not distributed with this repository" message, and record it in the docs as
unsupported. Ask before removing outright.

**`Crystal23` vs `Crystal14`:** the GUI labels the backend Crystal23 but
writes the value `Crystal14` (`lamaGOET.sh:5839-5841`), and every downstream
branch compares `"Crystal14"`. Leave the wire value alone — changing it would
break every saved `job_options.txt` — but document it in CLAUDE.md as a
deliberate trap.

### 5. Fix the duplication drift

`RUN_lamaGOET_release.sh` is ~95% identical to `lamaGOET.sh:1965-4600` (only
133 of ~2630 lines differ), and the copies have drifted apart with real
consequences:

- `RUN_lamaGOET_release.sh:1230` and `:1265` still read
  `[[ ... && "$DEFRAGNETW"=="true" ]]` — a missing space makes this a
  non-empty-string test, so it is **always true on the cluster runner**.
  Commit `f84a94c` fixed this in `lamaGOET.sh:3146`/`:3181` only.
- `SCFCALCPROG != "CP2K"` guards at `lamaGOET.sh:2791,2799,3041,3347,3364`
  are missing from `RUN_lamaGOET_release.sh:825,833,1075,1375,1392`.

**Recommendation: fix the drift, do not deduplicate yet.** Extracting 2600
lines of shared shell into a sourced library is the correct long-term fix, but
this code is untested and runs multi-hour refinements; a sourcing error would
surface only mid-run. Fix the two concrete divergences now, then add a
`Tests/test_runner_parity.py` that diffs the shared region and *fails* when the
two copies diverge outside a known-differences allowlist. That converts silent
drift into a red test, and makes a later deduplication safe. Flag deduplication
as a follow-up.

### 6. Documentation

Collapse six overlapping documents into four with clear audiences:

| File | Audience | Contents |
|---|---|---|
| `README.md` | user | What lamaGOET is, the HAR concept in a paragraph, install per OS, "run your first job", pointer to the others. Rewritten from scratch — the current file is accumulated release notes that contradict themselves. |
| `INSTALL.md` | user | macOS (Homebrew, incl. `gnu-sed gawk coreutils`), Linux/WSL (apt), Windows (WSL). Tonto build steps and the two known CMake/gfortran failures, lifted from the lab notes. What `install.sh` does and does not do. |
| `docs/HOW_IT_WORKS.md` | developer | The architecture: Qt GUI → `job_options.txt` → `lamaGOET.sh --run-job-options`; the complete-schema contract from `options_schema.py:1-8`; the module map; the cluster/PBS path; backend dispatch table. |
| `docs/TESTING.md` | developer | The Python and shell suites, how to run each, and the end-to-end epoxide/NH3 regression below. |

**Delete after merging their live content:** `QT_GUI_TESTING.md`,
`TESTING_cleanup.md`, `RELEASE_NOTES_cleanup.md`,
`Tonto_Lolo_CP2K_TESTING.md` (it documents a *different repo* and cites a
`benchmark_c23_fourier_kernel.f90` that does not exist — move the substance
upstream to Tonto or into `docs/HOW_IT_WORKS.md` as a short note).

Correct while rewriting: no `instalation_July19/` or `git checkout periodic`
(the lab notes still say this); no `install_all_you_need.sh` (does not exist);
mention the LICENSE; document the `bootstrap.py:41-58` user-level venv
fallback (`~/Library/Application Support/lamaGOET` on macOS); document that
`install.sh`'s symlinks are what create the `RUN_lamaGOET` command the PBS
script depends on.

Also fix `lamaGOET.sh:551`, which still stamps generated files with
`! Generated directly by instalation_July19/lamaGOET.sh`.

### 7. Worked examples from the lab notes

The six example datasets are in a public Drive folder (listing confirmed):
`1-epoxide`, `2-NH3`, `3-Urea`, `4-GlyAla`, `5-L-ala`, `6-DWGN`.

Fetch with `gdown --folder <url>` (pip, handles public folders). Land them in
`examples/`, **not** `Tests/` — the user's framing is right, they are worked
examples rather than tests, and `examples/README.md` should say so and carry
the reference table from the lab notes.

Check total size before committing. If it exceeds ~50 MB, use Git LFS or
attach them to a GitHub release instead of committing blobs — this repo is
already 7.9 MB and the fork is public. Decide once the download size is known.

### 8. CLAUDE.md

Written for an agent landing in this repo cold. Must state:

- **The `job_options.txt` contract is load-bearing.** Every one of the ~170
  keys in `options_schema.py` must be written on every save, because the shell
  tests `[[ "$VALUE" == "false" ]]` and an absent key is not `false`.
- **There are two copies of the runner** (`lamaGOET.sh` and
  `RUN_lamaGOET_release.sh`, ~95% identical). A fix to one almost always
  belongs in the other. `Tests/test_runner_parity.py` enforces this.
- **GNU tools are required.** Use `$SED`/`$AWK`/`$REALPATH`, never bare
  `sed`/`awk`. Never add a bash-4 construct — macOS ships bash 3.2.
- **`Crystal23` in the UI is `Crystal14` on the wire.** Do not "fix" it.
- **Do not restructure `main_window.py`** without asking.
- How to run the tests; that `.venv-qt` is generated, not source.
- Powder/Jana is unsupported (missing scripts).

---

## Verification

**Verification does not go through the GUI, so deleting the old GUI does not
invalidate the lab notes.** Both GUIs are only editors for `job_options.txt`;
the runner reads that file and nothing else. Confirmed: the captured
`Tests/inputs/nh3-Tonto/job_options.txt` is old-GUI output, and the Qt schema
in `options_schema.py` already covers 48 of its 52 keys. The notes' screenshots
go stale; their *numbers* and *job semantics* do not.

(Four keys in that file are absent from the Qt schema — `COMPLETECIF` has a
documented legacy alias to `COMPLETESTRUCT`, but `BASISSET`, `LAMBDA` and
`TESTS` need checking: if the runner reads them, the Qt GUI has a real gap.)

**Tonto is already built on this machine** — ten binaries, including the macOS
build at `/Users/dylan/tonto.antlr4.mac/release/tonto`. Examples 1–3 (epoxide,
NH3, urea) use Tonto only, per the notes, so full end-to-end verification is
achievable here without Gaussian, ORCA or CP2K.

The lab notes (`2024_Malaspina_lab_notes.pdf`, now in the repo root) provide
published reference values, and `Tests/inputs/` already holds golden
`my_job.lst` / `my_job.archive.cif` outputs. Together these give a real
end-to-end check rather than a smoke test.

**Static / unit — both platforms, no chemistry software needed:**
```bash
cd ~/lamaGOET
bash -n lamaGOET.sh RUN_lamaGOET_release.sh install.sh    # bash 3.2 parse
python3 -m unittest discover -s Tests -p 'test_*.py' -v
bash Tests/test_gui_cp2k_helpers.sh                        # currently fails on macOS
bash Tests/test_har_stall_detection.sh
bash Tests/test_live_cif_publish.sh
```
`test_gui_cp2k_helpers.sh` failing on macOS today, and passing after commit 3,
is the single clearest proof the portability work landed.

**GUI — offscreen, no display needed:**
```bash
.venv-qt/bin/python -m unittest Tests.test_qt_gui_smoke -v
QT_QPA_PLATFORM=offscreen .venv-qt/bin/python GUI_lamaGOET_qt.py --setup-only
```
Plus the manual check that started this work: open the Settings tab, click
Browse for the Tonto executable, and confirm `/usr/local/bin` is now reachable.

**End-to-end HAR — drive it headlessly, no GUI involved:**
```bash
export PATH=/Users/dylan/tonto.antlr4.mac/release:$PATH
cd examples/2-NH3          # or a copy of Tests/inputs/nh3-Tonto
bash ~/lamaGOET/lamaGOET.sh --run-job-options ./job_options.txt
grep 'R(F)' my_job.lst
```
This is the same code path the Qt GUI's **OK** button takes
(`main_window.py:2066-2081`). Run the NH3 example and the epoxide example from
the notes (Tonto, HF/STO-3G, cutoff 4, λ=0.71073, no cluster charges, start
from Tonto IAM). Assert against:

| Case | Reference | Source |
|---|---|---|
| NH3 Tonto | `R(F) = 0.027232` | `Tests/inputs/nh3-Tonto/my_job.lst` |
| Epoxide Tonto IAM, STO-3G | `R(F) 0.0355`, `wR(F²) 0.0725`, `ρmax 0.220`, `ρmin -0.225`, 1308 refl, 44 param | lab notes p.19 |
| Epoxide SHELX IAM baseline | `R(F) 0.0353`, `wR(F²) 0.0964` | lab notes p.18 |

Expected runtime per the notes: epoxide HAR ~30 s, with SCCC ~50 s. Results
land in `<jobname>.lst`.

Run the same on Linux (or WSL) to confirm both platforms agree.

---

## Deferred / not attempted

- **Deduplicating the two runners.** Correct, but too risky against untested
  shell that runs multi-hour jobs. The parity test in commit 5 is the
  prerequisite.
- **Refactoring `main_window.py`** — explicitly excluded by decision 4. The
  `load_options`/`_current_values` pair (~480 lines mapping 170 keys twice)
  remains the largest bug surface in the Python; worth revisiting later.
- **Removing the powder/Jana path** — needs your call, since it is a science
  feature that is merely missing its scripts rather than genuinely dead.
- **CI.** There is none. Adding a GitHub Actions workflow running the Python
  suite on macOS and Ubuntu would be cheap and high value, but it is additive
  and can follow.
- **Real-GUI screenshot verification** is blocked until iTerm has Screen
  Recording permission; offscreen `grab()` covers everything except native
  macOS file dialogs.
- **Rewriting the lab notes for the Qt GUI.** The PDF's field-by-field
  screenshots show the gtkdialog GUI and will not match Qt after this work.
  Replacing them is a separate documentation project; the numbers stay valid
  meanwhile. Worth doing eventually, out of scope here.
