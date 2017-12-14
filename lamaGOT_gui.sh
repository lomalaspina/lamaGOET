#!/bin/bash
Encoding=UTF-8

GET_CHARGE(){
awk 'NF==5 {print $5} ' $JOBNAME.gamess.inp | gawk 'BEGIN { FS = "" } {print $1}' | awk '{ if ($1 == "N") print 7; else if ($1 == "H") print 1; else if ($1 == "O") print 8; else if ($1 == "C") print 6; else if ($1 == "S") print 16; }' > atoms_Z
}

GAMESS_ELMODB(){
PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
echo "title" > $JOBNAME.gamess.inp
echo "prova $JOBNAME - $BASISSET - closed shell SCF" >> $JOBNAME.gamess.inp
echo "charge $CHARGE " >> $JOBNAME.gamess.inp
if [ "$MULTIPLICITY" != "1" ]; then
	echo "multiplicity $MULTIPLICITY" >> $JOBNAME.gamess.inp
fi
echo "adapt off" >> $JOBNAME.gamess.inp
echo "nosym" >> $JOBNAME.gamess.inp
echo "geometry angstrom" >> $JOBNAME.gamess.inp
awk '$1 ~ /ATOM/ {printf "%f\t %f\t %f\t %s\t %s\n", $6, $7, $8, "carga", $3} ' $CIF > atoms
awk '{print $5}' atoms | gawk 'BEGIN { FS = "" } {print $1}' | awk '{ if ($1 == "N") print "7.0"; else if ($1 == "H") print "1.0"; else if ($1 == "O") print "8.0"; else if ($1 == "C") print "6.0"; else if ($1 == "S") print "16.0"; }' > atoms_Z
awk 'FNR==NR{a[NR]=$1;next}{$4=a[FNR]}1' atoms_Z atoms > full
awk '{printf "%f\t %f\t %f\t %s\t %s\n", $1, $2, $3, $4, $5}' full >> $JOBNAME.gamess.inp
#awk '$1 ~ /ATOM/ {printf "%f\t %f\t %f\t %s\t %s\n", $6, $7, $8, "carga", $3} ' $CIF >> $JOBNAME.gamess.inp
rm atoms 
rm atoms_Z 
rm full
echo "end" >> $JOBNAME.gamess.inp
echo "basis $BASISSET" >> $JOBNAME.gamess.inp
echo "runtype scf" >> $JOBNAME.gamess.inp
echo "scftype rhf" >> $JOBNAME.gamess.inp
echo "enter " >> $JOBNAME.gamess.inp
I=$[ $I + 1 ]
echo "Calculating overlap integrals with gamessus, cycle number $I" 
$GAMESS < $JOBNAME.gamess.inp > $JOBNAME.gamess.out
echo "Gamess cycle number $I ended"
mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
cp $JOBNAME.gamess.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.inp
cp $JOBNAME.gamess.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.out
cp sao  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.sao
rm ed* 
rm gamess_input*
if ! grep -q 'OVERLAP INTEGRALS WRITTEN ON FILE sao' "$JOBNAME.gamess.out"; then
	echo "ERROR: Calculation of overlap integrals with gamessus finished with error, please check the $I.th gamess.out file for more details" | tee -a $JOBNAME.lst
	unset MAIN_DIALOG
	exit 0
else 
	ln -s $ELMOLIB LIBRARIES
	cp $SCFCALC_BIN .
	echo " "'$INPUT_METHOD'"      basis_set='$BASISSET' ncpus=1 divcon=.false. rotvirt=.false. full_occ=.true. full_virt=.false. max_atom=2000000 "'$END'" " > $JOBNAME.elmodb.inp
	echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' nssbond=0 ntail=0 nspec=0 max_atail=50 max_frtail=50 maxsh=40 "'$END'"  " >> $JOBNAME.elmodb.inp
	$SCFCALC_BIN < $JOBNAME.elmodb.inp > $JOBNAME.elmodb.out
	if ! grep -q 'Number of electrons =' "$JOBNAME.elmodb.out"; then
		echo "ERROR: elmodb finished with error, please check the $I.th elmodb.out file for more details" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
	else
		sed -i 's/Alpha Orbital Energies/Alpha MO coefficients/g' OUTPUT.fchk
	fi
fi
}

TONTO_TO_ORCA(){
I=$[ $I + 1 ]
echo "Extrating XYZ for Orca cycle number $I"
if [ "$METHOD" = "rks" ]; then
	echo "! blyp $BASISSET" > $JOBNAME.inp
else
	if [ "$METHOD" = "uks" ]; then
		echo "! ublyp $BASISSET" > $JOBNAME.inp
	else
		echo "! $METHOD $BASISSET" > $JOBNAME.inp
	fi
fi
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
if [ "$SCCHARGES" = "true" ]; then 
	awk '{a[NR]=$0}{b=12}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", "Q\t" $2, $3, $4, $1 }' >> $JOBNAME.inp
fi
echo "*"  >> $JOBNAME.inp
echo "Runing Orca, cycle number $I" 
$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.log
echo "Orca cycle number $I ended"
if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
	echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
	unset MAIN_DIALOG
	exit 0
fi
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
echo "   keyword_echo_on" >> stdin
echo "" >> stdin
if [ "$SCFCALCPROG" = "Gaussian" ]; then
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
	echo "   read_g09_fchk_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk" >> stdin
elif [ "$SCFCALCPROG" = "Orca" ]; then
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
	echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
else
	echo "   name= $JOBNAME" >> stdin
fi
echo "" >> stdin
#echo "   charge= $CHARGE" >> stdin       
#echo "   multiplicity= $MULTIPLICITY" >> stdin
#echo "" >> stdin
echo "   ! Process the CIF" >> stdin
echo "   CIF= {" >> stdin
if [ $J = 0 ]; then 
	echo "       file_name= $CIF" >> stdin
	if [ "$XHALONG" = "true" ]; then
           	if [[ ! -z "$BHBOND" ]]; then
		   	echo "       BH_bond_length= $BHBOND angstrom" >> stdin
	   	fi
           	if [[ ! -z "$CHBOND" ]]; then
		   	echo "       CH_bond_length= $CHBOND angstrom" >> stdin
	   	fi
           	if [[ ! -z "$NHBOND" ]]; then
		   	echo "       NH_bond_length= $NHBOND angstrom" >> stdin
	   	fi
           	if [[ ! -z "$OHBOND" ]]; then
		   	echo "       OH_bond_length= $OHBOND angstrom" >> stdin
	   	fi
	fi
else 
#	cp $JOBNAME'_cartesian.cif2' $JOBNAME.cartesian.cif2
	echo "       file_name= $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
fi
#if ( $J -gt 0 ); then
#cp $JOBNAME'_cartesian.cif2' $JOBNAME.cartesian.cif2
#echo "       file_name= $JOBNAME.cartesian.cif2" >> stdin
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
	echo "   basis_name= $BASISSETT" >> stdin
	echo "" >> stdin
fi
if [ "$DISP" = "yes" ]; then 
	echo "   	 dispersion_coefficients= {" >> stdin
	echo "   	 $(cat DISP_inst.txt)" >> stdin
#commented but its the working one
#	for ((L=0; i<${#XDISP[]*]}; L++));
#	do
#	    echo "      ${XDISP[L]}" >> stdin
#	done
	echo "   	 }" >> stdin
	echo "" >> stdin
fi
if [[ $J = 0 && "$COMPLETECIF" = "true" ]]; then
	echo "   cluster= {" >> stdin
	echo "      defragment= $COMPLETECIF" >> stdin
	echo "      make_info" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
fi
echo "   charge= $CHARGE" >> stdin       
echo "   multiplicity= $MULTIPLICITY" >> stdin
echo "" >> stdin
if [[ $J = 0 && "$IAMTONTO" = "true" ]]; then 
	echo ""
	echo "   crystal= {    " >> stdin
	if [ "$COMPLETECIF" = "true" ]; then
		echo "      defragment= $COMPLETECIF" >> stdin
		echo "      make_info" >> stdin
		echo "      put_cluster_info" >> stdin
	fi
	echo "      xray_data= {   " >> stdin
	echo "         optimise_extinction= false" >> stdin
	echo "         correct_dispersion= $DISP" >> stdin
	echo "         wavelength= $WAVE Angstrom" >> stdin
	echo "         REDIRECT $HKL" >> stdin
	echo "         f_sigma_cutoff= $FCUT" >> stdin
	echo "         refine_H_U_iso= $HADP" >> stdin
	echo "" >> stdin
	echo "         show_fit_output= true" >> stdin
	echo "         show_fit_results= true" >> stdin
	echo "" >> stdin
	echo "      }  " >> stdin
	echo "   }  " >> stdin
	echo "" >> stdin
	echo "   ! Geometry    " >> stdin
	echo "   put" >> stdin
	echo "" >> stdin
	echo "   IAM_refinement" >> stdin
	echo "" >> stdin
fi
echo "" >> stdin
echo "   crystal= {    " >> stdin
if [[ $J = 0 && "$COMPLETECIF" = "true" ]]; then
	echo "      defragment= $COMPLETECIF" >> stdin
	echo "      make_info" >> stdin
	echo "      put_cluster_info" >> stdin
fi
echo "      xray_data= {   " >> stdin
echo "         thermal_smearing_model= hirshfeld" >> stdin
echo "         partition_model= mulliken" >> stdin
echo "         optimise_extinction= false" >> stdin
echo "         correct_dispersion= $DISP" >> stdin
echo "         optimise_scale_factor= true" >> stdin
echo "         wavelength= $WAVE Angstrom" >> stdin
echo "         REDIRECT $HKL" >> stdin
echo "         f_sigma_cutoff= $FCUT" >> stdin
echo "         refine_H_U_iso= $HADP" >> stdin
if [[ "$SCFCALCPROG" = "Tonto" && "$IAMTONTO" = "true" ]]; then 
	echo "" >> stdin
	echo "         show_fit_output= false" >> stdin
	echo "         show_fit_results= false" >> stdin
fi
echo "" >> stdin
if [ "$SCFCALCPROG" != "Tonto" ]; then 
	echo "	 show_fit_output= TRUE" >> stdin
	echo "	 show_fit_results= TRUE" >> stdin
	echo "" >> stdin
fi
if [ "$POSONLY" = "true" ]; then 
	echo "	 refine_positions_only= $POSONLY" >> stdin
fi
if [ "$ADPSONLY" = "true" ]; then 
	echo "	 refine_ADPs_only= $ADPSONLY" >> stdin
fi
if [ "$REFHADP" = "false" ]; then
	if [ "$ADPSONLY" != "true" ]; then 
		echo "	 refine_H_ADPs= $REFHADP" >> stdin 
	fi
fi
if [ "$REFHPOS" = "false" ]; then
	if [ "$ADPSONLY" != "true" ]; then
		echo "	 refine_H_pos= $REFHPOS" >> stdin 
	fi
fi
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
		echo "      kind= $METHOD" >> stdin
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
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
		echo "      kind= $METHOD" >> stdin
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
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
	echo "      kind= $METHOD" >> stdin
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
	echo "      kind= $METHOD" >> stdin
	if [ "$SCCHARGES" = "true" ]; then 
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
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
sed -i 's/(//g' $JOBNAME.xyz
sed -i 's/)//g' $JOBNAME.xyz
echo "Tonto cycle number $J ended"
if ! grep -q 'Wall-clock time taken' "stdout"; then
	echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
	unset MAIN_DIALOG
	exit 0
fi
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
	cp $JOBNAME'.archive.cif' $J.fit_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fco' $J.fit_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME'.archive.fcf' $J.fit_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp gaussian-point-charges $J.fit_cycle.$JOBNAME/$J.gaussian-point-charges
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
	if [ "$METHOD" = "rks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# blyp/$BASISSET Charge nosymm output=wfn 6D 10F" >> $JOBNAME.com
		else
			echo "# blyp/$BASISSET nosymm output=wfn 6D 10F" >> $JOBNAME.com
	        fi
	else
		if [ "$METHOD" = "uks" ]; then
			if [ "$SCCHARGES" = "true" ]; then 
		   		echo "# ublyp/$BASISSET Charge nosymm output=wfn 6D 10F" >> $JOBNAME.com
			else
				echo "# ublyp/$BASISSET nosymm output=wfn 6D 10F" >> $JOBNAME.com
		        fi
		else
			if [ "$SCCHARGES" = "true" ]; then 
		   		echo "# $METHOD/$BASISSET Charge nosymm output=wfn 6D 10F" >> $JOBNAME.com
			else
				echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F" >> $JOBNAME.com
		        fi
		fi			
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
	if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
		echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
	fi
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

run_script(){
SECONDS=0
I=$"0"   ###counter for gaussian jobs
J=$"0"   ###counter for tonto fits
#removing  0 0 0 line 
awk '{if (($1) != "0" && ($2) != "0" && ($3) != "0" ) print}' $HKL > $JOBNAME.tonto_edited.hkl
#backing up hkl input file and copying the one without the 0 line to the $HKL variable
if [ -f "$JOBNAME.tonto_edited.hkl" ]; then
	cp $HKL $JOBNAME.your_input.hkl
	cp $JOBNAME.tonto_edited.hkl $HKL
	rm $JOBNAME.tonto_edited.hkl
	echo "WARNING: HKL has been formated, your original input is saved with the name $JOBNAME.your_input.hkl!"
fi
#checking if numbers are grown together and separating them. note that this will ignore the header lines if is exists.
if [[ ! -z "$(awk ' NF<5 && NF>2 {print $0}' $HKL)" ]]; then
	gawk 'BEGIN { FS = "" } { for (i = 1; i <= NF; i = i + 1) h=$1$2$3$4; k=$5$6$7$8; l=$9$10$11$12; i_f=$13$14$15$16$17$18$19$20; sig=$21$22$23$24$25$26$27$28; print h, k, l, i_f, sig }' $HKL > $JOBNAME.tonto_edited.hkl
	cp $HKL $JOBNAME.your_input.hkl
	cp $JOBNAME.tonto_edited.hkl $HKL
	rm $JOBNAME.tonto_edited.hkl
fi
if [ "$WRITEHEADER" = "true" ]; then
  	#checking if the header was not there already
	if [[ ! -z "$(grep "reflection_data= {" $HKL)" ]]; then
		echo "header was already in the hkl file, nothing to do."
	else
		#putting the header in
		sed -i '1 i\   data= {' $HKL 
		if [ "$ONF" = "true" ]; then
			sed -i '1 i\  keys= { h= k= l= f_exp= f_sigma= }' $HKL 
	     	elif [ "$ONF2" = "true" ]; then
			sed -i '1 i\  keys= { h= k= l= i_exp= i_sigma= }' $HKL 
		else
			echo "ERROR: Please select the format of the hkl file for header (F or F^2)" | tee -a $JOBNAME.lst
			unset MAIN_DIALOG
			exit 0
		fi
		sed -i '1 i\ reflection_data= {' $HKL 
		sed -i '$ a\   }' $HKL
		sed -i '$ a\  }' $HKL 
		sed -i '$ a\ REVERT' $HKL 
	fi
fi
echo "###############################################################################################" > $JOBNAME.lst
echo "                                           lamaGOT                                             " >> $JOBNAME.lst
echo "###############################################################################################" >> $JOBNAME.lst
echo "Job started on:" >> $JOBNAME.lst
date >> $JOBNAME.lst
echo "User Inputs: " >> $JOBNAME.lst
echo "Tonto executable	: $TONTO"  >> $JOBNAME.lst 
echo "$($TONTO -v)" >> $JOBNAME.lst 
#awk 'NR==7 { print }' stdout >> $JOBNAME.lst      #print the tonto version, but there is no stdout yet
echo "SCF program		: $SCFCALCPROG" >> $JOBNAME.lst
if [ "$SCFCALCPROG" != "Tonto" ]; then 
	echo "SCF executable		: $SCFCALC_BIN" >> $JOBNAME.lst
fi
echo "Job name		: $JOBNAME" >> $JOBNAME.lst
echo "Input cif		: $CIF" >> $JOBNAME.lst
echo "Input hkl		: $HKL" >> $JOBNAME.lst
echo "Wavelenght		: $WAVE" >> $JOBNAME.lst
echo "F_sigma_cutoff		: $FCUT" >> $JOBNAME.lst
echo "Charge			: $CHARGE" >> $JOBNAME.lst
echo "Multiplicity		: $MULTIPLICITY" >> $JOBNAME.lst
if [ "$SCFCALCPROG" = "Tonto" ]; then 
	echo "Level of theory 	: $METHOD/$BASISSETT" >> $JOBNAME.lst
	echo "Basis set directory	: $BASISSETDIR" >> $JOBNAME.lst
else
	echo "Level of theory 	: $METHOD/$BASISSET" >> $JOBNAME.lst
fi
if [ "$SCFCALCPROG" = "Tonto" ]; then 
	echo "Becke grid (not default): $USEBECKE" >> $JOBNAME.lst
	if [ "$USEBECKE" = "true" ]; then
		echo "Becke grid accuracy	: $ACCURACY" >> $JOBNAME.lst
		echo "Becke grid pruning scheme	: $BECKEPRUNINGSCHEME" >> $JOBNAME.lst
	fi
fi
if [ "$SCFCALCPROG" != "elmodb" ]; then 
	echo "Use SC cluster charges 	: $SCCHARGES" >> $JOBNAME.lst
	if [ "$SCCHARGES" = "true" ]; then
		echo "SC cluster charge radius: $SCCRADIUS Angstrom" >> $JOBNAME.lst
		echo "Complete molecules	: $DEFRAG" >> $JOBNAME.lst
	fi
fi
echo "Refine position and ADPs: $POSADP" >> $JOBNAME.lst
echo "Refine positions only	: $POSONLY" >> $JOBNAME.lst
echo "Refine ADPs only	: $ADPSONLY" >> $JOBNAME.lst
if [ "$POSONLY" != "true" ]; then
	echo "Refine H ADPs 		: $REFHADP" >> $JOBNAME.lst
	if [ "$REFHADP" = "true" ]; then
		echo "Refine Hydrogens anis.	: $HADP" >> $JOBNAME.lst
	fi
fi
echo "Dispersion correction	: $DISP" >> $JOBNAME.lst
if [ $DISP = "yes" ]; then
	echo "			  $(cat DISP_inst.txt)" >> $JOBNAME.lst
# commented but I think it was working
#for loop in { 1..$NUMATOMTYPE }
#		do
#		echo "Dispersion coefficients	:  ${ATOMTYPE[loop]} ${FP[loop]} ${FPP[loo]}" >> $JOBNAME.lst
#	done	

fi
if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then 
	echo "Only for Gaussian/Orca job	" >> $JOBNAME.lst
	echo "Number of processor 	: $NUMPROC" >> $JOBNAME.lst
	echo "Memory		 	: $MEM" >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "                                     Starting Geometry                                         " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
#####################################################################################################
###################### Begin extracting XYZ with tonto and input to gaussian ########################
#sed '/^# Cartesian axis system ADPs$/,$d' $CIF > cut.cif
###commented but was working before, now with the new cifs the put_tonto command is not working because it doesnt have the vcv matrix to generate the geom table... should add a ensure that it has the vcv matrix to calculate the geom blocks... I will use the cif entered by the user then...
###sed -e '/# Tonto-specific key and data/,/# Standard CIF keys and data/d' $CIF > cut.cif
	echo "{ " > stdin
	echo "" >> stdin
	echo "   keyword_echo_on" >> stdin
	echo "" >> stdin
	echo "   ! Process the CIF" >> stdin
	echo "   CIF= {" >> stdin
	echo "       file_name= $CIF" >> stdin
	if [ "$XHALONG" = "true" ]; then
           	if [ ! -z "$BHBOND" ]; then
		   	echo "       BH_bond_length= $BHBOND angstrom" >> stdin
	   	fi
           	if [ ! -z "$CHBOND" ]; then
		   	echo "       CH_bond_length= $CHBOND angstrom" >> stdin
	   	fi
           	if [ ! -z "$NHBOND" ]; then
		   	echo "       NH_bond_length= $NHBOND angstrom" >> stdin
	   	fi
           	if [ ! -z "$OHBOND" ]; then
		   	echo "       OH_bond_length= $OHBOND angstrom" >> stdin
	   	fi
	fi
	###echo "       file_name= cut.cif" >> stdin
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
	sed -i 's/(//g' $JOBNAME.xyz
	sed -i 's/)//g' $JOBNAME.xyz
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: something wrong with your input cif file, please check the stdout file for more details" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
	fi
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
		if [ "$METHOD" = "rks" ]; then
			echo "# blyp/$BASISSET nosymm output=wfn 6D 10F" | tee -a $JOBNAME.com $JOBNAME.lst    
		else
			if [ "$METHOD" = "uks" ]; then
				echo "# ublyp/$BASISSET nosymm output=wfn 6D 10F" | tee -a $JOBNAME.com $JOBNAME.lst
			else
				echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F" | tee -a $JOBNAME.com $JOBNAME.lst
		        fi
		fi			
		echo ""  | tee -a $JOBNAME.com $JOBNAME.lst
		echo "$JOBNAME" | tee -a $JOBNAME.com $JOBNAME.lst
		echo "" | tee -a  $JOBNAME.com $JOBNAME.lst
		echo "$CHARGE $MULTIPLICITY" | tee -a  $JOBNAME.com $JOBNAME.lst
		### commented but working on new tonto, will use dylan's old write_xyz_file keyword because that one keeps the atom labels, florian's new one does not.
		###awk '{a[NR]=$0}/^_atom_site_Cartn_U_iso_or_equiv_esu/{b=NR}/^# ==============/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.$J.cartesian.cif2 | awk -v OFS='\t' 			'{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }'| awk 'NR%2==1 {print }' | tee -a $JOBNAME.com $JOBNAME.lst
		awk 'NR>2' $JOBNAME.xyz | tee -a  $JOBNAME.com $JOBNAME.lst
		### old working
		###awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.cartn-fragment.cif | awk -v 			OFS='\t' '{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' | tee -a $JOBNAME.com $JOBNAME.lst
		#awk '{a[NR]=$0}/^Atom\ coordinates/{b=NR}/^Atomic\ displacement\ parameters\ \(ADPs\)/{c=NR}END{for(d=b+11;d<=c-4;++d)print a[d]}' stdout | awk 'NR%2==1 {print $2, $4, 	$5, $6}' > test.txt 
		#awk '{gsub("[(][^)]*[)]","")}1 {print }' test.txt >> $JOBNAME.com
		#rm test.txt
		echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
	 	#if [ "$SCCHARGES" = "true" ]; then 
	        #	awk '{a[NR]=$0}{b=12}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $2, $3, $4, $1 }' | tee -a $JOBNAME.com  $JOBNAME.lst
		#	echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
		#fi
		echo "./$JOBNAME.wfn" | tee -a $JOBNAME.com  $JOBNAME.lst
		echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
		###################### End extracting XYZ with tonto and input to gaussian ########################
		###################### Begin first gaussian single point calculation and storing energy and RMSD ########################
		#put if Gaussian or Orca
		I=$"1"
		echo "Runing Gaussian, cycle number $I" 
		$SCFCALC_BIN $JOBNAME.com
		echo "Gaussian cycle number $I ended"
		if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
			echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
			unset MAIN_DIALOG
			exit 0
		fi
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
			if [ "$METHOD" = "rks" ]; then
				echo "! blyp $BASISSET" > $JOBNAME.inp
				echo "! blyp $BASISSET" >> $JOBNAME.lst
			else
				if [ "$METHOD" = "uks" ]; then
					echo "! ublyp $BASISSET" > $JOBNAME.inp
					echo "! ublyp $BASISSET" >> $JOBNAME.lst
				else
					echo "! $METHOD $BASISSET" > $JOBNAME.inp
					echo "! $METHOD $BASISSET" >> $JOBNAME.lst
				fi
			fi
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
			if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
				echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
				unset MAIN_DIALOG
				exit 0
			fi
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
elif [ "$SCFCALCPROG" = "Tonto" ]; then
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
else
	GAMESS_ELMODB
	SCF_TO_TONTO
#	echo "title" > $JOBNAME.gamess.inp
#	echo "prova $JOBNAME - $BASISSET - closed shell SCF" >> $JOBNAME.gamess.inp
#	echo "charge $CHARGE " >> $JOBNAME.gamess.inp
#	if [ "$MULTIPLICITY" != "1" ]; then
#		echo "multiplicity $MULTIPLICITY" >> $JOBNAME.gamess.inp
#	fi
#	echo "adapt off" >> $JOBNAME.gamess.inp
#	echo "nosym" >> $JOBNAME.gamess.inp
#	echo "geometry angstrom" >> $JOBNAME.gamess.inp
#	awk '$1 ~ /ATOM/ {printf "%f\t %f\t %f\t %s\t %s\n", $6, $7, $8, "carga", $3} ' $CIF >> $JOBNAME.gamess.inp
#	echo "end" >> $JOBNAME.gamess.inp
#	echo "basis $BASISSET" >> $JOBNAME.gamess.inp
#	echo "runtype scf" >> $JOBNAME.gamess.inp
#	echo "scftype rhf" >> $JOBNAME.gamess.inp
#	echo "enter " >> $JOBNAME.gamess.inp
#	I=$[ $I + 1 ]
#	echo "Calculating overlap integrals with gamessus, cycle number $I" 
#	gamess_int < $JOBNAME.gamess.inp > $JOBNAME.gamess.out
#	echo "Gamess cycle number $I ended"
#	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
#	cp $JOBNAME.gamess.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.inp
#	cp $JOBNAME.gamess.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.out
#	cp sao  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.sao
#	rm ed* gamess_input*
#	if ! grep -q 'OVERLAP INTEGRALS WRITTEN ON FILE sao' "$JOBNAME.log"; then
#		echo "ERROR: Calculation of overlap integrals with gamessus finished with error, please check the $I.th gamess.out file for more details" | tee -a $JOBNAME.lst
#		unset MAIN_DIALOG
#		exit 0
#	else 
#		cp $SCFCALC_BIN .
#		echo " $INPUT_METHOD      basis_set='$BASISSET' ncpus=1 divcon=.false. rotvirt=.false. full_occ=.true. full_virt=.false. max_atom=2000000 $END" > $JOBNAME.elmodb.inp
#		echo " $INPUT_STRUCTURE   pdb_file='$CIF' nssbond=0 ntail=0 nspec=0 max_atail=50 max_frtail=50 maxsh=40 $END  " >> $JOBNAME.elmodb.inp
#		./$SCFCALC_BIN < $JOBNAME.elmodb.inp > $JOBNAME.elmodb.out
#		if ! grep -q 'Number of electrons =' "$JOBNAME.log"; then
#			echo "ERROR: elmodb finished with error, please check the $I.th elmodb.out file for more details" | tee -a $JOBNAME.lst
#			unset MAIN_DIALOG
#			exit 0
#		else
#			sed -i 's/Alpha Orbital Energies/Alpha MO coefficients/g' OUTPUT.fchk
#	fi
fi

}

export MAIN_DIALOG='

<window window_position="1" title="Tonto Gaussian Orca interface">

 <vbox scrollable="true" space-expand="true" space-fill="true" height="1200" width="800" >

  <hbox homogeneous="True" >

    <hbox homogeneous="True">
     <frame>
      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>Welcome to the interface for Hirsfeld Atom fit and Gaussian/Orca</span>"</label></text>
      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>(You need to have coreutils installed on your machine to use this script</span>"</label></text>
      <pixmap>
       <width>40</width>
       <height>40</height>
       <input file>/usr/local/include/Tonto_logo.png</input>
      </pixmap>
     </frame>  
    </hbox>

  </hbox>
  
  <frame>

 <hbox>
    <text xalign="0" use-markup="true" wrap="false" space-fill="True"  space-expand="True"><label>Software for SCF calculation</label></text>
      <radiobutton space-fill="True"  space-expand="True">
        <label>Gaussian</label>
        <default>true</default>
        <action>if true echo 'SCFCALCPROG="Gaussian"'</action>  
        <action>if true enable:MEM</action>
        <action>if true enable:NUMPROC</action>
        <action>if true disable:BASISSETDIR</action>
        <action>if true enable:SCFCALC_BIN</action>
        <action>if false disable:MEM</action>
        <action>if false disable:NUMPROC</action>
        <action>if false disable:SCFCALC_BIN</action>
        <action>if false enable:BASISSETDIR</action>
        <action>if true disable:BASISSETT</action>
        <action>if false enable:BASISSETT</action>
        <action>if true disable:GAMESS</action>
        <action>if false enable:GAMESS</action>
        <action>if true disable:ELMOLIB</action>
        <action>if false enable:ELMOLIB</action>
        <action>if true enable:XHALONG</action>
        <action>if false disable:XHALONG</action>
      </radiobutton>
      <radiobutton space-fill="True"  space-expand="True">
        <label>Orca</label>
        <default>false</default>
        <action>if true echo 'SCFCALCPROG="Orca"'</action>
        <action>if true enable:MEM</action>
        <action>if true enable:NUMPROC</action>
        <action>if true enable:SCFCALC_BIN</action>
        <action>if true disable:BASISSETDIR</action>
        <action>if false disable:MEM</action>
        <action>if false disable:NUMPROC</action>
        <action>if false disable:SCFCALC_BIN</action>
        <action>if false enable:BASISSETDIR</action>
        <action>if true disable:BASISSETT</action>
        <action>if false enable:BASISSETT</action>
        <action>if true disable:GAMESS</action>
        <action>if false enable:GAMESS</action>
        <action>if true disable:ELMOLIB</action>
        <action>if false enable:ELMOLIB</action>
        <action>if true enable:XHALONG</action>
        <action>if false disable:XHALONG</action>
      </radiobutton>
      <radiobutton space-fill="True"  space-expand="True">
        <label>Tonto</label>
        <default>false</default>
        <action>if true echo 'SCFCALCPROG="Tonto"'</action>
        <action>if true enable:BASISSETDIR</action>
        <action>if false disable:BASISSETDIR</action>
        <action>if true enable:USEBECKE</action>
        <action>if false disable:USEBECKE</action>
        <action>if true enable:USEBECKE</action>
        <action>if false disable:USEBECKE</action>
        <action>if true disable:BASISSET</action>
        <action>if false enable:BASISSET</action>
        <action>if true disable:MEM</action>
        <action>if true disable:NUMPROC</action>
        <action>if false enable:MEM</action>
        <action>if false enable:NUMPROC</action>
        <action>if true disable:GAMESS</action>
        <action>if false enable:GAMESS</action>
        <action>if true disable:ELMOLIB</action>
        <action>if false enable:ELMOLIB</action>
        <action>if true enable:XHALONG</action>
        <action>if false disable:XHALONG</action>
      </radiobutton>
      <radiobutton space-fill="True"  space-expand="True">
        <label>elmodb</label>
        <default>false</default>
        <action>if true echo 'SCFCALCPROG="elmodb"'</action>
        <action>if true disable:MEM</action>
        <action>if true disable:NUMPROC</action>
        <action>if true enable:SCFCALC_BIN</action>
        <action>if true disable:BASISSETDIR</action>
        <action>if false enable:MEM</action>
        <action>if false enable:NUMPROC</action>
        <action>if false disable:SCFCALC_BIN</action>
        <action>if false enable:BASISSETDIR</action>
        <action>if true disable:BASISSETT</action>
        <action>if false enable:BASISSETT</action>
        <action>if true disable:SCCHARGES</action>
        <action>if false enable:SCCHARGES</action>
        <action>if true enable:GAMESS</action>
        <action>if false disable:GAMESS</action>
        <action>if true enable:ELMOLIB</action>
        <action>if false disable:ELMOLIB</action>
        <action>if true disable:XHALONG</action>
        <action>if false enable:XHALONG</action>
      </radiobutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text label="Your Tonto executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
    <entry fs-action="file" fs-folder="./"
           fs-title="Select the gamess_int file">
     <default>tonto</default>
     <variable>TONTO</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">TONTO</action>
    </button>
   </hbox>

   <hseparator></hseparator>

  <hbox>
    <text label="Your Gaussian, Orca or elmodb executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
    <entry fs-action="file" fs-folder="./"
           fs-title="Select the gamess_int file">
     <default>g09</default>
     <variable>SCFCALC_BIN</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">SCFCALC_BIN</action>
    </button>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text label="Your gamess_int executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
    <entry sensitive="false" fs-action="file" fs-folder="./"
           fs-title="Select the gamess_int file">
     <default>gamess_int</default>
     <variable>GAMESS</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">GAMESS</action>
    </button>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text label="ELMO libraries folder" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
    <entry sensitive="false" fs-action="folder" fs-folder="./"
           fs-title="Select the ELMO library folder">
     <default>/usr/local/bin/ELMO_LIB</default>
     <variable>ELMOLIB</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">ELMOLIB</action>
    </button>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Job name(one word)</label></text>
    <entry>
     <default>my_job</default>
     <variable>JOBNAME</variable>
    </entry>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text label="Select the cif or pdb file that you wish to submit" has-tooltip="true" tooltip-markup="ONLY use pdb file if you are using elmodb!!!" ></text>
    <entry fs-action="file" fs-folder="./"
           fs-filters="*.cif|*.pdb"
           fs-title="Select a cif or pdb file">
     <variable>CIF</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">CIF</action>
    </button>

    <checkbox active="false" has-tooltip="true" tooltip-markup="THIS OPTION WILL BE AVAILABLE SOON! 
Make sure you will enter the correct charge and multiplicity" space-fill="True"  space-expand="True" sensitive="false">
     <label>Complete molecule(s) in the cif </label>
      <variable>COMPLETECIF</variable>
    </checkbox>

   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text label="Select the hkl file that you wish to submit" ></text>
    <entry fs-action="file" fs-folder="./"
           fs-filters="*.hkl"
           fs-title="Select an hkl file">
     <variable>HKL</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">HKL</action>
    </button>

    <checkbox active="false" has-tooltip="true" tooltip-markup="WARNING: Select one ONLY if you need a header to be written in the hkl file!" space-fill="True"  space-expand="True">
     <label>write header </label>
      <variable>WRITEHEADER</variable>
      <action>if true enable:ONF</action>
      <action>if true enable:ONF2</action>
      <action>if false disable:ONF</action>
      <action>if false disable:ONF2</action>
    </checkbox>

    <checkbox active="false" sensitive= "false" space-fill="True"  space-expand="True">
     <label>on F </label>
      <variable>ONF</variable>
    </checkbox>

    <checkbox active="false" sensitive= "false" space-fill="True"  space-expand="True">
     <label>on F^2 </label>
      <variable>ONF2</variable>
    </checkbox>

   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text label="Select the basis_sets directory" ></text>
    <entry sensitive="false" fs-action="folder" fs-folder="/usr/local/bin/"
           fs-title="Select the basis_sets directory">
     <variable>BASISSETDIR</variable>
     <default>/usr/local/bin/basis_sets</default>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">BASISSETDIR</action>
    </button>
   </hbox>
 
   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Wavelenght (in Angstrom)</label></text>
    <entry>
     <default>0.71073</default>
     <variable>WAVE</variable>
    </entry>

    <text use-markup="true" wrap="false"><label>Enter the F/sigma cutoff</label></text>
    <entry>
     <default>3</default>
     <variable>FCUT</variable>
    </entry>

   </hbox>

   <hseparator></hseparator>

   <hbox> 
    <text xalign="0" use-markup="true" wrap="false"><label>Charge</label></text>
    <spinbutton  range-min="-10"  range-max="10" space-fill="True"  space-expand="True">
	<default>0</default>
	<variable>CHARGE</variable>
    </spinbutton>

    <text xalign="1" use-markup="true" wrap="false"><label>Multiplicity</label></text>
    <spinbutton  range-min="0"  range-max="10"  space-fill="True"  space-expand="True" >
	<default>1</default>
	<variable>MULTIPLICITY</variable>
    </spinbutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text xalign="0" use-markup="true" wrap="false" > <label>Method: </label></text>
    <combobox has-tooltip="true" tooltip-markup="'"'rhf'"' - Restricted Hartree-Fock, 
'"'rks'"' - Restricted Kohn-Sham, 
'"'rohf'"' - Restricted open shell Hartree-Fock, 
'"'uhf'"' - Unrestricted Hartree-Fock, 
'"'uks'"' - Unrestricted Kohn-Sham" space-fill="True"  space-expand="True" >
     <variable>METHOD</variable>
     <item>rhf</item>
     <item>rks</item>
     <item>rohf</item>
     <item>uhf</item>
     <item>uks</item>
    </combobox>


    <text xalign="1" use-markup="true" wrap="false"><label>Basis set</label></text>
    <combobox has-tooltip="true" tooltip-markup="List of Basis sets available on Tonto. Please check if the basis set you want to use contains all the elements of your structure." sensitive="false" space-fill="True"  space-expand="True">
     <variable>BASISSETT</variable>
     <item>STO-3G</item>
     <item>3-21G</item>
     <item>6-31G(d)</item>
     <item>6-31G(d,p)</item>
     <item>6-311++G(2d,2p)</item>
     <item>6-311G(d,p)</item>
     <item>ahlrichs-polarization</item>
     <item>aug-cc-pVDZ</item>
     <item>aug-cc-pVQZ</item>
     <item>aug-cc-pVTZ</item>
     <item>cc-pVDZ</item>
     <item>cc-pVQZ</item>
     <item>cc-pVTZ</item>
     <item>Clementi-Roetti</item>
     <item>Coppens</item>
     <item>def2-SVP</item>
     <item>def2-SV(P)</item>
     <item>def2-TZVP</item>
     <item>def2-TZVPP</item>
     <item>DZP</item>
     <item>DZP-DKH</item>
     <item>pVDZ-Ahlrichs</item>
     <item>Sadlej+</item>
     <item>Sadlej-PVTZ</item>
     <item>Spackman-DZP+</item>
     <item>Thakkar</item>
     <item>TZP-DKH</item>
     <item>vanLenthe-Baerends</item>
     <item>VTZ-Ahlrichs</item>
    </combobox>

   </hbox>

   <hseparator></hseparator>

   <hbox>

    <text><label>Enter manually for Gaussian or Orca!</label> </text>
    <entry tooltip-text="Use the correct Gaussian or Orca or Tonto format" sensitive="true">
     <default>STO-3G</default>
     <variable>BASISSET</variable>
    </entry>

   </hbox>

   <hseparator></hseparator>

   <hbox>

    <checkbox>
     <label>Use SC cluster charges? </label>
      <variable>SCCHARGES</variable>
      <action>if true enable:SCCRADIUS</action>
      <action>if false disable:SCCRADIUS</action>
      <action>if true enable:DEFRAG</action>
      <action>if false disable:DEFRAG</action>
    </checkbox>

    <text use-markup="true" wrap="false" ><label>SC Cluster charges radius</label></text>
    <entry has-tooltip="true" tooltip-markup="in Angstrom" sensitive="false">
     <default>8</default>
     <variable>SCCRADIUS</variable>
    </entry>

    <checkbox sensitive="false">
     <label>Complete molecules </label>
     <default>false</default>
      <variable>DEFRAG</variable>
    </checkbox>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <checkbox sensitive="false" space-fill="True"  space-expand="True">
     <label>Use becke grid? </label>
      <variable>USEBECKE</variable>
      <action>if true enable:ACCURACY</action>
      <action>if true enable:BECKEPRUNINGSCHEME</action>
      <action>if false disable:ACCURACY</action>
      <action>if false disable:BECKEPRUNINGSCHEME</action>
    </checkbox>

    <text use-markup="true" wrap="false"><label>Becke grid accuracy</label></text>
    <combobox has-tooltip="true" tooltip-markup="FOR TONTO SCF ONLY: 
'"'very_low'"' to '"'very_high'"' are Treutler-Ahlrichs settings, 
'"'extreme'"' and '"'best'"' are better than the Mura-Knowles settings. 
The '"'low'"' value is the one comparable to Gaussian." sensitive="false">
      <variable>ACCURACY</variable>
      <item>very_low</item>
      <item>low</item>
      <item>medium</item>
      <item>high</item>
      <item>very_high</item>
      <item>extreme</item>
      <item>best</item>

    </combobox>
   </hbox>


   <hbox>
    <text use-markup="true" wrap="false"><label>Becke grid prunning scheme</label></text>
    <combobox sensitive="false" has-tooltip="true" tooltip-markup="FOR TONTO SCF ONLY: 
Set the angular pruning scheme for lebedev_grid given a radial point '"'i'"' out of a set of '"'nr'"' radial points arranged in increasing order.">
      <variable>BECKEPRUNINGSCHEME</variable>
      <item>none</item>
      <item>jayatilaka0</item>
      <item>jayatilaka1</item>
      <item>jayatilaka2</item>
      <item>treutler_ahlrichs</item>
    </combobox>
   </hbox>


   <hseparator></hseparator>

   <hbox>
    <text xalign="0" use-markup="true" wrap="false" space-fill="True"  space-expand="True"><label>Refinement options (all atom types): </label></text>
    <radiobutton>
        <label>positions and ADPs</label>
        <default>true</default>
        <variable>POSADP</variable>
    </radiobutton>
    <radiobutton>
        <label>positions only</label>
        <variable>POSONLY</variable>
        <action>if true disable:REFHADP</action>
        <action>if false enable:REFHADP</action>
        <action>if true disable:HADP</action>
        <action>if false enable:HADP</action>
    </radiobutton>
    <radiobutton>
        <label>ADPs only</label>
        <variable>ADPSONLY</variable>
        <action>if true disable:REFHPOS</action>
        <action>if false enable:REFHPOS</action>
    </radiobutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <checkbox sensitive="true" space-fill="True"  space-expand="True">
     <label>Start refinement with a Tonto IAM </label>
      <variable>IAMTONTO</variable>
      <action>if true disable:XHALONG</action>
      <action>if false enable:XHALONG</action>
    </checkbox>
   </hbox>

   <hseparator></hseparator>

   <hbox>

    <checkbox active="true" space-fill="True"  space-expand="True">
     <label>Refine H positions ?</label>
      <variable>REFHPOS</variable>
      <action>if true disable:XHALONG</action>
      <action>if false enable:XHALONG</action>
    </checkbox>

    <checkbox active="true">
     <label>Refine_H_ADPs</label>
      <variable>REFHADP</variable>
      <action>if true enable:HADP</action>
      <action>if false disable:HADP</action>
    </checkbox>

    <text xalign="0" use-markup="true" wrap="false"><label>Refine H atom isotropically?</label></text>
    <combobox>
      <variable>HADP</variable>
      <item>no</item>
      <item>yes</item>
    </combobox>
   </hbox>

   <hseparator></hseparator>

   <hbox>

    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True">
     <label>Alongate X-H bond lengths ?</label>
     <variable>XHALONG</variable>
     <default>false</default>
     <action>if true enable:BHBOND</action>
     <action>if false disable:BHBOND</action>
     <action>if true enable:CHBOND</action>
     <action>if false disable:CHBOND</action>
     <action>if true enable:NHBOND</action>
     <action>if false disable:NHBOND</action>
     <action>if true enable:OHBOND</action>
     <action>if false disable:OHBOND</action>
    </checkbox>

    <text xalign="1" use-markup="true" wrap="false"><label>if yes, enter new bond lengths below (leave empty for unchanged)</label></text>
   </hbox>

   <hbox>
    <text xalign="0" use-markup="true" wrap="false"><label>B-H:</label></text>
    <entry sensitive="false">
     <default>1.190</default>
     <variable>BHBOND</variable>
      <visible>disabled</visible>
    </entry>
    <text xalign="0" use-markup="true" wrap="false"><label>C-H:</label></text>
    <entry sensitive="false">
     <default>1.083</default>
     <variable>CHBOND</variable>
    </entry>
   </hbox>

   <hbox>
    <text xalign="0" use-markup="true" wrap="false"><label>N-H:</label></text>
    <entry sensitive="false">
     <default>1.009</default>
     <variable>NHBOND</variable>
    </entry>
    <text xalign="0" use-markup="true" wrap="false"><label>O-H:</label></text>
    <entry sensitive="false">
     <default>0.983</default>
     <variable>OHBOND</variable>
    </entry>

   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text xalign="0" use-markup="true" wrap="false"><label>Would you like to apply dispersion corrections?</label></text>
    <combobox has-tooltip="true" tooltip-markup="Enter the '"f'"' and '"f''"' values in popup window after pressing '"'OK'"'" space-fill="True"  space-expand="True">
      <variable>DISP</variable>
      <item>no</item>
      <item>yes</item>
    </combobox>
   </hbox>

   <hseparator></hseparator>

   <hbox> 
    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>Number of processors available for the Gaussian or Orca job</label></text>
    <spinbutton  range-min="1"  range-max="100" space-fill="True"  space-expand="True">
	<default>1</default>
	<variable>NUMPROC</variable>
    </spinbutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text xalign="0" use-markup="true" wrap="false"><label>Memory available for the Gaussian or Orca job (including the unit mb or gb)</label></text>
    <entry>
     <default>1gb</default>
     <variable>MEM</variable>
    </entry>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <button ok>
    </button>
    <button cancel>
    </button>
   </hbox>

  </frame>
 </vbox>
</window>
'

#export dispersion_coef='
#<window window_position="1" title="Tonto Gaussian Orca interface">

# <vbox>

# <hbox homogeneous="True">

#    <hbox homogeneous="True">
#     <frame>
#      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>Enter the dispersion coefficients</span>"</label></text>
#     </frame>  
#    </hbox>
#  </hbox>
 
#   <hseparator></hseparator>

#   <hbox>
#    <text use-markup="true" wrap="false"><label>Atom type</label></text>
#    <combobox>
#      <variable>ATOMTYPE</variable>
#<item>H</item><item>He</item><item>Li</item><item>Be</item><item>B</item><item>C</item><item>N</item> <item>O </item><item>F</item> <item>Ne</item><item>Na</item><item>Mg</item><item>Al</item><item>Si</item><item>P</item><item>S</item><item>Cl</item><item>Ar</item><item>K</item><item>Ca</item><item>Sc</item><item>Ti</item><item>V</item><item>Cr</item><item>Mn</item><item>Fe</item><item>Co</item><item>Ni</item><item>Cu</item><item>Zn</item><item>Ga</item><item>Ge</item><item>As</item><item>Se</item><item>Br</item><item>Kr</item><item>Rb</item><item>Sr</item><item>Y</item><item>Zr</item><item>Nb</item><item>Mo</item><item>Tc</item><item>Ru</item><item>Rh</item><item>Pd</item><item>Ag</item><item>Cd</item><item>In</item><item>Sn</item><item>Sb</item><item>Te</item><item>I</item><item>Xe</item><item>Cs</item><item>Ba</item><item>La</item><item>Ce</item><item>Pr</item><item>Nd</item><item>Pm</item><item>Sm</item><item>Eu</item><item>Gd</item><item>Tb</item><item>Dy</item><item>Ho</item><item>Er</item><item>Tm</item><item>Yb</item><item>Lu</item><item>Hf</item><item>Ta</item><item>W</item><item>Re</item><item>Os</item><item>Ir</item><item>Pt</item><item>Au</item><item>Hg</item><item>Tl</item><item>Pb</item><item>Bi</item><item>Po</item><item>At</item><item>Rn</item><item>Fr</item><item>Ra</item><item>Ac</item><item>Th</item><item>Pa</item><item>U</item><item>Np</item><item>Pu</item><item>Am</item><item>Cm</item><item>Bk</item><item>Cf</item><item>Es</item><item>Fm</item><item>Md</item><item>No</item><item>Lr</item><item>Rf</item><item>Db</item><item>Sg</item><item>Bh</item><item>Hs</item><item>Mt</item><item>Ds</item><item>Rg</item><item>Cn</item><item>Ut</item><item>Fl</item><item>Up</item><item>Lv</item><item>Us</item><item>Uo</item>
#    </combobox>
#    <text use-markup="true" wrap="false"><label>f</label></text>
#    <entry>
#     <default>0</default>
#     <variable>FP</variable>
#    </entry>	
#    <text use-markup="true" wrap="false"><label>f</label></text>
#    <entry>
#     <default>0</default>
#     <variable>FPP</variable>
#    </entry>	
#   </hbox>
#'

#no need for basis set in tonto!!!

gtkdialog --program=MAIN_DIALOG > job_options.txt
source job_options.txt
rm job_options.txt
if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG="Gaussian"
fi

if [ "$DISP" = "yes" ]; then
	zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	while [ $? -eq 1 ]; do 
		zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	done
fi

#	gtkdialog --program=dispersion_coef > DISP_instructions.txt




if [ "$EXIT" = "OK" ]; then
        tail -f $JOBNAME.lst | zenity --title "Job output file - this file will auto-update, scroll down to see later results." --no-wrap --text-info --width 1024 --height 800 &
#	zenity --title="Tonto job status" --text-info --no-wrap --filename=$JOBNAME.lst &
	run_script
else
	unset MAIN_DIALOG
	clear
	exit 0
fi



