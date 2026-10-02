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
for its stated population. The definitions follow the [IUCr CIF Core
dictionary](https://www.iucr.org/resources/cif/dictionaries/cif_core); see
{doc}`references` for the archival standard.

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
description in `_refine_special_details`. The required nomenclature is set by
the [IUCr extinction-method
definition](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.extinction_method.html);
the primary model papers are collected in {doc}`references`.

### Post-refinement Flack result

When **Calculate post-refinement Flack x** is enabled and a valid Parsons
regression is available, Tonto prints a labelled absolute-structure block in
`stdout` containing $x$, its standard uncertainty, and the number of selected
Friedel quotients.  The archive CIF records the result as

```text
_refine_ls_abs_structure_details
;
Flack x determined using N quotients [(I+)-(I-)]/[(I+)+(I-)]
(Parsons, Flack and Wagner, Acta Cryst. B69 (2013) 249-259).
;
_refine_ls_abs_structure_Flack      x(su)
```

Here `N` is the number of pairs remaining after the published intensity and
outlier selections, and `x(su)` is written with its calculated standard
uncertainty.  If the option is off or no valid estimate exists, both CIF items
are written as unavailable (`.`); the program does not invent a value.

These data names follow the IUCr CIF Core definitions of
[`_refine_ls_abs_structure_Flack`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.abs_structure_Flack.html)
and
[`_refine_ls_abs_structure_details`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.abs_structure_details.html).
The method text and equations follow [Parsons, Flack and Wagner
(2013)](https://doi.org/10.1107/S2052519213010014).  This is a post-refinement
estimate: it does not state that an inversion-twin fraction was present in the
coordinate/ADP least-squares model.  See {doc}`principles` and
{doc}`limitations` before interpreting the number.

## Residual-density outputs

The final residual calculation rebuilds the current reflection population and
uses the final aspherical model. This matters when the input is unmerged:
weak-observation filtering, symmetry merging, and model-dependent systematic
absence pruning must be applied to the immutable original observations again,
not to a previously merged subset.

`JOBNAME.lst` records the standard residual-density maximum, minimum, and
r.m.s.; `JOBNAME.residual_density,cell.cube` is the spatial field. If
`SHELXL_RESIDUAL_MAP=true`, the listing also contains a labelled **Nominal
SHELXL FMAP 2 coefficient map** block and
`JOBNAME.shelxl_residual_density,cell.cube` is archived alongside the standard
cube. A requested comparison cube that is missing or empty is a hard runner
error, preventing a stale result from being reported as current. Both outputs
use the same final reflection population and grid. The comparison coefficient
is the nominal `FMAP 2` expression documented in the [official SHELXL
instruction reference](https://shelx.uni-goettingen.de/shelxl_html.php), not
an emulation of undocumented executable behavior.

At the start of every job, the runner removes the same-name working comparison
cube and any same-name cycle or CP2K archive copies. This happens even when the
option is off and before program dispatch, so a disabled or failed rerun cannot
leave an older cube that appears current.

A chemically recognizable residual feature is evidence that the fitted model
does not explain that feature; it is not by itself proof of the cause. Check
Fourier truncation, data resolution, absorption/extinction, phase quality,
basis/grid convergence, and model constraints before assigning it chemically.
Extrema from differently sampled grids are not directly comparable.

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

## Anharmonic atomic probability-density cubes

With **Export anharmonic atomic probability-density cubes** enabled, Tonto
writes files matching
`JOBNAME.anharmonic_pdf_*,gaussian.cube` after the final-model calculation.
The runner deletes same-name working and cycle-archive cubes before that
calculation, then archives only files produced by the current run. A requested
export that produces no cube is a hard error, preventing an older result from
being reported as current.

Each cube header identifies the atom and included second-, third-, and/or
fourth-order contributions. Values follow the Gaussian-cube atomic-unit
convention (bohr$^{-3}$). Standard output reports the signed positive and
negative integrals, and records the equal-magnitude positive/negative contour
suggestion in bohr$^{-3}$ and Å$^{-3}$. Adjacent unit-cell/image atoms may be
included in the cube atom list to preserve bonding context; they do not add
probability density to the selected atom's field. See {doc}`principles` for
the equations and {doc}`validation` for the XD/XDPDF numerical check.

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
and Fock/KS information supported by the selected native interface. The
container is defined by the [TREXIO
specification](https://trex-coe.github.io/trexio/) and [Posenitskiy *et al.*
(2023)](https://doi.org/10.1063/5.0148161).

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
