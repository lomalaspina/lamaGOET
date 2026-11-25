# Lissajous displacement distributions

:::{admonition} Separate experimental route
:class: important
This is an additional, explicitly selected model, not a replacement for
{doc}`curved-adp`, ordinary Gaussian ADPs or Gram–Charlier coefficients.
The 2D/3D command and GUI integration have synthetic validation. The current
CuCl 1:2, 2:3, 1:3 and 3:4 experimental pilots **have not converged** and are
not passing refinement references. Lower residual peaks alone do not validate
a distribution or identify its physical cause.
:::

## Model and fitted quantities

The phase-locked 2D path is

$
v(\tau)=(A\sin(m\tau+\delta),\ B\sin(n\tau),\ 0)^T,
\qquad\tau\sim\mathcal U[0,2\pi).
$

The optional 3D path is

$
v(\tau)=(A\sin(m\tau+\delta_x),\ B\sin(n\tau+\delta_y),
 C\sin(p\tau))^T.
$

All coordinates share one phase variable. The last phase is fixed to zero
to remove the arbitrary time origin. A freely refined rotation matrix
$Q(\boldsymbol\omega)$, represented by a three-component rotation vector,
orients the distribution. Here $\boldsymbol\omega$ describes orientation,
**not angular frequency**. No bond, neighbour or pivot is required.

The full random displacement is

$
u=Qv+\eta,\qquad\eta\sim\mathcal N(0,U_{\rm local}),
$

with independent positive Gaussian broadening. Thus both the 2D and 3D paths
give volumetric, non-negative distributions. A 3D parametric path is still a
one-parameter curve; it does not acquire volume simply by having three
coordinates. The atomic displacement factor is the characteristic function

$
\Phi(q)=\exp(-q^T U_{\rm local}q/2)
 \frac{1}{2\pi}\int_0^{2\pi}\exp(iq^TQv(\tau))\,d\tau,
$

where $q$ includes the reciprocal-space $2\pi$ factor. Uniform phase/time
sampling is used, not uniform arc length. The atomic position is its mean.
For distinct frequencies, the path has zero mean and

$
U_{\rm total}=U_{\rm local}
 +Q\,\operatorname{diag}(A^2,B^2,C^2)Q^T/2,
$

with the third entry zero for 2D, followed by the actual site-group average.
The total second moment is not a complete description of the non-Gaussian
cloud. Output CIF U values are total moments; exact restart files retain
local U separately.

Before symmetry or data rank reductions, 2D has six shape parameters
(two amplitudes, one phase, three orientation coordinates), plus six local-U
terms: at most 12 displacement parameters. 3D has eight shape parameters
(three amplitudes, two phases, three orientation coordinates), plus six U
terms: at most 14. Shared structural parameters and the intensity scale are
also fitted. These counts do not guarantee that all parameters are identifiable.

For site operations $S\in G$, the entire distribution obeys site symmetry:

$
\Phi_G(q)=|G|^{-1}\sum_{S\in G}\Phi(S^Tq).
$

The original native structural Jacobian remains in place. Probability
symmetrization is not a substitute for a full-rank information check.

## Ratios, time averaging and independent phases

Ratios are **discrete model choices**, not continuously fitted physical
frequencies. In 2D, $a=m\Omega$, $b=n\Omega$, and substituting
$\tau=\Omega t$ into a full-period average eliminates $\Omega$.
The same path traversed faster has the same stationary distribution. An
ordinary time-averaged Bragg dataset does not determine that common frequency.

Use reduced integer pairs/triples with entries from 1 to 16. For triples the
joint gcd must be one; 2:3:4 is allowed. Repeated frequencies are rejected in
the free-orientation parameterization because they introduce redundancies.
The GUI currently refines **one selected ratio**, not a batch search.

Rational ratios are a restriction of the **closed, phase-locked path**, not
a general requirement for atomic vibrations. For two incommensurate
frequencies in the infinite-time limit, or independently randomized phases,
the phase averages separate. In the path frame,

$
\Phi(q)=\exp(-q^TU_{\rm local}q/2)
 J_0(A\tilde q_x)J_0(B\tilde q_y),\qquad\tilde q=Q^Tq,
$

with another $J_0(C\tilde q_z)$ factor in 3D for independent phases.
This follows directly from [Bessel's integral](https://dlmf.nist.gov/10.9.E1).
The phase differences and frequency ratios then disappear and must not be
included as fitted parameters. This independent-phase alternative is a
separate proposed control, **not activated by the current selector**.
For a finite observation time, a near resonance need not sample independent
phases completely. Introducing that finite-time model would require additional
physical information; it is not inferred just from experiment duration.

Independent fixed-amplitude oscillations remain non-Gaussian but have an
inversion-symmetric distribution: all odd centred moments vanish. Thermally
averaged equilibrium harmonic normal coordinates instead have Gaussian
statistics. Neither fixed-amplitude model should be identified as a measured
phonon motion merely because it improves residuals.

In the 1–10 2D grid there are 44 ordered reduced mixed-parity ratios that can
produce asymmetric distributions. With unrestricted orientation, axis exchange
gives equivalent families, leaving 22. Both-odd ratios always have inversion
symmetry; a crystallographic inversion site enforces it for every ratio.
The 44 is not the number of all possible ratios, nor a list of experimentally
distinguishable motions. Any future ratio search must compare converged fits
and held-out predictions using a fixed selection protocol.

## Using lamaGOET

1. Select **Lissajous — 2D or 3D (experimental)** in the opt-in displacement
   model box, then choose the dimension and a single asymmetric target label.
2. Enter the discrete ratio. Starting amplitudes are in Å; phases and the
   orientation vector are in radians. Defaults are numerical seeds, not
   restraints or universally optimal starts. Check sensitivity to other starts.
3. Confirm that the starting target tensor is **local Gaussian U**. The GUI
   requires an anisotropic target tensor. It rejects output total-U model CIFs
   as new local-U input. Additional angular targets must be cleared explicitly;
   this route currently supports one Lissajous target.
4. Choose IAM, which needs no SCF, or the supported single-density molecular
   HAR option. The latter performs one converged restricted Tonto molecular
   SCF and one fit against its retained Hirshfeld factors. It is not the
   periodic/outer iterative HAR workflow.
5. Choose F² and sigma or SHELXL weights in the ordinary data controls. Set
   time/cycle bounds and a new result subdirectory. The native experimental
   solver controls convergence; the ordinary Gauss–Newton/LM widgets do not
   switch this solver.

The runner checks that the executable advertises `--lissajous-adp` before
creating the result directory. An old executable is rejected; no ordinary
ADP refinement is substituted. Signed intensities and input ordering are
retained, with merging/cutoff applied by Tonto according to the chosen settings.
Jobs use one CPU thread and a 10 GiB address-space limit. Previous results are
never overwritten.

Molecular HAR is currently restricted to complete, nonrelativistic, unembedded
singlet fragments with native RHF/PBE/BLYP/B3LYP and conventional molecular
Hirshfeld partitioning. Periodic HAR, extinction, riding H, simultaneous
Gram–Charlier/angular models and XCW are not supported by this command.

## Results and limitations

`lissajous.summary` is authoritative for convergence. A process exit alone,
small damped steps, or lower R factors is insufficient. `lissajous.factors`
and `.fcf` retain model-aware factors/phases for diagnostic maps; `.cif`
reports total second moments. `.model.json` is the portable displacement-cloud
artifact for the viewer. `.restart` is the exact local-U native restart, with
identity, cell, symmetry and constraint checks. A restart is not itself proof
of convergence.

Only certified full-rank interior fits produce `.uncertainty.json`, containing
the joint intensity-scale/structural/shape covariance and propagated total-U
covariance, including cross terms. Failed fits receive no invented ESDs.
The CIF does not substitute Gaussian local-U uncertainties for the complete
non-Gaussian distribution; use the explicit uncertainty artifact.

At zero amplitude, some phase limits or symmetry-induced degeneracies, the
ordinary parameter covariance can be singular or nonregular. Current free
2D 3:4/4:3 refinement is explicitly unsupported at nontrivial site stabilizers
after synthetic recovery failures. Factor evaluation alone is not evidence
that free refinement works there. Other ratios/triples are not universally
validated by the tested examples.

The CuCl 1:2/2:3 pilots reached their CPU limits without meeting convergence
criteria; 1:2 reduced some lobes, but is not a certified fit. 1:3 also reached
its limit and 3:4 found no acceptable descent step; both retained the strong
alternating pattern. None supplies a final uncertainty estimate or a physical
mechanism conclusion. The independent-phase control and experimental
phase-boundary optimality treatment remain separate work.
