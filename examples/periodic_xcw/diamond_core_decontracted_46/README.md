# Diamond 46-AO paired-basis example

This directory preserves the exact custom basis pair used in the retained
Diamond core-decontraction experiment:

- `crystal23_basis.txt` is the CRYSTAL23 shell block. It has exactly one final
  `99 0` terminator.
- `core-decontracted-carbon` is the matching Tonto basis-library sidecar.

In the lamaGOET periodic-XCW panel, enable **Use an exact paired custom
Crystal23/Tonto basis**, choose these two files, and enter
`core-decontracted-carbon` as the Tonto basis name.

This is a carbon-only research example, not a universal default. It produces
23 AOs per carbon (46 AOs in the two-carbon primitive Diamond cell). The
standard POB-TZVP-rev2 reference produces 18 AOs per carbon (36 per primitive
cell). In matched fixed-geometry lambda-zero validation, both references
reproduced bonding density better than IAM, while the standard 36-AO result
was slightly better than this 46-AO result. The full intercell density is
encoded by all imported direct-lattice `P(R)` blocks, not by AO count alone.

Tonto verifies the XML AO count and central overlap against the selected
sidecar before periodic XCW starts. Do not mix either file with a different
basis definition.
