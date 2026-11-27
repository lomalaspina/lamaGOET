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

(positive-adp-cucl-comparison)=
## Matched CuCl comparison and held-out prediction

The 27 November 2026 comparison uses all 10,593 measured observations and
the same retained, audited Gaussian RB3LYP/def2-TZVP/DKH electronic density,
dispersion, free isotropic-H treatment and signed $F^2$ refinement as the
{ref}`earlier angular/Gram–Charlier example <curved-cucl-example>`.
SHELXL weighting uses $a=0.0494$, $b=0.1307$, without extinction. This is
a comparison conditional on one electronic density, not a newly converged
outer HAR loop or validation of the large native molecular SCF.

The identical five-fold split for every model groups Friedel-related
observations and balances reciprocal resolution. Each reflection is predicted
once while held out. Each training fit retains its own scale: no test-set
scale is fitted. Tonto independently verified all thirty training endpoints'
factors; all thirty passed the full-rank undamped-step and outer-IRLS tests.
Completed full-data fits and earlier folds were reused, not rerun.

```{list-table}
:header-rows: 1
:widths: 34 14 17 17 18

* - Cl displacement model
  - Total / added
  - All-data $R_1$ (%)
  - All-data $wR_2$ (%)
  - Held-out $wR_2$ (%)
* - Harmonic HAR
  - 647 / 0
  - 2.9659
  - 6.4986
  - 7.4950
* - Multi-harmonic angular
  - 654 / 7
  - 2.7870
  - 6.0319
  - 7.0067
* - Gram–Charlier third order
  - 657 / 10
  - 2.7780
  - 6.0119
  - 6.9700
* - Gram–Charlier third + fourth
  - 672 / 25
  - 2.7852
  - 5.9920
  - 6.9547
* - Shared-U mixture
  - 651 / 4
  - 2.7819
  - 6.0348
  - 7.0042
* - Single-axis overtone control
  - 651 / 4
  - 2.7900
  - 6.0579
  - 7.0232
```

Full-data $wR_2$ uses each model's self-consistent SHELXL weights. The pooled
held-out score uses **common weights** from each fold's training-harmonic
prediction. They are different diagnostics, not interchangeable columns.
GC3+4 has the lowest pooled held-out score and wins three folds; GC3 wins
the other two. The small lead does not establish superiority on another
dataset or a microscopic mechanism.

The single-axis overtone is a **separate reduced control**, with two amplitudes
and two direction coordinates. It is not unrestricted three-direction
Model B. Both full-data starts of unrestricted Model B failed convergence;
they receive neither ESDs nor a score in this table. A successful reduced
control does not retroactively validate those failed fits.

```{figure} _static/positive-adp-cl-matched-slices.png
:width: 100%
:alt: Matched Cl1 residual slices for harmonic HAR, a converged shared-U mixture, and the separately identified converged single-axis overtone control. The full reflection list, orientation and colour scale are unchanged.

Archived full-data Cl1 residual slices, reused without recalculation.
The full 10,593-reflection list, fixed view and ±1 e/Å³ colour scale match
the angular/Gram–Charlier comparison. These are residual electron-density
maps, not atomic displacement probability densities.
```

The following extrema are on the **identical central slice**, not the full
three-dimensional neighbourhood extrema in the earlier chapter.

```{list-table}
:header-rows: 1
:widths: 45 32 23

* - Model
  - Slice min / max (e/Å$^3$)
  - Negative probability mass (%)
* - Harmonic HAR
  - −0.8871 / +1.0284
  - 0
* - Multi-harmonic angular
  - −0.1889 / +0.2149
  - 0
* - Gram–Charlier third order
  - −0.1870 / +0.2143
  - 0.2196
* - Gram–Charlier third + fourth
  - −0.1901 / +0.2114
  - 0.8562
* - Shared-U mixture
  - −0.1788 / +0.2221
  - 0
* - Single-axis overtone control
  - −0.1837 / +0.3589
  - 0
```

Positive models avoid negative displacement probability by construction;
they do not guarantee zero residual density. The GC negative masses refer
to the full-data fitted distributions, not every cross-validation fold.
The largest absolute local parameter correlation is about 0.886 for the
mixture, 0.9973 for the angular model and 0.99998 for the single-axis
overtone. These include ordinary structural parameters. They are local
frozen-weight diagnostics, not globally calibrated uncertainties.
An apparently good overtone residual map does not make its two amplitudes
independently precise.

### Resolution sensitivity, not a universal cutoff

A separate nested-cutoff test retained 8,731, 6,129 and 4,446 observations
at $d_{\min}=0.80$, $0.90$ and $1.00$ Å, respectively, compared with all
10,593 observations to 0.75006 Å. It reused the same electronic density and
refinement conventions, starting each fit at its full-data endpoint.
The mixture converged at all three cutoffs: canonical weights were 0.189,
0.217 and 0.194, with separations 0.395, 0.389 and 0.392 Å. The full-data
values were 0.192 and 0.392 Å. This is a warm-start sensitivity check, not
proof of global uniqueness or a calibrated confidence interval.

Unrestricted Model B did not converge at any of these cutoffs: the 0.80 Å
case reached its time bound; the 0.90 and 1.00 Å cases had rank-deficient
designs. No ESDs were assigned. Reduced resolution did not repair its
identifiability problem. These outcomes do not define a transferable
minimum-resolution equation. Retain the full-data result as the final
reference; a lower residual from fewer observations is not a reason to
discard measured reflections.

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
