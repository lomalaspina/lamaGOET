# Scientific principles

## From an IAM to Hirshfeld atoms

In an independent-atom model (IAM), the calculated structure factor is built
from spherical atomic form factors. Density deformation caused by bonding,
lone-pair formation, polarization, and charge transfer is therefore not
represented explicitly. In HAR, a quantum-mechanical calculation supplies an
electron density $\rho(\mathbf r)$ appropriate to the current geometry and
environment. A Hirshfeld stockholder partition then assigns that density to
atoms:

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

Tonto uses the resulting aspherical structure factors to refine the selected
structural parameters against the observations. Each accepted refinement cycle
produces a new geometry. Because those coordinates define the subsequent
quantum-mechanical calculation, lamaGOET regenerates the input, recomputes the
wavefunction or density, repartitions it, and calculates new structure factors.
The cycle repeats until both the electronic calculation and geometry have
converged. Reusing atomic form factors from the first cycle would be
scientifically wrong: the first geometry can contain IAM-biased X--H distances,
and every accepted geometry defines a new density.

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

The standard finite model is labelled **cluster**. The periodic stockholder
uses translated proatoms throughout the periodic neighbourhood. Report which
model was used.

### Periodic neutral-proatom Hirshfeld partition used by Tonto

The currently implemented **periodic** stockholder is a lattice-periodic form
of the original, neutral-proatom Hirshfeld partition (H0). For a lattice
$\Lambda$, atoms $B$ in a reference cell, nuclear positions $\mathbf R_B$, and
neutral spherical proatom densities $\rho_B^0$, its periodic procrystal is

$$
\rho_{\mathrm{pro}}^{\mathrm{per}}(\mathbf r)=
\sum_{\mathbf T\in\Lambda}\sum_{B\in\mathrm{cell}}
\rho_B^0(\mathbf r-\mathbf R_B-\mathbf T).
$$

The weight and density assigned to atom $A$ in the reference cell are

$$
w_A^{\mathrm{H0,per}}(\mathbf r)=
\frac{\rho_A^0(\mathbf r-\mathbf R_A)}
{\rho_{\mathrm{pro}}^{\mathrm{per}}(\mathbf r)},
\qquad
\rho_A^{\mathrm{H0,per}}(\mathbf r)=
w_A^{\mathrm{H0,per}}(\mathbf r)\rho_{\mathrm{per}}(\mathbf r).
$$

Tonto evaluates the lattice sum over the required periodic neighbourhood and
terminates negligible proatom contributions using its density-support/cutoff
criteria. The **cluster** and **periodic** choices use the same imported
Crystal23 or CP2K density; they differ in the denominator used to assign that
density to atoms. The current implementation uses fixed neutral spherical
reference atoms and does **not** update those references to the charges obtained
from the partition. It is therefore periodic H0, not periodic Hirshfeld-I. Where
the periodic procrystal is nonzero, the translated weights form a
partition of unity,

$$
\sum_{\mathbf T\in\Lambda}\sum_{A\in\mathrm{cell}}
w_{A,\mathbf T}^{\mathrm{H0,per}}(\mathbf r)=1,
$$

so recombining all translated atomic densities recovers the source periodic
density. This identity is an important implementation test.

Neutral reference atoms do **not** force the assigned atoms to be neutral. The
electron population and net charge of a partitioned atom are

$$
N_A=\int \rho_A(\mathbf r)\,d\mathbf r=f_A(\mathbf 0),
\qquad q_A=Z_A-N_A.
$$

Consequently, the present H0 factors can already contain charge transfer,
polarization, bonding density, and lone-pair deformation from the periodic
source density. They are environment-specific, aspherical atom-in-crystal
scattering factors with generally non-integer partial populations. They should
not be described as conventional tabulated spherical scattering factors for an
integer ion.

If all partitioned atoms were recombined at the same geometry without
atom-specific operations, a complete partition would reproduce the same total
density and structure factors irrespective of the stockholder definition. The
partition becomes consequential in HAR because atomic contributions are moved
with their nuclei, subjected to atom-specific displacement parameters and site
symmetry, and recalculated as the geometry changes. A different partition can
therefore change refined coordinates and ADPs without improving the underlying
Crystal23 or CP2K density itself.

### Experimental periodic Hirshfeld-I

Hirshfeld-I replaces the fixed neutral references by self-consistent proatoms.
At internal iteration $i$, a proatom density corresponding to the previous
atomic population is used in the periodic weight,

$$
w_A^{i}(\mathbf r)=
\frac{\rho_A^0\!\left(N_A^{i-1};\mathbf r-\mathbf R_A\right)}
{\displaystyle
 \sum_{\mathbf T\in\Lambda}\sum_{B\in\mathrm{cell}}
 \rho_B^0\!\left(N_B^{i-1};
 \mathbf r-\mathbf R_B-\mathbf T\right)},
\qquad
N_A^{i}=\int w_A^{i}(\mathbf r)\rho_{\mathrm{per}}(\mathbf r)\,d\mathbf r.
$$

Populations (or equivalently charges $q_A^i=Z_A-N_A^i$) are iterated until
self-consistency. Fractional populations require a defined interpolation
between charged reference atoms. This *inner population iteration* is distinct
from the *outer HAR cycle*, which recalculates the source density after the
crystallographic geometry changes. Vanpoucke, Bultinck and Van Driessche
formulated this construction for bulk periodic materials and described the
additional treatment needed for diffuse anionic references.

The experimental lamaGOET/Tonto implementation is selected explicitly as
`periodic-hi`; it does not replace `periodic` H0. It is currently restricted to
the imported periodic-density path used by Crystal23 and CP2K HAR. At each
inner iteration Tonto constructs a fractional-charge spherical reference by
linear interpolation between real neutral and adjacent integer-ion Thakkar
densities. With $q_A=Z_A-N_A$,

$$
\rho_A^0(q_A)=
\begin{cases}
(1-q_A)\rho_A^0(0)+q_A\rho_A^0(+1), & 0\le q_A\le 1,\\
(1+q_A)\rho_A^0(0)-q_A\rho_A^0(-1), & -1\le q_A<0.
\end{cases}
$$

Here positive $q_A$ denotes electron loss. H$^+$ is the physically correct
zero-electron limiting density. Tonto does not silently rescale a neutral
reference, clamp a charge, or extrapolate beyond this interval: a missing
required ion or $|q_A|>1$ is a fatal diagnostic. This fail-closed boundary is
important because an arbitrary neutral-density rescaling would change the
population without supplying the ionic radial relaxation that motivates
Hirshfeld-I. The Vanpoucke *et al.* formalism is not itself restricted to
$|q_A|\leq 1$; that bound is a limitation of this first implementation and its
currently validated adjacent-ion reference library. Extending it requires
additional normalized integer-ion radial densities and separate validation of
their diffuse tails.

Let $\widetilde q_A^i=Z_A-N_A^i$ be the charge returned by a new partition.
The next reference charge is damped as

$$
q_A^i=(1-\alpha)q_A^{i-1}+\alpha\widetilde q_A^i,
\qquad 0<\alpha\le 1,
$$

and convergence is assessed from the largest independent-atom fixed-point
residual $\max_A|\widetilde q_A^i-q_A^{i-1}|$. Symmetry equivalents share the
charge of their asymmetric-unit parent. Finite-grid populations are normalized
to the neutral crystallographic-cell electron count, so the multiplicity-
weighted cell charge remains zero. The converged weights are also used by the
optional per-atom Hirshfeld cube output.

For ionic and strongly polar crystals, periodic Hirshfeld-I is a scientifically
plausible extension: charge-adapted proatoms can assign the density between
cations and anions more consistently than neutral references and usually yield
larger, more chemically intuitive partial charges. It would still partition the
same periodic density, however, and is **not guaranteed** to lower an R factor or
improve coordinates and ADPs. Tests of iterative Hirshfeld partitions in HAR by
Chodkiewicz *et al.* found only small changes in agreement factors; some polar
X--H distances improved, while ADPs, standard uncertainties, and convergence
were often worse for Hirshfeld-I. Ionic crystals were not established as a
validated HAR use case in that study.

| Property | Periodic H0 | Experimental periodic Hirshfeld-I |
|---|---|---|
| Reference | fixed neutral spherical proatoms | population-adapted spherical proatoms |
| Assigned charge | yes; often modest partial charge | yes; often larger charge separation |
| Source density | unchanged | unchanged |
| Factors | aspherical atom-in-crystal | self-consistent charge-adapted atom-in-crystal |
| Status | established option `periodic` | opt-in `periodic-hi`; validation pending |

This option is an experimental method, not a recommended default. Its software
contract requires population and unit-cell electron-count convergence,
space-group/site-symmetry constraints, partition of unity, and recombined
$F_{\mathrm{calc}}$ checks. Publication-grade validation must compare H0 and
Hirshfeld-I against identical data, IAM controls, neutron geometry where
available, residual maps, and held-out reflections, with explicit tests on
genuinely ionic crystals. That validation plan is recorded in
{doc}`validation`; no improvement in refinement statistics is implied merely
by convergence of the inner charges.

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
re-enter the refinement when its current aspherical prediction changes (a
good example here is the 222 reflection in diamond). Residual-density and
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
refined parameters, and correction models, remembering that the weigting scheme
will always be different between the two.

## Scale and extinction

For an F refinement without extinction, Tonto minimizes weighted residuals of
$k|F_c|-F_o$. The least-squares amplitude scale is

$$
k=\frac{\sum_h w_h |F_c|F_o}{\sum_h w_h |F_c|^2}.
$$

If intensities and their uncertainties are both multiplied by 100, amplitudes
and their uncertainties scale by 10 and the fitted amplitude scale changes by
10; dimensionless residuals should remain invariant.

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
