# Shared-U two-Gaussian displacement mixture

:::{admonition} Model A — development, not yet a GUI option
:class: warning
This is a new positive displacement model, not chemical disorder support or
a replacement for ordinary ADPs. Its component mathematics has numerical
validation. Native refinement, uncertainty/artifact export and GUI activation
must pass their own tests before deployment. The shared-phase Lissajous route
and Multi-harmonic angular ADP are unchanged. No new CuCl convergence or
mechanism claim follows from this development chapter.
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
It does not require a bond direction. The intended numerical starting value
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

Future native uncertainty export must retain the joint scale, coordinates,
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
These gates precede native synthetic recovery, matched full-data CuCl fits,
held-out prediction, resolution scans and an experimental model comparison.
Reduced residual lobes alone do not establish the proposed distribution.
