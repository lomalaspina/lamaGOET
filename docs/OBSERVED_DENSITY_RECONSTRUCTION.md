# Observed-density reconstruction

Tonto observed-density refinement is available only when **Tonto** is the SCF
program and **Regularized observed density** is selected as the density model.

New lamaGOET jobs use **Constrained positive density prior (recommended)**.
This reconstruction:

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

The **Legacy residual / thermal-factor deconvolution** option remains available
only to reproduce older calculations. It partitions a thermally blurred
residual and divides the resulting atomic correction by the atom's temperature
factor. For weak hydrogen scattering this can amplify high-resolution noise and
couple the reconstructed density to the refined H ADP.

For small data sets, consider increasing **Held-out reflections** from 10% to
15--20%, while checking that enough work reflections remain for the structural
parameters. The work and held-out chi-squared sequences are printed in Tonto's
stdout for every reconstruction.

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

The constrained result is a regularized, model-phased density model. It is not
a unique experimental wavefunction or proof of a unique Kohn-Sham potential.
