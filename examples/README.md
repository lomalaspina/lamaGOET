# Worked examples

These are the datasets from the 2024 Malaspina lab notes
(`../2024_Malaspina_lab_notes.pdf`). They are teaching examples rather than
an automated test suite, but the published numbers below make them the closest
thing lamaGOET has to an end-to-end check: if a refinement here stops matching,
something has broken.

All three use **Tonto only**, so no Gaussian, ORCA or CP2K licence is needed.

For a guided walk through these, with the theory and what to look for, see
[../docs/WORKSHOP.md](../docs/WORKSHOP.md).

## Running one

From inside an example folder, either open the interface

    bash /path/to/lamaGOET/lamaGOET_qt.sh

or, if you already have a `job_options.txt`, skip the interface entirely:

    bash /path/to/lamaGOET/lamaGOET.sh --run-job-options ./job_options.txt

Results are collected in `<job name>.lst`.

## The examples

### 1-epoxide

The simplest case: one whole molecule in the asymmetric unit, so no completion
is needed.

| Setting | Value |
|---|---|
| SCF program | Tonto |
| Wavelength | 0.71073 Å (Mo Kα) |
| F/σ cutoff | 4 |
| Method / basis | HF / STO-3G |
| Cluster charges | none |
| Start | Tonto IAM |

Published results:

| | SHELX IAM | Tonto IAM |
|---|---|---|
| R(F) | 0.0353 | 0.0355 |
| wR(F²) | 0.0964 | 0.0725 |
| ρ<sub>max</sub> | 0.205 | 0.220 |
| ρ<sub>min</sub> | −0.213 | −0.225 |
| reflections | 1308 | 1308 |
| parameters | 44 | 44 |
| C–H distances | 0.997(10) 0.993(10) 0.945(11) 0.947(11) | 1.003(9) 0.974(8) 0.971(10) 0.958(9) |

Roughly 30 seconds. The lab notes' main walkthrough uses def2-SVP; the table
above is the STO-3G comparison from the same document.

### 2-NH3

Only a third of the molecule is in the asymmetric unit, so **Complete
molecule(s) in the CIF** must be ticked. Hirshfeld Atom Refinement needs a
chemically complete fragment, because it runs a quantum-chemistry calculation
on it.

| | SHELX IAM |
|---|---|
| R(F) | 0.0071 |
| wR(F²) | 0.0191 |
| ρ<sub>max</sub> | 0.014 |
| ρ<sub>min</sub> | −0.013 |
| reflections | 98 |
| parameters | 8 |
| N–H distance | 0.842(7) |

### 3-Urea

A quarter of the molecule is in the asymmetric unit, so again tick **Complete
molecule(s) in the CIF**.

Note the wavelength: **0.3173 Å**, not the 0.71073 Å used by the other two.

| | SHELX IAM |
|---|---|
| R(F) | 0.0253 |
| wR(F²) | 0.0680 |
| ρ<sub>max</sub> | 0.352 |
| ρ<sub>min</sub> | −0.214 |
| reflections | 817 |
| parameters | 21 |
| N–H distances | 0.964(17) 0.900(12) |

## Suggested comparisons

The lab notes pose these as exercises, and they are a good check that the
refinement is behaving:

- Run epoxide with an F/σ cutoff of 4, then of 3, and compare the residual
  density. Weaker reflections are included in the second run.
- Repeat with point charges (self-consistent cluster charges, 8 Å radius,
  complete molecules) and see how much the hydrogen positions move.
- For urea, compare a plain HAR against one with an explicit cluster of
  molecules. The difference is much larger than it is for epoxide — worth
  understanding why.
