# Curved-path atomic displacement model

:::{admonition} Experimental, explicitly selected model
:class: important
This chapter documents the native Tonto **planar** and **two-direction surface**
displacement models, checked against the implementation on 18 November 2026.
They do not replace conventional harmonic ADPs by default. The command-line
refinement is opt-in; lamaGOET currently provides a separate displacement-cloud
viewer, not a GUI selector that activates this refinement. The existing
**Refine anharmonic ADPs** control selects Gram–Charlier coefficients, not this
model.
:::

## What is being refined?

The selected atom has a normalized, non-negative distribution of displacements
about its refined mean position. A curved angular distribution supplies the
non-Gaussian part; a positive local Gaussian supplies additional broadening.
Both belong to **one atomic probability distribution**. Other atoms retain
their ordinary displacement treatment. The mean coordinates, allowed local
ADPs, angular parameters and diffraction scale are refined together.

The model is geometrically referenced to a selected pivot atom and an explicit
pivot image. It can describe an arc-like cloud, or bending in two transverse
directions. Its shape is not forced to be a banana, mushroom or ellipsoid.
Site symmetry can generate several related parts of the cloud.

This is an atomic displacement model, not a new electron-density model. It can
be combined with spherical IAM factors or, within the supported restricted
molecular interface, with a single frozen set of Hirshfeld atomic factors.
Changing the displacement distribution does not turn an IAM into a HAR.

It is **not** a phonon calculation, a whole-cell oscillator, a correlated-motion
model for all atoms, or a measurement of vibrational frequencies. No frequency
calculation is required. The pivot defines geometry, but this implementation
does not infer a joint time-dependent trajectory of the target and pivot.
Normal Mode Refinement (NoMoRe) instead uses a calculated lattice-dynamical
model and refines selected mode frequencies or their scale factors; the two
procedures are not equivalent. See [Butkiewicz et al.
(2025)](https://journals.iucr.org/m/issues/2025/01/00/pen5001/).

## Coordinates and the harmonic reference

All vector and tensor equations below use an orthonormal Cartesian frame.
Let $D$ map fractional coordinates to Cartesian coordinates and let
$\mathbf h=(h,k,l)^T$. Define the scattering vector in radians per unit length:

$$
\mathbf q=2\pi D^{-T}\mathbf h.
$$

Use consistent length units throughout. Tonto's native kernels use bohr;
the explicit pivot shift in the user namelist uses Å. Angles are in radians.
Crystallographic CIF $U^{ij}$ values must be transformed into Cartesian
covariances before using these equations; they are not interchangeable in a
non-orthogonal cell.

For displacement $\mathbf u$ about a mean atomic position, a conventional
Gaussian model is

$$
G(\mathbf u;U)=\frac{\exp[-\tfrac12\mathbf u^TU^{-1}\mathbf u]}
 {(2\pi)^{3/2}\sqrt{\det U}},\qquad U\succ0.
$$

Its characteristic function, the displacement factor in the structure factor,
is

$$
\Phi_G(\mathbf q)=\int G(\mathbf u;U)e^{i\mathbf q^T\mathbf u}\,d^3u
 =\exp(-\tfrac12\mathbf q^TU\mathbf q).
$$

Thus an ordinary ellipsoid specifies a second moment. A non-Gaussian
distribution can have the same second moment but a different diffraction
signature at larger scattering vectors. The distinction between a Gaussian
approximation, generalized displacement parameters and their coordinate
conventions follows the [IUCr ADP nomenclature
report](https://www.iucr.org/who-we-are/commissions/commission-on-crystallographic-nomenclature/published-reports/adp).

## Bond frame and angular coordinates

Let $\bar{\mathbf r}_t$ and $\bar{\mathbf r}_p$ be the target and pivot mean
positions, and let $\boldsymbol\Delta$ be the explicitly selected Cartesian
pivot-image shift. The code uses

$$
\mathbf b=\bar{\mathbf r}_t-(\bar{\mathbf r}_p+\boldsymbol\Delta),
\qquad \ell=|\mathbf b|,\qquad \mathbf e=\mathbf b/\ell.
$$

There is no automatic nearest-image wrapping. The selected pivot image must
remain the intended one throughout the fit.

For a user-supplied Cartesian reference vector $\mathbf a$, construct

$$
\mathbf v=\frac{\mathbf a-\mathbf e(\mathbf e^T\mathbf a)}
 {|\mathbf a-\mathbf e(\mathbf e^T\mathbf a)|},\qquad
\mathbf w=\mathbf e\mathbin{\times}\mathbf v,
$$

and rotate the transverse frame by the refined angle $\varphi$:

$$
\begin{aligned}
\mathbf t_1&=\cos\varphi\,\mathbf v+\sin\varphi\,\mathbf w,\\
\mathbf t_2&=-\sin\varphi\,\mathbf v+\cos\varphi\,\mathbf w.
\end{aligned}
$$

The reference is a coordinate chart, not a physical preferred vibration
direction. A nearly bond-parallel reference is singular and is rejected.
Derivatives include changes of this frame as either mean endpoint moves.

## Phase distribution and its Chebyshev interpretation

For the first transverse direction, the angular coordinate is

$$
\alpha(\theta)=A_1\cos\theta+B_1\cos2\theta+C_1\cos3\theta,
\qquad \theta\sim\operatorname{Uniform}[0,2\pi).
$$

The surface model adds an independent phase and transverse coordinate:

$$
\beta(\psi)=A_2\cos\psi+B_2\cos2\psi+C_2\cos3\psi,
\qquad \psi\sim\operatorname{Uniform}[0,2\pi).
$$

There are seven angular variables: the six coefficients and $\varphi$.
The planar model uses the first triple and $\varphi$, with $\beta=0$.
These coefficients are signed angles, **not** ADPs in Å$^2$, frequencies,
mode populations, or Gram–Charlier cumulants.

The identity $T_n(\cos\theta)=\cos n\theta$ permits the equivalent notation

$$
\alpha=A_1T_1(x)+B_1T_2(x)+C_1T_3(x),\qquad x=\cos\theta.
$$

Uniform phase implies the arcsine measure
$p(x)=1/[\pi\sqrt{1-x^2}]$ on $(-1,1)$, **not uniform sampling of $x$**.
The present code uses this cosine/first-kind representation. It does not use
second-kind Chebyshev or Legendre polynomials. Orthogonality of an angular
basis does not make the parameters uncorrelated after the nonlinear geometry,
site-symmetry average and diffraction fit.

The harmonic indices 1, 2 and 3 describe a chosen phase parameterization.
They do not establish a measured 1:2:3 frequency ratio. In particular, adding
$T_3$ is not equivalent to adding third-order Gram–Charlier terms. Finite-angle
geometry produces displacement moments of several orders even from a simple
angular function.

## Mean-preserving curved geometry

### Two-direction surface

Write $\rho=(\alpha^2+\beta^2)^{1/2}$ and
$\operatorname{sinc}\rho=\sin\rho/\rho$, with value 1 at zero. The unit direction is

$$
\mathbf n(\theta,\psi)=\cos\rho\,\mathbf e+
 \operatorname{sinc}\rho\,(\alpha\mathbf t_1+\beta\mathbf t_2).
$$

The phase average is denoted by angle brackets; for this surface it is the
normalized double integral over $\theta,\psi$. Define

$$
\mathbf m=\langle\mathbf n\rangle,\qquad
\mu=|\mathbf m|,\qquad \mathbf k=\mathbf m/\mu.
$$

The implementation uses the minimal proper rotation $Q$ taking $\mathbf k$
to $\mathbf e$. With $\mathbf d=\mathbf k\times\mathbf e$ and
$[\mathbf d]_\times\mathbf x=\mathbf d\times\mathbf x$,

$$
Q=I+[\mathbf d]_\times+
 \frac{[\mathbf d]_\times^2}{1+\mathbf k^T\mathbf e}.
$$

The centered displacement and bending radius are

$$
R=\ell/\mu,\qquad
\mathbf u_b(\theta,\psi)=R\,Q[\mathbf n(\theta,\psi)-\mathbf m].
$$

Consequently $\langle\mathbf u_b\rangle=0$ and

$$
\bar{\mathbf r}_t+\mathbf u_b
 =\bar{\mathbf r}_p+\boldsymbol\Delta+RQ\mathbf n.
$$

The bending component therefore lies on a sphere about the selected mean
pivot image while preserving the refined target mean position. Its radius
$R$ need not equal the mean bond length $\ell$: averaging a curved trajectory
shortens the vector between mean positions. This is why simply drawing an arc
of radius $\ell$ would not implement the same model.

### Planar limit

For $\beta=0$, let $c=\langle\cos\alpha\rangle$,
$s=\langle\sin\alpha\rangle$ and $\mu=(c^2+s^2)^{1/2}$. The implemented planar
expression is

$$
\mathbf u_b=\frac{\ell}{\mu}\left[
 \left(\frac{c\cos\alpha+s\sin\alpha}{\mu}-\mu\right)\mathbf e
 +\frac{c\sin\alpha-s\cos\alpha}{\mu}\mathbf t_1\right].
$$

It agrees with the surface construction in the zero-second-direction limit.
That limit is useful for evaluating factors, but a seven-variable refinement
started with an exactly zero second triple has unidentifiable columns.

### Domain and numerical integration

The surface guard requires

$$
\sqrt{(|A_1|+|B_1|+|C_1|)^2+(|A_2|+|B_2|+|C_2|)^2}<1.2\ \mathrm{rad}.
$$

For the planar model the corresponding sum is below 1.2 rad. This retains a
single-hemisphere domain for centering; it is not a physical amplitude limit
inferred from the experiment. The bond and reference must be nonzero, and the
reference's transverse projection must be at least 10% of its norm.

Uniform phase quadrature uses 128/256 points for the planar model and
$32^2/64^2$ points for the surface, with a possible $64^2/128^2$ retry.
Both values and derivatives must agree at the prescribed tolerances. Geometry
derivatives use complex-step differentiation; the structure-factor chain rule
also includes endpoint motion. Failed quadrature or invalid geometry is
rejected, not accepted after reducing numerical accuracy.

## Local broadening, positivity and double counting

Let $\boldsymbol\epsilon\sim G(0,U_{\rm loc})$, independent of the phase
variables, with $U_{\rm loc}\succ0$. The complete seed displacement is
$\mathbf u=\mathbf u_b+\boldsymbol\epsilon$, so

$$
P_{\rm seed}(\mathbf u)=
 \left\langle G(\mathbf u-\mathbf u_b;U_{\rm loc})\right\rangle.
$$

This is a positive, normalized Gaussian mixture with zero mean. It can be
asymmetric, curved or nearly ellipsoidal. Its covariance is

$$
U_{\rm seed}=U_{\rm loc}+\langle\mathbf u_b\mathbf u_b^T\rangle.
$$

The **bending component** has fixed radius; the complete cloud does not enforce
an exactly fixed instantaneous bond because it includes local Gaussian
broadening. Nor does it model the pivot's correlated instantaneous motion.

An ordinary harmonic ADP fitted to the data already attempts to represent the
atom's *total* displacement variance. Keeping that tensor unchanged as
$U_{\rm loc}$ and adding a new bending variance generally counts part of the
width twice. The solution is not to forbid both contributions: it is to fit
them as parts of a single distribution and report their sum. The input
acknowledgment `initial_covariance_is_local=.true.` makes this interpretation
explicit. No automatic subtraction or covariance clipping is performed.

Two independent Gaussian translations simply give
$U_{\rm total}=U_1+U_2$ and another Gaussian. Different frequencies alone do
not change that conclusion for a harmonic thermal Gaussian ensemble.
A weighted mixture of alternative Gaussians, or the nonlinear curved
construction above, is a different statistical model. A fixed-amplitude,
uniform-phase oscillator is also not the same ensemble as an equilibrium
harmonic Gaussian. These distinctions prevent attributing a non-Gaussian
fit automatically to collective harmonic cell vibrations.

## Special positions and crystal symmetry

Let $\mathcal G_t$ be the stabilizer of the target site. Its Cartesian
rotations are obtained from fractional rotations as $R_g=D S_gD^{-1}$, with
the further transformation to the selected fragment representative's frame.
The full site distribution is

$$
P_t(\mathbf u)=\frac{1}{|\mathcal G_t|}
 \sum_{g\in\mathcal G_t}P_{\rm seed}(R_g^{-1}\mathbf u).
$$

This averages **probability distributions, not coordinates**. Every orbit
member has the corresponding transformed pivot and path. The normalization
remains one; occupancy and crystallographic multiplicity are separate.
In particular, inversion removes odd displacement moments at an inversion
site, and a mirror or rotation can require several related arcs. A single
arbitrarily oriented banana is not permitted to break a special site's
symmetry.

The local Gaussian tensor must already obey the site symmetry. The code
rejects an incompatible tensor rather than silently changing it. The exported
total second moment is

$$
U_{\rm total}=\frac{1}{|\mathcal G_t|}\sum_g
 R_g\left[U_{\rm loc}+\langle\mathbf u_b\mathbf u_b^T\rangle\right]R_g^T.
$$

The existing native structural constraint Jacobian is retained. Appending
angular variables does not release fixed coordinates, symmetry-related ADPs,
or the isotropic-H constraints of other atoms. A two-direction surface is
therefore not an arbitrary unrestricted density on a special site.

## Structure factors and electronic density

For the seed distribution,

$$
\Phi_{\rm seed}(\mathbf q)=
 e^{-\mathbf q^TU_{\rm loc}\mathbf q/2}
 \left\langle e^{i\mathbf q^T\mathbf u_b}\right\rangle,
\qquad
\Phi_t(\mathbf q)=\frac{1}{|\mathcal G_t|}\sum_g
 \Phi_{\rm seed}(R_g^T\mathbf q).
$$

The single-atom contribution is schematically

$$
F_t(\mathbf q)=o_t f_t^{\rm static}(\mathbf q)
 e^{i\mathbf q^T\bar{\mathbf r}_t}\Phi_t(\mathbf q),
$$

where $o_t$ is occupancy. Tonto supplies the full crystal sum with the correct
symmetry transformations, multiplicities and electronic-factor mapping.
The equivalent duplicate stabilizer average is removed algebraically inside
that sum; it must not be applied a second time by a caller. Aspherical atomic
factors also require their correctly transformed electronic orientation.

In IAM, the static factors are spherical tabulated factors with the selected
dispersion treatment. In the supported frozen-density HAR extension, a
Hirshfeld partition is captured once. Its electronic shape translates as
mean coordinates change; it is **not rotated along the angular path**.
Thus this is a rigid translated-electronic-shape approximation, not a fully
coupled electronic response to bending. Complex dispersion is retained
separately; inversion must not reverse the sign of $if''$ by incorrectly
conjugating the whole atomic factor.

The normal molecular HAR command requires a converged restricted native SCF
in the same input, followed by one partition. There is no repeated SCF or
repartitioning during its structural trial steps. It is a one-cycle,
fixed-electronic-density refinement, not an outer self-consistent HAR and
not an XCW optimization.

## Objective, scale and numerical convergence

Let $I_h$ be the signed observed intensity, $a_h(\mathbf x)=|F_h(\mathbf x)|^2$
and $k>0$ the **intensity** scale. At fixed weights $w_h$, the objective is

$$
S(\mathbf x,k)=\sum_h w_h[k a_h(\mathbf x)-I_h]^2.
$$

The scale is profiled analytically at each geometry:

$$
N=\sum_h w_h a_h I_h,\qquad D_s=\sum_h w_h a_h^2,
\qquad k=N/D_s.
$$

A non-positive or undefined scale is rejected. Negative observations are not
discarded or replaced by positive values in this residual. Scale derivatives
are included:

$$
\frac{\partial k}{\partial x_j}=
 \frac{D_s\sum_h w_h I_h\,\partial_j a_h
       -2N\sum_h w_h a_h\,\partial_j a_h}{D_s^2},
\qquad
\partial_j a_h=2\operatorname{Re}(F_h^*\partial_jF_h).
$$

For sigma weights $w_h=1/\sigma_h^2$. The supported SHELXL-style law is

$$
w_h=\frac{1}{\sigma_h^2+(a_w P_h)^2+b_w P_h},\qquad
P_h=\frac{\max(I_h,0)+2k a_h}{3}.
$$

Here $a_w,b_w$ are weight-law constants, not angular coefficients. Weights
are **frozen during an inner trial comparison** and updated in the outer
iteratively reweighted least-squares procedure. A reweighted printed sum is
not the same function as the frozen trial objective and need not decrease on
every outer update. The implementation and the conventional weighting law
are distinct from claiming the same solver as SHELXL; see its [instruction
reference](https://shelx.uni-goettingen.de/shelxl_html.php).

The solver uses the native reduced structural Jacobian, scaled QR and
Levenberg–Marquardt trial steps. Only known crystallographic origin freedoms
are gauged out. Rank deficiency is not hidden by deleting arbitrary weak
parameters. Convergence requires both the undamped objective metric and
relative undamped step below $10^{-9}$, and outer relative weight change below
$10^{-8}$. Small damped steps alone are not success. A checked residual-curvature
correction can propose a Newton step in a weak nonzero-residual valley; it
does not waive full-rank, physical-domain or actual-descent checks.

The solver's damping parameter is numerical step control, **not** an XCW
experimental-restraint parameter. The new command performs joint refinement;
it does not implement the earlier proposed alternating cell-motion/ADP schedule.

## Uncertainties and identifiability

For a converged interior solution, the full joint weighted design includes
structural, angular and scale variables. In the supported independent
coordinates its local Gauss–Newton approximation is

$$
C_{\mathbf z}\simeq s^2(J^TJ)^{-1},\qquad
s^2=\frac{\sum_h w_h(k a_h-I_h)^2}{N_r-N_p}.
$$

The implementation uses a rank-checked factorization rather than relying on
this displayed inverse as a numerical algorithm. For any derived quantity
$\mathbf y$, including the selected atom's total second moment,

$$
C_{\mathbf y}=A C_{\mathbf z}A^T,\qquad
A=\partial\mathbf y/\partial\mathbf z.
$$

This propagation includes the local-U/angular/coordinate correlations.
Adding component standard uncertainties in quadrature while ignoring their
cross-covariances would not give the same result. Fixed-weight Gauss–Newton
errors are local approximations: they do not include all effects of
model-dependent weighting, systematic data errors, electronic-model error,
nonlinearity or model selection. They are not boundary confidence intervals.
Failed fits do not receive successful-fit uncertainty artifacts.

A full-rank design is necessary but insufficient for a well-determined shape.
Large angular uncertainties or strong parameter correlations can coexist
with a relatively precise total second moment. Phase/sign or direction
reparameterizations can also describe equivalent distributions. Compare
distributions, predictions and propagated moments, not coefficients alone.

There is no established universal resolution cutoff for this model analogous
to a chosen Gram–Charlier order. At small $\mathbf q$,

$$
\Phi(\mathbf q)=1-\tfrac12\langle(\mathbf q^T\mathbf u)^2\rangle
 -\tfrac{i}{6}\langle(\mathbf q^T\mathbf u)^3\rangle
 +\tfrac1{24}\langle(\mathbf q^T\mathbf u)^4\rangle+\cdots .
$$

Higher-shape information can therefore be weak when only the mean and second
moment are resolved. The angular $T_3$ parameter is not a third-order
displacement expansion, so Kuhs' order-based criterion cannot simply be
relabelled for it. Test directional coverage, precision, profile sensitivity,
resolution stability and held-out prediction; retain the full intended
reflection population for the final fit. For the established generalized-ADP
context see [Kuhs (1992)](https://doi.org/10.1107/S0108767391009510).

## How to run an opt-in refinement

### Prepare the input

1. Use a Tonto executable compiled with the experimental curved command.
   The build option is `TONTO_EXPERIMENTAL_CURVED_PATH=ON`; an ordinary older
   executable does not gain the model from opening a JSON file in lamaGOET.
2. Work in a **new output directory**. Keep the source CIF, observations and
   successful harmonic baseline unchanged.
3. Prepare ordinary Tonto `stdin` to read the crystal and the full intended
   $F^2$ observations, with the correct wavelength, dispersion, weights,
   atom identities, space group and hydrogen treatment. Do not also execute
   an ordinary harmonic fit or an outer HAR loop in that input.
4. Select one anisotropic target and a distinct pivot by their exact unique
   fragment labels. Check their Cartesian bond/image and choose a reference
   vector with a substantial component perpendicular to it.
5. Supply a physically sensible positive **local** starting covariance for
   the target. Other atoms keep their conventional ADPs. Use nonzero starts
   in both directions for a surface refinement and investigate more than one
   sensible start; the following numbers are an input illustration, not
   fitted values or a universal recommendation.

### Namelist and command

Save a separate `curved.nml`:

```fortran
&curved_adp
 ! One atomic distribution, not a whole-cell vibration.
 model='surface',
 electronic_source='iam',
 target_label='Cl1', pivot_label='Cu1',
 ! Three signed angular coefficients per direction, in radians.
 transverse_1=0.10,0.03,0.01,
 transverse_2=0.06,0.02,0.01,
 plane_angle=0.0,
 reference_cartesian=0.0,0.0,1.0,
 ! Cartesian shift ADDED to the pivot position, in Angstrom.
 pivot_shift_angstrom=0.0,0.0,0.0,
 initial_covariance_is_local=.true.,
 max_cycles=100, time_limit_seconds=3600
/
```

Run from that directory:

```sh
/path/to/validated/tonto --curved-adp curved.nml
```

Tonto reads the ordinary file named `stdin` in the working directory. For
`model='planar'`, only the first angular triple and the plane angle participate.
The run bounds are 1–10000 cycles and a positive time limit up to 86400 s;
reaching a bound is not convergence. Existing curved result files are refused
instead of being overwritten.

For the supported native single-cycle HAR, change
`electronic_source='molecular_hirshfeld'` and include a converged restricted
`rhf` or `rks` SCF in the ordinary input before capture. The complete basis-atom
list must match the refinement fragment, with no intervening change to basis,
geometry or density. The command checks actual finite orbitals, density,
energies and native convergence conditions; archive-only or unconverged input
is rejected. The separately audited external-wavefunction comparison in the
validation record used a library/test harness. It is **not** evidence that
the ordinary command accepts an arbitrary Gaussian archive.

### Restart and held-out evaluation

`initial_parameters='curved.accepted.parameters'` reads an exact structural
checkpoint and checks labels/order. Angular values still come from the
namelist and must be copied from the matching saved model. Keep the same
reference frame, pivot image, cell, symmetry and electronic provenance.
Do not restart from the total-U CIF and call its tensor the local covariance.

For a genuinely fixed-parameter prediction, use
`evaluation_only=.true., evaluation_scale=...`, supplying the positive
**intensity** scale learned on the training observations. This mode does not
refit scale to the evaluation set. `derivative_audit=.true.` is a diagnostic
allowed only with fixed evaluation. Evaluation status is distinct from
refinement convergence.

## Outputs and viewing the atomic shape

| Artifact | Interpretation |
|---|---|
| `curved.summary`, `curved.iterations`, `curved.trials` | Status, objective, convergence and trial history; inspect before using a model |
| `curved.accepted.parameters` | Exact structural/local-U checkpoint; not the total-U representation |
| `curved.model.json` | Reproducible distribution: model/status, nodes, weights, cell, identities, site operations, local and total moments |
| `curved.cif` | Conventional structural interchange; the target anisotropic tensor is the **total** second moment |
| `curved.factors`, `curved.fcf` | Factors calculated from the full curved distribution, not merely its equivalent ellipsoid |
| `curved.covariance`, `curved.uncertainty.json` | Labelled joint covariance and propagated total-moment errors for accepted converged interior fits |

Retain all artifacts together. A conventional CIF containing only the total
tensor cannot reconstruct the curved distribution. In the LIST6-style FCF,
calculated $F_c$ is an amplitude with the full model phase; measured $F^2$ and
its uncertainty are placed on the model scale by dividing by the fitted
intensity scale. Do not confuse that scale with its square root.

In lamaGOET, choose **Open displacement cloud…** and select
`curved.model.json`. This opens a separate view and does not change the loaded
CIF or activate a new refinement model. Select either:

- **Actual displacement probability cloud**, the non-Gaussian distribution; or
- **Equivalent second-moment ellipsoid**, a Gaussian with $U_{\rm total}$.

The enclosed-probability selector defaults to 50%. For the actual cloud the
contour level $c_p$ is chosen so that

$$
\int_{P_t(\mathbf u)\ge c_p}P_t(\mathbf u)\,d^3u=p.
$$

For the equivalent Gaussian, the corresponding ellipsoid satisfies
$\mathbf u^TU_{\rm total}^{-1}\mathbf u=\chi^2_3(p)$.
These are different surfaces even at the same $p$. A general non-Gaussian
contour can be non-ellipsoidal or disconnected. The viewer checks moments,
normalization, symmetry, numerical grid convergence and enclosed probability;
it refuses an invalid artifact. A displayed failed-fit cloud remains a failed
fit, not a validated structure.

A probability cloud describes the atomic displacement distribution, not
electron density and not a residual map. To compare residual maps, retain
identical reflections, electronic factors, phase convention, scale treatment,
grid, view and positive/negative electron-density isovalues. The same-looking
50% probability surface is not a substitute for a matched residual comparison.

## Limitations and validation checklist

Current supported scope is one selected target, planar or two-direction
geometry, $F^2$, one scale and zero fixed extinction. The target requires
anisotropic local U. Riding H, selected-target total-Uiso coupling,
Gram–Charlier/curved combinations and amplitude-subtraction dispersion are
not supported. Ordinary isotropic-H constraints on other atoms remain intact.
Periodic GRED/XML density capture, unrestricted/spin-polarized HAR capture,
multiple curved targets and a general collective-motion refinement are not
provided by this command. Unsupported combinations must fail explicitly.

Positive local covariance, geometry guards and rank checks are mandatory.
There is no certified physical-boundary inference: do not clip a covariance,
freeze an offending atom, change hydrogen treatment or relax tolerances just
to obtain a convergence label. Atomic Gaussian widths and angular shape can
be strongly correlated. Synthetic recovery and numerical convergence do not
prove that a real-data shape is uniquely determined.

IAM can confound an imperfect spherical electronic model with displacement
shape. Frozen HAR reduces that particular approximation but still neglects
electronic relaxation and orientation changes along the path. Absorption,
disorder, twinning, truncation, integration and scaling errors can also leave
structured residuals. An improved fit does not identify their physical cause.

Gram–Charlier is an essential separate comparator, not an automatically
invalid alternative. Its truncated probability density can have negative
regions, which must be measured and reported rather than clipped. Conversely,
positivity by construction does not prove the curved model's physical truth.
Use the existing signed-PDF tools described in {doc}`plots` for the
Gram–Charlier control and preserve the different model definitions.

For each scientific use:

1. Check an ordinary harmonic baseline and its site constraints.
2. Match data, weights, dispersion, electronic source and H treatment across
   harmonic, curved and any Gram–Charlier comparisons.
3. Require actual numerical convergence, positive local tensors, preserved
   symmetry and independent factor/statistics checks.
4. Inspect uncertainty, correlations, alternative starts and sensitivity to
   resolution and model choices. Where feasible, test held-out predictions
   without refitting their scale.
5. Inspect matched residual maps **and** the probability distribution; retain
   negative-PDF diagnostics for Gram–Charlier.
6. Report software/build identity, all model and quadrature settings, the
   pivot image/reference, electronic provenance and unresolved limitations.

The retained 18 November fixed-density HAR comparison used all 10,593
observations and the same audited Gaussian density for its two fits. The
harmonic and surface models gave $R_1=0.029659$ and $0.027870$, and
$wR_2=0.064986$ and $0.060319$, respectively. The Cl-local residual extrema
changed from approximately $-0.891/+1.058$ to $-0.237/+0.236$ e/Å$^3$ on the
matched map. This is a **reduction, not elimination**, of the residual pattern.
The second angular direction remained weakly determined. These results are
an implementation control, not a transferable guarantee, a fitted phonon
frequency or proof of a unique motion mechanism.

The large native molecular SCF attempted for that example did not converge;
the successful comparison used a separately validated external wavefunction.
The native-SCF diagnosis and a matched HAR Gram–Charlier comparison are
separate ongoing checks. Do not describe them as completed by the curved-fit
validation. The approximate uncertainty export also does not establish that
every legacy raw CIF uncertainty writer is free of numerical roundoff issues.

Despite inexpensive IAM atomic factors, this model evaluates angular
quadrature, geometry derivatives, symmetry and rank/convergence checks.
It can therefore be substantially slower than a harmonic IAM, especially in
a weakly identified valley. No SCF is hidden inside an IAM curved trial; a
single-partition HAR also reuses its captured factors during refinement.

Implementation provenance for this chapter is Tonto's
`native/curved_path` kernels, command, profile, covariance and artifact modules,
and lamaGOET's `adp_cloud` viewer. General ADP and NoMoRe references establish
their respective context; they do not independently validate this experimental
finite-angle model.
