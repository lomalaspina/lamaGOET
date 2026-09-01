# Observed-density reconstruction

Tonto observed-density refinement is available only when **Tonto** is the SCF
program and **Regularized observed density** is selected as the density model.

New lamaGOET jobs use **Constrained positive density prior (recommended)**.
The default motion treatment is **Static density + independently refined ADPs
(recommended)**. In this conventional interpretation the reconstructed atomic
form factors describe static electron density, and each atom's harmonic
temperature factor is applied once in both the diffraction forward and adjoint
operators. The reconstruction:

- places each atom's current harmonic ADP inside the diffraction forward and
  adjoint operators;
- never divides a partitioned residual by a small atomic temperature factor;
- projects the reconstructed density onto nonnegative values;
- preserves the crystallographic electron count;
- damps unsupported high-resolution corrections; and
- validates density iterations using deterministic held-out reflections that
  are excluded from both density reconstruction and geometry refinement.  An
  iterate is admissible when its held-out reduced chi-squared is within one
  sampling standard error of the IAM-prior baseline; among admissible iterates,
  Tonto retains the one with the lowest work-set chi-squared.

## Experimental dynamic atom shapes

The alternative **Dynamic thermally averaged atom shapes (experimental)**
uses each reconstructed atomic Fourier coefficient directly:

```
static:   F(h) = sum_a T_a(h) g_a(h)
dynamic:  F(h) = sum_a        g_a(h)
```

Here `g_a(h)` is the Fourier transform of the stockholder-partitioned atomic
electron density. In dynamic mode its shape can contain bonding polarization,
thermal smearing and unresolved static disorder together. lamaGOET therefore
does not apply an ADP again, which would count thermal motion twice.

A dynamic atom is a time-averaged **electron-density contribution**, not a
probability distribution for the nucleus and not literally the probability of
finding an atom at a point. Obtaining a nuclear positional distribution would
require a separate electron--nuclear motion model, normally supported by
additional neutron or diffuse-scattering information.

Dynamic mode is intentionally restricted to the constrained reconstruction.
lamaGOET selects and writes the following safe combination automatically:

- keep atom-centre coordinates fixed;
- do not refine harmonic ADPs, H `U_iso`, or third-/fourth-order anharmonic
  displacement terms;
- use in-memory structure factors; and
- retain the global scale and, when requested, the supported extinction
  parameters.

The density shape is updated by Tonto's regularized outer reconstruction; it is
not a set of unconstrained grid values in the inner least-squares fit.
Occupancies should remain fixed because occupancy, integrated atom density and
the global scale are not separately identifiable in the present model.

There is an exact position--shape gauge freedom: translating an atom centre and
applying the opposite phase translation to its shape describes the same
structure factor. Held-out reflections cannot distinguish two exactly
equivalent parameterizations. The initial implementation therefore fixes all
reference coordinates and assigns supported spatial changes to the reconstructed
electron-density shapes. A future coordinate-refining variant would need an
explicit first-moment/centring constraint before its coordinates could be
interpreted.

The dynamic calculation bypasses Tonto's structural least-squares matrix.
Scale and the selected extinction model are optimized directly while the
density is reconstructed. Phase-updated outer cycles stop when the RMS complex
change in `F_calc`, normalized by `sigma(F)`, is below the GUI convergence
tolerance; the GUI maximum-cycle value is the safety limit. This is deliberately
different from a conventional maximum coordinate-shift/ESD test.

The **Legacy residual / thermal-factor deconvolution** option remains available
only to reproduce older calculations. It partitions a thermally blurred
residual and divides the resulting atomic correction by the atom's temperature
factor. For weak hydrogen scattering this can amplify high-resolution noise and
couple the reconstructed density to the refined H ADP.

For small data sets, consider increasing **Held-out reflections** from 10% to
15--20%, while checking that enough work reflections remain for the structural
parameters. The work and held-out chi-squared sequences are printed in Tonto's
stdout for every reconstruction.

Held-out validation is mandatory for both motion treatments and especially
important for dynamic shapes. A lower work-set residual alone is not evidence
that a flexible time-averaged atom shape is chemically meaningful. Report the
held-out behavior and test sensitivity to the stockholder choice and reasonable
regularization settings.

Iteration zero is the positive IAM prior. A message saying that validation
selected iteration zero means that no observed-density correction was
supported for that outer cycle; it must not be reported as a successful
experimental-density reconstruction. Selection of the last allowed iteration
means that increasing the reconstruction-iteration limit should be tested.

With **Output Hirshfeld atoms after partition** enabled, constrained jobs write
the neutral prior, signed accepted observed deformation, and final positive
atomic density as separate unit-cell cubes. These cubes replay the accepted
reconstruction on the regular grid rather than interpolating the quadrature
points. Supplying an atom label is strongly recommended for large structures
because exact replay for every independent atom is intentionally expensive.

Dynamic jobs use filenames containing `dynamic_IAM_prior`,
`dynamic_observed_update`, and `dynamic_Hirshfeld_atom` to prevent these cubes
from being mistaken for static-atom densities. The neutral IAM starting prior
is static and unsmeared even in dynamic mode; it is only a positive initial
guess. The current cluster and periodic stockholder weights also use the
existing static neutral proatoms rather than thermally averaged proatoms. Both
choices are explicit model limitations and potential sources of prior
dependence, particularly for light atoms or large/disordered motion.

The constrained result is a regularized, model-phased density model. It is not
a unique experimental wavefunction or proof of a unique Kohn-Sham potential.
The dynamic result should be described specifically as an experimental,
regularized time-averaged electron-density model; it cannot be converted into
conventional ADPs without introducing and validating an additional motion
decomposition.

The generated `job_options.txt` records the choice as
`OBSERVED_DENSITY_MOTION_MODEL=static` or `dynamic`. If options are edited by
hand, the runner and Tonto both reject a dynamic request combined with legacy
reconstruction, coordinate refinement, ADP refinement, H `U_iso`, anharmonic
displacement refinement, or disk structure factors instead of silently
changing the scientific model. `POSONLY=true` is written only as the existing
Tonto switch that suppresses ADP columns; the dynamic operator itself suppresses
the remaining coordinate derivatives.
