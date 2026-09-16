# Molecular Hirshfeld atom refinement

## Purpose and supported engines

Molecular HAR alternates an electronic-structure calculation on a finite
fragment with Tonto's stockholder partition and crystallographic least-squares
fit. The SCF-program selector determines the wavefunction producer and the
interchange format:

| GUI selection | Density/wavefunction route | Principal boundary |
|---|---|---|
| Tonto | native Tonto SCF | simplest and best-integrated molecular route |
| Gaussian | formatted checkpoint read by Tonto | Gaussian and Tonto methods/bases must be mutually interpretable |
| ORCA | Molden/ORCA-derived data | orbital convention and basis representation must be supported |
| OCC | formatted checkpoint | OCC output and requested method must be supported by the runner |
| ELMO database | transferred ELMOs, optional GAMESS-US overlap | protein/fragment-tail definitions require ELMO expertise |
| SC cluster optimization: Gaussian + Tonto | geometry optimization with refreshed cluster field | theoretical optimization, not a crystallographic HAR; see {doc}`sccc` |
| SC cluster optimization: ORCA + Tonto | as above through ORCA | theoretical optimization, not a crystallographic HAR |

Crystal23 and CP2K are periodic routes and are described in
{doc}`periodic-har`.

## Molecular HAR cycle

For an external molecular program, lamaGOET performs:

1. Tonto reads the CIF, symmetry, ADPs, and reflections and creates the
   chemically complete calculation fragment requested by the user.
2. The selected program computes the current molecular wavefunction.
3. Tonto reads that program's output, constructs Hirshfeld atoms, calculates
   aspherical form factors, preprocesses the observations, and performs
   `ha_fit`.
4. The cycle directory retains the electronic-structure input/output and
   Tonto input/output.
5. The refined geometry becomes the next electronic-structure geometry.
6. The loop ends when the maximum shift/s.u. is at or below `CONVTOL`, the
   maximum cycle limit is reached, or the guarded stationary-wavefunction test
   establishes that the external calculation is repeating.
7. A final theoretical calculation is run at the accepted final geometry, then
   Tonto calculates residual density and final artifacts.

The terminal prints `maximum shift/esd` after each fit cycle. Inspect the
cycle-wise geometry, energy, and residuals rather than relying only on the
final line.

With Tonto selected, the equivalent wavefunction/fit loop is performed inside
Tonto. lamaGOET still writes and preserves the complete input and result set.

## Preparing a meaningful fragment

If the asymmetric unit cuts through a molecule, select **Complete molecule(s)
in CIF with Tonto**. Tonto's `defragment` path creates the finite fragment used
by the electronic-structure calculation while the crystallographic asymmetric
unit remains the object refined.

The 3D viewer's manual grow modes serve a different purpose. They let the user
inspect and export a chosen starting fragment:

- **Complete fragments/molecules** follows connectivity;
- **Short contacts** includes neighbors within a user distance; and
- **van der Waals radii** uses radii plus a tolerance.

Export retains the source unit cell and symmetry. It does not convert the CIF
to P1. Tonto still refines the asymmetric unit after reading the exported
structure. Always inspect the export for duplicate atoms, incorrect disorder
components, or an unintended polymeric expansion.

## Method and basis

The method and basis boxes are editable. Their menus are conservative
program-specific suggestions, not an exhaustive statement of what an external
program can execute. lamaGOET also has to reconstruct atomic form factors in
Tonto, so an external method is suitable only when its exchange/correlation
content and the interchange file are supported at that boundary.

For Gaussian, the GUI canonicalizes legacy PBE aliases:

| User/legacy name | Gaussian route keyword |
|---|---|
| `pbe`, `pbepbe` | `PBEPBE` |
| `upbe`, `upbepbe` | `uPBEPBE` |
| `pbe0`, `pbe1pbe` | `PBE1PBE` |
| `upbe0`, `upbe1pbe` | `uPBE1PBE` |

Only choices known to have a matching Tonto treatment are suggested. The box
remains editable for experts, but entering a keyword does not implement a
missing Tonto functional.

### External and Basis Set Exchange definitions

Select **Input external basis set manually** to stage `basis_gen.txt`. The
Basis Set Exchange dialog selects an all-electron basis independently for each
element found in the loaded CIF. lamaGOET renders the syntax expected by the
selected program and writes one final program terminator, not one between
element blocks.

An all-electron definition is necessary because Tonto forms a total electron
density. Effective-core-potential valence-only bases are not equivalent. For a
molecular calculation, additionally verify:

- the basis covers every element and charge state;
- spherical/Cartesian shell convention matches the interchange file;
- contractions and normalization are preserved; and
- diffuse functions do not cause numerical instability.

## Crystal environment controls

### Self-consistent cluster charges

**Use SC cluster charges** surrounds the quantum fragment with charges
generated from the preceding Tonto description. The radius is in Å. **Complete
molecules** prevents the environmental construction from truncating neighboring
molecules. **Use dipoles** includes the supported multipoles. The ORCA-only
**Nuclear interaction** option requests the corresponding interaction in the
ORCA input.

The field is self-consistent only if the charges are regenerated as the model
changes. Compare a radius series and monitor whether central geometry and ADPs
are stable. A larger cluster is not automatically better if it introduces an
unbalanced boundary.

### Explicit molecules

**Use explicit cluster of molecules** adds complete quantum-mechanical
neighbors within the selected radius. It is more expensive than point charges
and can substantially change hydrogen bonds and polarization. Check the grown
cluster visually and test cluster-size convergence.

These environment controls are hidden for ELMOdb, Crystal23, and CP2K because
those workflows use different density/environment models.

## Reflection controls

**Write header** tells lamaGOET to describe whether the reflection values are
on F or F² and to pass the selected MERG code. For an unmerged data set, use a
code consistent with the anomalous-scattering treatment and intended Friedel
handling:

| MERG | Rule implemented by lamaGOET/Tonto |
|---:|---|
| 0 | retain every observation and original indices |
| 1 | transform to the standard setting but do not merge observations |
| 2 | merge space-group equivalents; keep Friedel pairs separate for non-centrosymmetric groups |
| 3 | merge space-group equivalents and Friedel opposites |
| 4 | as MERG 3 and suppress anomalous-scattering corrections (`f''=0`) |

The F/σ cutoff is applied to the individual observations before merging. The
current aspherical $F_{calc}$ determines model-zero/systematic-absence pruning,
and the immutable unmerged observations are revisited after every new
partition. See {doc}`principles` for the lifecycle.

## Refinement controls

### Global atom mode

- **positions and ADPs** refines both for ordinary atoms;
- **positions only** fixes ADPs;
- **ADPs only** fixes coordinates; and
- **dynamic shapes only** appears only for experimental dynamic observed
  density and fixes both conventional coordinates and ADPs.

### Selective constraints

**Refine nothing for atom labels** fixes the listed labels. **Refine these
atoms isotropically** replaces their anisotropic displacement treatment with
the isotropic path. Enter exact CIF labels separated in the syntax accepted by
the existing runner; retain the generated `stdin` as the authoritative record.

Hydrogen positions and ADPs are separately selectable; **H atoms isotropic**
uses isotropic hydrogen displacement parameters. An anharmonic model can be
requested for named atoms at third and/or fourth order. The number of
parameters grows quickly, so verify data resolution, parameter correlations,
positive density/probability behavior, and significance.

**Elongate X-H bond lengths** sets starting B-H, C-H, N-H, and O-H distances.
These are starting-geometry controls, not restraints on the final HAR unless a
separate constraint is explicitly generated.

### IAM controls

**Start with Tonto IAM** provides an IAM fit before the aspherical cycles.
**Only perform Tonto IAM** is a control calculation and must not be presented
as HAR. An IAM comparison is strongly recommended because it checks reflection
processing and provides the baseline that the aspherical model is expected to
improve or explain.

## Convergence and safeguards

`Maximum shift/s.u.` is the structural stopping criterion. `Maximum HAR
cycles` is a safety cap, not a convergence criterion. The advanced energy and
SCF-RMSD tolerances detect a repeating external wavefunction, including a
two-cycle numerical oscillation caused by limited geometry precision. When the
wavefunction has demonstrably stopped changing, lamaGOET proceeds to final
residual calculation rather than consuming cycles indefinitely.

Do not lower thresholds merely to force termination. Inspect whether:

- the same geometry alternates at printed precision;
- the electronic energy and SCF RMSD repeat within configured tolerances;
- the largest shift belongs to a weak/disordered/anharmonic parameter; and
- the final residuals and geometry are stable over the last cycles.

## Experimental and extinction corrections

**Apply experimental dispersion correction** requests the Tonto experimental
dispersion treatment. This is distinct from Gaussian's **Use Grimme dispersion
(GD3BJ)**, which modifies the electronic energy/model.

**Refine extinction correction** exposes Zachariasen or Becker-Coppens. For
Becker-Coppens, select type, mosaic distribution, isotropic/anisotropic nature,
and the absorption-weighted mean path length. See {doc}`principles` and the CIF
reporting rules in {doc}`outputs`.

## Acceptance checklist

Before reporting a molecular HAR:

1. confirm chemical completeness and charge/multiplicity;
2. match every external atom and AO to the Tonto import;
3. compare IAM and HAR on the same reflection set and weights;
4. demonstrate fragment/environment and basis stability;
5. verify cycle convergence and positive, physically oriented ADPs;
6. inspect residual-density extrema and chemically meaningful features; and
7. archive all generated inputs, external outputs, `stdout`, `.lst`, CIF, and
   FCF/FCO files.
