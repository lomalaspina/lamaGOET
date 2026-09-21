# Worked examples

The examples are intentionally separated into two classes:

- **re-runnable teaching examples** under `examples/`, which include input
  data and published comparison values; and
- **retained validation cases**, whose exact outputs document a particular
  development snapshot but may require licensed external programs and local
  installations.

Numbers labelled *target* are comparison values, not values silently inserted
by lamaGOET. Reproduce them with the program versions, basis, reflection
selection, and model stated for the example before interpreting a deviation.

## Common execution pattern

Copy an example to a writable directory; never run in the repository copy if
you want to preserve it as a reference.

```bash
cp -a /path/to/lamaGOET/examples/1-epoxide ~/lamagoet-work/epoxide
cd ~/lamagoet-work/epoxide
bash /path/to/lamaGOET/lamaGOET_qt.sh
```

After saving `job_options.txt`, the same calculation can be replayed without
the GUI:

```bash
bash /path/to/lamaGOET/lamaGOET.sh \
  --run-job-options "$PWD/job_options.txt"
```

Inspect `my_job.lst`, `my_job.archive.cif`, and `my_job.archive.fcf` together.

## Example 1: epoxide Tonto control

This is the shortest end-to-end molecular control and requires only the
compatible Tonto executable.

| Control | Value |
|---|---|
| SCF program | Tonto |
| Method / basis | RHF / def2-SVP |
| Wavelength | 0.71073 Å |
| F/σ cut | 4 |
| Reflection handling | packaged unmerged HKL; MERG 2 |
| Structure completion | off; the asymmetric unit contains the molecule |
| Starting model | Tonto IAM |

The current end-to-end control gives:

| Stage | R(F) | wR(F²) | Reflections | Parameters |
|---|---:|---:|---:|---:|
| Tonto IAM | 0.035630 | 0.073136 | 1,313 | 44 |
| Tonto HAR | 0.030272 | 0.053130 | 1,313 | 64 |

The retained calculation behind the older lecture table used the already
merged `epoxide_I_obs.hkl` file and an F/σ cutoff of 2. Its retained HAR values
were `R(F)=0.030237`, `wR(F²)=0.052652`, 1,308 reflections, and 64 parameters.
A rerun of that exact historical input with the validation executable
reproduced them as 0.030247 and 0.052663. The historical and packaged targets
use distinct reflection files and populations and are therefore not
interchangeable; “already merged” and the nominal cutoff alone do not fully
describe the earlier selection history.

STO-3G is deliberately **not** the acceptance basis for this example. With
the otherwise identical current input it produced HAR `R(F)=0.044052`, worse
than the IAM. That is a useful basis-quality warning, not an installation
target. Agreement with the def2-SVP control at the stated tolerance checks the
input/model path; it is not a universal tolerance across compilers or future
method changes. The automated harness accepts R, wR, and GoF within an absolute
`1×10⁻⁴` of these targets and requires the reflection and parameter counts to
match exactly.

Useful variations are to lower the cut from 4 to 3 and to add
self-consistent cluster charges. Record both the changed reflection count and
the changed structural parameters; a change in residual density alone does
not identify which choice caused it.

## Example 2: NH3 with symmetry completion

`examples/2-NH3/nh3_third.cif` contains only one third of the molecule in the
asymmetric unit. Enable **Complete molecule(s) in the CIF with Tonto**. This is
not the same as visually growing the structure: Tonto must receive a complete
quantum-chemical fragment while refining only the crystallographic asymmetric
unit.

The retained SHELX IAM comparison is:

- `R(F)=0.0071`;
- `wR(F²)=0.0191`;
- 98 reflections and 8 parameters;
- N--H = 0.842(7) Å.

For a HAR comparison, report the final N--H distance, H-atom displacement
ellipsoid eigenvalues/orientation, reflection population, residual extrema,
and convergence history. A lower R factor alone is insufficient evidence of
a physically improved hydrogen model.

## Example 3: urea

`examples/3-Urea/urea.cif` contains one quarter of the molecule, so enable
Tonto completion. Set the experimental wavelength to **0.3173 Å**; retaining
the common Mo Kα default would describe a different experiment.

The retained SHELX IAM comparison has `R(F)=0.0253`, `wR(F²)=0.0680`, 817
reflections, 21 parameters, and N--H distances of 0.964(17) and 0.900(12) Å.
Use this example to compare an isolated molecular HAR with an explicit
crystal cluster. Keep basis, method, reflection selection, and refinement
flags fixed when attributing a change to the environment model.

## Periodic HAR: Crystal23 native GRED versus legacy XML

This is a format-equivalence test, not a basis-convergence study.

1. Prepare the same converged restricted all-electron Crystal23 calculation
   twice.
2. Select **Native GRED** for one lamaGOET run and **Legacy XML** for the
   other.
3. Hold the CIF, HKL, basis, method, k mesh, stockholder model, grid, and
   refinement flags fixed.
4. Compare FCF reflection records, final fractional coordinates, ADPs, and
   statistics.

Retained tests gave identical FCF files for NH3, chiral quartz, and
non-centrosymmetric natrolite at the written precision. For natrolite the GRED
file was 25.72 MB versus 845.15 MB for XML. This establishes equivalence of
the two import paths for those cases; it does not establish that every
Crystal23 calculation or unrestricted state is supported by GRED.

## Periodic HAR: CP2K native matrices versus legacy XML

Select **Native CP2K (density, overlap and Fock)** and run one complete
`ha_fit` cycle. The matched legacy control must use the same structure,
all-electron basis, functional, k mesh, and stockholder settings.

Retained one-cycle results were:

| System | k mesh | Reflections | Native and XML final R(F) |
|---|---:|---:|---:|
| NH3, BLYP | 2×2×2 | 81 | 0.007280 |
| Diamond, PBE | 6×6×6 | 57 | 0.005859 |

The native tests also checked the density-matrix electron trace and the
Kohn--Sham/Fock orbital equation. See {doc}`validation` for the numerical
residuals and boundaries.

## Periodic XCW: Diamond paired basis

The directory `examples/periodic_xcw/diamond_core_decontracted_46` contains an
exact Crystal23/Tonto custom-basis pair. In the periodic-XCW panel:

1. enable **Use an exact paired custom Crystal23/Tonto basis**;
2. choose `crystal23_basis.txt` and `core-decontracted-carbon`;
3. enter `core-decontracted-carbon` as the Tonto basis name;
4. first run λ = 0 at fixed geometry and ADPs;
5. only after the λ-zero gates pass, explore a nonzero λ path.

The pair yields 23 AOs per carbon, 46 AOs in the two-carbon primitive cell.
It is a core-radial-flexibility experiment, not a universal target. In the
matched retained controls, the standard 36-AO POB-TZVP-rev2 result had
`R(F)=0.005680` and χ² = 3.035515, while the 46-AO result had
`R(F)=0.006054` and χ² = 3.287344. Both were better than the matched IAM
`R(F)=0.009500`, but the larger AO count was not automatically better.

## Historical ten-case archive

`Tests/inputs` retains outputs from the former `RUN_tests.sh` driver for
Gaussian, Tonto, and ELMOdb molecular cases, including cluster-charge and
dispersion variants. `Tests/test_scientific_archives.py` checks that the
artifacts and exact recorded CIF values remain intact. It does **not** claim a
fresh electronic-structure rerun.

To execute current live cases, use the opt-in driver:

```bash
bash Tests/run_scientific_regressions.sh nh3-Tonto yellow-Tonto
```

The driver stages input in a temporary directory. Set
`LAMAGOET_KEEP_SCIENTIFIC_WORK=1` to retain it. External executables and
licences remain the operator's responsibility.

## Reporting an example

For a scientifically useful report include:

- input-data provenance and whether the reflection file was unmerged;
- space group, wavelength, resolution, cut and MERG rule;
- program/version, method, all-electron basis and basis provenance;
- periodic cell setting, k mesh, density interface, stockholder and grids;
- refined/fixed parameter classes, extinction model, scale convention;
- every outer-cycle maximum shift/e.s.d. and energy;
- final CIF/FCF statistics, residual extrema, key distances and ADPs;
- relevant executable and source revisions, and any warnings.

Copying only the lowest R factor omits the evidence needed to reproduce or
interpret the model.
