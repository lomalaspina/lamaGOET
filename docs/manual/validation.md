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

On 20 September 2026, `bash Tests/run_all.sh` completed **27 test files: 27
passed, 0 failed, 0 skipped** on Linux x86-64, Bash 5.2.21, using the
repository `.venv-qt` Python. The suite included six shell tests and twenty-one
Python tests.

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
| Documentation option contract | A GUI/schema option is added without a manual definition | All 204 canonical `OPTION_DEFAULTS` keys occur in the option reference |

The suite does not invoke licensed programs and does not prove numerical
equivalence of a fresh HAR. Live scientific calculations remain opt-in.

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
| Chiral Quartz | GRED and XML FCF files identical |
| Non-centrosymmetric Natrolite | GRED and XML FCF files identical; complete CIFs; empty stderr |
| Diamond static prediction | R(F) 0.068526; R(F²) 0.104435; Rw(F) 0.092063; Rw(F²) 0.209767; GoF² 996.600747; extinction 2.972074; scale 1.013156 |
| Diamond 46-AO periodic XCW at λ=0 | GRED+KRED and XML+KRED FCF identical; R(F) 0.006054; R(F²) 0.012090; Rw(F) 0.005287; Rw(F²) 0.010640; GoF² 3.287344 |

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

## Observed-density reconstruction

**Question.** Does the constrained update incorporate chemically relevant
low-order residual density without producing non-positive H ADPs or selecting
the model only on training reflections?

**Design.** The NH3 measured data, Becke grid, structural flags, deterministic
10% R-free split (8 reflections), cube grid, and iteration limit were fixed.
The old inverse-σ step was compared with reliability preconditioning
`F²/(F²+σF²)`, positivity/electron-count projections, phased targets,
backtracking, and held-out one-standard-error selection.

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

## Tonto regression-suite context

Dated Tonto validations also ran focused and short suites. The most recent
native CP2K snapshot reported 63/67 short tests passing. Four existing failures
were retained and named: the optional RGBI doctor, two NH3 reference-output
alignment tests, and one compiler-dependent urea property tolerance. The
native Crystal23 snapshot reported 62/66 with the same four categories.
These nonzero failure counts are disclosed because “most tests passed” is not
equivalent to a clean suite; none selected the newly tested interface, but
they remain maintenance work.

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
