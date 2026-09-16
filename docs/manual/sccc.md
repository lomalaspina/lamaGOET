# Theoretical optimization with Tonto SCCC

## Purpose

The two **SC cluster optimization** program choices perform a theoretical
geometry optimization with Gaussian or ORCA while Tonto updates a
self-consistent representation of the crystal environment. They are included
for crystal-field theoretical optimization and frequency workflows; they are
not a crystallographic least-squares HAR and do not require a reflection file.

Use:

- **SC cluster optimization: Gaussian + Tonto** (`SCFCALCPROG=optgaussian`), or
- **SC cluster optimization: ORCA + Tonto** (`SCFCALCPROG=optorca`).

The runner requests the external program's geometry optimizer, rebuilds the
Tonto cluster charges when enabled, repeats until the energy/environment cycle
meets the configured threshold, and performs the supported final frequency
calculation.

## Procedure

1. Read and, if requested, complete the molecular fragment from the CIF.
2. Generate the finite quantum geometry and initial crystal-field environment.
3. Optimize the geometry in Gaussian or ORCA.
4. If self-consistent charges are enabled, Tonto recalculates the surrounding
   charges from the updated wavefunction/geometry.
5. Repeat external optimization and field update until the energy difference
   meets the configured convergence or the cycle cap is reached.
6. Run the final frequency job appropriate to the selected external program.

Without self-consistent charges, the runner performs the direct optimization
and final frequency step; there is no outer charge-update loop.

## Applicable controls

| Control | Guidance |
|---|---|
| CIF or PDB | starting molecular/crystal fragment; inspect completion carefully |
| Method / basis | external-program electronic-structure model |
| External basis | rendered for Gaussian/ORCA; verify all-electron need for any Tonto density use |
| Charge / multiplicity | quantum fragment electronic state |
| SC processors / memory | external program resources |
| Use SC cluster charges | activates the iterative crystal-field update |
| Cluster radius | test convergence of central geometry and frequencies |
| Complete molecules | avoids charged/truncated environment fragments |
| Use dipoles | include supported environmental dipoles |
| Nuclear interaction | ORCA-only interaction control |
| Energy convergence | outer optimization/environment stopping threshold |
| Maximum HAR cycles | reused as the outer-cycle safety cap; it does not make this a HAR |

The reflection-file field and Tonto reflection-header controls are hidden for
these modes because no diffraction least-squares fit is performed.

## Scientific limitations

- The optimized object is a finite fragment in an approximate field, not a
  fully periodic geometry optimization.
- A cluster radius can converge central bonds while boundary polarization or
  low-frequency modes remain unstable.
- Frequency interpretation requires a genuine stationary point and the correct
  treatment of external charges in the Hessian.
- A successful frequency file does not validate the environment model.
- Report the exact cluster construction, radius, charge/dipole model, external
  method/basis, and convergence history.

For network solids or collective phonons, use a periodic program and a method
designed for periodic geometry/frequency calculations rather than treating
SCCC as an equivalent substitute.
