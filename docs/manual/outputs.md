# Output files and scientific interpretation

lamaGOET deliberately retains both a human-readable summary and the machine
artifacts needed to audit a refinement. In the names below, `JOBNAME` is the
value entered as **Job name** and `J` is a one-based outer-cycle number.

## Primary results

| File | Meaning | Recommended use |
|---|---|---|
| `JOBNAME.lst` | Consolidated lamaGOET report: program/cycle progress, energies, maximum shift/e.s.d., final refinement statistics, and residual-density extrema | First file to inspect; cite numerical results only after checking the corresponding CIF/FCF |
| `JOBNAME.archive.cif` | Crystallographic archive produced by Tonto | Deposition-oriented result; verify all data-quality, refinement, extinction, and uncertainty fields |
| `JOBNAME.fractional.cif` | Refined structure in fractional coordinates | Restarting a crystallographic calculation and comparing fractional parameters |
| `JOBNAME.cartesian.cif` | Refined structure expressed in Cartesian coordinates | Geometry inspection; not a replacement for the archive CIF |
| `JOBNAME.archive.fcf` | Observed and calculated reflection data from the final model | Difference maps and independent reflection-level checks |
| `JOBNAME.archive.fco` | Tonto reflection output used by compatible downstream workflows | Retain with the calculation; format support varies between programs |
| `JOBNAME.residual_density,cell.cube` | Final residual density on a unit-cell grid, when requested | Three-dimensional inspection of model deficiencies |

The archive CIF and FCF are the authoritative crystallographic pair. The
listing is a readable digest, not a substitute for them.

## Cycle directories

Molecular and periodic HAR calculations create directories such as
`1.tonto_cycle.JOBNAME`, `2.tonto_cycle.JOBNAME`, and program-specific
wavefunction-cycle directories. They retain the `stdin`, `stdout`, geometry,
reflection, and density artifacts belonging to that outer cycle. XCW uses
analogous `J.XCW_cycle.JOBNAME` directories.

Do not compare two files solely by their cycle number. In an external-program
HAR cycle, the theoretical calculation before a Tonto fit belongs to the
starting geometry, while the calculation immediately after the fit belongs to
that cycle's final geometry. lamaGOET's energy table follows this distinction:

\[
\Delta E_J = E(\text{final geometry of cycle }J)
             - E(\text{final geometry of cycle }J-1).
\]

The `maximum shift/e.s.d.` is the geometry-refinement convergence diagnostic.
It is not a wavefunction convergence threshold and should be read together
with the energy and structural changes.

## CIF statistics

The current compatible Tonto writes data-set and refinement quantities from
the actual reflection population used at the relevant stage. Important items
include:

| CIF item | Interpretation |
|---|---|
| `_diffrn_reflns_number` | Number of measured observations represented by the unmerged data set |
| `_diffrn_reflns_av_R_equivalents` | Agreement of symmetry-equivalent measured intensities |
| `_diffrn_reflns_av_unetI/netI` | Mean uncertainty-to-net-intensity measure defined by the CIF Core dictionary |
| `_diffrn_reflns_limit_*_{min,max}` | Measured index limits before symmetry merging |
| `_diffrn_reflns_theta_{min,max,full}` | Angular limits/completeness threshold derived from the measurement set |
| `_reflns_number_total` | Unique reflections entering the reported refinement statistic |
| `_reflns_number_gt` | Unique reflections satisfying the reported observed-reflection criterion |
| `_refine_ls_R_factor_{all,gt}` | Conventional residual over all or observed reflections |
| `_refine_ls_wR_factor_{all,gt}` | Weighted residual for the indicated population |
| `_refine_ls_goodness_of_fit_{all,gt}` | Goodness of fit for the indicated population and refined-parameter count |

The suffixes `all`, `gt`, and the historical Tonto alias `ref` must not be
treated as interchangeable labels. The archive writer recomputes each value
for its stated population. The definitions follow the IUCr CIF Core
dictionary; see {doc}`references`.

### Scale and extinction

Tonto refines an amplitude scale, whereas some programs display an intensity
scale or a differently normalized quantity. Squaring or comparing printed
numbers without first matching the definitions can therefore create an
apparent order-of-magnitude discrepancy with no difference in fitted
intensities. Compare calculated reflections and residuals, not just the raw
scale value.

When extinction is refined, the CIF should contain:

- `_refine_ls_extinction_method`;
- `_refine_ls_extinction_expression`;
- `_refine_ls_extinction_coef`, including its standard uncertainty when
  available.

Zachariasen--Larson and Becker--Coppens models are different physical models;
their coefficients are not directly interchangeable. For anisotropic or
mixed Becker--Coppens models, multiple parameters may additionally require a
description in `_refine_special_details`.

## Residual-density outputs

The final residual calculation rebuilds the current reflection population and
uses the final aspherical model. This matters when the input is unmerged:
weak-observation filtering, symmetry merging, and model-dependent systematic
absence pruning must be applied to the immutable original observations again,
not to a previously merged subset.

`JOBNAME.lst` records the residual-density maximum, minimum, and r.m.s. The
cube is the spatial field. A chemically recognizable residual feature is
evidence that the fitted model does not explain that feature; it is not by
itself proof of the cause. Check Fourier truncation, data resolution,
absorption/extinction, phase quality, basis/grid convergence, and model
constraints before assigning it chemically.

## Hirshfeld-atom cubes

With **Output Hirshfeld atoms after partition** enabled, Tonto writes one
unit-cell Gaussian cube per independent atom after a live partition. A value
in **Atom label** restricts output to that label. The cubes contain the density
assigned to the named atom while retaining the unit-cell context and atom
list; they are diagnostics of the partition, not isolated normalized atomic
wavefunctions.

The runner archives files matching `JOBNAME.Hirshfeld_atom_*,cell.cube` with
the cycle that created them. Absence of a requested cube is reported as a
warning because it usually means the chosen Tonto executable predates the
feature or the requested label did not match the current structure.

## Molecular orbital exports

For a finite canonical molecular-orbital calculation, the final residual step
can write:

| File | Content and boundary |
|---|---|
| `JOBNAME.47` | NBO archive, including the basis, density, overlap, and Fock information required by the implemented analysis path |
| `JOBNAME.wfn` | AIM2000-style finite molecular wavefunction |
| `JOBNAME.wfx` | Extended finite wavefunction including the available orbital space |

These formats describe finite orbitals. They cannot exactly encode an
infinite periodic Bloch wavefunction.

## Periodic wavefunction export

For Crystal23 and CP2K, **Write final periodic wavefunction as TREXIO** writes
`JOBNAME.periodic.trexio`, its metadata sidecar when present, and
`JOBNAME.periodic-wavefunction-export.log`. TREXIO is the exact-output route
for the cell, k-point weights, complex Bloch coefficients, density, overlap,
and Fock/KS information supported by the selected native interface.

The optional finite-cluster `.47`/WFN/WFX route is a *new finite all-electron
calculation* performed on a cluster cut from the converged periodic structure.
It is useful for molecular analysis but is not the periodic wavefunction. The
listing states this distinction explicitly and the periodic TREXIO file must
be retained as the reference result.

## Live GUI structure

The viewer follows only the CIF selected by the user and its descendants. It
does not load an arbitrary CIF merely because one exists in the working
directory. During a refinement it watches the published live CIF. The final
theoretical residual calculation may produce a geometry-only CIF without
ADPs; in that case the viewer combines the final positions with the ADPs from
the last successful refinement cycle so the final ellipsoid display is not
erased.

## Minimum archive for reproducibility

Retain at least:

1. the original CIF and unmerged or merged reflection file;
2. `job_options.txt` and the generated Tonto/external-program inputs;
3. `JOBNAME.lst`, archive CIF, archive FCF/FCO, and residual cube;
4. all cycle directories needed to reconstruct convergence;
5. native GRED/KRED or CP2K matrix/orbital exports for periodic work;
6. program versions, executable hashes where practical, basis source, grid,
   k mesh, and the lamaGOET/Tonto revisions.

Never replace the original observations with a merged file generated midway
through a refinement. The immutable unmerged set is required for a defensible
repeat of the reflection lifecycle.
