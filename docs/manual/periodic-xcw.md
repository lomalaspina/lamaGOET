# Experimental periodic XCW

:::{admonition} Status
:class: warning
The periodic solver is an experimental fixed-geometry Tonto implementation.
Retained engineering tests establish import, symmetry, lambda-zero identity,
gradient response, and restart behavior for specific Diamond references. They
do not yet constitute publication-grade convergence or validation for an
arbitrary material.
:::

## Model and nomenclature

Periodic XCW optimizes k-resolved Tonto orbitals under an X-ray restraint while
holding atomic coordinates and ADPs fixed. It is selected in the **XCW** tab,
not by choosing a periodic HAR program. A Crystal23 or CP2K HAR followed by
this calculation is periodic XWR.

The current periodic reference is a neutral, restricted closed-shell
Crystal23 BLYP or PBE determinant. HF, hybrids, open-shell references, and a
CP2K-only periodic-XCW reference are not implemented.

## Why both GRED and KRED are required

Crystal23 supplies complementary representations:

- **GRED** contains the atom/basis mapping and the exact retained
  direct-lattice overlap, density, and Fock/Kohn-Sham blocks. It is the
  lambda-zero real-space density anchor.
- **KRED** contains the full-zone complex Bloch orbital state used as the
  variational periodic-XCW degrees of freedom.

A finite k mesh does not uniquely recover every retained direct-lattice block.
A direct inverse transform of the KRED projector contains Born-von Karman alias
sums. Therefore KRED cannot replace GRED at lambda zero. The implementation
starts from $P_0(\mathbf R)$ in GRED and applies only the inverse-transformed
projector change produced by XCW:

$$
P_\lambda(\mathbf R)=P_0(\mathbf R)+
\mathcal F^{-1}\!\left[P_\lambda(\mathbf k)-P_0(\mathbf k)\right].
$$

This preserves the exact external periodic density anchor while allowing a
controlled k-space variational response.

## Preparation sequence

1. lamaGOET fixes the selected input or final-HAR geometry.
2. It runs a fresh Crystal23 SCF/properties calculation at exactly that
   geometry and basis.
3. `NEWK` plus `CRYAPI_OUT` generates a matched GRED+KRED pair.
4. Tonto validates cell, mesh, electron count, occupations, overlap metric,
   projector idempotency/stationarity, time reversal, space-group covariance,
   and the direct-density reference.
5. Tonto constructs the periodic KS grid and verifies lambda-zero diffraction.
6. It follows the requested lambda path with damping and convergence checks.
7. Each accepted step writes a checkpoint and final crystallographic
   artifacts are rebuilt from the current reflection lifecycle.

For XWR after a CP2K HAR, step 2 still uses Crystal23 at the final CP2K
geometry. The native CP2K HAR import is not currently a compatible
periodic-XCW orbital/overlap/Fock reference.

## Controls

| GUI control | Meaning and validation requirement |
|---|---|
| Native reference functional | BLYP or PBE for the current restricted implementation |
| Crystal23/Tonto all-electron basis | one basis represented compatibly on both sides |
| Exact paired custom basis | explicitly stage a Crystal shell block and matching Tonto sidecar |
| Periodic KS grid | real-space grid used for periodic density/Hartree/XC response; converge it |
| Direct-density lattice radius | number of lattice shells retained in direct-density evaluation; converge it |
| Objective/projector tolerance | convergence gate for the constrained objective/projector |
| Old-iterate damping | fraction of the previous iterate retained; stabilizes but changes the iteration path |
| Maximum iterations per lambda | safety cap for each restraint point |
| Deterministic held-out reflections | excluded from fitting and used for selection/validation |
| Restart from checkpoint | require signature-compatible saved orbitals/projector/reference |
| Write restart checkpoint | persist accepted state after each iteration |
| Initial/step/maximum lambda | restraint path |

lamaGOET promotes a Becke accuracy below `extreme` to the validated minimum for
this path. That is an implementation floor, not a grid-convergence proof.

## Custom basis pairs

The common reference-basis selector is preferred. A custom pair is inseparable:

- the Crystal file must contain valid shell records and exactly one final
  `99 0` terminator;
- the Tonto sidecar must reproduce the same functions, contractions, order,
  normalization, and AO dimension; and
- Tonto rejects central-overlap or AO-count mismatch.

The retained 46-AO Diamond core-decontracted basis is an optional radial-
flexibility experiment, not a universal completeness target. The standard
36-AO periodic reference retains the full tested off-cell density and produced
the better matched Diamond lambda-zero statistics. AO count alone is not an
accuracy measure.

## Lambda-zero gates

Before any nonzero restraint, require:

- unchanged fixed coordinates and ADPs;
- no orbital/projector update at lambda zero;
- reproduced Crystal23/Tonto structure factors and fit statistics;
- negligible density-symmetry leakage;
- exact or quantified electron count and metric residuals; and
- identical results after a fresh run and a signature-checked checkpoint
  reload.

For the retained Diamond controls, matched IAM gave `R(F)=0.009500`. The
standard 36-AO lambda-zero reference gave `R(F)=0.005680`, while the optional
46-AO pair gave `R(F)=0.006054`. Both retained all 219 direct-lattice blocks;
182 were nonzero off-cell blocks. These values are regression evidence at the
specified settings, not transferable acceptance limits.

## Nonzero-lambda interpretation

The retained lambda=$10^{-6}$ engineering runs converged in three ordinary
iterations and produced nonzero occupied-virtual response while leaving
geometry and ADPs unchanged. They used an 8×8×8 periodic grid and no held-out
reflections; they establish mechanical response, not a scientifically selected
lambda.

For production work:

1. converge periodic Poisson and atom-centred grids;
2. converge direct-lattice radius and basis cutoff;
3. converge the Crystal23 k mesh and reference basis;
4. select lambda with deterministic held-out reflections;
5. repeat from a fresh, uninterrupted reference;
6. test origin/phase and symmetry covariance explicitly; and
7. report the complete lambda path and rejected models.

## Reflection lifecycle

For unmerged data, every periodic-XCW diffraction evaluation starts from the
immutable unmerged observations, cuts weak observations before merging,
applies the requested MERG rule, and then prunes current model zeros. The
retained Diamond MERG 4 control started each pass from 18,201 observations,
removed 1,628 systematic absences and 2,852 weak observations, and merged to
63 reflections. The same process was repeated for the XCW pass and final
artifacts.

## Outputs and restart safety

`periodic_XCW.<job-name>/` contains fixed-geometry CIFs, FCF/FCO, residual
density, projector/orbital checkpoints, lambda/convergence markers, basis and
k-point dimensions, electron count, and a reference signature. A checkpoint
is valid only when its geometry, cell, basis, k mesh, reference, and relevant
controls match. Tonto revalidates the terminal checkpoint against the current
gradient before accepting it.

Do not hand-edit the signature or mix GRED/KRED/checkpoints from different
geometries. A successful file read is not a valid restart.
