# Molecular XCW and XWR

## Definition

X-ray constrained wavefunction fitting (XCW) modifies a quantum-mechanical
wavefunction so that it remains governed by the electronic Hamiltonian while
also improving agreement with measured diffraction data. In the Tonto
implementation, a Lagrange multiplier $\lambda$ controls the relative X-ray
term schematically:

$$
\mathcal L[\Psi]=E[\Psi]+\lambda\,\chi^2[\Psi],
$$

with the precise normalization and sign defined by Tonto. At $\lambda=0$ the
calculation should reproduce the unconstrained reference at the supplied fixed
geometry. Increasing $\lambda$ follows a restraint path rather than a new
structural least-squares cycle.

The vocabulary in lamaGOET is:

- **XCW only**: use the supplied geometry and perform only the constrained
  wavefunction calculation;
- **XWR**: complete HAR first, then perform XCW at the accepted HAR geometry;
- **HAR**: refine geometry/ADPs using theoretical Hirshfeld atoms, whether the
  wavefunction came from Tonto, Gaussian, ORCA, OCC, Crystal23, or CP2K.

## Molecular XCW workflow

1. Tonto reads the fixed CIF geometry, basis, reflections, and optional
   molecular environment.
2. It converges the reference molecular SCF at the initial lambda.
3. The X-ray restraint is increased according to initial lambda, step, and
   maximum lambda.
4. At each lambda, Tonto optimizes the constrained wavefunction and writes the
   wavefunction/reflection outputs.
5. lamaGOET preserves each XCW cycle and then calculates residual-density
   artifacts for the accepted endpoint.

In XWR, the HAR phase is completed before step 1. The XCW step does not resume
geometry refinement unless a distinct subsequent refinement is explicitly
started.

## GUI controls

| Control | Effect |
|---|---|
| Perform XCW only | bypass HAR and use the input geometry |
| Perform XWR (HAR+XCW) | run the selected HAR, then XCW at its final geometry |
| XCW implementation | select molecular or experimental periodic solver |
| XCW method | Tonto SCF kind/exchange-correlation treatment for molecular XCW |
| XCW basis | all-electron Tonto basis used for the constrained SCF |
| Use SC cluster charges in XCW | include the supported self-consistent crystal field |
| XCW cluster radius | environment radius in Å |
| Complete XCW cluster molecules | avoid cutting neighboring molecules at the environment boundary |
| Initial lambda | first X-ray restraint multiplier |
| Lambda step | increment between restraint calculations |
| Maximum lambda | final requested multiplier |

`BASISSETDIRXCW` on **Settings** selects the Tonto basis directory. Do not use
an ECP/valence-only definition where Tonto requires a full electron density.

## Choosing a lambda path

A high final lambda and lower residual are not automatically better. Follow a
path from zero in modest steps and inspect:

- SCF and constrained-wavefunction convergence;
- energy penalty versus diffraction improvement;
- changes in density-derived properties;
- stability to basis, grid, reflection cutoff, scale, and extinction;
- physically implausible charge accumulation or oscillatory density; and
- held-out or otherwise independent validation where available.

Record the entire path rather than only the selected endpoint. A defensible
choice should be stable over a neighborhood of lambda and not be determined by
one outlier or an under-specified weight model.

## Molecular environment

The molecular XCW density is affected by the finite-fragment and crystal-field
model just as a molecular HAR density is. A cluster-charge radius should be
converged, molecules should be completed, and the charge/multiplicity must
describe the calculation fragment. If the preceding HAR used a different
environment, say so explicitly and justify the change.

## Outputs

The runner preserves XCW-cycle input/output directories, covariance and final
CIFs, FCF/FCO files, and the residual-density cube. The exact molecular
wavefunction outputs depend on the current Tonto keywords and build. Keep the
Tonto `stdin` and `stdout`: they are the authoritative record of method, basis,
lambda path, convergence, and fitted quantities.

## Boundaries

- Molecular XCW is a Tonto wavefunction optimization; selecting Gaussian or
  ORCA as the HAR producer does not make those programs perform XCW.
- Experimental information is filtered through model phases, resolution,
  uncertainties, reflection selection, and the finite basis.
- The constrained wavefunction is not determined uniquely by a reduced set of
  Bragg intensities.
- XCW must not be used to conceal an unconverged or chemically incomplete HAR
  geometry.
- Compare the lambda-zero calculation against the unconstrained reference
  before interpreting any nonzero-lambda result.
