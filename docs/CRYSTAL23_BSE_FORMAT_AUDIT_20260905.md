# CRYSTAL23 Basis Set Exchange format audit

## Conclusion

The def2-TZVP export used by `Natrolite_crystal23_periodic_GKRED` already matches
CRYSTAL23's general-basis input format. No converter rewrite, shell deletion,
exponent adjustment, or basis replacement was made. No Tonto production code
was changed. The original calculation folder was not modified.

## Format reference and checks

Reference: [CRYSTAL23 manual, section 2.2.1, printed pages 20–23](https://crystalsolutions.eu/upload/2022-12-14_12-12-06_crystal23.pdf).

- Element records use `NAT NSHL`; atomic numbers associate bases with atoms, not
  their position in the input list.
- General shells use `ITYB LAT NG CHE SCAL`, followed by NG primitive records.
- LAT maps S/SP/P/D/F/G to 0/1/2/3/4/5. A primitive row has an exponent and one
  coefficient, except SP, which has separate S and P coefficients.
- The documented NG limits checked here are 10 for S/P and 6 for D.
- CHE specifies the initial shell electron population; it is not a contraction
  coefficient. Shell capacities and neutral per-element totals are correct.
- One `99 0` ends the entire mixed-element section.

The manual's internal AO ordering table is **not** an instruction to rearrange
radial coefficient rows. CRYSTAL itself constructs the angular components;
D/F shells contain five/seven spherical AOs. Reordering exponents without their
paired coefficients would change the basis and is not a format correction.

## Exact Natrolite comparison

The current lamaGOET renderer (BSE 0.12) produces a byte-identical `basis_gen.txt`:

```text
SHA256 c43b2d593864b54882223c6abe3e7f3b0ea63be48082f98ee76fcb648c6e60ad
```

The new regression test compares every exponent/coefficient pair and complete
contraction directly against raw BSE JSON, independently of BSE's CRYSTAL writer.
It checks that no radial function was lost or added. BSE may permute complete
shells into compact-to-diffuse order; their contents are unchanged.

| Element | Shells | Spherical AOs per atom | Sum CHE |
| --- | ---: | ---: | ---: |
| H | 4 | 6 | 1 |
| O | 11 | 31 | 8 |
| Na | 12 | 32 | 11 |
| Al | 13 | 37 | 13 |
| Si | 13 | 37 | 14 |

CRYSTAL reports 46 atoms, 474 shells, 1290 AOs and 380 electrons for the complete
calculation, consistent with these definitions.

## Root cause of the RHOLSK failure

The original run fails at `RHOLSK: BASIS SET LINEARLY DEPENDENT`, after reading
the basis. An isolated rerun reproduced this in about 5 seconds. A second run
permuted complete shell records without changing CHE or any exponent/coefficient;
it reached exactly the same error and retained all 1290 AOs.

Two additional EIGS diagnostic runs found negative overlap eigenvalues at all
five k-points. The minimum at Gamma was -4.5511e-5 in both shell orders. Negative
eigenvalue counts were 6, 6, 4, 6 and 8 respectively. The spectra agreed to the
printed precision except one difference of 1e-7. Thus shell ordering does not
resolve this numerical failure.

This is numerical rather than exact linear dependence. The molecular def2-TZVP
basis contains diffuse functions (the smallest exponents include 0.01926862 for
Na S and 0.03000000 for Na P). In the periodic Natrolite lattice, overlaps
between their translated copies are large enough that CRYSTAL's default
Coulomb screening (T1/T2 = 6; nominal `TOLINTEG 6 6 6 6 12`) makes the computed
overlap matrix slightly indefinite.

The manual's EIGS documentation relates negative reciprocal-space overlap
eigenvalues and RHOLSK/CHOLSK failures to numerical dependence. Basis
conditioning/integral accuracy is a separate issue from input formatting.

## Correction

An accuracy scan changed only the five `TOLINTEG` values, retaining all 1290
AOs and every original exponent and contraction coefficient:

| TOLINTEG | Negative overlap eigenvalues | Lowest eigenvalue |
| --- | ---: | ---: |
| CRYSTAL default | 30 | -4.5511e-5 |
| 7 7 7 7 14 | 4 | -4.786e-7 |
| **8 8 8 8 16** | **0** | **+1.7598e-7** |
| 10 10 10 10 20 | 0 | +1.6021e-7 |

lamaGOET therefore now has a `CRYSTAL_TOLINTEG` option. Its default `auto`
behaviour is deliberately narrow:

- a CRYSTAL built-in/periodic basis keeps CRYSTAL's own defaults;
- an external or Basis Set Exchange basis receives `TOLINTEG 8 8 8 8 16`;
- `default` explicitly suppresses the record, and five custom positive integer
  values may be entered in the GUI.

This is the smallest tested accuracy that makes every sampled overlap matrix
positive. It does not silently remove functions with `LDREMO`, alter exponents,
combine S and P shells, or replace the user's chosen basis. The runners also
stop immediately after a failed CRYSTAL SCF, before attempting the properties
step, and report a specific diagnostic for RHOLSK/CHOLSK failures.

Retained isolated inputs, outputs, scripts and numerical summaries:

```text
/home/lorraine/private_Tonto/Lolo_tests/Natrolite/bse_order_validation_20260905/
/home/lorraine/private_Tonto/Lolo_tests/Natrolite/natrolite_rholsk_accuracy_20260905/
```

CRYSTAL's diagnostic executable returned status zero even on the original
RHOLSK failure, so validation explicitly inspects the output instead of relying
on the process status. A serial `MAXCYCLE 1` smoke run with the corrected input
passed the former five-second RHOLSK failure point and continued in the
expensive 1290-AO calculation for 625 seconds before it was deliberately
terminated. It contained neither RHOLSK nor CHOLSK. The EIGS result proves the
overlap correction, but neither check is reported as a completed SCF or HAR
refinement.

## Regression validation

```bash
cd /home/lorraine/lamaGOET_cleanup
PYTHONPATH=. .venv-qt/bin/python Tests/test_qt_basis_exchange.py
bash Tests/run_all.sh
git diff --check
```

2026-09-05: all 10 basis-export tests passed; all 23 test files in the full
lamaGOET suite passed, with no skips. Shell syntax, Python compilation and
`git diff --check` passed. Changes are local and uncommitted.
