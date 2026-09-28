# References

This manual distinguishes primary methodological literature from software
manuals and living online documentation. URLs were selected to resolve to the
publisher or software project wherever possible.

## lamaGOET and Tonto

1. L. A. Malaspina, A. Genoni and S. Grabowsky, “lamaGOET: an interface for
   quantum crystallography,” *J. Appl. Cryst.* **54** (2021), 987–995.
   [doi:10.1107/S1600576721002545](https://doi.org/10.1107/S1600576721002545).

2. [lamaGOET source repository](https://github.com/lomalaspina/lamaGOET),
   `cleanup` branch for the interface documented here.

3. [Tonto source repository](https://github.com/dylan-jayatilaka/tonto).
   Periodic and observed-density options in this manual require the compatible
   development branch identified in the calculation provenance.

## Hirshfeld atoms and HAR

4. F. L. Hirshfeld, “Bonded-atom fragments for describing molecular charge
   densities,” *Theor. Chim. Acta* **44** (1977), 129–138.
   [doi:10.1007/BF00549096](https://doi.org/10.1007/BF00549096).

5. D. Jayatilaka and B. Dittrich, “X-ray structure refinement using
   aspherical atomic density functions obtained from quantum-mechanical
   calculations,” *Acta Cryst.* A**64** (2008), 383–393.
   [doi:10.1107/S0108767308005709](https://doi.org/10.1107/S0108767308005709).

6. S. C. Capelli, H.-B. Bürgi, B. Dittrich, S. Grabowsky and D. Jayatilaka,
   “Hirshfeld atom refinement,” *IUCrJ* **1** (2014), 361–379.
   [doi:10.1107/S2052252514014845](https://doi.org/10.1107/S2052252514014845).

7. P. N. Ruth, R. Herbst-Irmer and D. Stalke, “Hirshfeld atom refinement
   based on projector augmented wave densities with periodic boundary
   conditions,” *IUCrJ* **9** (2022), 286–297.
   [doi:10.1107/S2052252522001385](https://doi.org/10.1107/S2052252522001385).

8. K. Chu, D. Jayatilaka, L. A. Malaspina, A. Genoni, G. Cametti, S. Mebs,
   D. Lentz, H.-B. Bürgi, S. V. Churakov and S. Grabowsky, “Periodic
   Hirshfeld Atom Refinement,” *J. Phys. Chem. Lett.* **17** (2026),
   3170–3179.
   [doi:10.1021/acs.jpclett.5c03918](https://doi.org/10.1021/acs.jpclett.5c03918).
   This is the primary publication for the lamaGOET/Tonto pHAR implementation.
   Its reported calculations used the historical Crystal23 XML interface.

9. D. E. P. Vanpoucke, P. Bultinck and I. Van Driessche, “Extending
   Hirshfeld-I to bulk and periodic materials,” *J. Comput. Chem.* **34**
   (2013), 405–417.
   [doi:10.1002/jcc.23088](https://doi.org/10.1002/jcc.23088).

10. M. L. Chodkiewicz, M. Woińska and K. Woźniak, “Hirshfeld atom like
   refinement with alternative electron density partitions,” *IUCrJ* **7**
   (2020), 1199–1215.
   [doi:10.1107/S2052252520013603](https://doi.org/10.1107/S2052252520013603).

11. [Current developments and trends in quantum crystallography](https://journals.iucr.org/b/issues/2024/04/00/je5055/index.html),
   *Acta Cryst.* B (2024). This review provides broader context for HAR,
   X-ray restrained wavefunctions, and current terminology.

## XCW/XRW and XWR

12. D. Jayatilaka and D. J. Grimwood, “Wavefunctions derived from experiment.
   I. Motivation and theory,” *Acta Cryst.* A**57** (2001), 76–86.
   [doi:10.1107/S0108767300013155](https://doi.org/10.1107/S0108767300013155).

13. D. J. Grimwood and D. Jayatilaka, “Wavefunctions derived from experiment.
    II. Further developments,” *Acta Cryst.* A**57** (2001), 87–100.
    [doi:10.1107/S0108767300013167](https://doi.org/10.1107/S0108767300013167).

14. M. L. Davidson, S. Grabowsky and D. Jayatilaka, “X-ray constrained
    wavefunctions based on Hirshfeld atoms. I. Method and review,” *Acta
    Cryst.* B**78** (2022), 312–332.
    [doi:10.1107/S2052520622004097](https://doi.org/10.1107/S2052520622004097).

15. M. L. Davidson, S. Grabowsky and D. Jayatilaka, “X-ray constrained
    wavefunctions based on Hirshfeld atoms. II. Reproducibility of electron
    densities in crystals of α-oxalic acid dihydrate,” *Acta Cryst.* B**78**
    (2022), 397–415.
    [doi:10.1107/S2052520622004103](https://doi.org/10.1107/S2052520622004103).
    This paper is especially relevant to the halting/overfitting and
    reproducibility problem.

## Crystallographic definitions

16. S. R. Hall, F. H. Allen and I. D. Brown, “The crystallographic
    information file (CIF): a new standard archive file for crystallography,”
    *Acta Cryst.* A**47** (1991), 655–685.
    [IUCr CIF Core dictionary](https://www.iucr.org/resources/cif/dictionaries/cif_core).

17. [CIF Core definition of `_refine_ls.extinction_method`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.extinction_method.html)
    and [definition of `_refine_ls.extinction_coef`](https://www.iucr.org/__data/iucr/cifdic_html/3_orig/CORE_DIC/Irefine_ls.extinction_coef.html).

18. W. H. Zachariasen, “A general theory of X-ray diffraction in crystals,”
    *Acta Cryst.* **23** (1967), 558–564,
    [doi:10.1107/S0365110X67003202](https://doi.org/10.1107/S0365110X67003202);
    A. C. Larson, “Inclusion of secondary extinction in least-squares
    calculations,” *Acta Cryst.* **23** (1967), 664–665,
    [doi:10.1107/S0365110X67003366](https://doi.org/10.1107/S0365110X67003366).
    These are the primary references for the commonly named
    Zachariasen/Larson treatment.

19. P. J. Becker and P. Coppens, “Extinction within the limit of validity of
    the Darwin transfer equations. I. General formalism for primary and
    secondary extinction and their applications to spherical crystals,”
    *Acta Cryst.* A**30** (1974), 129–147,
    [doi:10.1107/S0567739474000337](https://doi.org/10.1107/S0567739474000337),
    and “II. Refinement of extinction in spherical crystals of SrF2 and LiF,”
    *Acta Cryst.* A**30** (1974), 148–153,
    [doi:10.1107/S0567739474000349](https://doi.org/10.1107/S0567739474000349).
    These papers define the Becker–Coppens classifications and distributions.

20. G. M. Sheldrick, “Crystal structure refinement with SHELXL,” *Acta
    Cryst.* C**71** (2015), 3–8.
    [doi:10.1107/S2053229614024218](https://doi.org/10.1107/S2053229614024218).

    The [official SHELXL command
    list](https://shelx.uni-goettingen.de/shelxl_comlist.pdf) documents `FMAP 2`
    as an $F_o-F_c$ synthesis using calculated phases.  The
    [official online instruction
    reference](https://shelx.uni-goettingen.de/shelxl_html.php) defines
    `DAMP` as multiplication of the normal-matrix diagonal by
    $1+d/1000$ and documents its `LIMSE` shift/esd limit.
    The [official Olex2 refinement
    documentation](https://www.olexsys.org/olex2/docs/tasks/tasks/structure-refinement/)
    provides a software-level comparison of full-matrix/conjugate-gradient
    least squares and its Gauss--Newton and Levenberg--Marquardt solvers.

## Periodic electronic-structure programs

21. R. Dovesi *et al.*, *CRYSTAL23 User's Manual*, University of Torino
    (2023). [Official PDF](https://www.crystal.unito.it/include/manuals/crystal23.pdf)
    and [CRYSTAL documentation page](https://www.crystal.unito.it/documentation.html).

22. T. D. Kühne *et al.*, “CP2K: An electronic structure and molecular
    dynamics software package — Quickstep: Efficient and accurate electronic
    structure calculations,” *J. Chem. Phys.* **152** (2020), 194103.
    [doi:10.1063/5.0007045](https://doi.org/10.1063/5.0007045).

23. CP2K manual entries for
    [GAPW](https://manual.cp2k.org/trunk/methods/dft/gapw.html),
    [k points](https://manual.cp2k.org/trunk/methods/dft/k-points.html),
    [molecular-orbital/k-point output](https://manual.cp2k.org/trunk/methods/electronic_structure/molecular_orbitals.html),
    and [the `MO_KP` print section](https://manual.cp2k.org/trunk/CP2K_INPUT/FORCE_EVAL/DFT/PRINT/MO_KP.html).

## Basis and interchange formats

24. B. P. Pritchard, D. Altarawy, B. Didier, T. D. Gibson and T. L.
    Windus, “A New Basis Set Exchange: An Open, Up-to-Date Resource for the
    Molecular Sciences Community,” *J. Chem. Inf. Model.* **59** (2019),
    4814–4820.
    [doi:10.1021/acs.jcim.9b00725](https://doi.org/10.1021/acs.jcim.9b00725).

25. [Basis Set Exchange](https://www.basissetexchange.org/), used as a source
    of basis definitions subject to the program-specific conversion and
    all-electron/periodic restrictions described in this manual.

26. [TREXIO documentation](https://trex-coe.github.io/trexio/), for the
    interoperable periodic wavefunction container used by optional exports.

## Manual design references

27. [XD2015 manual](https://www.chem.gla.ac.uk/~louis/xd-home/docs/xd2015manual.pdf)
    and [XD2006 workshop manual](https://www.chem.gla.ac.uk/~louis/xdworkshop/workshop/documentation/xd2006manual.pdf),
    consulted for scientific-manual organization and crystallographic style.

28. [Gaussian keyword index](https://gaussian.com/keywords/) and
    [optimization keyword page](https://gaussian.com/opt/), consulted for the
    pattern of concise keyword definitions followed by examples. Gaussian
    input syntax in lamaGOET must still be checked against the manual for the
    installed licensed version.

## Additional method references used by implemented controls

29. H. D. Flack, “On enantiomorph-polarity estimation,” *Acta Cryst.*
    A**39** (1983), 876–881.
    [doi:10.1107/S0108767383001762](https://doi.org/10.1107/S0108767383001762).

30. S. Parsons, H. D. Flack and T. Wagner, “Use of intensity quotients and
    differences in absolute structure refinement,” *Acta Cryst.* B**69**
    (2013), 249–259.
    [doi:10.1107/S2052519213010014](https://doi.org/10.1107/S2052519213010014).

31. IUCr CIF Core definitions of
    [`_refine_ls_abs_structure_Flack`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.abs_structure_Flack.html)
    and
    [`_refine_ls_abs_structure_details`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.abs_structure_details.html).

32. IUCr CIF Core definitions of the anomalous-scattering terms
    [`_atom_type_scat_dispersion_real`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Iatom_type.scat_dispersion_real.html)
    and
    [`_atom_type_scat_dispersion_imag`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Iatom_type.scat_dispersion_imag.html).

33. K. Levenberg, “A method for the solution of certain non-linear problems
    in least squares,” *Q. Appl. Math.* **2** (1944), 164–168.
    [doi:10.1090/qam/10666](https://doi.org/10.1090/qam/10666).

34. D. W. Marquardt, “An algorithm for least-squares estimation of nonlinear
    parameters,” *SIAM J. Appl. Math.* **11** (1963), 431–441.
    [doi:10.1137/0111030](https://doi.org/10.1137/0111030).

35. C. K. Johnson, “The effect of thermal motion on interatomic distances and
    angles,” *Acta Cryst.* A**25** (1969), 187–194.
    [doi:10.1107/S0567739469000325](https://doi.org/10.1107/S0567739469000325).

36. K. N. Trueblood *et al.*, “Atomic displacement parameter nomenclature.
    Report of a subcommittee on atomic displacement parameter nomenclature,”
    *Acta Cryst.* A**52** (1996), 770–781.
    [doi:10.1107/S0108767396005697](https://doi.org/10.1107/S0108767396005697).

37. S. Grimme, J. Antony, S. Ehrlich and H. Krieg, “A consistent and accurate
    *ab initio* parametrization of density functional dispersion correction
    (DFT-D) for the 94 elements H–Pu,” *J. Chem. Phys.* **132** (2010),
    154104. [doi:10.1063/1.3382344](https://doi.org/10.1063/1.3382344).

38. S. Grimme, S. Ehrlich and L. Goerigk, “Effect of the damping function in
    dispersion corrected density functional theory,” *J. Comput. Chem.*
    **32** (2011), 1456–1465.
    [doi:10.1002/jcc.21759](https://doi.org/10.1002/jcc.21759).

39. M. Douglas and N. M. Kroll, “Quantum electrodynamical corrections to the
    fine structure of helium,” *Ann. Phys.* **82** (1974), 89–155.
    [doi:10.1016/0003-4916(74)90333-9](https://doi.org/10.1016/0003-4916(74)90333-9).

40. B. A. Hess, “Relativistic electronic-structure calculations employing a
    two-component no-pair formalism with external-field projection
    operators,” *Phys. Rev. A* **33** (1986), 3742–3748.
    [doi:10.1103/PhysRevA.33.3742](https://doi.org/10.1103/PhysRevA.33.3742).

41. A. D. Becke, “A multicenter numerical integration scheme for polyatomic
    molecules,” *J. Chem. Phys.* **88** (1988), 2547–2553.
    [doi:10.1063/1.454033](https://doi.org/10.1063/1.454033).

42. E. Posenitskiy *et al.*, “TREXIO: A file format and library for quantum
    chemistry,” *J. Chem. Phys.* **158** (2023), 174801.
    [doi:10.1063/5.0148161](https://doi.org/10.1063/5.0148161).

43. F. Kleemiss *et al.*, “Accurate crystal structures and chemical
    properties from NoSpherA2,” *Chem. Sci.* **12** (2021), 1675–1692.
    [doi:10.1039/D0SC05526C](https://doi.org/10.1039/D0SC05526C).

44. M. Woińska *et al.*, “Hirshfeld atom refinement for modelling strong
    hydrogen bonds,” *Sci. Adv.* **2** (2016), e1600192.
    [doi:10.1126/sciadv.1600192](https://doi.org/10.1126/sciadv.1600192).

45. M. Fugel *et al.*, “Probing the accuracy and precision of Hirshfeld atom
    refinement with HARt,” *IUCrJ* **5** (2018), 32–44.
    [doi:10.1107/S2052252517016010](https://doi.org/10.1107/S2052252517016010).

## Program, functional, basis and advanced-model references

46. D. Jayatilaka and D. J. Grimwood, “Tonto: A Fortran based
    object-oriented system for quantum chemistry and crystallography,” in
    *Computational Science — ICCS 2003*, LNCS **2660** (Springer, 2003),
    142–151.
    [doi:10.1007/3-540-44864-0_15](https://doi.org/10.1007/3-540-44864-0_15).

47. D. Jayatilaka, “Wave function for beryllium from X-ray diffraction
    data,” *Phys. Rev. Lett.* **80** (1998), 798–801.
    [doi:10.1103/PhysRevLett.80.798](https://doi.org/10.1103/PhysRevLett.80.798).

48. F. Neese, F. Wennmohs, U. Becker and C. Riplinger, “The ORCA quantum
    chemistry program package,” *J. Chem. Phys.* **152** (2020), 224108.
    [doi:10.1063/5.0004608](https://doi.org/10.1063/5.0004608). Also follow
    the [version-specific ORCA citation
    guidance](https://orca-manual.mpi-muelheim.mpg.de/contents/appendix/public.html)
    for the methods actually used.

49. P. R. Spackman, “Open Computational Chemistry (OCC) — A portable
    software library and program for quantum chemistry and crystallography,”
    *J. Open Source Softw.* **11** (2026), 9609.
    [doi:10.21105/joss.09609](https://doi.org/10.21105/joss.09609).

50. B. Meyer and A. Genoni, “Libraries of Extremely Localized Molecular
    Orbitals. 3. Construction and preliminary assessment of the new
    databanks,” *J. Phys. Chem. A* **122** (2018), 8965–8981.
    [doi:10.1021/acs.jpca.8b09056](https://doi.org/10.1021/acs.jpca.8b09056).

51. G. M. J. Barca *et al.*, “Recent developments in the general atomic and
    molecular electronic structure system,” *J. Chem. Phys.* **152** (2020),
    154102.
    [doi:10.1063/5.0005188](https://doi.org/10.1063/5.0005188). GAMESS-US
    requests additional method-specific citations where applicable.

52. Gaussian citations are release-specific. Use the exact program revision
    printed by the executable and the vendor's
    [official citation guidance](https://gaussian.com/citation/), together
    with primary papers for the selected electronic-structure method.

53. A. D. Becke, “Density-functional exchange-energy approximation with
    correct asymptotic behavior,” *Phys. Rev. A* **38** (1988), 3098–3100.
    [doi:10.1103/PhysRevA.38.3098](https://doi.org/10.1103/PhysRevA.38.3098).

54. C. Lee, W. Yang and R. G. Parr, “Development of the Colle–Salvetti
    correlation-energy formula into a functional of the electron density,”
    *Phys. Rev. B* **37** (1988), 785–789.
    [doi:10.1103/PhysRevB.37.785](https://doi.org/10.1103/PhysRevB.37.785).

55. A. D. Becke, “Density-functional thermochemistry. III. The role of exact
    exchange,” *J. Chem. Phys.* **98** (1993), 5648–5652.
    [doi:10.1063/1.464913](https://doi.org/10.1063/1.464913).

56. J. P. Perdew, K. Burke and M. Ernzerhof, “Generalized gradient
    approximation made simple,” *Phys. Rev. Lett.* **77** (1996), 3865–3868.
    [doi:10.1103/PhysRevLett.77.3865](https://doi.org/10.1103/PhysRevLett.77.3865).

57. C. Adamo and V. Barone, “Toward reliable density functional methods
    without adjustable parameters: The PBE0 model,” *J. Chem. Phys.* **110**
    (1999), 6158–6170.
    [doi:10.1063/1.478522](https://doi.org/10.1063/1.478522).

58. F. Weigend and R. Ahlrichs, “Balanced basis sets of split valence,
    triple zeta valence and quadruple zeta valence quality for H to Rn:
    Design and assessment of accuracy,” *Phys. Chem. Chem. Phys.* **7**
    (2005), 3297–3305.
    [doi:10.1039/B508541A](https://doi.org/10.1039/B508541A).

59. V. Petříček, M. Dušek and L. Palatinus, “Crystallographic computing
    system JANA2006: General features,” *Z. Kristallogr. Cryst. Mater.*
    **229** (2014), 345–352.
    [doi:10.1515/zkri-2014-1737](https://doi.org/10.1515/zkri-2014-1737).

60. C. K. Johnson and H. A. Levy, “Thermal-motion analysis using Bragg
    diffraction data,” in *International Tables for X-ray Crystallography*,
    Vol. IV, edited by J. A. Ibers and W. C. Hamilton (Kynoch Press, 1974),
    311–335. This is the primary tabulation used for third- and fourth-order
    Gram–Charlier thermal-motion coefficients; use the nomenclature in
    reference 36 when reporting them.

61. M. Hudák, D. Jayatilaka, L. Perašínová, S. Biskupič, J. Kožíšek and
    L. Bučinský, “X-ray constrained unrestricted Hartree–Fock and
    Douglas–Kroll–Hess wavefunctions,” *Acta Cryst.* A**66** (2010), 78–92.
    [doi:10.1107/S0108767309038744](https://doi.org/10.1107/S0108767309038744).

62. L. Bučinský, D. Jayatilaka and S. Grabowsky, “Importance of relativistic
    effects and electron correlation in structure factors and electron
    density of diphenyl mercury and triphenyl bismuth,” *J. Phys. Chem. A*
    **120** (2016), 6650–6669.
    [doi:10.1021/acs.jpca.6b05769](https://doi.org/10.1021/acs.jpca.6b05769).

63. S. Pawlędzio *et al.*, “Relativistic Hirshfeld atom refinement of an
    organo-gold(I) compound,” *IUCrJ* **8** (2021), 608–620.
    [doi:10.1107/S2052252521004541](https://doi.org/10.1107/S2052252521004541).

64. A. L. Spek, “Single-crystal structure validation with the program
    PLATON,” *J. Appl. Cryst.* **36** (2003), 7–13.
    [doi:10.1107/S0021889802022112](https://doi.org/10.1107/S0021889802022112).

65. A. L. Spek, “Structure validation in chemical crystallography,” *Acta
    Cryst.* D**65** (2009), 148–155.
    [doi:10.1107/S090744490804362X](https://doi.org/10.1107/S090744490804362X).

## Citation practice

For a publication, cite lamaGOET, Tonto, the electronic-structure program,
the method/basis, and the methodological paper appropriate to the workflow.
Also report the actual repository revisions and executable versions. Citing a
software package does not replace disclosure of the options that define the
scientific calculation.

For a Basis Set Exchange selection, retain the basis-specific bibliography
returned in its metadata in addition to references 24–25: the general Basis
Set Exchange paper is not a substitute for the authors' citation of the
selected basis family. Likewise, a generic program citation does not replace
method-specific references requested by that program. Finite-wavefunction
outputs such as NBO `.47`, WFN and WFX have program dialects; report the
producing program/version and do not describe a dialect as a universal
standard unless a normative specification has been identified.
