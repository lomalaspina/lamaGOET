# Experimental periodic XCW

:::{admonition} Status
:class: warning
The periodic solver is an experimental fixed-geometry Tonto implementation.
Retained engineering tests establish import, symmetry, lambda-zero identity,
gradient response, and restart behavior for specific Diamond references. They
do not yet constitute publication-grade convergence or validation for an
arbitrary material.

This periodic extension and its lamaGOET GRED+KRED orchestration are original
experimental developments in the compatible Tonto/lamaGOET branches. They are
not a Crystal23 feature and should not be attributed to the Crystal23 authors.
The conceptual XCW foundations remain Jayatilaka
([1998](https://doi.org/10.1103/PhysRevLett.80.798)), Jayatilaka and Grimwood
([2001, part I](https://doi.org/10.1107/S0108767300013155);
[2001, part II](https://doi.org/10.1107/S0108767300013167)), and the
Hirshfeld-atom review of Davidson *et al.*
([2022](https://doi.org/10.1107/S2052520622004097)). Cite the exact development
revisions and describe the validation performed for the reported material; see
{doc}`references`.
:::

## Model and nomenclature

Periodic XCW optimizes k-resolved Tonto orbitals under an X-ray restraint while
holding atomic coordinates and ADPs fixed. It is selected in the **XCW** tab,
not by choosing a periodic HAR program. A Crystal23 or CP2K HAR followed by
this calculation is periodic XWR.

The most extensively exercised engineering path uses a neutral, restricted
closed-shell Crystal23 BLYP or PBE determinant. Restricted periodic HF/PBE0
response and intensity-based XCW objectives pass focused compilation,
scalar-derivative, semilocal-PBE0, finite-lattice exact-exchange, and a small
native GRED+KRED nonzero-lambda end-to-end regression. That compact synthetic
He fixture is an implementation test, not publication-grade validation for an
arbitrary material.
The lamaGOET reference selector exposes HF/PBE0 as explicitly experimental
choices in addition to the engineering-tested semilocal choices.
Open-shell references and a CP2K-only periodic-XCW reference are unsupported.

## Variational principle: where the experimental information enters

The electronic parameters, rather than the geometry, are adjusted against
the measured diffraction data. For a chosen restraint strength $\lambda$,
Tonto seeks a stationary restricted determinant of

$$
\mathcal L[P]=E_{\rm rel}[P]+\lambda\chi^2[P].
$$

The equivalent constrained notation is
$E_{\rm rel}+\lambda(\chi^2-\Delta)$, where $\Delta$ is a desired discrepancy.
At fixed $\lambda$ the constant $-\lambda\Delta$ does not change the orbitals.
The electronic energy is measured in hartree per primitive cell relative to
the imported theoretical reference. The numerical value of $\lambda$ depends
on this energy convention, the diffraction normalization and the selected
uncertainties/weights; values from differently normalized calculations are
not directly interchangeable.

This is the energy-plus-diffraction principle of XCW introduced by
[Jayatilaka (1998)](https://doi.org/10.1103/PhysRevLett.80.798) and developed by
[Jayatilaka and Grimwood (2001)](https://doi.org/10.1107/S0108767300013155).
Its extension to a Bloch-orbital state and the reference-relative numerical
functional described here belong to this experimental implementation.

### Periodic orbitals and the SCF equations

Using Bloch sums $\chi_{\mu\mathbf k}$ of atom-centred basis functions,

$$
\psi_{n\mathbf k}(\mathbf r)=
\sum_\mu C_{\mu n}(\mathbf k)\chi_{\mu\mathbf k}(\mathbf r),
\qquad C^\dagger(\mathbf k)S(\mathbf k)C(\mathbf k)=1,
$$

$$
P(\mathbf k)=2C_{\rm occ}(\mathbf k)C_{\rm occ}^\dagger(\mathbf k),
\qquad N_e=\sum_\mathbf k\omega_\mathbf k
\operatorname{Tr}[P(\mathbf k)S(\mathbf k)].
$$

Here $S$ is the overlap matrix, the factor two is the closed-shell occupation,
and $\sum_\mathbf k\omega_\mathbf k=1$. The stored complete uniform mesh has
$\omega_\mathbf k=1/N_k$. Electron count and occupied-subspace idempotency are
constraints on the electronic state; they are not fitted to the reflections.
Variation under orbital orthonormality gives the generalized SCF equations

$$
\left[F_{\rm el}[P](\mathbf k)
 +\lambda C_{\rm X}[P](\mathbf k)\right]C(\mathbf k)
=S(\mathbf k)C(\mathbf k)\varepsilon(\mathbf k),
\qquad C_{\rm X}=\frac{\delta\chi^2}{\delta P}.
$$

The matrix derivative uses the same normalized k-space trace convention as
the energy. At every nonzero-$\lambda$ iteration, Tonto rebuilds the
diffraction derivative and density-dependent electronic terms, obtains new
Bloch orbitals, constructs their occupied density, and repeats. Thus the
measured amplitudes or intensities act inside the electronic optimization.
The SCF eigenvalues are multipliers for orbital orthonormality; their change
is not by itself a prediction of an experimental excitation spectrum.

### The current semilocal electronic functional

Let $P_0$, $\rho_0$ and $F_0$ denote the imported native reference and let
$\Delta P=P-P_0$ and $\Delta\rho=\rho-\rho_0$. Define
$\langle A,B\rangle_k=\sum_\mathbf k\omega_\mathbf k
\operatorname{Re}\operatorname{Tr}[A(\mathbf k)B(\mathbf k)]$.
For pure PBE or BLYP, the implemented energy difference is

$$
\begin{aligned}
E_{\rm rel}[P]={}&\langle\Delta P,F_0\rangle_k
 +\tfrac12\langle\Delta\rho,J[\Delta\rho]\rangle\\
 &+E_{\rm xc}[\rho]-E_{\rm xc}[\rho_0]
 -\langle V_{\rm xc}[\rho_0],\Delta P\rangle_k.
\end{aligned}
$$

$J$ is the periodic Hartree operator. For a GGA, the last contraction includes
the density-gradient terms belonging to the same XC quadrature. Its
derivative gives

$$
F_{\rm el}[P]=F_0+J[\Delta\rho]
 +V_{\rm xc}[\rho]-V_{\rm xc}[\rho_0].
$$

Both current and reference XC energies/potentials are evaluated; the update
is not limited to a fixed linear XC response kernel. The Hartree difference
is solved periodically with its zero reciprocal component removed. Charge
neutrality is checked with the overlap trace, independently of real-space
grid integration.

The functional definitions are [PBE (Perdew, Burke and Ernzerhof,
1996)](https://doi.org/10.1103/PhysRevLett.77.3865), or BLYP, combining
[Becke exchange (1988)](https://doi.org/10.1103/PhysRevA.38.3098) with
[Lee--Yang--Parr correlation (1988)](https://doi.org/10.1103/PhysRevB.37.785).

At fixed nuclei and basis, the kinetic and electron--nucleus operator
$h_0$ is fixed. Formally, $F_0=h_0+J[\rho_0]+V_{\rm xc}[\rho_0]$.
Consequently, the reference-relative expression is an ordinary semilocal
KS energy difference, up to a constant, **if** all terms share a consistent
representation. In the actual code, $F_0$ is imported and the response uses
Tonto quadratures and a finite lattice representation. Agreement with an
independent periodic energy evaluation away from the reference remains a
validation requirement. Reusing $F_0$ retains the fixed one-electron physics;
it does not freeze the density-dependent SCF operator.

### From the static density to diffraction

The variational density is a fixed-nucleus electronic density. With the
selected stockholder weights $w_a$, Tonto forms
$\rho_a(\mathbf r)=w_a(\mathbf r)\rho(\mathbf r)$. For a full unit-cell atom
sum, a convenient Fourier convention is

$$
F_{\mathbf h}[P]=\sum_a e^{i\mathbf q_{\mathbf h}\cdot\mathbf R_a}
 T_a(\mathbf q_{\mathbf h})
 \int \rho_a(\mathbf R_a+\mathbf u)
                 e^{i\mathbf q_{\mathbf h}\cdot\mathbf u}\,d\mathbf u,
$$

where $\mathbf q_{\mathbf h}$ includes the $2\pi$ reciprocal-space factor.
For harmonic ADPs,
$T_a(\mathbf q)=\exp[-\mathbf q^{\mathsf T}U_a\mathbf q/2]$.
Fixed higher-order displacement terms enter through the corresponding
characteristic function when present. The implementation uses independent
atoms and their symmetry operations with the required site factors rather
than duplicating every integral.

Coordinates, ADPs and the chosen neutral-reference stockholder weights are
fixed during the electronic variation. The current electronic density and
its atomic form factors change. The same partition, thermal averaging,
symmetry factors and scale/extinction mapping must appear in both the
predicted structure factors and their derivative. This is the one-centre
Hirshfeld-atom diffraction model described by
[Davidson, Grabowsky and Jayatilaka (2022)](https://doi.org/10.1107/S2052520622004097).

The electronic operator is projected onto Hermiticity, time reversal and
the full space group before orbital updating. Site and lattice symmetry
therefore constrain the density response. Only stockholder models whose
forward calculation and derivative are both supported may be selected;
the availability of a partition for HAR alone does not establish an XCW
derivative for it.

### Amplitude and intensity objectives

Write $A_h=g(|F_h|;s,x)$ for the predicted amplitude including the selected
scale and extinction treatment, and $I_h^{\rm calc}=A_h^2$. For amplitude
fitting with inverse-variance weights,

$$
\chi_F^2=\frac1\nu\sum_{h\in W}
\frac{(A_h-F_h^{\rm obs})^2}{\sigma(F_h^{\rm obs})^2}.
$$

$W$ is the work set. The current diffraction normalization is
$\nu=\max(N_W-N_{\rm param},1)$, with $N_{\rm param}$ the value reported by
the crystallographic model, not the number of Bloch-orbital coefficients.
The derivative contains both the complex phase response and the derivative
of the amplitude correction:

$$
\delta\chi_F^2=\frac2\nu\sum_{h\in W}
\frac{A_h-F_h^{\rm obs}}{\sigma(F_h^{\rm obs})^2}
g'(|F_h|)\,
\frac{\operatorname{Re}(F_h^*\delta F_h)}{|F_h|}.
$$

Numerical model-zero handling must agree with the reflection lifecycle.
When scale or extinction is optimized as a nuisance parameter, an analytic
profile derivative also requires those nuisance parameters to be stationary
for the same objective; otherwise they must be held fixed in the derivative
check.

The new intensity branch uses signed observed intensities,
including negative observations, in

$$
\chi_{F^2}^2=\frac1\nu\sum_{h\in W}
w_h\bigl(I_h^{\rm calc}-I_h^{\rm obs}\bigr)^2,
\qquad w_h=\sigma(I_h^{\rm obs})^{-2}
$$

or the selected SHELXL `WGHT` expression. It requires the intensity chain
rule $\delta I_h^{\rm calc}=2A_h\delta A_h$. Merely selecting an $F^2$
statistic while retaining the amplitude derivative is inconsistent. For a
model-dependent weight, the complete differential is

$$
\delta\chi_{F^2}^2=\frac1\nu\sum_{h\in W}
\left[2w_h(I_h^{\rm calc}-I_h^{\rm obs})\,\delta I_h^{\rm calc}
 +(I_h^{\rm calc}-I_h^{\rm obs})^2\delta w_h\right].
$$

A fixed-weight least-squares subproblem omits the last term only while the
same weights are frozen in both objective and derivative. Updating the
weights between subproblems must be stated explicitly. The periodic branch
instead differentiates the dynamic weight and profiles
scale/extinction against that same objective. This is a variational choice
for the electronic optimization; it is distinct from the conventional
SHELXL fixed-weight normal-equation step, which remains unchanged in Tonto's
geometrical refinement.

For `WGHT a,b,c,d,e,f`, define $t=\sin\theta/\lambda_X$ in
angstrom$^{-1}$ (where $\lambda_X$ is the X-ray wavelength),
$\mathcal P=f\max(I^{\rm obs},0)+(1-f)I^{\rm calc}$, and

$$
D=\sigma(I^{\rm obs})^2+(a\mathcal P)^2+b\mathcal P+d+et,
\qquad w=\frac{q(t)}{D},
$$

with $q=\exp(ct^2)$ for $c>0$, $q=1-\exp(ct^2)$ for $c<0$, and $q=1$
for $c=0$. At an ordinary positive denominator,

$$
\frac{\partial w}{\partial I^{\rm calc}}
=-\frac{q(2a^2\mathcal P+b)(1-f)}{D^2}.
$$

The negative observed intensity is clipped only in $\mathcal P$, not in the
residual. Numerical denominator guards must be differentiated consistently.
These weights follow the
[SHELXL instruction definition](https://shelx.uni-goettingen.de/shelxl_html.php).
Using the same weight formula does not make two different optimization
algorithms identical, and a geometrical-refinement comparison does not
independently validate the periodic electronic functional.

The $F$/inverse-variance path has retained engineering tests. The audit found
that the former shared controls could pass $F^2$/SHELXL settings to an
amplitude-only periodic derivative. Results from that former combination
are not validated periodic XCW results. The new intensity implementation
must pass objective/derivative and numerical SCF checks. Periodic XCW now
explicitly rejects nonzero structure-factor mixing, multiple scale factors
and weights frozen by a preceding structural IRLS calculation.

### Periodic HF and global-hybrid extension

The required extension includes a nonlocal exchange response, rather than
only changing the reference's method label. Define $K[P]$ so that for a
spin-summed closed-shell density

$$
E_x^{\rm HF}[P]=-\tfrac14\langle P,K[P]\rangle_k,
\qquad F_x^{\rm HF}[P]=-\tfrac12K[P].
$$

$K$ couples orbital products across lattice translations and k points through
the periodic Coulomb kernel. For exact-exchange fraction $\alpha$, with
$E_{\rm xc}^{\rm sl}$ denoting the remaining semilocal part of the chosen
functional, the required response is

$$
\begin{aligned}
F_{\rm el}[P]={}&F_0+J[\Delta\rho]-\tfrac\alpha2K[\Delta P]\\
 &+V_{\rm xc}^{\rm sl}[\rho]-V_{\rm xc}^{\rm sl}[\rho_0],\\
E_{\rm rel}[P]={}&\langle\Delta P,F_0\rangle_k
 +\tfrac12\langle\Delta\rho,J[\Delta\rho]\rangle
 -\tfrac\alpha4\langle\Delta P,K[\Delta P]\rangle_k\\
 &+E_{\rm xc}^{\rm sl}[\rho]-E_{\rm xc}^{\rm sl}[\rho_0]
 -\langle V_{\rm xc}^{\rm sl}[\rho_0],\Delta P\rangle_k.
\end{aligned}
$$

HF has $\alpha=1$ and no semilocal XC term. The initial global-hybrid target
is [PBE0 (Adamo and Barone, 1999)](https://doi.org/10.1063/1.478522), with
$\alpha=1/4$ and $E_{\rm xc}^{\rm sl}=(3/4)E_x^{\rm PBE}+E_c^{\rm PBE}$.
The imported reference must use the same method and coefficients.

The initial HF/PBE0 implementation uses finite-lattice
Gaussian electron-repulsion integrals for the exchange change. An explicit
lattice range and workload guard control that calculation. One exchange
kernel must be shared by energy and matrix construction, and its range and
k-mesh convergence must be demonstrated before it can be interpreted as
converged crystal exchange. Reusing an imported frozen hybrid Fock matrix
alone does not supply the exchange response. Screened and range-separated
hybrids require their own kernels and are outside this initial scope.
Focused and small native numerical HF/PBE0 validation is reported below;
real-material convergence and comparison with independent XCW results remain
required before scientific use.

For direct Tonto input, `periodic_xcw_reference_dft=hf` requires
`scfdata={ kind=rhf }`. PBE0 requires
`periodic_xcw_reference_dft=pbe0` with
`scfdata={ kind=rks dft_exchange_functional=pbex dft_correlation_functional=pbec }`.
The periodic response itself applies the $3/4$ exchange and full correlation
coefficients; do not add a separate molecular hybrid multiplier. The
reference declaration must agree with the method that produced GRED/KRED.

Both new methods require an explicit `periodic_xcw_exchange_radius` integer
between `2` and `12`. Direct Tonto input defaults to `-1` (unconfigured) and
is rejected for HF/PBE0; lamaGOET writes an explicit starting value of `4`,
which must still be converged for each system. The exchange contraction sums the auxiliary translation
$\mathbf S$ over the integer cube $[-r,r]^3$; the density/output block
supports remain those imported from GRED. A preflight estimate rejects jobs
requiring more than two million shell quartets in this validation kernel.
This limit makes the initial implementation suitable for small diagnostic
cases rather than arbitrary production structures.

For nonzero $\Delta P$, the implementation also computes the maximum,
over response-matrix entries, of the sum of absolute individual exchange
contributions from the last **two** $\mathbf S$ shells. Dividing this measure
by $\max|\Delta P|$ must give at most $10^{-8}$ for the update to proceed.
The normalization prevents a small restraint-induced density change alone
from making the range test pass. This is a finite-window diagnostic, not a
bound on the omitted infinite-lattice tail. Passing it still requires
independent comparison with larger exchange ranges, k meshes and imported
density support. At exactly zero $\Delta P$, the response is zero and this
test provides no exchange-range evidence.

## Why both GRED and KRED are required

Crystal23 supplies complementary representations:

- **GRED** contains the atom/basis mapping and the exact retained
  direct-lattice overlap, density, and Fock/Kohn-Sham blocks. It is the
  lambda-zero real-space density anchor.
- **KRED** contains the full-zone complex Bloch orbital state used as the
  variational periodic-XCW degrees of freedom.

The meanings and generation controls of Crystal23 files must be checked
against the
[official manual for the installed Crystal23 release](https://www.crystal.unito.it/include/manuals/crystal23.pdf).
The use of those files as the matched periodic-XCW reference is the experimental
Tonto/lamaGOET interface described here, not an independently validated
Crystal23 workflow.

A finite k mesh does not uniquely recover every retained direct-lattice block.
A direct inverse transform of the KRED projector contains Born-von Karman alias
sums. Therefore KRED cannot replace GRED at lambda zero. The implementation
starts from $P_0(\mathbf R)$ in GRED and applies only the inverse-transformed
projector change produced by XCW:

$$
P_\lambda(\mathbf R)=P_0(\mathbf R)+
\mathcal F^{-1}\!\left[P_\lambda(\mathbf k)-P_0(\mathbf k)\right].
$$

This preserves the external real-space reference while allowing a controlled
k-space variational response on its imported finite block footprint. This
equation specifies the density representation; the variational functional
and self-consistent electronic updates are the ones defined above.

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
7. At every converged lambda, Tonto rebuilds the current reflection lifecycle
   and writes a lambda-qualified CIF, FCF/FCO, and (when enabled) residual
   cube. Unsuffixed files are rebuilt once more for the final endpoint.

Retain the Crystal23 output and version banner as the authoritative record of
the external reference calculation. Cite Crystal23 according to its installed
manual in addition to lamaGOET, Tonto and the XCW method papers.

For XWR after a CP2K HAR, step 2 still uses Crystal23 at the final CP2K
geometry. The native CP2K HAR import is not currently a compatible
periodic-XCW orbital/overlap/Fock reference.

## Controls

| GUI control | Meaning and validation requirement |
|---|---|
| Native reference method | BLYP or PBE; HF and PBE0 are visibly labelled experimental |
| Least-squares target | select amplitudes $F$ or intensities $F^2$ for the diffraction term; this choice changes the XCW derivative as well as the reported objective |
| Weighting scheme | uncertainty weights are available for $F$ and $F^2$; SHELXL `WGHT a`--`f` is an intensity-only dynamic objective and must be used with $F^2$ |
| Crystal23/Tonto all-electron basis | one basis represented compatibly on both sides |
| Exact paired custom basis | explicitly stage a Crystal shell block and matching Tonto sidecar |
| Periodic KS grid | real-space grid used for periodic density/Hartree/XC response; converge it |
| Direct-density lattice radius | compatibility control: only `1` is accepted, meaning the complete imported GRED block footprint; it does not select one neighbour shell |
| Exact-exchange lattice radius | `periodic_xcw_exchange_radius=2..12`, enabled for HF/PBE0; lamaGOET starts at `4`, but the result must be converged and remains subject to workload and last-two-shell checks |
| Objective/projector tolerance | convergence gate for the constrained objective/projector |
| Old-iterate damping | fraction of the previous iterate retained; stabilizes but changes the iteration path |
| Maximum iterations per lambda | safety cap for each restraint point |
| Deterministic held-out reflections | excluded from fitting and used for selection/validation |
| Restart from checkpoint | require signature-compatible saved orbitals/projector/reference |
| Write restart checkpoint | persist accepted state after each iteration |
| Initial/step/maximum lambda | strength and path of the energy-plus-diffraction restraint; not a target R factor |

lamaGOET promotes a Becke accuracy below `extreme` to the minimum used by the
retained engineering path. That is an implementation floor, not a
grid-convergence proof. Convergence of the real-space representation requires
checking the native reference's retained blocks and their numerical cutoffs;
changing the compatibility radius cannot enlarge that footprint.

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

For the native path this is explicitly an **identity check**: at $\lambda=0$
the code accepts the stationary imported determinant without updating its
orbitals. Passing it verifies import and forward-model consistency. It does
not demonstrate that a perturbed state has independently converged to the
same unrestrained periodic SCF solution in Tonto.

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

### Native HF/PBE0 engineering regression

The exact-exchange branch was tested with separate, converged Crystal23 HF and
PBE0 GRED+KRED references for a deliberately small neutral He cell. The cell
has two electrons, two independent s functions, eight full-zone k points and
a 124-reflection **synthetic** target; it is not measured data or a physical
He-crystal result. At $\lambda=0.001$:

| Reference | initial $\chi^2$ | final $\chi^2$ | $\lVert\Delta P\rVert$ | exact-exchange response norm |
|---|---:|---:|---:|---:|
| restricted HF | 1.032056 | 0.873456 | 0.015403 | 0.005690 |
| PBE0 | 1.051225 | 0.888086 | 0.015611 | 0.005691 |

Central differences of the complete reference-linear, Hartree, semilocal-XC
and exact-exchange electronic functional agreed with the corresponding Fock
components to maximum relative errors of about $1.1\times10^{-8}$ for HF and
$2.5\times10^{-8}$ for PBE0. Exchange radii two and three gave byte-identical
final FCFs; signature-checked checkpoint restarts reproduced those FCFs
exactly. The fixed-geometry guards remained satisfied and each lambda point
produced distinct CIF/FCF/FCO files.

This closes the missing native nonzero-lambda implementation regression. It
does **not** establish infinite-lattice exact-exchange convergence, validate
the synthetic target as an experiment, or remove the need to converge basis,
k mesh, periodic and atom-centred grids, exchange radius, and held-out
statistics for each real material.

For production work:

1. converge periodic Poisson and atom-centred grids;
2. converge the imported direct-lattice representation and basis cutoffs;
3. converge the Crystal23 k mesh and reference basis;
4. select lambda with deterministic held-out reflections;
5. repeat from a fresh, uninterrupted reference;
6. test origin/phase and symmetry covariance explicitly; and
7. report the complete lambda path and rejected models.

The convergence tests use changes of the energy-plus-data objective,
occupied--virtual electronic gradient and occupied subspace. Damping changes
the SCF iteration path. Neither damping nor a successful SCF convergence
flag proves that the global minimum was found, and objective decrease need
not be monotonic at every iteration. $R(F)$, $wR$ and held-out discrepancies
are diagnostics, not the electronic objective itself. A reduced work-set R
factor alone cannot distinguish a useful density correction from fitting
experimental or model errors. Retain an unchanged held-out set when
comparing lambda values.

Fixed geometry and ADPs do **not** imply fixed diffraction results. The
periodic orbitals, density, Hirshfeld-atom form factors, and therefore
$F_{\rm calc}$ all change along the lambda path. R factors, goodness-of-fit,
residual extrema, and the residual-density cube must consequently be
recomputed from each converged projector. They are diagnostics of that lambda
state, not quantities inherited from the starting HAR or lambda-zero model.

Scale and extinction are not frozen merely because coordinates and ADPs are
fixed. When enabled, they are reoptimized against the current diffraction
objective at each density evaluation, using only the working reflections.
The held-out data do not determine their values. Temporary fixed-nuisance
settings used for derivative tests are diagnostics, not the production
lambda-path behavior.

For the current $F^2$ objective, the working statistic is normalized by
$N_{\rm work}-N_{\rm param}$. The held-out $F^2$ statistic uses
$N_{\rm free}$ because no nuisance parameter is refitted on the free set.
The retained legacy amplitude-$F$ free statistic uses its established
$N_{\rm free}-1$ convention. These target-dependent values must not be mixed
when selecting lambda.

## Reflection lifecycle

For unmerged data, every periodic-XCW diffraction evaluation starts from the
immutable unmerged observations, applies the selected raw-observation
filters and MERG rule, and then prunes current model zeros. Cutoff handling
depends on the target and weighting controls; the shared SHELXL-weight path
does not apply the amplitude weak-observation cutoff before merging. The
retained Diamond MERG 4 control started each pass from 18,201 observations,
removed 1,628 systematic absences and 2,852 weak observations, and merged to
63 reflections. The same process was repeated for the XCW pass and final
artifacts. These are the counts of that historical control, not prescribed
counts or cutoff rules for every target. At a fixed derivative check the
reflection set must be held constant; a discontinuous change of membership
at a cutoff is a separate preprocessing event.

## Outputs and restart safety

`periodic_XCW.<job-name>/` contains lambda-qualified fixed-geometry CIFs,
FCF/FCO files, and residual-density cubes for every converged restraint point,
plus unsuffixed copies for the final endpoint. It also contains
projector/orbital checkpoints, lambda/convergence markers, basis and k-point
dimensions, electron count, and a reference signature. A checkpoint is valid
only when its geometry, cell, basis, k mesh, reference, and relevant controls
match. Tonto revalidates the terminal checkpoint against the current gradient
before accepting it.

Do not hand-edit the signature or mix GRED/KRED/checkpoints from different
geometries. A successful file read is not a valid restart.
