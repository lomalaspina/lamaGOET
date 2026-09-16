# Scientific principles

## From an IAM to Hirshfeld atoms

In an independent-atom model (IAM), the calculated structure factor is built
from spherical atomic form factors. Bonding and lone-pair redistribution are
not represented explicitly. In HAR, a quantum calculation supplies an
electron density $\rho(\mathbf r)$ appropriate to the current geometry and
environment. A stockholder partition assigns it to atoms:

$$
w_A(\mathbf r)=\frac{\rho_A^0(\mathbf r)}
{\sum_B \rho_B^0(\mathbf r)},\qquad
\rho_A(\mathbf r)=w_A(\mathbf r)\rho(\mathbf r).
$$

The atomic scattering factor is the Fourier transform of that aspherical
atomic density,

$$
f_A(\mathbf h)=\int \rho_A(\mathbf r)
\exp(2\pi i\,\mathbf h\!\cdot\!\mathbf r)\,d\mathbf r,
$$

and the crystal prediction combines the translated atoms and their displacement
factors. In a harmonic model this is schematically

$$
F_{\mathrm{calc}}(\mathbf h)=
\sum_A f_A(\mathbf h)T_A(\mathbf h)
\exp(2\pi i\,\mathbf h\!\cdot\!\mathbf r_A).
$$

Tonto refines the selected structural parameters against the observations.
Because those coordinates define the density calculation, lamaGOET then
recomputes the wavefunction/density and repeats. Reusing atomic form factors
from the first cycle would be scientifically wrong: the first geometry can
contain IAM-biased X-H distances and every accepted geometry defines a new
density.

## Molecular and periodic densities

A molecular HAR approximates the crystal environment with a finite molecule,
an explicit molecular cluster, self-consistent point charges/dipoles, or an
ELMO transfer. A periodic HAR obtains the density under lattice-periodic
boundary conditions from Crystal23 or all-electron CP2K. These approaches are
not interchangeable controls:

- molecular models require a chemically complete fragment and a defensible
  treatment of the surroundings;
- periodic models require a converged k mesh, periodic-safe all-electron basis,
  and a validated mapping of atoms, AOs, density, overlap, and phases into
  Tonto;
- changing the stockholder denominator from a finite cluster to a periodic
  procrystal changes the partition but not the underlying source density.

The standard finite model is labeled **cluster**. The periodic stockholder
uses symmetry-related proatoms throughout the periodic neighborhood. Report
which was used.

## Reflection lifecycle

When unmerged observations are supplied, the implemented order is:

1. retain an immutable copy of the full unmerged data;
2. apply the weak-observation cutoff to individual observations;
3. transform indices and merge according to the selected MERG rule;
4. calculate the model-specific structure factors;
5. prune systematic absences only when the current model predicts a zero; and
6. refine against the resulting set.

This preprocessing is repeated from the **full unmerged set** whenever a new
partition supplies new aspherical factors. A reflection can therefore leave or
re-enter when its current aspherical prediction changes. Residual-density and
final-artifact calculations repeat the same preprocessing instead of using the
raw unmerged data directly.

The important distinction is model dependence. A reflection such as 222 in
diamond may be absent for an IAM yet nonzero for an aspherical periodic model.
IAM pruning must use IAM predictions; HAR pruning must use the current
aspherical predictions.

## Refinement statistics

lamaGOET reports the statistics written by Tonto. Their numerical meaning
depends on the refined observable, weighting, cutoff, merge rule, extinction,
and number of refined parameters. For an amplitude refinement,

$$
R(F)=\frac{\sum_h\left|\,|F_o|-|F_c|\,\right|}
{\sum_h |F_o|},
$$

while a weighted residual and goodness of fit contain the supplied standard
uncertainties and the actual degrees of freedom. Do not compare a Tonto
F-refinement scale, $R$, or goodness of fit directly with a SHELXL $F^2$
refinement without first matching input normalization, selected observations,
weights, refined parameters, and correction models.

## Scale and extinction

For an F refinement without extinction, Tonto minimizes weighted residuals of
$k|F_c|-F_o$. The least-squares amplitude scale is

$$
k=\frac{\sum_h w_h |F_c|F_o}{\sum_h w_h |F_c|^2}.
$$

If intensities and their uncertainties are both multiplied by 100, amplitudes
and their uncertainties scale by 10 and the fitted amplitude scale changes by
10; dimensionless residuals should remain invariant. The retained Quartz
normalization control demonstrates this behavior.

Two extinction families are exposed:

- **Zachariasen (SHELXL/Larson)**: the established scalar correction used by
  the lamaGOET/Tonto path;
- **Becker-Coppens**: type 1 (mosaic-spread dominated), type 2 (particle-size
  dominated with a primary component), or mixed; Gaussian/Lorentzian mosaic
  distribution; isotropic/anisotropic nature.

The CIF Core dictionary requires mixed or anisotropic multiple coefficients to
be recorded in `_refine_special_details`, not compressed into the scalar
`_refine_ls_extinction_coef`. The mean path length is specimen-dependent; the
GUI default is an input convenience, not a calibrated crystal property.

## HAR, XCW, and XWR

HAR changes geometry and displacement parameters while recalculating a
theoretical density. XCW holds the chosen geometry fixed and variationally
optimizes a Tonto wavefunction under an X-ray restraint. XWR is their sequence:

```text
initial model -> HAR geometry -> fixed-geometry XCW
```

Periodic XCW likewise fixes geometry and ADPs, but optimizes k-resolved
periodic orbitals. It is not a CP2K/Crystal23 geometry refinement and it does
not turn a periodic HAR into an XCW by changing the SCF-program selector.

## Observed-density reconstruction

The experimental `oc-observed` path is available only with Tonto as the SCF
program. It combines an IAM prior with phased experimental residual information
under positivity, electron-count, smoothing, symmetry, and held-out-reflection
controls before stockholder partitioning. It is an ill-posed reconstruction,
not a unique experimental wavefunction.

Two motion conventions exist:

- **static** reconstructs an intrinsic density and applies independently
  refined ADPs in the diffraction forward model;
- **dynamic** reconstructs thermally averaged atom shapes and applies no second
  ADP factor. Coordinates and conventional ADPs are fixed to avoid an exact
  position/shape ambiguity.

The dynamic atom shape can generate atomic form factors and hence structure
factors, but it does not uniquely separate bonding, thermal motion, and static
disorder. Its parameters must not be reported as conventional ADPs.

## Reproducibility principle

An apparently lower R factor is not sufficient validation. A defensible result
requires, as applicable: basis and grid convergence, k-mesh convergence,
held-out reflections, symmetry checks, electron counts, phase-sensitive
controls, stable cycle convergence, physically interpretable geometry/ADPs,
and exact preservation of all inputs and versions. The validation appendix
states which of these gates were actually exercised for each retained test.
