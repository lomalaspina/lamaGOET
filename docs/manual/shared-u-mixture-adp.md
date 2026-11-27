# Shared-U two-Gaussian displacement mixture

:::{admonition} Model A — experimental opt-in
:class: warning
This is a new positive displacement model, not chemical disorder support or
a replacement for ordinary ADPs. Its component mathematics has numerical
validation. Native command, joint covariance, exact restart, model-aware
CIF/FCF and GUI routing have synthetic end-to-end validation. Select
**Shared-U two-Gaussian mixture (experimental)** with a capability-enabled
Tonto executable; ordinary builds need not include the command. This does
not establish reliable global parameter uncertainties on measured data.
The read-only cloud viewer is available independently.
The shared-phase Lissajous route and Multi-harmonic angular ADP are unchanged.
:::

## Centred probability and characteristic function

The refined atom position remains the mean. For a positive-definite local
Gaussian covariance $U$ and separation vector $d$, define

$$
P(u)=w\,\mathcal N(u;(1-w)d,U)
 +(1-w)\,\mathcal N(u;-wd,U),\qquad
w=\frac1{1+e^{-s}}.
$$

Both component probabilities are positive and sum to one; their weighted
means cancel. This is a mixture of **alternative positions**, not the sum of
two simultaneous Gaussian displacements. The latter would remain Gaussian.
The mixture weight is an atom-specific displacement probability, not a
chemical site occupancy or a probability for a complete disorder component.

In orthonormal Cartesian coordinates, Tonto uses bohr internally and
$q=2\pi D_{\rm cell}^{-T}h$, so the displacement factor is

$$
\Phi(q)=e^{-q^TUq/2}
 \left[w e^{i(1-w)t}+(1-w)e^{-iwt}\right],\qquad t=q^Td.
$$

The model has four shape parameters, $(d_x,d_y,d_z,s)$, plus six local-U
parameters at a general position: ten displacement parameters in total.
It does not require a bond direction. The default numerical starting value
is $w=0.3$, $|d|=0.1$ Å along the largest principal axis of starting U, with
alternative directions and starts tested. This is an initialization, not a
restraint or a universal optimum. Separate component covariances $U_1,U_2$
would define a distinct 16-parameter extension; that extension is not enabled.

## Moments and site symmetry

Put $b=w(1-w)$. Before site averaging,

$$
U_{\rm total}=U+bdd^T,\qquad
K_3=b(1-2w)d^{\otimes3},\qquad
K_4=b(1-6b)d^{\otimes4}.
$$

Thus a non-equal-weight mixture can represent a uniaxial third cumulant
without ten independent Gram–Charlier third-order coefficients. The
special-site distribution is the complete probability orbit

$$
\Phi_G(q)=\frac1{|G|}\sum_{R\in G}\Phi(R^Tq).
$$

Local U must already be positive definite and site compatible; it is never
clipped. The total covariance and third cumulant are averaged over the orbit.
For the fourth cumulant, first average the fourth moments, then subtract the
three pairwise products of the averaged covariance. Averaging seed fourth
cumulants alone is generally incorrect. Inversion-site averaging removes
all odd moments, so seed skewness cannot survive there.

## Derivatives, canonical labels and uncertainty

Writing $e_1=e^{i(1-w)t}$, $e_2=e^{-iwt}$ and
$B=we_1+(1-w)e_2$, the analytic shape derivatives are

$$
\frac{\partial\Phi}{\partial d_j}
 =e^{-q^TUq/2}\,iq_j b(e_1-e_2),\qquad
\frac{\partial\Phi}{\partial s}
 =e^{-q^TUq/2}\,b(e_1-e_2-itB).
$$

The six U derivatives have coefficients
$(-q_x^2/2,-q_y^2/2,-q_z^2/2,-q_xq_y,-q_xq_z,-q_yq_z)$ multiplying $\Phi$,
in order $U_{11},U_{22},U_{33},U_{12},U_{13},U_{23}$.
Site averaging applies to derivatives as well as factors.

$(w,d)$ and $(1-w,-d)$ are identical distributions. Refinement should stay in
its smooth chart; reporting uses $w\le1/2$. When a report changes labels,
$(d,s)\mapsto(-d,-s)$ and its covariance must transform consistently. At
$w=1/2$, both labels already satisfy the convention; no artificial singularity
or extra directional restriction should be introduced.

At $d=0$ the mixture is exactly Gaussian and the weight column vanishes;
the separation columns also vanish to first order. Equal weights alone are
not a singularity: departure from equal weights can encode skewness. Actual
weighted sensitivity singular values determine identifiability and ESDs.
At or near numerical endpoint weights, information can also be weak. No
parameter is silently removed to obtain a full-rank result.

The uncertainty export retains the joint scale, coordinates,
local-U and shape covariance. The propagated total-U covariance is

$$
C_{U_{\rm total}}=J_U C_{\rm joint}J_U^T,
$$

including local-U/shape cross terms, not a sum of separate error estimates.
A total-U CIF is not an exact local-U restart. Failed or rank-deficient fits
must not receive invented ESDs.

## Interpretation and validation limits

Positive probability prevents the negative-density issue of a truncated
Gram–Charlier expansion. It does not by itself prove a good fit, sufficient
resolution, unique parameters, or a physical mechanism. A single-temperature
Bragg experiment cannot generally distinguish a double-well potential,
dynamic hopping and static two-site disorder from this average alone. The
[IUCr ADP nomenclature report](https://www.iucr.org/who-we-are/commissions/commission-on-crystallographic-nomenclature/published-reports/adp)
explicitly includes static displacements within the ADP concept.

The isolated tests compare analytic derivatives with high-precision complex
steps, moments with independent probability averages and small-q differences,
and Fourier factors with million-sample Monte Carlo ensembles. Positive-grid
integrals are checked at two spacings without clipping or renormalization.
Native noiseless recovery, matched full-data refinements and conditional
five-fold prediction have also been tested in isolated development harnesses.
The interface checks do not replace those scientific tests. In the noisy synthetic pilot,
some fits failed to converge and local three-ESD intervals did not reliably
contain the generating shape parameters. A full-rank covariance therefore
must not be presented as a calibrated global confidence region.

Report compatible joint distributions, not just a population estimate.
Population, separation, local covariance and mean coordinates can compensate
for one another. A two-component mixture can even have a **single** density
maximum. Confidence profiles must refit nuisance parameters and scale under
the specified weighting rule; a conditional scan with geometry fixed answers
a narrower question. Resampling linearized residuals is not equivalent to
fully reoptimizing every realization. These limitations are unchanged by
cleaner residual lobes or improved held-out prediction.

## Using lamaGOET and the native command

1. Choose **Shared-U two-Gaussian mixture (experimental)** in the opt-in
   displacement-model box and enter one asymmetric target label. No bond,
   pivot or reference direction is required. Additional angular targets must
   be cleared explicitly; this route currently supports one target.
2. Keep the defaults or expand **Edit starting values** to change population,
   separation length, or the explicit Cartesian separation vector. Automatic
   direction uses the largest principal axis of local U only as a start.
   Refinement does not constrain the separation to that initial direction.
3. Confirm that the starting anisotropic tensor is **local Gaussian U**.
   Select F² and sigma or SHELXL weights, a finite iteration/time bound and
   a new output subdirectory. Failed or rank-deficient fits remain failed.
4. Select IAM (no SCF), or the supported single-density molecular HAR route.
   That route requires a complete nonrelativistic, unembedded singlet fragment
   and one converged native restricted RHF/PBE/BLYP/B3LYP SCF. It is not the
   periodic or repeated outer-HAR loop. Riding H, extinction, XCW and
   simultaneous Gram–Charlier are rejected.

The runner verifies `--positive-adp` in the executable's help before creating
the result directory. Missing capability is an error, never a fallback to
ordinary ADPs. Jobs retain the chosen reflection, merging, dispersion and H
settings, use one thread and a 10 GiB address-space limit, and never overwrite
an old result. The native solver is independent of the ordinary solver widget.

For native use, supply normal CIF/reflection setup in `stdin` and run
`tonto --positive-adp model.nml`. A minimal mixture namelist is:

```fortran
&positive_adp
 model_kind='mixture', target_label='Cl1',
 initial_covariance_is_local=.true., electronic_source='iam',
 max_cycles=100, time_limit_seconds=3600
/
```

`positive.summary` is authoritative. A missing summary means the output is
incomplete, even if other files exist. `positive.model.json` supplies the cloud;
`.factors` and `.fcf` contain model-aware factors/phases; `.cif` contains total
second moments, not local U. Only certified full-rank fits write
`.uncertainty.json`, including structure/shape/scale cross covariance and
total-U propagation. Its ESDs are **local frozen-weight approximations**, not
calibrated global shape confidence intervals.

For an exact native restart, retain the original input identity/cell/constraints
and set `restart_file='input.restart'` to a copy of `positive.restart` in a
new directory. Do not feed the total-U CIF back as local U. New fits profile
their own scale; fixed prediction uses `evaluation_only=.true.` plus an explicit
`evaluation_scale` from training, with no held-out scale refit. A stored
convergence label never certifies a new fit.

### Read-only displacement-cloud viewer

Use **Open displacement cloud…** to open an explicitly identified
`tonto.shared-u-mixture-adp` version-1 JSON artifact. The viewer checks the
canonical component weights, target identity, site orbit, local covariance
and total second moment. It plots the weighted positive Gaussian mixture,
not an unweighted pair of point clouds. The equivalent ellipsoid represents
only its second moment. Probability mass and grid convergence must pass
before a probability surface is displayed.

Opening this artifact does not activate a refinement and does not convert
an ordinary CIF into a fitted mixture. Use the artifact's authoritative
status to distinguish a certified result from a diagnostic distribution.
