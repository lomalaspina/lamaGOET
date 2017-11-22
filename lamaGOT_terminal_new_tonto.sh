#!/bin/bash

TONTO_TO_ORCA(){
I=$[ $I + 1 ]
echo "Extrating XYZ for Orca cycle number $I"
echo "! $METHOD $BASISSET" > $JOBNAME.inp
echo "" >> $JOBNAME.inp
echo "%output"  >> $JOBNAME.inp
echo "   PrintLevel=Normal"  >> $JOBNAME.inp
echo "   Print[ P_Basis       ] 2"  >> $JOBNAME.inp
echo "   Print[ P_GuessOrb    ] 1"  >> $JOBNAME.inp
echo "   Print[ P_MOs         ] 1"  >> $JOBNAME.inp
echo "   Print[ P_Density     ] 1"  >> $JOBNAME.inp
echo "   Print[ P_SpinDensity ] 1"  >> $JOBNAME.inp
echo "end"  >> $JOBNAME.inp
echo ""  >> $JOBNAME.inp
echo "* xyz $CHARGE $MULTIPLICITY"  >> $JOBNAME.inp
awk 'NR>2' $JOBNAME.xyz  >> $JOBNAME.inp
echo "*"  >> $JOBNAME.inp
echo "Runing Orca, cycle number $I" 
$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.log
echo "Orca cycle number $I ended"
echo "Generation molden file for Orca cycle number $I"
orca_2mkl $JOBNAME -molden
echo "Orca cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
cp $JOBNAME.inp $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
cp $JOBNAME.log $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
}

SCF_TO_TONTO(){
echo "Writing Tonto stdin"
echo "{ " > stdin
echo "" >> stdin
if [ "$SCFCALCPROG" = "Gaussian" ]; then 
	echo "   read_g09_fchk_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk" >> stdin
else 
	if [ "$SCFCALCPROG" = "Orca" ]; then
		echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
	else
		echo "   name= $JOBNAME" >> stdin
	fi
fi
echo "" >> stdin
echo "   charge= $CHARGE" >> stdin       
echo "   multiplicity= $MULTIPLICITY" >> stdin
echo "" >> stdin
echo "   name= $JOBNAME" >> stdin
echo "" >> stdin
echo "   ! Process the CIF" >> stdin
echo "   CIF= {" >> stdin
if [ $J = 0 ]; then 
	echo "       file_name= $CIF.cif" >> stdin
else 
#	cp $JOBNAME'_cartesian.cif2' $JOBNAME.cartesian.cif2
	echo "       file_name= $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
fi
#if ( $J -gt 0 ); then
#echo "       file_name= $JOBNAME.$J.cartn-fragment.cif" >> stdin
#else
#echo "       file_name= $CIF" >> stdin
#fi
echo "    }" >> stdin
echo "" >> stdin
echo "   process_CIF" >> stdin
echo "" >> stdin
echo "   name= $JOBNAME" >> stdin
echo "" >> stdin
if [ "$SCFCALCPROG" = "Tonto" ]; then 
	echo "   basis_directory= $BASISSETDIR" >> stdin
	echo "   basis_name= $BASISSET" >> stdin
fi
if [ "$DISP" = "yes" ]; then 
	echo "   dispersion_coefficients= {" >> stdin
	L=${#XDISP[*]}
	while [ $L != "0" ]
	do
		echo "      ${XDISP[L]}" >> stdin
		L=$[ $L - 1 ]
	done
	echo "   }" >> stdin
fi
echo "" >> stdin
echo "   crystal= {    " >> stdin
echo "      xray_data= {   " >> stdin
echo "         thermal_smearing_model= hirshfeld" >> stdin
echo "         partition_model= mulliken" >> stdin
echo "         optimise_extinction= false" >> stdin
echo "         correct_dispersion= $DISP" >> stdin
echo "         optimise_scale_factor= true" >> stdin
echo "         wavelength= $WAVE Angstrom" >> stdin
echo "         REDIRECT $HKL.hkl" >> stdin
echo "         f_sigma_cutoff= $FCUT" >> stdin
echo "         refine_H_U_iso= $HADP" >> stdin
echo "" >> stdin
if [ "$SCFCALCPROG" != "Tonto" ]; then 
	echo "	 show_fit_output= TRUE" >> stdin
	echo "	 show_fit_results= TRUE" >> stdin
	echo "" >> stdin
fi
echo "" >> stdin
echo "      }  " >> stdin
echo "   }  " >> stdin
echo "" >> stdin
if [ "$HADP" = "yes" ]; then 
echo "	 set_isotropic_h_adps"  >> stdin
echo "" >> stdin
fi
echo "   ! Geometry    " >> stdin
echo "   put" >> stdin
echo "" >> stdin
if [ "$SCFCALCPROG" != "Tonto" ]; then 
	if [ "$SCCHARGES" = "true" ]; then 
		echo "     ! SC cluster charge SCF" >> stdin
		echo "      scfdata= {" >> stdin
		echo "      initial_MOs= existing" >> stdin
		if [ "$METHOD" = "HF" ]; then
			echo "      kind= rhf" >> stdin
		fi
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      save_cluster_charges= true" >> stdin
		echo "      convergence= 0.001" >> stdin
		echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
		echo "      output= YES" >> stdin
		echo "      output_results= YES" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   make_scf_density_matrix" >> stdin
		echo "   make_fock_matrix" >> stdin
		echo "" >> stdin
		echo "   ! SC cluster charge SCF" >> stdin
		echo "   scfdata= {" >> stdin
		echo "      initial_density= promolecule" >> stdin
		echo "      initial_MOs= existing" >> stdin
		if [ "$METHOD" = "HF" ]; then
			echo "      kind= rhf" >> stdin
		fi
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      put_cluster" >> stdin
		echo "      put_cluster_charges" >> stdin
		echo "" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   ! Make Hirshfeld structure factors" >> stdin
		echo "   fit_hirshfeld_atoms" >> stdin
		echo "" >> stdin
		echo "   write_xyz_file" >> stdin
	else
		echo "   ! Make Hirshfeld structure factors" >> stdin
		echo "   fit_hirshfeld_atoms" >> stdin
		echo "" >> stdin
		echo "   write_xyz_file" >> stdin
	fi
else
	if [ "$USEBECKE" = "true" ]; then 
		echo "   !Tight grid" >> stdin
		echo "   becke_grid = {" >> stdin
		echo "      set_defaults" >> stdin
		echo "      accuracy= $ACCURACY" >> stdin
		echo "      pruning_scheme= $BECKEPRUNINGSCHEME" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
	fi
	echo "   ! Normal SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_density= promolecule " >> stdin
	if [ "$METHOD" = "HF" ]; then
		echo "      kind= rhf" >> stdin
	fi
	echo "      use_SC_cluster_charges= FALSE" >> stdin
	echo "      convergence= 0.001" >> stdin
	echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   scf" >> stdin
	echo "" >> stdin
	echo "   ! SC cluster charge SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_MOs= restricted" >> stdin
	if [ "$METHOD" = "HF" ]; then
		echo "      kind= rhf" >> stdin
	fi
	if [ "$SCCHARGES" = "true" ]; then 
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= SCCRADIUS angstrom" >> stdin
	else
		echo "      use_SC_cluster_charges= FALSE" >> stdin
	fi
	echo "      convergence= 0.001" >> stdin
	echo "      diis= {" >> stdin
	echo "         convergence_tolerance= 0.0002" >> stdin
	echo "      }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   ! Make Hirshfeld structure factors" >> stdin
	echo "   refine_hirshfeld_atoms" >> stdin
fi
echo "" >> stdin
echo "}" >> stdin 
J=$[ $J + 1 ]
echo "Runing Tonto, cycle number $J" 
$TONTO
echo "Tonto cycle number $J ended"
if [ $J = 1 ]; then 
	#awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout 
	echo "====================" >> $JOBNAME.lst
	echo "Begin rigid-atom fit" >> $JOBNAME.lst
	echo "====================" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo "_________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo "Cycle   Fit         chi2         R       R_w        Max.     Max.  No. of  No. of     Energy         RMSD         Delta " >> $JOBNAME.lst
	echo "       Iter                                        Shift    Shift  params   eig's    at final      at final       Energy " >> $JOBNAME.lst
	echo "                                                    /esd    param          near 0     Geom.          Geom.                " >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo "_________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
#	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)    $ENERGIA   $RMSD   $ENERGY "  >> $JOBNAME.lst
fi
#	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)"  >> $JOBNAME.lst
#echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)    $ENERGIA2   $RMSD2   $DE"  >> $JOBNAME.lst
if [ "$SCFCALCPROG" != "Tonto" ]; then 
	mkdir $J.fit_cycle.$JOBNAME
	cp $JOBNAME.xyz $J.fit_cycle.$JOBNAME/$J.$JOBNAME.xyz
	cp stdin $J.fit_cycle.$JOBNAME/$J.stdin
	cp stdout $J.fit_cycle.$JOBNAME/$J.stdout
	cp $JOBNAME'.cartesian.cif2' $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
fi
}

#######################################################################

TONTO_TO_GAUSSIAN(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Gaussian cycle number $I"
	echo "%chk=./$JOBNAME.chk" > $JOBNAME.com
	echo "%rwf=./$JOBNAME.rwf" >> $JOBNAME.com
	echo "%int=./$JOBNAME.int" >> $JOBNAME.com
	echo "%mem=$MEM" >> $JOBNAME.com
	echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
	#echo "# rb3lyp/$BASISSET output=wfn" >> $JOBNAME.com
#	if [ "$METHOD" = "rks" ]; then
#		echo "# b3lyp/$BASISSET  nosymm output=wfn 6D 10F" | tee -a $JOBNAME.com $JOBNAME.lst
#	fi
	if [ "$SCCHARGES" = "true" ]; then 
   		echo "# $METHOD/$BASISSET Charge nosymm output=wfn 6D 10F" >> $JOBNAME.com
	else
		echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F" >> $JOBNAME.com
        fi
	echo "" >> $JOBNAME.com
	echo "$JOBNAME" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
### commented but working on new tonto, will use dylan's old write_xyz_file keyword because that one keeps the atom labels, florian's new one does not.
###	awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+4;d<=c-4;++d)print a[d]}' $JOBNAME.cartesian.cif2 | awk -v OFS='\t' 'NR%2==0 {print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' >> $JOBNAME.com 
	awk 'NR>2' $J.fit_cycle.$JOBNAME/$J.$JOBNAME.xyz >> $JOBNAME.com 
#	sleep 15 #check if needed
#	awk '{a[NR]=$0}/^_atom_site_Cartn_U_iso_or_equiv_esd/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.cartn-fragment.cif | awk 'NR%2==1 {print $1, $2, $3, $4}' >> $JOBNAME.com 
	echo "" >> $JOBNAME.com
	if [ "$SCCHARGES" = "true" ]; then 
        	awk '{a[NR]=$0}{b=12}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $2, $3, $4, $1 }' >> $JOBNAME.com
		echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
	fi
	echo "./$JOBNAME.wfn" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "Runing Gaussian, cycle number $I"
	$SCFCALC_BIN $JOBNAME.com
	echo "Gaussian cycle number $I ended"
	echo "Generation fcheck file for Gaussian cycle number $I"
	formchk $JOBNAME.chk $JOBNAME.fchk
     	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp $JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
}
######################  Gaussian done ########################
######################  Begin check energy ########################
CHECK_ENERGY(){
if [ "$SCFCALCPROG" = "Gaussian" ]; then 
	ENERGIA2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
	RMSD2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $2}'| tr -d '\r')
	echo "Gaussian cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
else
	ENERGIA2=$(sed -n '/Total Energy       :/p' $JOBNAME.log | awk '{print $4}' | tr -d '\r')
	RMSD2=$(sed -n '/Last RMS-Density change/p' $JOBNAME.log | awk '{print $5}' | tr -d '\r')
	echo "Orca cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
fi
#	DE=$(($ENERGIA - $ENERGIA2))
###	DE=$(echo "$ENERGIA2 - $ENERGIA" | bc)
	DE=$(awk "BEGIN {print $ENERGIA2 - $ENERGIA}")
#	DE=$(echo "$ENERGIA - $ENERGIA2" | bc)
#	DRMSD=$(($RMSD - $RMSD2))
	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout)    $ENERGIA2   $RMSD2   $DE"  >> $JOBNAME.lst
	ENERGIA=$ENERGIA2
	RMSD=$RMSD2
	echo "Delta E (cycle  $I - $[ I - 1 ]): $DE (convergency will reach when Delta E is smaller than 0.0001)"
#	J=$[ $J + 1 ]
#	echo "Runing Tonto, cycle number $J"
#	$TONTO
#	echo "Tonto cycle number $I ended"
#	cp stdout stdout.$J
}

######################  End check energy ########################
clear
declare -a XDISP
echo "Welcome to the interface for Hirsfeld Atom fit and Gaussian" 
echo "(You need to have coreutils installed on your machine to use this script)"
echo ""
echo "Please type the name of your Tonto executable [tonto]"
read TONTO
if [[ -z "$TONTO" ]]; then
	TONTO=$"tonto"
fi
echo "Which software for SCF steps, Gaussian, Orca or Tonto [Gaussian]"
read SCFCALCPROG
if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG=$"Gaussian"
fi
if [ "$SCFCALCPROG" != "Tonto" ]; then  
	echo "Please type the name of your SCF executable [g09]"
	read SCFCALC_BIN
	if [[ -z "$SCFCALC_BIN" ]]; then
		SCFCALC_BIN=$"g09"
	fi
fi
echo "Please type the name of the name for the job (one word)"
echo ""
read JOBNAME
echo "Please type the name of the cif file that you wish to submit (without extension)" #| tee -a "$JOBNAME.lst"
echo "" 
read CIF 
echo "Please type the name of the hkl file that you wish to submit (without extension)" 
echo "(this hkl should be a merged hkl that does not contain systematic absences)"
echo ""
read HKL
echo "Please type the wavelenght (in Angstrom) [0.71073]"
read WAVE
if [[ -z "$WAVE" ]]; then
	WAVE=$"0.71073"
fi
echo "Please enter the charge [0]"
echo ""
read CHARGE
if [[ -z "$CHARGE" ]]; then
	CHARGE=$"0"
fi
echo "Please enter the multiplicity [1]"
echo ""
read MULTIPLICITY
if [[ -z "$MULTIPLICITY" ]]; then
	MULTIPLICITY=$"1"
fi
if [ "$SCFCALCPROG" = "Tonto" ]; then  
	echo "Please enter the basis set directory [/usr/local/bin/basis_sets]"
	echo ""
	read BASISSETDIR
	if [[ -z "$BASISSETDIR" ]]; then
		BASISSETDIR=$"/usr/local/bin/basis_sets"
	fi
fi
echo "Method that you wish to use (Gaussian, Orca or Tonto format) [HF]"
echo ""
read METHOD
if [[ -z "$METHOD" ]]; then
	METHOD=$"HF"
fi
echo "Basis set that you wish to use (Gaussian, Orca or Tonto format) [STO-3G]"
echo ""
read BASISSET
if [[ -z "$BASISSET" ]]; then
	BASISSET=$"STO-3G"
fi
echo "Use cluster charges (yes or no)? [no]"
echo ""
read SCCHARGES
if [[ -z "$SCCHARGES" ]]; then
	SCCHARGES=$"no"
fi
if [ "$SCCHARGES" = "yes" ]; then  
	echo "Enter the SC Cluster charges radius in Angstrom [8]"
	echo ""
	read SCCRADIUS
	if [[ -z "$SCCRADIUS" ]]; then
		SCCRADIUS=$"8"
	fi
fi
if [ "$SCFCALCPROG" = "Tonto" ]; then  
	echo "Use becke grid (yes or no)? [no]"
	echo ""
	read USEBECKE
	if [[ -z "$USEBECKE" ]]; then
		USEBECKE=$"no"
	fi
	if [ "$USEBECKE" = "yes" ]; then  
		echo "Becke grid accuracy [low]"
		echo ""
		read BECKE
		if [[ -z "$BECKE" ]]; then
			BECKE=$"low"
		fi
		echo "Becke grid prunning scheme [jayatilaka2]"
		echo ""
		read BECKEPRUNINGSCHEME
		if [[ -z "$BECKEPRUNINGSCHEME" ]]; then
			BECKEPRUNINGSCHEME=$"jayatilaka2"
		fi
 	fi
fi
echo "Please enter the f_sigma_cutoff [4]"
echo ""
read FCUT
if [[ -z "$FCUT" ]]; then
	FCUT=$"4"
fi
echo "Refine H atom isotropically? [no]"
echo ""
read HADP
if [[ -z "$HADP" ]]; then
	HADP=$"no"
fi
echo "Would you like to apply dispersion corrections (yes or no)? [no]"
echo ""
read DISP
if [[ -z "$DISP" ]]; then
	DISP=$"no"
fi
if [ "$DISP" = "yes" ]; then
	L=$"1"
	echo "Please enter one atom type, f' and f'' values per line (empty line if no more to inform):"
	echo ""
	while [ ! ${finished} ]
	do
		read line
		if [ "$line" = "" ]; then
			finished=true
		else
			XDISP[$L]="$line"
			L=$[ $L + 1 ]
		fi
	done
fi
if [ "$SCFCALCPROG" != "Tonto" ]; then  
	echo "Please enter the number of processors available for the SCF job [1]"
	echo ""
	read NUMPROC
	if [[ -z "$NUMPROC" ]]; then
		NUMPROC=$"1"
	fi
	echo "Please enter the memory available for the SCF job (including the unit mb or gb) [1gb]"
	echo ""
	read MEM
	if [[ -z "$MEM" ]]; then
		MEM=$"1gb"
	fi
fi
#####################################################################################################
SECONDS=0
I=$"0"   ###counter for gaussian jobs
J=$"0"   ###counter for tonto fits
echo "###############################################################################################" > $JOBNAME.lst
echo "                                          lamaGOT                                              " >> $JOBNAME.lst
echo "###############################################################################################" >> $JOBNAME.lst
echo "Job started on:" >> $JOBNAME.lst
date >> $JOBNAME.lst
echo "User Inputs: " >> $JOBNAME.lst
echo "Tonto executable	: $TONTO"  >> $JOBNAME.lst 
echo "$($TONTO -v)" >> $JOBNAME.lst 
#awk 'NR==7 { print }' stdout >> $JOBNAME.lst      #print the tonto version, but there is no stdout yet
echo "SCF program	: $SCFCALCPROG" >> $JOBNAME.lst
echo "SCF executable	: $SCFCALC_BIN" >> $JOBNAME.lst
echo "Job name		: $JOBNAME" >> $JOBNAME.lst
echo "Input cif		: $CIF.cif" >> $JOBNAME.lst
echo "Input hkl		: $HKL.hkl" >> $JOBNAME.lst
echo "Wavelenght		: $WAVE" >> $JOBNAME.lst
echo "F_sigma_cutoff		: $FCUT" >> $JOBNAME.lst
echo "Charge			: $CHARGE" >> $JOBNAME.lst
echo "Multiplicity		: $MULTIPLICITY" >> $JOBNAME.lst
echo "Level of theory 	: $METHOD/$BASISSET" >> $JOBNAME.lst
if [ "$SCFCALCPROG" = "Tonto" ]; then 
	echo "Basis set directory	: $BASISSETDIR" >> $JOBNAME.lst
fi
echo "Refine Hydrogens anis.	: $HADP" >> $JOBNAME.lst
echo "Dispersion correction	: $DISP" >> $JOBNAME.lst
if [ $DISP = "yes" ]; then
	echo "Dispersion coefficients	:  " >> $JOBNAME.lst
	M=$L
	while [ $M != "0" ]
	do
		echo "${XDISP[M]}"  >> $JOBNAME.lst
		M=$[ $M - 1 ]
	done
fi
if [ "$SCFCALCPROG" != "Tonto" ]; then 
	echo "Only for Gaussian/Orca job	" >> $JOBNAME.lst
	echo "Number of processor 	: $NUMPROC" >> $JOBNAME.lst
	echo "Memory		 	: $MEM" >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "                                     Starting Geometry                                         " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
#####################################################################################################
###################### Begin extracting XYZ with tonto and input to gaussian ########################
#sed '/^# Cartesian axis system ADPs$/,$d' $CIF.cif > cut.cif
#sed -e '/# Tonto-specific key and data/,/# Standard CIF keys and data/d' $CIF.cif > cut.cif
	echo "{ " > stdin
	echo "" >> stdin
	echo "   ! Process the CIF" >> stdin
	echo "   CIF= {" >> stdin
	echo "       file_name= $CIF.cif" >> stdin
	echo "    }" >> stdin
	echo "" >> stdin
	echo "   process_CIF" >> stdin
	echo "" >> stdin
	echo "   name= $JOBNAME" >> stdin
	echo "" >> stdin
	echo "   put" >> stdin 
	echo "" >> stdin
	echo "   write_xyz_file" >> stdin
	#echo "###############################################################################################" >> $JOBNAME.lst
	###echo "   put_cif" >> stdin
	echo "" >> stdin
	echo "}" >> stdin 
	echo "Reading cif with Tonto"
	$TONTO
	mkdir $J.fit_cycle.$JOBNAME
	cp $JOBNAME.xyz $J.fit_cycle.$JOBNAME/$JOBNAME.starting_geom.xyz
	cp stdin $J.fit_cycle.$JOBNAME/$J.stdin
	cp stdout $J.fit_cycle.$JOBNAME/$J.stdout
	awk '{a[NR]=$0}/^Atom coordinates/{b=NR}/^Unit cell information/{c=NR}END{for(d=b-1;d<=c-2;++d)print a[d]}' stdout >> $JOBNAME.lst
	echo "Done reading cif with Tonto"
###rm cut.cif
#cp $JOBNAME'_cartesian.cif2' $JOBNAME.$J'_cartesian.cif2'
#######commented now that the put_cif is not working then that file doesn not exist...
#######cp $JOBNAME'_cartesian.cif2' $JOBNAME.$J.cartesian.cif2
	if [ "$SCFCALCPROG" = "Gaussian" ]; then 
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Starting Gaussian                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "%chk=./$JOBNAME.chk" > $JOBNAME.com 
		echo "%chk=./$JOBNAME.chk" >> $JOBNAME.lst 
		echo "%rwf=./$JOBNAME.rwf" | tee -a $JOBNAME.com  $JOBNAME.lst
		echo "%int=./$JOBNAME.int" | tee -a $JOBNAME.com  $JOBNAME.lst
		echo "%mem=$MEM" | tee -a $JOBNAME.com  $JOBNAME.lst
		echo "%nprocshared=$NUMPROC" | tee -a $JOBNAME.com $JOBNAME.lst
		#if [ "$METHOD" = "rks" ]; then
		#	echo "# b3lyp/$BASISSET  nosymm output=wfn 6D 10F" | tee -a $JOBNAME.com $JOBNAME.lst
		#fi
		echo "# $METHOD/$BASISSET  nosymm output=wfn 6D 10F" | tee -a $JOBNAME.com $JOBNAME.lst
		echo ""  | tee -a $JOBNAME.com $JOBNAME.lst
		echo "$JOBNAME" | tee -a $JOBNAME.com $JOBNAME.lst
		echo "" | tee -a  $JOBNAME.com $JOBNAME.lst
		echo "$CHARGE $MULTIPLICITY" | tee -a  $JOBNAME.com $JOBNAME.lst
		### commented but working on new tonto, will use dylan's old write_xyz_file keyword because that one keeps the atom labels, florian's new one does not.
		###awk '{a[NR]=$0}/^_atom_site_Cartn_U_iso_or_equiv_esu/{b=NR}/^# ==============/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.$J.cartesian.cif2 | awk -v OFS='\t' '{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }'| awk 'NR%2==1 {print }' | tee -a $JOBNAME.com $JOBNAME.lst
		awk 'NR>2' $JOBNAME.xyz | tee -a  $JOBNAME.com $JOBNAME.lst
		### old working
		###awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.cartn-fragment.cif | awk -v 	OFS='\t' '{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' | tee -a $JOBNAME.com $JOBNAME.lst
		#awk '{a[NR]=$0}/^Atom\ coordinates/{b=NR}/^Atomic\ displacement\ parameters\ \(ADPs\)/{c=NR}END{for(d=b+11;d<=c-4;++d)print a[d]}' stdout | awk 'NR%2==1 {print $2, $4, 	$5, $6}' > test.txt 
		#awk '{gsub("[(][^)]*[)]","")}1 {print }' test.txt >> $JOBNAME.com
		#rm test.txt
		echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
		echo "./$JOBNAME.wfn" | tee -a $JOBNAME.com  $JOBNAME.lst
		echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
		###################### End extracting XYZ with tonto and input to gaussian ########################
		###################### Begin first gaussian single point calculation and storing energy and RMSD ########################
		#put if Gaussian or Orca
		I=$"1"
		echo "Runing Gaussian, cycle number $I" 
		$SCFCALC_BIN $JOBNAME.com
		echo "Gaussian cycle number $I ended"
		ENERGIA=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
		RMSD=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $2}' | tr -d '\r')
		echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "Generation fcheck file for Gaussian cycle number $I"
		formchk $JOBNAME.chk $JOBNAME.fchk
		echo "Gaussian cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
	     	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
		cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
		cp $JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
		cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
	###################### End first gaussian single point calculation and storing energy and RMSD ########################
	###################### Begin first tonto fit ########################
		SCF_TO_TONTO
		TONTO_TO_GAUSSIAN
		CHECK_ENERGY
	else 
		if [ "$SCFCALCPROG" = "Orca" ]; then  
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Orca                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "! $METHOD $BASISSET" > $JOBNAME.inp
			echo "! $METHOD $BASISSET" >> $JOBNAME.lst
			echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "%output" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   PrintLevel=Normal" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_Basis       ] 2" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_GuessOrb    ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_MOs         ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_Density     ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_SpinDensity ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "end" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "* xyz $CHARGE $MULTIPLICITY" | tee -a $JOBNAME.inp $JOBNAME.lst
			awk 'NR>2' $JOBNAME.xyz | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "*" | tee -a $JOBNAME.inp $JOBNAME.lst
			I=$"1"
			echo "Runing Orca, cycle number $I" 
	 		$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.log
			echo "Orca cycle number $I ended"
			ENERGIA=$(sed -n '/Total Energy       :/p' $JOBNAME.log | awk '{print $4}' | tr -d '\r')
			RMSD=$(sed -n '/Last RMS-Density change/p' $JOBNAME.log | awk '{print $5}' | tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "Generation molden file for Orca cycle number $I"
			orca_2mkl $JOBNAME -molden
			echo "Orca cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
		     	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
			cp $JOBNAME.inp $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
			cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
			cp $JOBNAME.log $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
			SCF_TO_TONTO
			TONTO_TO_ORCA
			CHECK_ENERGY
		fi
	fi
	###################### First fit done start refeed gaussian ########################
	######################  Iterative begins ########################

	#echo "6.421e-09" | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}' | bc  #aqui aparece um numero em notacao cientifica e a condicao nao pode ser testada, o comando acima transforma ele em float mas nao ta funcionando

	#awk -v a="$DE" -v b="0.00001" 'BEGIN{print (a > b)}'
	while [ "$(awk -F'\t' 'function abs(x){return ((x < 0.0) ? -x : x)} BEGIN{print (abs('$DE') > 0.0001)}')" = 1 ]; do
	#while [ "$(echo "${DE=$(printf "%f", "$DE")} >= 0.000001" | bc -l)" -eq 1 ]; do  
		SCF_TO_TONTO
		if [ "$SCFCALCPROG" = "Gaussian" ]; then  
			TONTO_TO_GAUSSIAN
		else 
			TONTO_TO_ORCA
		fi
		CHECK_ENERGY
	done
	echo "_________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "                                     Final Geometry                                         " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo "Energy= $ENERGIA2, RMSD= $RMSD2" >> $JOBNAME.lst
	###commented but working, will change because the residual data is not being printed in the .lst file
	###echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Analysis of the Hirshfeld atom fit/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
	echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
	DURATION=$SECONDS
	echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
	echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
	exit
else
	SCF_TO_TONTO
	echo "_________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "                                     Final Geometry                                         " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
	DURATION=$SECONDS
	echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
	echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
	exit
fi
# falta incluir os residuos do stdout na lst file.
