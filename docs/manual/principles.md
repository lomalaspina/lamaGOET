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
2. apply the target-specific weak-observation cutoff to individual
   observations ($F/u(F)$ for an $F$ target or $I/u(I)$ for an $F^2$ target
   with inverse-sigma weighting); a SHELXL-WGHT fit instead retains all merged
   observations and uses $I>2u(I)$ only for its reported `gt` subset;
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
refined parameters, and correction models, remembering that the weighting
scheme may also differ unless the objective and weighting are explicitly
matched.

## Nonlinear least-squares step solvers

The crystallographic model is nonlinear in atomic coordinates, displacement
parameters, scale, and (when selected) extinction parameters.  Tonto therefore
repeats two operations: it evaluates the current calculated structure factors
and their Jacobian, then solves the **full dense normal matrix** for a local
parameter step.  Calling the established algorithm *Gauss--Newton* does not
mean that it is a linear refinement or a diagonal approximation; it describes
the local linearization used to solve the nonlinear problem.

Three step controllers are available, without changing the selected $F$ or
$F^2$ objective or its weights:

- **Gauss--Newton** is the established Tonto default for harmonic refinements.
  lamaGOET emits no new solver keyword in this mode, preserving compatibility
  with older Tonto executables and established results.  The exception is a
  third- or fourth-order Gram--Charlier refinement: an unchanged/default
  Gauss--Newton selection is promoted to adaptive LM because an unguarded
  high-order step can leave the valid displacement model before the next
  objective evaluation.
- **SHELXL-style fixed damping** multiplies every diagonal normal-matrix
  element by $1+d/1000$ before inversion, where $d$ is `SHELXL_DAMP`.  If the
  largest structural shift/esd exceeds `SHELXL_LIMSE`, all structural shifts
  are scaled by the same factor.  Tonto profiles the overall scale separately,
  so it is not part of this cap.  A zero `SHELXL_LIMSE` therefore computes
  uncertainties but applies no structural shift.  This follows the published SHELXL `DAMP`
  definition; damping changes curvature-derived uncertainties, so final
  reportable uncertainties should come from a stable undamped cycle.
- **Adaptive Levenberg--Marquardt** solves
  $(J^T WJ+\lambda\,\mathrm{diag}(J^T WJ))\,\Delta x=J^TWr$.
  A trial is retained only when the complete nonlinear objective does not
  increase beyond its established numerical tolerance (including the existing
  iteratively reweighted $F^2$/SHELXL tolerance). Rejected trials are rolled
  back exactly and retried with a larger $\lambda$; accepted trials reduce
  $\lambda$. If no acceptable step is found
  within `LM_MAX_TRIALS`, Tonto stops at the last accepted model rather than
  leaving a materially uphill geometry. The final covariance is refreshed
  from the undamped curvature at that accepted geometry.

Fixed damping is useful when a known conservative step is wanted.  Adaptive
LM is preferable for an unstable or oscillatory starting model because it
tests the actual nonlinear objective rather than accepting every linearized
step.  Neither method repairs an incorrect model, reflection set, weighting
law, or near-singular parameterization.

For an anharmonic fit, lamaGOET uses at least 20 LM trial steps and 200 inner
fit iterations.  These are safety/convergence budgets, not a requirement that
all 200 iterations be used.  A deliberately selected SHELXL-style damped
solver remains available and is not replaced.

## Anharmonic atomic probability density

For an atom displaced by the Cartesian vector $\mathbf u$ with harmonic ADP
tensor $U$, the normalized harmonic probability density is

$$
P_0(\mathbf u)=
\frac{\exp[-\tfrac12\mathbf u^T U^{-1}\mathbf u]}
{(2\pi)^{3/2}\sqrt{\det U}}.
$$

Tonto evaluates the crystallographic Gram--Charlier expansion directly in
Cartesian coordinates as additive contributions,

$$
P^{(2)}(\mathbf u)=P_0(\mathbf u),
$$

$$
P^{(3)}(\mathbf u)=P_0(\mathbf u)
\frac{1}{3!}\sum_{ijk}U^{ijk}H_{ijk}(\mathbf u),
\qquad
P^{(4)}(\mathbf u)=P_0(\mathbf u)
\frac{1}{4!}\sum_{ijkl}U^{ijkl}H_{ijkl}(\mathbf u).
$$

The exported field is the sum of the terms selected in the GUI. Selecting all
three gives $P=P^{(2)}+P^{(3)}+P^{(4)}$; selecting only third or fourth order
gives the corresponding signed correction rather than a normalized
probability distribution. The refinement order and export order are separate
controls so that an already refined model can be decomposed without changing
its parameters.

Here the generalized Hermite tensors are formed from
$\mathbf v=U^{-1}\mathbf u$. For example,

$$
H_{ijk}=v_i v_j v_k-(U^{-1})_{ij}v_k
-(U^{-1})_{ik}v_j-(U^{-1})_{jk}v_i.
$$

The fourth-order tensor is evaluated with the analogous six single-contraction
and three double-contraction terms. This coordinate-free form avoids assuming
that $U$ is diagonal and uses the same Cartesian third- and fourth-order
quasi-moments as the refinement. The harmonic tensor must be positive
definite. A cube containing $P^{(2)}$ should integrate to one once the boundary
is large enough; an isolated odd correction should integrate to zero in the
infinite-domain limit. Discretization and a finite box control the remaining
error.

For a requested harmonic-reference probability $q$, Tonto solves for the
three-dimensional chi-square quantile $x_q$ from

$$
q=\operatorname{erf}\!\left(\sqrt{x_q/2}\right)
-\sqrt{\frac{2x_q}{\pi}}\exp(-x_q/2),
$$

and reports the symmetric contour pair

$$
\rho_q^{\pm}=\pm P_0(\mathbf 0)\exp(-x_q/2).
$$

These levels are metadata for visualization. They do not change the signed
grid values and they deliberately use the same probability for positive and
negative contours.

Because a finite Gram--Charlier series is not guaranteed to remain positive,
the cube writer preserves signed values. A substantial negative region is not
clipped: it warns that the fitted truncated probability model is unphysical or
poorly conditioned. These cubes describe nuclear positional probability, not
electron density. The convention follows the anharmonic probability-density
treatment in [XD/XDPDF, Chapter
11.3](https://www.chem.gla.ac.uk/~louis/xdworkshop/workshop/documentation/xd2006manual.pdf)
and the crystallographic ADP conventions of [Johnson
(1969)](https://doi.org/10.1107/S0567739469000325), [Kuhs
(1992)](https://doi.org/10.1107/S0108767391009510), and [Trueblood *et al.*
(1996)](https://doi.org/10.1107/S0108767396005697). MoleCoolQt/MolIso
`.face` files are triangulated isosurface meshes, not volumetric grids; they
are therefore useful visualization references but are not interchangeable
with Gaussian cube files or XD `.grd` data.

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

## Post-refinement absolute-structure estimate

For an acentric, noncentrosymmetric structure measured with useful anomalous
signal, lamaGOET can ask Tonto to estimate the Flack parameter *after* the
structural least-squares fit.  The implementation follows the intensity-
quotient method of [Parsons, Flack and Wagner
(2013)](https://doi.org/10.1107/S2052519213010014), rather than adding an
inversion-twin fraction to the structural normal matrix.

For each measured Friedel pair, let $I^+$ and $I^-$ be the observed
intensities and $I_c^+$ and $I_c^-$ the corresponding final calculated
intensities.  Tonto forms

$$
Q_{\mathrm{obs}}=
\frac{I^+-I^-}{I^++I^-},
\qquad
Q_{\mathrm{single}}=
\frac{I_c^+-I_c^-}{I_c^++I_c^-}.
$$

The observed-quotient uncertainty is propagated as

$$
u(Q_{\mathrm{obs}})=
\frac{2\sqrt{(I^+)^2u(I^-)^2+(I^-)^2u(I^+)^2}}
{(I^++I^-)^2},
$$

and the origin-constrained weighted slope is

$$
m=\frac{\sum_h w_h Q_{\mathrm{single},h}Q_{\mathrm{obs},h}}
        {\sum_h w_h Q_{\mathrm{single},h}^2},
\qquad
w_h=\frac{1}{u(Q_{\mathrm{obs},h})^2}.
$$

The reported parameter and standard uncertainty are

$$
x=\frac{1-m}{2},
\qquad
u(x)=\frac{u(m)}{2}.
$$

The implemented Parsons selections require both observations in a pair to
exceed $3u(I)$ and reject an observed Friedel difference whose magnitude is
greater than twice the largest calculated Friedel difference in the data set.
The calculated quotients come from the accepted final model, including its
active scale and extinction treatment.  Symmetry equivalents must first be
merged while Friedel opposites remain separate; in lamaGOET this is the
`MERG 2` contract.  Experimental anomalous-dispersion corrections must also be
enabled, because without meaningful $f'$ and $f''$ the quotient regression
cannot determine absolute structure.

This switch is deliberately diagnostic.  It does **not** refine $x$ together
with coordinates, ADPs, scale, or extinction; it does not change
$F_{\mathrm{calc}}$ or the residual-density map.  Sheldrick's discussion of
SHELXL explains why the Parsons post-refinement estimate is preferred for
routine absolute-structure reporting: placing $x$ in the full least-squares
matrix can substantially overestimate its uncertainty
([Sheldrick, 2015](https://doi.org/10.1107/S2053229614024218)).  A genuine
inversion twin with an intermediate fraction for which the twin contribution
must alter calculated intensities requires an explicit inversion-twin model;
the post-refinement checkbox is not a substitute.  The original definition of
the inversion parameter is given by [Flack
(1983)](https://doi.org/10.1107/S0108767383001762).  Controls and output fields
are cross-referenced in {doc}`gui-reference`, {doc}`options-reference`, and
{doc}`outputs`; the primary bibliography is collected in {doc}`references`.

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
