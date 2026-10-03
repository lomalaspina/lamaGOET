# Validation and development tests

This appendix separates tests by evidential strength. A parser unit test, a
matched numerical import test, and a publication-grade scientific validation
answer different questions and must not be reported as if they were the same.

## Evidence policy

**Current automated test**
: Executed against the documented lamaGOET working tree during preparation of
  this manual.

**Retained numerical validation**
: Inputs, outputs, comparison scripts, and a dated report exist in the local
  development archive. The number is quoted from that report; it was not
  silently rerun while building this manual.

**Historical archive regression**
: Final artifacts from the former lamaGOET test driver are checked for
  integrity and exact recorded values. This detects loss or accidental
  rewriting but is not a current electronic-structure run.

**Publication gate**
: A test still required before making a general scientific claim.

Transient exploratory runs with no retained input/output/provenance are not
converted into validation claims. The tables below include the auditable
development tests relevant to the present interfaces.

## Current lamaGOET suite

On 27 September 2026, `bash Tests/run_all.sh` completed **30 test files: 30
passed, 0 failed, 0 skipped** on Linux x86-64, Bash 5.2.21, using the
repository `.venv-qt` Python. The suite included six shell tests and
twenty-four Python tests.

### Why these tests exist

| Test family | Risk addressed | Acceptance criterion |
|---|---|---|
| Shell parsing and portability | A Bash-4-only construct or malformed branch breaks macOS/Linux runners before science begins | Both runners parse; prohibited constructs absent |
| Runner parity/regressions | Local and cluster runners silently generate different scientific inputs | Contract assertions pass in both runners |
| Qt job options and GUI smoke | Hidden/default controls disappear from `job_options.txt`, or the widget tree cannot construct | All canonical options round-trip; offscreen window constructs |
| Crystal23 parallel/TOLINTEG | Vendor wrapper invocation or basis-screening policy is malformed | Synthetic serial/parallel inputs and dispatch match the contract |
| CP2K geometry/native interface | CIF/CP2K atom mapping or native file requirements drift | Alignment and fail-closed interface tests pass |
| Basis Set Exchange | Program-specific terminators, Crystal23 shell charges/order, or lookup behavior regress | Format and conversion fixtures match their consumers |
| Periodic/finite wavefunction export | `GEN` is mistaken for a Tonto basis, or periodic and finite outputs are conflated | Export preconditions, metadata, and explicit boundaries pass |
| Scientific archive integrity | Historical cases or expected numbers are silently deleted/rewritten | All ten case directories and exact CIF scalars match the manifest |
| Documentation option contract | A GUI/schema option is added without a manual definition | All 225 canonical `OPTION_DEFAULTS` keys occur in the option reference |

The suite does not invoke licensed programs and does not prove numerical
equivalence of a fresh HAR. Live scientific calculations remain opt-in.

### Live external-basis and relativistic acceptance

On 24 September 2026, the opt-in command
`LAMAGOET_RUN_LIVE_SCF_TESTS=1 .venv-qt/bin/python -m unittest -v
Tests.test_live_external_basis` completed **6/6** executable tests.
Every job ran in a temporary directory; the retained KHMAL inputs were read
but not modified.

| Consumer | Input/contract exercised | Observed acceptance |
|---|---|---|
| Gaussian 09 | H2O RHF with BSE `def2-TZVP`, `6D 10F FChk` | Normal termination; positive Cartesian shell types written; Tonto FChk import completed |
| Gaussian 09 | H2, RHF, BSE `cc-pVDZ-DK`, `int=dkh` | Normal termination and explicit `Using DK2 one-electron Hamiltonian` marker |
| ORCA 5.0.4 | KHMAL PBE with per-element BSE `jorge-TZP` rendered as `%basis` / `NewGTO` | Full SCF terminated normally; no legacy `$DATA` parser error |
| OCC | KHMAL PBE, charge 5, multiplicity 1, `--spherical`, mixed BSE JSON | Full 554-spherical-function SCF completed; final energy −4051.659551024744 hartree; formatted checkpoint written and imported by Tonto |
| Tonto | H2 RHF/STO-3G from generated native `basis_gen` library | SCF completed; final energy −1.116759 hartree |
| Tonto relativistic guard | H2 with `relativity_kind=dkh` | Explicitly rejected before SCF; no silent nonrelativistic fallback |

These are executable acceptance checks of input rendering and dispatch. They
do not validate every basis in Basis Set Exchange, establish periodic
conditioning, or replace a relativistic molecular benchmark. A separate
formatter sweep confirmed that H, C, N and Si expose `def2-TZVP` and
`jorge-TZP` through every supported Gaussian, ORCA, Crystal23, CP2K, OCC and
Tonto export path; the GUI still filters all displayed choices through the
selected exporter.

The external-basis provenance is the published [Basis Set Exchange data
model](https://doi.org/10.1021/acs.jcim.9b00725). The DKH smoke case exercises
the Douglas--Kroll--Hess family ([Douglas and Kroll,
1974](https://doi.org/10.1016/0003-4916(74)90333-9); [Hess,
1986](https://doi.org/10.1103/PhysRevA.33.3742)); it is not a benchmark of
relativistic energies or properties.

The common FChk reader was also replayed against the retained real
L-alanine ELMOdb checkpoint.  Its 76 shell records use positive Cartesian
types, contain 156 basis functions, and were imported successfully by the
current Tonto executable.  ELMOdb remains deliberately outside the BSE menu;
this check validates its existing checkpoint interchange, not a new external
basis contract.

### Spherical external-wavefunction final exports

The ORCA Molden regression also exercises the final `.47`, `.wfn`, and `.wfx`
writers with a def2-TZVP water wavefunction.  Tonto retains 43 pure-spherical
contracted AOs for calculation and FILE47 output.  For WFN/WFX only, the same
orbitals are expanded with Tonto's solid-harmonic transformation into 67
Cartesian primitive components (rather than the 62 spherical primitive
components).  The automated test checks these dimensions, complete file
terminators, spherical d/f FILE47 labels, the Fock block, and all MOs.  The
resulting 43-function FILE47 was additionally accepted by GenNBO 7, which
completed with total electron population 10.00000 and net charge 0.00000.

The same retained case directly compares Tonto's AIM WFN with ORCA 5.0.4
`orca_2aim`, after semantic sorting by centre, Cartesian primitive type and
exponent and allowing the arbitrary global sign of each MO.  This exposed and
then guarded the external `px,py,pz` to Tonto `pz,px,py` pure-P import
permutation.  Across the five occupied orbitals, the largest primitive
coefficient difference is 4.0×10⁻⁸; the maximum relative exponent difference
is 3.44×10⁻⁷ (WFN print precision), and the maximum orbital-energy difference
is 3.0×10⁻⁸ hartree.  The matched pure-spherical FChk and Molden density cubes
are byte-identical after import.

A larger retained KHMAL ORCA/PBE/jorge-TZP final-output replay provided a
memory-safety and scale check: 554 pure-spherical contracted AOs expanded to
913 Cartesian primitive components; all three files completed.  The residual
map was unchanged at +1.198602/−0.860503 e Å⁻³, r.m.s. 0.074358 e Å⁻³.  This
validates representation conversion and output completion, not the chemical
quality of that KHMAL residual map.

## Epoxide molecular HAR control

**Question.** Does the shortest Tonto-only teaching workflow still reproduce
an IAM and then improve it with a molecular HAR?

**Design.** The packaged Epoxide CIF and unmerged HKL were run end to end with
the current lamaGOET runner and Tonto, using RHF/def2-SVP, wavelength
0.71073 Å, MERG 2, F/σ cutoff 4, and a starting Tonto IAM. A second run used
the historical already merged HKL and cutoff 2 to distinguish implementation
drift from a reflection-selection difference.

The fresh controls used lamaGOET revision `295dab0` and Tonto 26.09.20 revision
`53bb245`, compiled with GNU Fortran 14.2.0 and LAPACK 3.12.0 under WSL2 on
20 September 2026. The exact full revisions and artifact hashes are recorded
in `Tests/epoxide_control.json`.

| Control | R(F) | wR(F²) | Reflections | Parameters | GoF |
|---|---:|---:|---:|---:|---:|
| Current packaged IAM | 0.035630 | 0.073136 | 1,313 | 44 | 2.131635 |
| Current packaged HAR | 0.030272 | 0.053130 | 1,313 | 64 | 1.551167 |
| Historical retained HAR | 0.030237 | 0.052652 | 1,308 | 64 | 1.529226 |
| Exact historical input rerun | 0.030247 | 0.052663 | 1,308 | 64 | 1.529556 |

The packaged CIF is byte-identical to the historical teaching CIF. The
retained and rerun results agree to about 10⁻⁵ when the exact historical input
and reflection file are reused. The packaged unmerged data are a distinct
reflection population; they must not be treated as equivalent merely by
choosing the same nominal cutoff. In contrast, replacing def2-SVP by STO-3G
while holding the current packaged input fixed gave HAR `R(F)=0.044052` and
`wR(F²)=0.079555`, worse than the IAM.

As a direct check, applying cutoff 2 to the packaged unmerged file produced
1,601 reflections, IAM `R(F)=0.048148`, and HAR `R(F)=0.042411`; it did not
recreate the historical 1,308-reflection population. This confirms that the
historical file carries selection provenance beyond the nominal cutoff.

**Conclusion.** The HAR implementation has not regressed in this control. The
failure arose because the manual accidentally paired the historical target
with STO-3G. `Tests/test_epoxide_control.py` now protects the input hashes,
documented settings, and (when explicitly enabled) the live numerical path.

## Historical ten-case lamaGOET archive

The original `RUN_tests.sh` was a 1,381-line fork of an old runner, not a
reliable harness. Its final comparison used a malformed shell expression and
could report a misleading result. It has therefore not been restored as CI.
Instead:

1. `Tests/scientific_regressions.json` records the archived cases and exact
   CIF values;
2. `Tests/test_scientific_archives.py` checks provenance, artifacts, selected
   program, statistics, and residual block;
3. `Tests/run_scientific_regressions.sh` stages optional live runs in a new
   temporary directory and returns a real exit status.

The retained archive values are:

| Case | Program | R(all) | wR(all) | GoF(all) | N refl. |
|---|---|---:|---:|---:|---:|
| GlyAla | ELMOdb | 0.0206 | 0.0167 | 1.5517 | 2357 |
| GlyAla + cluster charges | ELMOdb | 0.0206 | 0.0167 | 1.5517 | 2357 |
| NH3 | Gaussian | 0.0272 | 0.0229 | 5.0533 | 98 |
| NH3 | Tonto | 0.0272 | 0.0229 | 5.0532 | 98 |
| NH3 + dispersion | Gaussian | 0.0270 | 0.0228 | 5.0204 | 98 |
| NH3 + dispersion | Tonto | 0.0270 | 0.0228 | 5.0204 | 98 |
| NH3 + cluster charges | Gaussian | 0.0272 | 0.0229 | 5.0512 | 98 |
| NH3 + cluster charges | Tonto | 0.0270 | 0.0229 | 5.0461 | 98 |
| Yellow compound | Gaussian | 0.0445 | 0.0274 | 1.4648 | 904 |
| Yellow compound | Tonto | 0.0445 | 0.0274 | 1.4648 | 904 |

| Case | Program | Residual max/min/r.m.s. (e Å⁻³) |
|---|---|---|
| GlyAla | ELMOdb | +0.1242 / −0.1373 / 0.0296 |
| GlyAla + cluster charges | ELMOdb | +0.1242 / −0.1373 / 0.0296 |
| NH3 | Gaussian | +0.0661 / −0.0448 / 0.0226 |
| NH3 | Tonto | +0.0661 / −0.0448 / 0.0226 |
| NH3 + dispersion | Gaussian | +0.0656 / −0.0444 / 0.0224 |
| NH3 + dispersion | Tonto | +0.0656 / −0.0444 / 0.0224 |
| NH3 + cluster charges | Gaussian | +0.0659 / −0.0447 / 0.0225 |
| NH3 + cluster charges | Tonto | +0.0655 / −0.0442 / 0.0221 |
| Yellow compound | Gaussian | +0.1344 / −0.1299 / 0.0312 |
| Yellow compound | Tonto | +0.1344 / −0.1299 / 0.0312 |

**Conclusion.** The retained artifacts now have a non-vacuous integrity
test, while fresh external-program equivalence remains an explicit opt-in
task. These values must be labelled archival if quoted.

## Crystal23 native GRED validation

**Question.** Can the smaller native GRED route replace the large XML density
file for supported restricted all-electron periodic HAR without changing
Tonto's prediction/refinement result?

**Design.** The same converged Crystal23 states were imported through GRED and
legacy XML. CIF, reflection data, basis, k mesh, stockholder, and Tonto
settings were held fixed. Reflection records, statistics, coordinates, ADPs,
and output geometries were compared. NH3, chiral quartz, natrolite, and
Diamond were chosen to expose non-centrosymmetric phase, large-system, and
genuinely periodic-density behavior.

**Results.**

| Control | Retained result |
|---|---|
| NH3 | GRED and XML FCF files identical |
| NH3 external BSE `def2-TZVP` | CRYSTAL23 expanded the general-basis records to 196 pure-spherical AOs (the same shells would give 216 Cartesian AOs); Tonto imported all 196 and reproduced the CRYSTAL central-cell overlap matrix to a maximum absolute difference of 0.000001 |
| Chiral Quartz | GRED and XML FCF files identical |
| Non-centrosymmetric Natrolite | GRED and XML FCF files identical; complete CIFs; empty stderr |
| KHMAL multi-block CIF | publication-only `data_global` was skipped in favour of the structural `data_K_HAR_aniso` block; 48 atoms and the 740-function `POB-TZVP-REV2` GRED density, overlap, and Fock matrices imported successfully |
| Diamond static prediction | R(F) 0.068526; R(F²) 0.104435; Rw(F) 0.092063; Rw(F²) 0.209767; GoF² 996.600747; extinction 2.972074; scale 1.013156 |
| Diamond 46-AO periodic XCW at λ=0 | GRED+KRED and XML+KRED FCF identical; R(F) 0.006054; R(F²) 0.012090; Rw(F) 0.005287; Rw(F²) 0.010640; GoF² 3.287344 |

The retained KHMAL calculation in
`Lolo_tests/Sep7/KHMAL/crystal23_periodic_PBE_pob` did **not** use a Basis Set
Exchange definition: its CRYSTAL input selected the built-in
`POB-TZVP-REV2` basis, and both `job_options.txt` and the CRYSTAL output select
the PBE Kohn--Sham Hamiltonian. Consequently, its residual-density
discrepancy cannot be attributed to BSE-to-CRYSTAL basis rendering. CRYSTAL general basis
records and the native GRED importer both use pure spherical shells: D, F and
G shells contribute 5, 7 and 9 functions respectively. The independent NH3
AO-count and overlap check above guards the representation boundary; it does
not by itself establish that a selected electronic-structure model will give
small residual extrema for every data set.

The matched one-cycle NH3 and Diamond refinements produced identical
fractional CIF, XYZ, and FCF content after normalizing only the job name. The
Diamond integration began from 13,721 unmerged observations, thereby testing
MERG, aspherical pruning, extinction, fitting, and geometry output rather than
only file parsing. GRED sizes were 4,276,401 bytes versus 23,908,478 bytes for
NH3 XML, and 25,715,013 versus 845,153,190 bytes for Natrolite XML.

**Conclusion.** Native GRED is numerically equivalent to the retained XML
route for these supported cases and greatly reduces input size. It does not
remove the need for KRED in periodic XCW, nor establish unrestricted/relativistic
support.

## Periodic Hirshfeld-I validation plan

**Status.** The `periodic-hi` implementation and lamaGOET controls are
experimental. The items below are publication gates, not completed scientific
results. Until the retained reports and artifacts exist, periodic H0 remains
the reference/default periodic stockholder.

The first retained implementation checks (21 September 2026) established the
following narrower facts. They do not validate periodic Hirshfeld-I for HAR:

| Check | Result | Interpretation |
|---|---|---|
| Source contract and Fortran build | both periodic-interface contracts passed; `run_molecule` built with gfortran-14 | keyword plumbing, symmetry mapping, fail-closed ion lookup, and the unchanged H0 branch are present in the generated program |
| Diamond PBE/pob-TZVP null control | one charge iteration; C1 charge 0.000000 e; multiplicity-weighted cell charge 0.000000 e; population normalization 0.999882 | the symmetry-equivalent elemental solid does not acquire a spurious charge |
| NH3 PBE/pob-TZVP polar control | cell charge remained 0.000000 e and normalization stayed between 0.999985 and 0.999993, but the iteration requested a nitrogen charge below -1 e and stopped at the adjacent-ion boundary | the current Thakkar neutral/+1/-1 library is insufficient even for this polar control; no NH3 Hirshfeld-I refinement result is claimed |

The NH3 failure is intentional and fail-closed. Extrapolating the N- density,
clamping its charge, or merely scaling a neutral atom would change the method
and could produce a positive-looking but scientifically undefined result. A
general periodic Hirshfeld-I implementation requires normalized radial
references that bracket every population reached by the iteration, including
multiple charge states for strongly ionic materials.

The implementation must first pass model-internal tests that do not depend on
an improved crystallographic fit:

1. selecting `cluster` or `periodic` must reproduce pre-Hirshfeld-I inputs and
   numerical outputs exactly;
2. symmetry-equivalent sites must have identical converged parent charges, and
   the multiplicity-weighted cell charge must be zero within the requested
   tolerance;
3. translated weights must sum to one wherever the procrystal is nonzero, and
   recombined atom densities/form factors must reproduce the imported periodic
   density/$F_{\mathrm{calc}}$ within grid and Fourier tolerances;
4. charge residuals must converge reproducibly when the grid, lattice cutoff,
   tolerance, and mixing are tightened;
5. unavailable +1/-1 references and any $|q|>1$ iterate must stop with an
   explicit diagnostic rather than silently falling back to H0; and
6. per-atom cubes must integrate to the reported populations and retain the
   required crystallographic site symmetry.

The scientific comparison will then hold CIF, reflections, merging, source
density, basis, functional, k mesh, grid, refinement parameters, and stopping
rules fixed while changing only `periodic` H0 versus `periodic-hi`. The planned
matrix is:

| Control class | Purpose | Required comparison |
|---|---|---|
| NH3 molecular crystal | weakly ionic/polar regression | H0 and Hirshfeld-I charges, N-H distance/ADPs, R/wR/GoF, residual map |
| Diamond | covalent null control | negligible scientifically material change; exact recombination and symmetry |
| LiF and NaCl | formal +/-1 ionic crystals within the supported reference interval | charge convergence, density transfer, held-out factors, grid/mixing sensitivity |
| Potassium hydrogen maleate (KHMAL) | available molecular salt with K+ and a hydrogen-bonded anion | multiplicity-weighted neutrality, K/anion charge transfer, site symmetry, H0-versus-HI residual maps |
| Natrolite | available extended polar/ionic network and neutron comparison | long-run structural test after the smaller numerical gates pass; reject the case if any iterate requires an unsupported charge magnitude |
| Ionic crystal with neutron geometry | structural relevance beyond agreement factors | X-H distances, ADP orientation/magnitude, uncertainties, residual features |

Each case requires an IAM baseline, held-out-reflection statistics, complete
charge-iteration logs, atom-population/cube integrals, and archived final CIF,
FCF, maps, and software revisions. A lower conventional R factor alone is not
an acceptance criterion; physically plausible charges, stable uncertainties,
neutron agreement where available, and robustness to numerical controls must
be considered together. If a system requires charges beyond +/-1, it is outside
the present model and must not be represented by clamping.

## Crystal23 phase and k-mesh tests

**Question.** Was degradation in a non-centrosymmetric structure caused by a
reflection-dependent phase convention or an unconverged k mesh?

**Design.** Complex Tonto factors reconstructed from the periodic import were
compared with Crystal23 XFAC after fitting only one crystallographic origin
shift and Fourier-sign convention. Natrolite XFAC from 2×2×2 and 4×4×4 meshes
was also compared.

| System | Reflections | Relative complex r.m.s. difference |
|---|---:|---:|
| NH3 | 81 | 1.535×10⁻⁴ |
| Diamond | 57 | 3.534×10⁻⁴ |
| Quartz | 512 | 1.812×10⁻⁴ |
| Natrolite | 9,928 | 2.923×10⁻⁴ |

Natrolite's amplitude R1 was 1.976×10⁻⁴. Its direct 2×2×2-versus-4×4×4 XFAC
comparison gave amplitude R1 = 2.016×10⁻⁶ and relative complex r.m.s. =
3.134×10⁻⁵. Directly inverse-transforming the finite-mesh KRED projector,
however, differed from the CRYAPI real-space density blocks by a relative
Frobenius norm of 1.424356 because it contains Born--von Kármán alias sums.

**Conclusion.** No reflection-dependent phase defect was detected at the
Tonto prediction boundary for the tested systems, and the Natrolite k mesh was
converged beyond the import/printing difference. KRED cannot replace the exact
direct-density anchor by itself.

## Native CP2K density, overlap, and Fock validation

**Question.** Can Tonto consume CP2K's direct real-space matrices and exact
k-resolved orbital data without the Python XML bridge, including a defensible
Fock/KS matrix?

**Design.** CP2K 2026.2 development revision `71c3ab0c0b` exported P, S, and
KS/Fock CSR matrices and MOKP data. Independent checks reconstructed k-space
overlap and orbital equations, verified translation mirrors and electron
count, and compared one complete native `ha_fit` cycle with the matched XML
route.

| Diagnostic | NH3 | Diamond |
|---|---:|---:|
| Cell atoms | 16 | 8 |
| Contracted AOs | 144 | 144 |
| k points | 8 | 216 |
| Direct-lattice images | 81 | 171 |
| Stored MOs | 40 | 24 |
| Tr(P S), integer target | 40 | 48 |
| Tr(P S) − target | 6.4×10⁻¹⁴ | 1.56×10⁻¹³ |
| max native-P versus MOKP Fourier error on retained entries | 4.97×10⁻¹⁵ | 1.98×10⁻⁹ |
| max \(C^\dagger S C-I\) | 8.59×10⁻¹⁴ | 1.19×10⁻⁹ |
| max \(H C-S C\varepsilon\) | 1.33×10⁻¹³ | 2.38×10⁻⁹ |
| max P mirror error | 0 | 0 |

The complex Diamond mesh fixes the convention: S(k) and H(k) use
`exp(+2π i k·R)` and the density inverse transform uses the negative sign.
Using the wrong sign yielded errors 0.8654 and 1.5201 for the two orbital
checks. One full native/XML `ha_fit` comparison gave R(F) = 0.007280 for NH3
(81 reflections) and 0.005859 for Diamond (57 reflections), with matching FCF,
geometry, atom parameters, and reported statistics at written precision.

**Conclusion.** The native path carries real Fock/KS information and
reproduces the retained XML prediction/refinement for these restricted
all-electron examples. Screened zero AO pairs are part of CP2K's sparse
support; dense coefficient norms outside nonzero overlap support are not a
valid equivalence metric.

## Periodic XCW gates

**Question.** Does the periodic-XCW implementation preserve the exact static
reference at λ = 0, include intercell density, respond variationally at
nonzero λ, and restart without changing geometry?

### Static and basis controls

| Fixed-geometry Diamond model | AOs | R(F) | χ² |
|---|---:|---:|---:|
| IAM | — | 0.009500 | 11.909232 |
| Standard POB-TZVP-rev2 reference | 36 | 0.005680 | 3.035515 |
| Core-decontracted reference | 46 | 0.006054 | 3.287344 |

Both periodic references retained all 219 direct-lattice blocks, 182 of them
off-cell. The off-cell Frobenius fractions were 0.573918 (36 AO) and 0.606824
(46 AO). Thus neither result is a molecular central-cell density, and AO count
alone did not rank quality. Against direct Crystal23 XFAC, all 57 reflections
had mean absolute amplitude difference 0.001877, r.m.s. 0.002549, and maximum
approximately 0.00679 for the reported reference comparison.

### Mathematical and lifecycle controls

- The periodic Hartree energy and one-half `Tr[dP J]` were both 6.5666×10⁻⁸;
  relative adjoint mismatch was 8×10⁻¹¹.
- Density, Cartesian-gradient, and GGA-adjoint translation errors were exactly
  zero for mixed translations up to six primitive cells.
- Each MERG-4 pass started from 18,201 raw observations, removed 1,628
  systematic absences and 2,852 weak observations, and merged to 63
  reflections. The process repeated for XCW and final artifacts.

### Nonzero λ response

At λ = 10⁻⁶, both Diamond references converged in three ordinary iterations:

| Reference | χ² iteration 1 | final χ² | final gradient ×10⁹ |
|---|---:|---:|---:|
| 36 AO | 3.035357 | 3.035371 | 5.835345 |
| 46 AO | 3.287110 | 3.287132 | 6.857722 |

| Reference | occupied-subspace change ×10⁹ | geometry/ADP change |
|---|---:|---:|
| 36 AO | 66.640019 | 0 |
| 46 AO | 54.750362 | 0 |

Terminal checkpoint reloads rebuilt all responses and reproduced the final
statistics with 57-row FCFs and no geometry/ADP change.

**Conclusion.** The implementation passes λ-zero identity, intercell-support,
adjoint, translation, immutable-reflection, response, and restart engineering
gates. These runs used an 8×8×8 Poisson grid and no held-out reflection set;
they do not select a publication-grade λ or establish grid/basis convergence.

## Reflection merging and aspherical absences

**Question.** Can weak data be rejected before merging, can model-zero
reflections change with a new partition, and can a reflection re-enter?

**Design.** Diamond began from the immutable unmerged SHELX-format data.
Preprocessing was repeated before each new fit/partition and before final
artifacts. IAM and periodic aspherical calculated factors supplied their
respective zero tests.

**Result.** The periodic-XCW lifecycle above reproduced the same raw, weak,
systematic-absence, and merged counts on each pass. The final FCF contained
the expected unique population. A source-level guard prevents starting a new
pass from the prior merged subset.

**Conclusion.** Weak selection precedes merging and aspherical pruning is
recomputed. A compact synthetic leave-and-re-enter reflection fixture remains
a desirable publication gate even though the real-data repeated lifecycle is
covered.

The code-name semantics of `MERG` are cross-checked against the [official
SHELXL instruction reference](https://shelx.uni-goettingen.de/shelxl_html.php),
while the aspherical zero test is a Tonto extension and must be validated
separately.

## Observed-density reconstruction

**Question.** Does the constrained update incorporate chemically relevant
low-order residual density without producing non-positive H ADPs or selecting
the model only on training reflections?

**Design.** The NH3 measured data, Becke grid, structural flags, deterministic
10% R-free split (8 reflections), cube grid, and iteration limit were fixed.
The old inverse-σ step was compared with reliability preconditioning
`F²/(F²+σF²)`, positivity/electron-count projections, phased targets,
backtracking, and held-out one-standard-error selection.

The atom-centred integration control refers to Becke's multicentre scheme
([Becke, 1988](https://doi.org/10.1063/1.454033)); this test fixes one grid and
does not replace an accuracy-convergence study.

| Model | Held-out χ² | Residual max/min/r.m.s. (e Å⁻³) |
|---|---:|---|
| Old inverse-σ, no prior/smoothing | 35.932625 | +0.022840 / −0.025339 / 0.006706 |
| Reliability, no prior/smoothing | 31.282418 | +0.004415 / −0.005772 / 0.001073 |
| Reliability, β=0.01 (selected default) | 31.095152 | +0.004771 / −0.005461 / 0.001166 |
| Reliability, prior=0.01, β=0.01 | 31.503438 | +0.006734 / −0.009692 / 0.001594 |

| Model | N--H (Å) | H U eigenvalues (Å²) | absolute axis cosine |
|---|---:|---|---:|
| Old inverse-σ, no prior/smoothing | 0.94354 | 0.04352, 0.05426, 0.07521 | 0.09984 |
| Reliability, no prior/smoothing | 0.94485 | 0.04736, 0.05627, 0.07281 | 0.12997 |
| Reliability, β=0.01 (selected default) | 0.94432 | 0.04714, 0.05664, 0.07240 | 0.12888 |
| Reliability, prior=0.01, β=0.01 | 0.93777 | 0.04650, 0.05439, 0.06885 | 0.19946 |

For the selected model, the N-atom deformation along the lone-pair axis at
0.3/0.4/0.5 Å was +0.21109/+0.21307/+0.18008 e Å⁻³, while the final residual
at those points was +0.00166/+0.00051/−0.00070 e Å⁻³. The old update left
+0.02096/+0.01989/+0.01732 e Å⁻³.

**Conclusion.** The corrected update captures the tested lone-pair feature,
improves held-out χ², and retains positive H ADPs with the long axis nearly
perpendicular to N--H. It does not recover a unique experimental density or
establish a neutron-accurate N--H distance.

### Dynamic observed-density engineering test

For the dynamic, thermally averaged variant, the retained reconstruction RMS
sequence was 0.125776, 0.042933, 0.019538, 0.011723, and 0.008098. In a longer
smoke test, outer cycle 1 changed working χ² from 12.048880 to 0.000210 and
held-out χ² from 35.354626 to 33.471112; cycle 2 gave 0.000170 and 33.475999
with density RMS change 0.001621. This demonstrates algorithmic convergence,
not identifiable simultaneous ADP/shape refinement.

## Extinction models

**Question.** Do the new extinction branches parse, refine, and write the CIF
semantics appropriate to scalar and multi-parameter models without breaking
the established Zachariasen route?

**Design.** Four L-alanine IAM calculations used identical CIF/HKL data:
Zachariasen--Larson; Becker--Coppens type 1 Gaussian isotropic; type 2
Lorentzian isotropic; and mixed Gaussian anisotropic.

**Result.** All four parser/optimization/output paths completed in the retained
validation. Scalar isotropic cases wrote coefficient and e.s.d. to
`_refine_ls_extinction_coef`. The mixed/anisotropic case wrote `.` for that
single scalar and listed its multiple coefficients in
`_refine_special_details`, consistent with CIF Core. The fixed mean path
0.3 mm was a test input only.

**Conclusion.** The software branches and CIF representation were exercised;
a real crystal requires an absorption-weighted mean path and data capable of
supporting the selected model.

Model names and archive requirements were checked against the [IUCr CIF Core
extinction
definition](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.extinction_method.html);
the underlying Zachariasen--Larson and Becker--Coppens references are listed in
{doc}`references`.

## Quartz scale-factor normalization

**Question.** Was Tonto's scale one order of magnitude too large relative to a
SHELXL result, or were the reflection intensities differently normalized?

**Design.** 43,045 matched Quartz observations showed median `I` and σ(I)
ratios of 100.0099 between the two input files. Tonto was rerun after dividing
both by 100 with no model change.

| Quantity | Original | I and σ(I) divided by 100 |
|---|---:|---:|
| Amplitude scale | 32.829708 | 3.282971 |
| R(F) | 0.022466 | 0.022466 |
| Rw(F) | 0.021723 | 0.021723 |
| GoF² | 33.224495 | 33.224495 |
| Extinction | 0.797802 | 0.797803 |
| Extinction e.s.d. | 0.048602 | 0.048602 |

**Conclusion.** An intensity rescaling by 100 changes the amplitude scale by
10 while leaving dimensionless fit statistics and extinction invariant. No
Tonto scale-optimizer change was justified. The remaining ∼1% difference
from SHELXL's 3.25048 is compatible with F/σ(F) versus F²/WGHT objectives and
a one-reflection population difference.

## KHMAL residual-map equation and grid audit

**Question.** Did the substantially deeper negative extremum in the final
KHMAL Tonto map, relative to Olex2/NoSpherA2 at the same stated electronic-
structure level, arise from a different Fourier equation?

**Design.** The final Olex2 and controlled Tonto coefficient populations were
matched by Miller index. Both contained 5,366 reflections. Observed amplitudes
agreed to 0.006204 e r.m.s. with correlation 0.99999999917; calculated
amplitudes differed by 0.055290 e r.m.s. with correlation 0.9999808704. Both
coefficient sets were independently synthesized on the same coarse grid. A
second Tonto entry point then implemented the nominal published SHELXL FMAP 2
coefficient $(F_o-F_c)\exp(i\phi_c)$ independently, while leaving Tonto's
established residual routine unchanged and retaining the identical reflection
population and grid. No unpublished sigma-dependent attenuation was introduced.

The independent coefficient was taken from the [official SHELXL `FMAP`
documentation](https://shelx.uni-goettingen.de/shelxl_html.php); the test does
not infer behavior that the public instructions do not define.

| Calculation | Grid | Minimum / maximum / r.m.s. (e Å⁻³) |
|---|---|---|
| Olex2 reported final map | approximately 0.3 Å | −0.3116 / +0.9097 / 0.0736 |
| Olex2 coefficients, independent coarse synthesis | Olex2-like matched grid | −0.309840 / +0.918723 / -- |
| Tonto coefficients, independent coarse synthesis | same coarse grid | −0.301643 / +0.939207 / -- |
| Standard Tonto final map | 0.097991 / 0.098753 / 0.099518 Å | −0.866085 / +1.209915 / 0.077083 |
| Independent nominal FMAP 2 coefficient path | identical Tonto grid | −0.866085 / +1.209915 / 0.077083 |
| SHELXL-2019/3 KHMAL run | SHELXL internal sampling | −0.86 / +1.21 / -- |

The standard Tonto cube remained byte-identical to the pre-comparison result
(`SHA-256 c6dc895fe281869206c5a6724f7e0680c342e6239975e4d0afbe4f3879bdd0f9`).
The two cube files have different descriptive second header lines, but their
complete numerical payloads after those headers are byte-identical
(`SHA-256 1570ae275e0c5554e296808f12a0a7656d93fa3a4ff4bdbf3752c1be9c75341e`).
The direct algebraic invariant additionally covers inversion symmetry, Friedel
multiplicity, a non-unit scale, nonzero $\sigma(F_o)$, a zero calculated phase,
and both supported anomalous-dispersion modes. It verifies that the prepared
corrected observation is used and that $\sigma(F_o)$ does not alter the nominal
coefficient.

**Conclusion.** For this no-dispersion KHMAL case, on an identical reflection
population and grid, the unchanged standard Tonto map and the independent
nominal coefficient path give the same field. The displayed difference-density
coefficient therefore does not explain the Olex2 extrema discrepancy. Matched
coarse-grid syntheses reproduce the much smaller Olex2 extrema closely,
showing that sampling is the dominant cause in this controlled case; modest
calculated-amplitude differences remain. The comparison does not claim to
reproduce undocumented SHELXL weak-data handling or Olex2/CCTBX internals.

## Nonlinear least-squares solver controls

**Question.** Can fixed SHELXL-style damping and adaptive
Levenberg--Marquardt step control be added without changing the established
Gauss--Newton result, and do the new paths behave correctly for both the
ordinary structure fit and an in-memory HAR fit?

**Design.** On 27 September 2026 the implementation was checked at three
levels. A native unit executable exercised keyword aliases, defaults, fixed
damping, a zero-shift `DAMP 0 0` calculation, LM acceptance, rejection,
rollback, lambda adaptation, and trial exhaustion. Focused CTest regressions
then covered the solver, SHELXL weighting, and residual-phase guard. Finally,
the retained Epoxide control was run through the unchanged default, two fixed
damping settings, stable and deliberately displaced LM starts, an
$F^2$/SHELXL-weighted LM fit, and both overloads of the structure-fit routine.
The NH3 RHF/DZP HAR case exercised the in-memory form-factor overload.

| Control | Retained observation |
|---|---|
| Established Gauss--Newton default | Baseline and current stdout, archive CIF, archive FCO, statistics, and geometry were identical after removing build/time metadata; a repeated current run was deterministic |
| SHELXL defaults (`DAMP 0.7 15`) | Epoxide converged in five iterations; $\chi^2$ 2.083909 to 2.039458, $R(F)=0.030703$, $R_w(F)=0.032601$ |
| Deliberate shift cap (`DAMP 100 2`) | First maximum shift/esd was exactly 2.000000, verifying the uniform LIMSE cap |
| ESD-only step (`DAMP 0 0`) | Two iterations completed with zero structural shift and no uninitialized diagnostic index |
| Stable LM start | Accepted objective sequence 2.039607, 2.039462, 2.039458, 2.039458 and converged |
| Deliberately displaced LM start | Rejected objectives near 190.55 and later 910.49/553.61 were rolled back; accepted objective fell from 12.640180 through 11.701975 to 2.574962 before convergence |
| $F^2$ plus SHELXL WGHT and LM | Converged with final $R_1=0.031196$, $wR_2=0.073207$, and goodness of fit squared 1.180953; round-off-level IRLS changes used the established objective tolerance |
| NH3 in-memory HAR plus LM | Six outer fits reduced final $\chi^2$ from 0.842 to 0.752 and maximum shift/esd from 9.565 to 0.004; final $R(F)=0.010$ and $R_w(F)=0.008$ |

The focused automated gate passed **3/3** tests:
`least_squares_solvers`, `shelxl_weighting`, and
`residual_phase_guard`. The default path emits no solver keyword from
lamaGOET, preserving compatibility with older Tonto executables.

**Conclusion.** The default remains the established full-matrix
Gauss--Newton calculation. Fixed damping reproduces the documented SHELXL
diagonal multiplier and shift/esd cap; adaptive LM evaluates the actual
nonlinear objective, rolls rejected trials back exactly, and stops at the last
accepted model if its retry budget is exhausted. These checks validate step
control and regression compatibility, not superiority for every model. A
stable undamped final cycle remains the appropriate source of reported
curvature-derived uncertainties.

The fixed multiplier and `LIMSE` interpretation are checked against the
[official SHELXL `DAMP`
documentation](https://shelx.uni-goettingen.de/shelxl_html.php). The adaptive
path is grounded in [Levenberg
(1944)](https://doi.org/10.1090/qam/10666) and [Marquardt
(1963)](https://doi.org/10.1137/0111030), but the numerical checks above concern
this implementation rather than claiming identity with another program.

### Third-order anharmonic safeguard regression

**Failure reproduced.** The supplied ORCA/B3LYP/def2-SVP calculation refined
third-order Gram--Charlier coefficients for O1 and O2 while attempting 190
effective structural parameters.  Its saved options selected the undamped
Gauss--Newton default, 8 LM trials, and 30 iterations.  The first accepted
linearized step raised $\chi^2$ from 26.801945 to 8129.789414 and raised
$R(F)$ from 0.041048 to 0.997480; the next iteration became nonfinite.  The
reported `update_fragment_info` segmentation fault occurred only after that
invalid state had already been printed and was therefore secondary.

**Independent model check.** The supplied XD third-order-only refinement is a
valid higher-order model and converges with matrix inversion plus damping.  It
uses 118 variables, including 20 third-order oxygen coefficients, whereas the
lamaGOET job also refined a substantially larger coordinate/ADP set.  The XD
result is therefore a semantic/control reference, not a numerically identical
least-squares oracle.

**Guarded replay.** The exact failing first-cycle Tonto input was replayed in
an isolated directory while deliberately retaining its legacy
`gauss-newton` and `max_iterations=30` text.  Tonto detected the active
anharmonic model and selected adaptive LM with 20 trials and 200 iterations.
The first three objective-increasing trial steps (approximately 8305.04,
8304.46, and 8296.11) were rejected from the unchanged $\chi^2=26.801945$
model.  The first accepted value was 22.917631.  The fit converged at accepted
iteration 110 with $\chi^2=16.637373$, $R(F)=0.036617$,
$R_w(F)=0.044720$, and maximum shift/esd 0.009440 for a tolerance of 0.01.
No NaN or segmentation fault occurred.

That numerical convergence is **not** a physically acceptable result.  The
same 190-parameter replay drove one hydrogen coordinate by approximately
5.8 Angstrom and produced pathological/non-positive hydrogen displacement
tensors.  The safeguarded solver removed the crash but also exposed a second,
independent problem: six freely refined anisotropic ADP components for every
H atom over-parameterized this already ill-conditioned anharmonic fit.
This is a finding about the supplied parameterization, not a prohibition on
anisotropic H ADPs in HAR.  In fact, the saved options identify this replay as
an ORCA HAR (`IAMTONTO=false`, `ONLYIAMTONTO=false`), and the Tonto input uses
`partition_model=oc-hirshfeld` followed by `ha_fit`.

Three matched controls used the same 4920 reflections.  Refining O1/O2 through
third order while refining H ADPs isotropically converged at iteration 47 to
$\chi^2=18.253432$, $R(F)=0.037999$, and $R_w(F)=0.047039$ (149 fit
parameters).  Keeping H ADPs fixed converged at iteration 12 to
$\chi^2=18.609498$, $R(F)=0.038020$, and $R_w(F)=0.047536$ (141 fit
parameters).  The harmonic/isotropic-H control converged at iteration 42 to
$\chi^2=19.104993$, $R(F)=0.038858$, and $R_w(F)=0.048225$ (130 fit
parameters).  H coordinates remained near the starting structure in all
three constrained-H controls.  The isotropic third-order result still had 42
filtered near-zero eigendirections and one weakly determined H $U_{iso}$ of
about 0.065(7) Angstrom squared, so it is a stability regression rather than
a claim that this is the final physical model.

The automatic replay and a separately prepared explicit-LM replay produced
byte-identical fractional/archive CIFs
(`SHA-256 a21acc3768ff325fd94f95fd7d2f04734dac57ae18a9e14de9f46b84f35ef4de`)
and FCF6 files
(`SHA-256 e44274e494c71efad5af801add0df3306fe0b592b0959babd2c199bfcc71943d`).
The focused Tonto tests `least_squares_solvers`,
`gram_charlier_derivatives`, `so2_read_anharmonic_GC_cif`, and
`so2_read_anharmonic_U_cif` passed 4/4.  The Gram--Charlier invariant checks
the production signs, factorials and lexical tensor mappings, then
independently finite-differences all 10 third-order and 15 fourth-order
coefficients.
The lamaGOET local and cluster runner regressions passed 60/60, the related
options/parity/documentation tests passed 26/26, and the off-screen Qt smoke
test confirmed both interactive selection and migration of a legacy saved
job.

**Conclusion.** Third-order-only refinement was not intrinsically defective.
The crash and exploded model had two separable causes: an unguarded nonlinear
step could accept an enormous objective increase, and freely refined
anisotropic H ADPs left an over-parameterized model capable of converging to
an unphysical minimum even after step control was repaired.  Harmonic/default
calculations retain their established solver path; anharmonic calculations
now use guarded trial steps.  Anisotropic H ADPs remain available for HAR.
lamaGOET gives the stronger H-ADP warning only for an IAM stage, where a
spherical independent-atom model normally cannot determine anisotropic H
motion reliably; it does not rewrite a HAR job.

### XD/XDPDF O1 probability-density regression

The anharmonic cube writer was checked against the supplied XD_IAM/XDPDF
calculation for O(1), rather than only against a synthetic tensor. The crystal
and diffraction data are from the 100 K 2-methyl-4-nitroaniline study of
[Whitten *et al.* (2006)](https://doi.org/10.1021/jp061830n). The compact
fixture uses the XD harmonic $U_{ij}$ tensor and all ten third-order
coefficients, requests the isolated third-order correction, and reproduces the
XD grid of $51^3$ points, a 1.6 Å box, and 0.032 Å spacing.

XDPDF reports integrated signed probabilities of +1.954% and -1.954%.
Tonto reports +1.9563% and -1.9563%; the 0.0023 percentage-point difference is
consistent with printed-coefficient precision and grid quadrature. At the 99%
harmonic-reference probability, Tonto reports equal-magnitude contours of
$+0.096715$ and $-0.096715$ Å$^{-3}$. The automated regression verifies the
grid dimensions, spacing, selected-order metadata, signed-integral balance,
and agreement with the XD integrated probability.

The retained `xd_pdf.out` explicitly states that the supplied map sections are
parallel to the cell axes and that the displacements use reciprocal axial
directions, consistent with [XD/XDPDF Chapter
11.3](https://www.chem.gla.ac.uk/~louis/xdworkshop/workshop/documentation/xd2006manual.pdf).
The raw amplitude scale in `xd_pdf.grd` is therefore not compared point by
point because Gaussian cube files instead use Cartesian axes and atomic-unit
density. The
integrated signed probability is invariant to that representation and is the
appropriate cross-program check. The accompanying MoleCoolQt `testpdf.face`
file was also decoded as a triangulated surface mesh (vertex normals followed
by polygon connectivity), not as a volumetric reference grid. Tonto therefore
continues to write standard Gaussian cubes and records the symmetric contour
pair as metadata rather than copying the `.face` convention.

This check is retained in
`tests/data/anharmonic_pdf_xd_o1/` and is run with
`ctest --output-on-failure -R anharmonic_pdf_xd_o1` from the Tonto build
directory. It passed on 2026-10-02 together with the independent synthetic
cube, rectangular-grid, Gram--Charlier derivative, and CIF tensor-reading
tests.

## Anomalous controls and exploratory anharmonic study

**Purpose and provenance.** Two iodine-containing datasets were kept
separate because they test different claims.  The 3-chloro-1-methylpyridinium
iodide crystal reported by [Fotović, Bedeković and Stilinović
(2021)](https://doi.org/10.1021/acs.cgd.1c00805), CCDC 2089228, is
centrosymmetric *Pbca*.  It tests dispersion, merging, extinction and
$F^2$/SHELXL weighting, but cannot test absolute structure.  The
glycyl-L-alanine hydroiodide monohydrate polymorph reported by [Baptista
*et al.* (2023)](https://doi.org/10.3390/ma16103690), CCDC 2247398, is polar
$P2_1$.  Its retained Friedel pairs and iodine atom permit dispersion,
Parsons--Flack and exploratory anharmonic comparisons.  All calculations
used copies; the deposited source directories were not modified.  SHELXL is
treated here as the trusted conventional harmonic-refinement control.  It
does not refine Gram--Charlier coefficients.  The local Olex2.refine model
derived from 2247398 is retained only as an interoperability and stability
comparison: neither its higher-order coefficients nor its CCTBX residual map
are accepted as a numerical reference.  The published XD/XDPDF comparison in
the preceding section remains the external numerical validation of Tonto's
anharmonic implementation.

**Harmonic controls.** A local SHELXL-2019/3 executable first refined a
harmonic model for each raw HKLF 4 dataset.  Tonto then used the same
unmerged observations, `MERG 2`, the deposited wavelength and dispersion
terms, a Zachariasen/Larson extinction parameter, an $F^2$ target and the
corresponding SHELXL `WGHT` coefficients.  For 2089228 the SHELXL
$2\theta_{max}=57.99$ degree limit was converted explicitly to
$\sin\theta/\lambda=0.682129107$ Angstrom$^{-1}$; this reduced both programs
to the same 2,215 merged reflections.  For 2247398 both retained 2,562.

| Dataset and harmonic model | $N$ | $R_1$ all | $R_1$ gt | $wR_2$ all | GoF all |
|---|---:|---:|---:|---:|---:|
| 2089228, SHELXL | 2,215 | 0.0354 | 0.0252 | 0.0617 | 1.029 |
| 2089228, Tonto | 2,215 | 0.038746 | 0.025995 | 0.061686 | 1.057738 |
| 2247398, SHELXL | 2,562 | 0.0299 | 0.0286 | 0.0672 | 1.247 |
| 2247398, Tonto | 2,562 | 0.031196 | 0.029577 | 0.070641 | 1.259636 |

| Dataset and harmonic model | Extinction | Residual max / min (e Angstrom$^{-3}$) |
|---|---:|---:|
| 2089228, SHELXL | 0.064752 | +0.53 / -0.71 |
| 2089228, Tonto | 0.066060 | +0.553 / -1.034 |
| 2247398, SHELXL | 0.219578 | +0.69 / -1.76 |
| 2247398, Tonto | 0.214643 | +0.707 / -1.808 |

The matched populations remove reflection count as an explanation for the
comparison.  The weighted statistics and extinction parameters are close,
including near-identical 2089228 $wR_2$, but the 2089228 negative residual
extremum is not reproduced exactly.  The direct Tonto controls fixed H atoms,
whereas the SHELXL models retained their deposited riding constraints, and
the Fourier implementations sample different grids.  These rows validate
the dispersion/weighting path and expose the remaining map-level difference;
they do not assert byte-identical refinement semantics.

**Exploratory iodine anharmonic comparison.** The supplied local
Olex2.refine model derived from 2247398 contains all ten third-order and
fifteen fourth-order Gram--Charlier coefficients for I1.  That result was not
published or independently validated by the Olex2.refine authors, so it is
not used as reference truth.  Tonto was tested twice: first by reading the
scale-tag-free Olex2 CIF, and then by starting all I1 higher-order
coefficients from zero at the independently refined harmonic SHELXL geometry.
Both Tonto fits converged without a rejected final state.  The harder
zero-start diagnostic is tabulated below.

| 2247398 model | $N$ | $R_1$ all | $R_1$ gt | $wR_2$ all | GoF all |
|---|---:|---:|---:|---:|---:|
| Supplied local Olex2.refine, I1 orders 3+4 | 2,562 | 0.0248 | 0.0235 | 0.0555 | 1.0372 |
| Tonto, I1 orders 3+4 from zero | 2,562 | 0.025826 | 0.024358 | 0.057159 | 1.024087 |

| 2247398 model | Extinction | Flack $x$ | Residual max / min (e Angstrom$^{-3}$) |
|---|---:|---:|---:|
| Supplied local Olex2.refine, I1 orders 3+4 | 0.244(6) | 0.06(2) | +0.387 / -0.765 |
| Tonto, I1 orders 3+4 from zero | 0.251977 | 0.058(25) | +0.478 / -0.954 |

For the ten third-order coefficients, the zero-start Tonto and supplied local
Olex2.refine vectors have Pearson correlation 0.9468, an r.m.s. component
difference of $0.433\times10^{-6}$ and a maximum component difference of
$1.192\times10^{-6}$.  For the fifteen fourth-order coefficients the
correlation is 0.8576, the r.m.s. difference is $4.365\times10^{-8}$ and the
maximum difference is $9.60\times10^{-8}$.  Six mixed fourth-order terms
remained effectively zero with large Tonto uncertainties, whereas the
supplied local Olex2.refine model reports finite values.  These quantities
show useful gross agreement for code interoperability and expose conditioning
or model-constraint differences.  They do **not** validate the physical
Gram--Charlier model, the Olex2.refine residual density, or
component-by-component fourth-order equivalence.  In particular, the
published XD/XDPDF control above, rather than this exploratory comparison, is
the accepted anharmonic numerical reference.  The unresolved mixed terms
remain a disclosed conditioning/model-constraint limitation.

The scale-tag-free interoperability replay gave $R_1=0.025723$,
$wR_2=0.056824$, GoF
$=1.018086$, extinction 0.251617 and Flack $x=0.058(25)$.  It also motivated
a reader regression: `anharmonic_pdf_cube` now rewrites its synthetic C3/C4
fixture into the unscaled form used by Olex2.refine, omits Tonto's optional
presentation-scale items, and requires the resulting cube values to remain
identical within $10^{-12}$.  This test passed together with
`gram_charlier_derivatives` and `anharmonic_pdf_xd_o1`.  This reader regression
validates scale-tag-free CIF interoperability only; it is not a scientific
validation of the supplied Olex2.refine anharmonic result.

### Strict fourth-order-only XD/Tonto diagnostic

**Question.** Does the fourth-order-only control really refine the fifteen
$D_{ijkl}$ terms while keeping every third-order $C_{ijk}$ term fixed, even
when anomalous dispersion is active?  This distinction matters for the
iodine-containing 2247398 dataset: a nominally fourth-order-only run must not
become an undocumented partial third-plus-fourth-order fit through the
$f'+if''$ derivative path.

**Failure found and corrected.** The ordinary structure-factor Jacobian
already suppressed C3 derivatives in fourth-order-only mode, but the
anomalous-dispersion Jacobian added those ten columns back.  Tonto therefore
retained C3 storage for CIF compatibility and, for a dispersive atom, also
gave those nominally fixed entries nonzero least-squares derivatives.  The
corrected routine propagates the explicit fourth-order-only flag into every
anomalous derivative call, omits the C3 anomalous derivatives, and removes
exactly inactive columns from the effective normal equations and parameter
count.  A source/algebra regression now checks all three requirements.  In
the corrected production fits, every I1 C3 value and uncertainty remained
exactly zero while D4 values refined normally.

**Independent XD control.** A fresh XD model was started from the harmonic
geometry with all C3 keys disabled, all D4 keys enabled for I1, and all D4
values zero.  It converged after 14 cycles using 2,418 reflections.  Tonto
was first run from the full 2,562-observation merged population.  A second
Tonto run then used the same 2,418 Miller indices retained by XD, selected
from the XD acceptance flags while preserving Tonto's own merged observed
intensities and uncertainties.  This is a matched reflection-population
comparison, not a claim that XD and Tonto use identical internal weights,
parameter constraints, or observation preprocessing.

| Strict I1 D4-only model | $N$ | $R(F)$ or $R_1$ | weighted $R(F^2)$ | reported GoF |
|---|---:|---:|---:|---:|
| XD, zero start | 2,418 | 0.0250 | 0.0605 | 1.1575 |
| Tonto, matched Miller set | 2,418 | 0.025151 | 0.058879 | 1.076316 |
| Tonto, full merged set | 2,562 | 0.027289 | 0.061180 | 1.093922 |

The corrected matched-set Tonto objective decreased monotonically through
accepted LM states from 1.173932 to 1.159467 and converged with 123 effective
structural parameters.  The full-set objective decreased from 1.209700 to
1.197648.  The close $R$ statistics are useful implementation evidence, while
the different GoF conventions and effective parameterizations preclude an
exact equality claim.  Raw $D_{ijkl}$ component vectors are not compared
directly here because XD and Tonto print them in different tensor coordinate
conventions; doing so without an explicit tensor transformation would be
misleading.

The corresponding probability-density integrations provide a second,
coordinate-invariant diagnostic:

| Strict I1 D4-only PDF | Positive | Negative | Integral/volume check |
|---|---:|---:|---|
| XD/XDPDF | 100.084% | -0.126% | negative volume 0.491 Angstrom$^3$ |
| Tonto, matched Miller set | 100.120455% | -0.164251% | cube integral 0.999562 |
| Tonto, full merged set | 100.187826% | -0.222370% | cube integral 0.999655 |

**Scientific limitation.** XD reports a measured maximum
$\sin\theta/\lambda=0.66671$ Angstrom$^{-1}$, whereas its Kuhs-resolution
diagnostic requires approximately 0.67 Angstrom$^{-1}$ for I1 C3 and
0.78 Angstrom$^{-1}$ for I1 D4.  The dataset therefore does not resolve a
physically reliable fourth-order iodine model.  The nonzero negative PDF
probability reinforces that warning.  This D4-only comparison validates mode
selection, derivative isolation, nonlinear stability, CIF output, and cube
generation; it must **not** be cited as validation of a physical fourth-order
thermal model for this crystal.

## Post-refinement Flack parameter

**Question.** Does the optional absolute-structure analysis reproduce the
Parsons-quotient result reported by SHELXL, while remaining a diagnostic after
refinement rather than adding the Flack parameter to every least-squares
matrix?

**Design.** The retained absolute-structure test uses the acentric
[glycyl-L-alanine hydroiodide monohydrate polymorph (CCDC
2247398)](https://doi.org/10.3390/ma16103690) reported by Baptista *et al.*
(2023).  Its iodine-containing polar $P2_1$ crystal provides the strong
anomalous signal required for a meaningful absolute-structure test.  CCDC
2089228 is centrosymmetric and is therefore deliberately excluded from this
section.  The 2247398 data were analysed with the origin-constrained quotient
regression of Parsons, Flack and Wagner. For each retained Friedel pair,

$$
Q_{\mathrm{obs}}=\frac{I^+-I^-}{I^++I^-}, \qquad
Q_{\mathrm{single}}=\frac{|F^+|^2-|F^-|^2}
{|F^+|^2+|F^-|^2}.
$$

Only pairs for which both observations exceeded three standard uncertainties
were admitted. The documented outlier test removed pairs whose observed
Friedel difference exceeded twice the largest calculated single-domain
difference. A weighted straight line constrained through the origin gave
slope $m$, followed by $x=(1-m)/2$ and
$u(x)=u(m)/2$. The test used the final scale and extinction treatment for
the regression, while the outlier threshold used the unextinguished
single-domain calculated amplitudes.

| Control | Friedel-pair accounting | Flack x |
|---|---|---:|
| SHELXL retained result | 1,083 quotients | 0.046(24) |
| Tonto replay of the final SHELXL FCF | 1,163 available; 1,086 strong; 3 outliers; 1,083 accepted | 0.045(23) |
| Ordinary Tonto IAM plus archive-CIF output | 1,012 accepted pairs after the Tonto cutoff-4 reflection selection | 0.111(45) |

The last row is intentionally not compared numerically with the first two: it
uses a different retained reflection population. It verifies the normal
post-refinement execution path and CIF serialization. The generated archive
CIF contains `_refine_ls_abs_structure_Flack` together with
`_refine_ls_abs_structure_details` identifying the Parsons-quotient method
and its accepted-pair count.

The option was also run both enabled and disabled on the same converged IAM.
After normalizing only the job name and the intentional Flack CIF payload,
the fractional and Cartesian CIFs, HBB CIF, archive FCO, archive FCF, and FCF6
were byte-identical. With the option disabled, no Flack analysis appeared in
stdout and the corresponding CIF items remained unknown (`.`).

The tracked `flack_parsons` runtime invariant supplies four analytic P1
Friedel pairs with
$Q_{\mathrm{obs}}=0.6Q_{\mathrm{single}}$. It therefore requires
$x=(1-0.6)/2=0.200$, four selected pairs, and a valid zero-residual regression
uncertainty. The test also invokes the explicit analysis operation without a
separate enable keyword, guarding the standalone reanalysis interface.

**Conclusion.** The standalone final-FCF control reproduces the retained
SHELXL result within rounding and reports the same 1,083 quotients. The normal
refinement control shows that enabling the analysis does not perturb the
refined model or calculated reflections. This is the post-refinement Parsons
analysis recommended for absolute-structure reporting when Friedel pairs are
retained; it is not a replacement for explicit inversion-twin refinement
when a real inversion twin contributes to the diffraction model.

The equations and selection procedure follow [Parsons, Flack and Wagner
(2013)](https://doi.org/10.1107/S2052519213010014). The distinction between
post-refinement quotient analysis and full-matrix inversion-twin refinement
follows [Sheldrick
(2015)](https://doi.org/10.1107/S2053229614024218).

## Tonto regression-suite context

On 3 October 2026, the current Tonto tree passed **77/78** short tests,
including nonlinear least-squares solvers, SHELXL weighting, anomalous
dispersion, Parsons quotients, scale-tag-free Olex2-style Gram--Charlier CIF
input, strict D4-only anomalous-derivative isolation, both anharmonic PDF cube
checks, spherical external-basis import, and FILE47/WFN/WFX export. The
previously stale `nh3_rhf_DZP_HAR` and
compiler-sensitive `urea_ccsd_pob-TZVP_Salvador_properties` comparisons both
passed in this build.

The sole nonzero test was the environment-only `rgbi_doctor_selftest`: this
workstation still lacks the optional `pdfcrop` and `mol2chemfig` executables.
The failure does not exercise molecular, diffraction, dispersion or
anharmonic numerical code, but it is disclosed because 77/78 is not a clean
suite.

## Publication gates

Before reporting a new material or methodological conclusion:

1. reproduce the final calculation from a fresh directory and fixed source
   revisions;
2. converge molecular/periodic basis, atom grid, Poisson grid, k mesh,
   direct-lattice range, cluster/embedding radius, and numerical thresholds;
3. verify electron count, site symmetry, translation covariance, cell/atom/AO
   mapping, and reflection lifecycle;
4. compare a native interface with an independent/legacy prediction at λ = 0;
5. select XCW/observed-density regularization using held-out data, not the
   training R factor alone;
6. compare chemically meaningful geometry and ADPs with appropriate neutron
   or high-quality reference data, including temperature differences;
7. deposit original observations, exact inputs, cycle history, CIF/FCF, and
   executable/source provenance.

Passing the engineering tests makes a calculation auditable. It does not by
itself make a scientific interpretation correct.
