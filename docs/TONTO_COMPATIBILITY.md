# Keeping up with Tonto

lamaGOET talks to Tonto in two directions, and both are fragile:

1. It **writes keywords** into the `stdin` file Tonto reads.
2. It **reads headings** out of the `stdout` file Tonto writes, to build the
   `<my_job>.lst` summary.

Neither is a stable interface. When Tonto renames a keyword, lamaGOET's job
dies at the first cycle. When Tonto renames an output heading, lamaGOET keeps
running and quietly produces an incomplete summary, which is worse.

This page records what has already changed, so a reviewer can see the whole
set at once rather than inferring it from individual commits.

## Fixed

### `thermal_smearing_model=` no longer exists

**Symptom:** every ordinary job failed on its first cycle:

```
Error in DIFFRACTION_DATA.READ:process_keyword ...
unknown option: thermal_smearing_model=
```

followed by Tonto printing every keyword it does accept.

**Cause:** lamaGOET wrote `thermal_smearing_model= atom-based` unconditionally
for all non-powder jobs.

**Fix:** the line is **deleted**, not renamed. Its job — choosing how the
density is partitioned before thermal smearing — now belongs to
`partition_model=`, which lamaGOET already writes on the following line. The
old value `atom-based` meant one-centre partitioning, which is what the `oc-`
prefix of `oc-hirshfeld`, `oc-crystal23` and the rest denotes. Renaming would
have set an invalid value (`atom-based` is not in Tonto's accepted list) and
then repeated the key.

### `Rigid-atom fit results` is no longer written

**Symptom:** none that a user would notice, which is the problem. Four places
extracted a block of results by finding this heading. When a search finds
nothing, awk leaves the line number unset, and

```awk
for (d = b-2; d < c-1; ++d) print a[d]
```

starts at −2 and copies **all** of stdout into the summary rather than one
block.

**Fix:** retargeted at `Structure refinement results`, which current Tonto does
write.

### The IAM result never reached the summary

**Symptom:** a job started from a Tonto IAM showed only the HAR numbers in
`<my_job>.lst`, under a heading that said `Begin rigid-atom fit`. The IAM figures
were in `stdout` but not in the file the lab notes call "always the file that
contains all the results" — so the IAM-versus-HAR comparison the notes ask for
could not be made from it.

**Cause:** Tonto heads the two refinements differently, and only the second was
being copied:

```
IAM refinement                 <- the starting model
Structure refinement results   <- the Hirshfeld atom refinement
```

**Fix:** `APPEND_IAM_RESULTS` in both runners.

## Still outstanding

Nothing known. The per-cycle convergence table, previously listed here as
broken, is fixed — see below.

## The per-cycle convergence table

`<my_job>.lst` used to print

```
Cycle   Fit      initial        final            R              R_w   ...
```

and then no rows at all. Two separate causes:

**For Gaussian, ORCA, OCC and Crystal**, every field was extracted by finding
a `Rigid-atom fit results` heading, which current Tonto does not write.
`FIT_TABLE_SUMMARY` now locates the last fit table by the headings Tonto does
write, and normalises the two shapes it comes in: the IAM table has ten columns
and a single chi², the Hirshfeld one has twelve, leading with a cycle number
and carrying both an initial and a final chi².

**For Tonto**, the table was empty for a different reason: Tonto runs the
refinement cycles internally, so there are no lamaGOET cycles to tabulate.
`CHECK_ENERGY`, which writes the rows, is only called for external programs.
A Tonto run now says that in place of the empty table, and points at the two
refinement blocks, which do carry the numbers.

The Tonto case is verified against the epoxide example. The external-program
case is not: no Gaussian, ORCA, OCC or Crystal was available here.

## Which Tonto to build

lamaGOET does not work with every Tonto branch. On the `antlr4` branch the
keyword above is commented out in `foofiles/diffraction_data.read.foo`:

```
! case ("thermal_smearing_model=       "); .read_temperature_factor_model
```

Branches that carry the lamaGOET-facing features include `lamaGOET`,
`Lolo_CP2K` and `lorraine`. The 2024 lab notes say `release-no-ptr`, which
predates all of this.

## Checking a new Tonto

Run the epoxide example (`examples/1-epoxide`) with Tonto, `HF/STO-3G`,
F/σ cutoff 4, no cluster charges, starting from a Tonto IAM, and confirm:

```
IAM refinement                R(F) 0.035630   44 parameters
```

against the published `R(F) 0.0355`, 44 parameters. If Tonto rejects a keyword
it will say so on the first cycle and list every keyword it accepts, which is
the quickest way to find the next rename.
