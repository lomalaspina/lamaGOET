# Periodic Hirshfeld atom refinement

## Why a periodic interface is different

A periodic density is represented in an atom-centred basis repeated over
lattice translations and sampled in reciprocal space. Correct transfer into
Tonto requires more than atomic coordinates and an AO count. The interface
must preserve:

- crystallographic and program atom identities;
- element-specific shell definitions, contractions, normalization, and AO
  ordering;
- the unit cell and direct-lattice translations;
- overlap, density, and where required Fock/Kohn-Sham matrices;
- k points, weights, occupations, eigenvalues, and complex phases; and
- space-group covariance and site symmetry.

An apparently reasonable molecular test does not validate these contracts for
an extended solid. Off-cell density blocks can contribute strongly to bonding
while being weakly exercised in a small molecular crystal.

## Crystal23 interfaces

The **Crystal23 density interface** selector offers:

### Native GRED (recommended)

lamaGOET runs Crystal23 properties and passes the formatted
`<JOBNAME>.GRED` file to Tonto. The native reader imports Crystal23's
atom-resolved periodic basis and direct-lattice density representation rather
than asking Tonto to reconstruct it from a molecular-library basis name.

This corrected the historic failure mode in which a syntactically valid XML
contained a periodic density, but Tonto reconstructed it in an incompatible AO
space, shell/contraction order, or normalization. In diamond, the direct
Crystal23 prediction was already good before atom-centred reconstruction; the
loss appeared at this import boundary. The native path preserves the external
basis and all retained off-cell blocks.

### Legacy XML

The XML path remains available for reproducibility and compatibility. When an
external Crystal23 basis is written as `GEN` in the `.d12`, `GEN` is **not** a
Tonto basis-library name. The **Tonto reference basis for Crystal23 HAR** must
identify the genuinely matching Tonto representation. Do not select a merely
similar named basis.

Legacy XML is also a control path for diagnosing import differences. Its
continued presence does not make it the recommended production route.

## CP2K interfaces

The CP2K panel offers:

### Native CP2K (density, overlap and Fock)

The native path reads the CP2K `.mokp` orbital/basis description and formatted
real-space density, overlap, and Kohn-Sham/Fock CSR matrices directly in Tonto.
The implemented initial contract is restricted, all-electron GAPW with a
k-point calculation and current CP2K output support. CP2K's official manual
describes GAPW as the all-electron extension of GPW and `.mokp` as the
k-resolved MO interchange containing cell, atoms, basis/AO ranges, k points,
weights, occupations, eigenvalues, and complex coefficients.

The Fock/Kohn-Sham matrix is not reconstructed from occupied orbitals. Tonto
validates dimensions, mirror translations, electron trace, overlap
orthonormality, and the generalized orbital equation before refinement.

### Legacy XML bridge

The Python bridge remains selectable. It is retained for older CP2K/Tonto
installations and regression comparison. Native failures are not silently
converted to XML: an incomplete native data set must stop with a diagnostic.

## Periodic HAR sequence

For each outer cycle:

1. lamaGOET writes the current crystallographic geometry in the external
   program's crystallographic cell;
2. Crystal23 or CP2K converges the periodic SCF calculation;
3. a native GRED/CSR+MOKP or legacy XML representation is produced;
4. Tonto validates and imports the exact external basis/density;
5. Tonto constructs current Hirshfeld atoms with cluster or periodic
   stockholder denominator, applies site symmetry, recalculates atomic form
   factors, and performs `ha_fit`;
6. lamaGOET prints the maximum shift/s.u. and archives the cycle; and
7. the refined crystallographic geometry starts the next periodic SCF.

The final energy listed for a cycle is the periodic energy calculated
**after** that Tonto fit at the cycle's final geometry. The reported Δenergy is
that value minus the corresponding energy of the preceding geometry.

## Crystallographic cell preservation

The refinement operates in the input crystallographic cell and asymmetric
unit. A periodic program may internally choose a primitive representation, but
the imported atoms and density must map back to the CIF cell. A change from one
independent atom to two, a reordered equivalent atom, or an unmatched label is
an interface error, not a new refinement model.

Use **Rhombohedral setting** to resolve hexagonal versus rhombohedral axes when
the CIF alone is ambiguous. **Use Hermann-Mauguin symbol** selects the supported
symbol path. **Network compound outputs** activates the intended periodic
structure handling. **Reuse previous-cycle guess** requests the Crystal23
restart path; it affects efficiency, not the model definition.

## Basis-set requirements

All-electron is necessary but not sufficient. A periodic basis must avoid
pathological near-linear dependence in the actual lattice and must be imported
without losing contractions or off-cell support.

### Built-in and external bases

The Crystal23 menu suggests periodic-optimized POB families. External Basis
Set Exchange definitions are converted to Crystal syntax by lamaGOET, including
formal shell electron charges and a single final `99 0`. The converter preserves
separate S and P shells; it must not infer an SP shell from adjacency.

For any external basis:

- inspect the generated shell sequence and CHE values;
- confirm unit-cell neutrality in Crystal23;
- examine overlap eigenvalues and SCF conditioning;
- compare against a periodic-optimized basis; and
- demonstrate stability of structural and residual results.

`TOLINTEG=auto` uses Crystal defaults for built-in bases and a more accurate
screening tuple for external definitions. It cannot repair a fundamentally
linearly dependent basis. **LDREMO** deliberately removes low-overlap
eigenvectors and therefore changes the variational space; leave it blank unless
the basis has been diagnosed and the altered model will be documented and
validated.

For CP2K, **All-electron CP2K basis file** is parsed to populate the basis
selector. The selected basis must be all-electron and compatible with GAPW.
Converge both plane-wave cutoff and relative cutoff; an atom-centred basis alone
does not converge the auxiliary grids.

## Crystal23 advanced controls

| Control | Meaning and use |
|---|---|
| Maximum Crystal cycles | optional SCF cycle override; blank keeps the automatic/default route |
| BIPOSIZE | optional bipolar Coulomb-buffer length in words; use a value recommended by Crystal23's `GENBUD` warning |
| ILASIZE | optional ILA array dimension; it is a compile/runtime capacity control, not an accuracy parameter |
| SUPERCON | requests the Crystal23 `SUPERCON` route supported by the runner |
| SHRINK A/B | Crystal23 reciprocal-space shrinking factors; converge the k mesh for the target property |
| TOLINTEG | five integral-screening tolerances or `auto/default` |
| LDREMO | expert overlap-eigenvector removal threshold multiplier; blank disables it |

Some vendor binaries have compile-time maxima. Printing a larger ILASIZE in a
`.d12` does not make an executable compiled with a smaller maximum accept it;
use an appropriately built Crystal23 executable.

## CP2K controls

| Control | Meaning |
|---|---|
| XC functional | currently BLYP or PBE in the supported native path |
| k-point grid | three Monkhorst-Pack dimensions; converge explicitly |
| Cutoff / relative cutoff | GAPW auxiliary-grid controls in Ry; converge both |
| Maximum SCF cycles | CP2K electronic-iteration cap |
| SCF tolerance | `EPS_SCF` convergence threshold |
| Added MOs | virtual orbitals retained; `-1` requests all available for export and can be costly |
| Charge / multiplicity | unit-cell electronic state; validate supported spin restrictions |

The k mesh controls periodic sampling but does not explain a discrepancy inside
Tonto's form-factor reconstruction by itself. Separate timing of periodic SCF,
import, partition, and `Making F_pred` before attributing a slow fit to k-point
count.

## Stockholder model and site symmetry

**Finite HS atom cluster** uses the established finite stockholder denominator.
**Periodic unit-cell procrystal** sums neutral spherical proatoms over the
periodic lattice. Both partition the same imported periodic density. The
periodic choice is particularly relevant for extended networks; it does not
substitute an observed density or change Crystal23/CP2K itself.

The established `periodic` option is the neutral-proatom Hirshfeld model (H0).
H0 can nevertheless assign a non-integer
population and net partial charge to an atom because the periodic total density,
not the neutral proatom density, is being divided. Its outputs are therefore
environment-specific aspherical atom-in-crystal scattering factors, rather than
tabulated spherical integer-ion factors.

Do not confuse the periodic orbital basis with Tonto's stockholder-reference
library. For example, a Crystal23 input may use `POB-TZVP-REV2`; that basis is
written in the `.d12` file and the corresponding ordered basis functions and
density matrices are imported from GRED. The Tonto lines
`basis_directory=...` and `slaterbasis_name=Thakkar` select the spherical
free-atom densities used only to construct stockholder weights. `Thakkar` is
therefore not a replacement for, or reinterpretation of, `POB-TZVP-REV2`.

**Periodic Hirshfeld-I (experimental)** is the separate `periodic-hi` choice.
It iterates population-adapted neutral/+1/-1 Thakkar references inside every
partition while leaving the imported Crystal23 or CP2K source density
unchanged. The default maximum is 50 inner iterations, the fixed-point charge
tolerance is $5\times10^{-4}$ e (the convergence criterion used by Vanpoucke
*et al.*), and charge mixing is 0.5. It fails rather than
clamping when a required ion is unavailable or a charge leaves the supported
[-1,+1] interval. It may be useful for ionic crystals, but is not guaranteed to
improve refinement statistics and is not yet publication-validated. The
equations, physical interpretation, and validation requirements are given in
{doc}`principles` and {doc}`validation`.

After partitioning, Tonto applies the crystallographic site-symmetry treatment
so an atom on a special position produces a symmetry-compatible atomic density
and form factor. Optional per-atom cube output is a direct diagnostic: inspect
bonding/lone-pair deformation and verify symmetry-equivalent directions.

## Periodic wavefunction outputs

A conventional finite-molecule WFN/WFX or NBO `.47` file cannot exactly store
an infinite Bloch wavefunction. Select **Write the final CP2K/Crystal23
wavefunction as TREXIO** for the periodic state. Crystal23 orbitals are
reconstructed from compatible periodic overlap and Fock/Kohn-Sham matrices;
CP2K orbitals come from `.mokp` with the native Fock information.

The optional **finite all-electron crystal-cluster calculation** instead starts
a new finite Tonto SCF on an active region plus buffer and writes `.47`, WFN,
and WFX. It is an approximation, not a conversion. Inspect every generated
cluster, cap severed bonds only where chemically justified, and compare active
region properties over at least two buffer radii.

## Retained validation boundaries

The retained native-interface controls include:

- GRED versus XML byte/numerical equivalence for NH3, Quartz, Natrolite, and
  Diamond at matched geometry and basis;
- phase-sensitive complex-factor comparisons in centrosymmetric,
  non-centrosymmetric, and chiral cells;
- complete one-cycle `ha_fit` replays from 13,721 unmerged Diamond observations;
- native CP2K versus legacy XML final FCF/geometry/statistics for NH3
  (`R(F)=0.007280`, 81 reflections) and Diamond (`R(F)=0.005859`, 57
  reflections); and
- CP2K electron traces and generalized-eigenproblem residuals for genuinely
  complex k meshes.

These validate the tested import boundaries and regressions. They do not prove
basis/grid convergence for a new material or validate every open-shell,
functional, disorder, or relativistic case. The complete evidence and exact
numbers are in {doc}`validation`.

## Production checklist

1. Preserve the crystallographic cell and atom mapping.
2. Use the native interface unless reproducing/diagnosing the legacy path.
3. Establish basis, integral/grid, k-mesh, and SCF convergence.
4. Verify electron count, AO dimension, symmetry leakage, and phase-sensitive
   predictions.
5. Compare cluster and periodic stockholder only as a documented model test.
6. Compare against an IAM using identical observations, merge, cutoff, weights,
   scale, and extinction.
7. Archive GRED/KRED or MOKP/CSR inputs alongside all cycle results.
