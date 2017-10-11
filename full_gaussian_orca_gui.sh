#!/bin/bash
Encoding=UTF-8


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
cp $JOBNAME.inp $JOBNAME.$I.inp
cp $JOBNAME.molden.input $JOBNAME.$I.molden.input
cp $JOBNAME.log $JOBNAME.$I.log
}

SCF_TO_TONTO(){
echo "Writing Tonto stdin"
echo "{ " > stdin
echo "" >> stdin
if [ "$SCFCALCPROG" = "Gaussian" ]; then 
	echo "   read_g09_fchk_file $JOBNAME.$I.fchk" >> stdin
else
	echo "   read_molden_file $JOBNAME.$I.molden.input" >> stdin
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
	echo "       file_name= $CIF" >> stdin
else 
#	cp $JOBNAME'_cartesian.cif2' $JOBNAME.cartesian.cif2
	echo "       file_name= $JOBNAME.$J.cartesian.cif2" >> stdin
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
if [ "$DISP" = "yes" ]; then 
	echo "   	 dispersion_coefficients= {" >> stdin
	echo "   	 $(cat DISP_inst.txt)" >> stdin
#commented but its the working one
#	for ((L=0; i<${#XDISP[]*]}; L++));
#	do
#	    echo "      ${XDISP[L]}" >> stdin
#	done
	echo "   	 }" >> stdin
fi
#echo "   basis_directory= $BASISSETDIR" >> stdin
#echo "   basis_name= $BASISSET" >> stdin
echo "" >> stdin
echo "   crystal= {    " >> stdin
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
echo "" >> stdin
echo "	 show_fit_output= TRUE" >> stdin
echo "	 show_fit_results= TRUE" >> stdin
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
echo "   ! Make Hirshfeld structure factors" >> stdin
echo "   fit_hirshfeld_atoms" >> stdin
echo "" >> stdin
echo "   write_xyz_file" >> stdin
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
cp stdin stdin.$J
cp stdout stdout.$J
cp $JOBNAME.xyz $JOBNAME.$J.xyz
cp $JOBNAME'.cartesian.cif2' $JOBNAME.$J.cartesian.cif2
#cp $JOBNAME'_cartesian.cif2' $JOBNAME.$J.teste.cif2
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
	echo "# $METHOD/$BASISSET  nosymm output=wfn 6D 10F" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$JOBNAME" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
### commented but working on new tonto, will use dylan's old write_xyz_file keyword because that one keeps the atom labels, florian's new one does not.
###	awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+4;d<=c-4;++d)print a[d]}' $JOBNAME.cartesian.cif2 | awk -v OFS='\t' 'NR%2==0 {print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' >> $JOBNAME.com 
	awk 'NR>2' $JOBNAME.$J.xyz >> $JOBNAME.com
#	sleep 15 #check if needed
#	awk '{a[NR]=$0}/^_atom_site_Cartn_U_iso_or_equiv_esd/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.cartn-fragment.cif | awk 'NR%2==1 {print $1, $2, $3, $4}' >> $JOBNAME.com 
	echo "" >> $JOBNAME.com
	echo "./$JOBNAME.wfn" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "Runing Gaussian, cycle number $I"
	$SCFCALC_BIN $JOBNAME.com
	echo "Gaussian cycle number $I ended"
	echo "Generation fcheck file for Gaussian cycle number $I"
	formchk $JOBNAME.chk $JOBNAME.fchk
	cp $JOBNAME.com $JOBNAME.$I.com
	cp $JOBNAME.fchk $JOBNAME.$I.fchk
	cp $JOBNAME.log $JOBNAME.$I.log
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
echo "###############################################################################################" > $JOBNAME.lst
echo "                                     TONTO - GAUSSIAN                                          " >> $JOBNAME.lst
echo "###############################################################################################" >> $JOBNAME.lst
echo "Job started on:" >> $JOBNAME.lst
date >> $JOBNAME.lst
echo "User Inputs: " >> $JOBNAME.lst
echo "Tonto executable	: $TONTO"  >> $JOBNAME.lst 
echo "$($TONTO -v)" >> $JOBNAME.lst 
#awk 'NR==7 { print }' stdout >> $JOBNAME.lst      #print the tonto version, but there is no stdout yet
echo "Gaussian executable	: $SCFCALC_BIN" >> $JOBNAME.lst
echo "Job name		: $JOBNAME" >> $JOBNAME.lst
echo "Input cif		: $CIF" >> $JOBNAME.lst
echo "Input hkl		: $HKL" >> $JOBNAME.lst
echo "Wavelenght		: $WAVE" >> $JOBNAME.lst
echo "F_sigma_cutoff		: $FCUT" >> $JOBNAME.lst
echo "Charge			: $CHARGE" >> $JOBNAME.lst
echo "Multiplicity		: $MULTIPLICITY" >> $JOBNAME.lst
echo "Level of theory 	: $METHOD/$BASISSET" >> $JOBNAME.lst
#echo "Basis set directory	: $BASISSETDIR" >> $JOBNAME.lst
echo "Refine Hydrogens anis.	: $HADP" >> $JOBNAME.lst
echo "Dispersion correction	: $DISP" >> $JOBNAME.lst
if [ $DISP = "yes" ]; then
	echo "			  $(cat DISP_inst.txt)" >> $JOBNAME.lst
# commented but I think it was working
#for loop in { 1..$NUMATOMTYPE }
#		do
#		echo "Dispersion coefficients	:  ${ATOMTYPE[loop]} ${FP[loop]} ${FPP[loo]}" >> $JOBNAME.lst
#	done	

fi
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
echo "   ! Process the CIF" >> stdin
echo "   CIF= {" >> stdin
echo "       file_name= $CIF" >> stdin
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
cp $JOBNAME.xyz $JOBNAME.starting_geom.xyz
cp stdin stdin.$J
cp stdout stdout.$J
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
	###awk '{a[NR]=$0}/^_atom_site_Cartn_U_iso_or_equiv_esu/{b=NR}/^# ==============/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.$J.cartesian.cif2 | awk -v OFS='\t' 		'{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }'| awk 'NR%2==1 {print }' | tee -a $JOBNAME.com $JOBNAME.lst
	awk 'NR>2' $JOBNAME.xyz | tee -a  $JOBNAME.com $JOBNAME.lst
	### old working
	###awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $JOBNAME.cartn-fragment.cif | awk -v 		OFS='\t' '{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' | tee -a $JOBNAME.com $JOBNAME.lst
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
	cp $JOBNAME.com $JOBNAME.$I.com
	cp $JOBNAME.fchk $JOBNAME.$I.fchk
	cp $JOBNAME.log $JOBNAME.$I.log
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
		cp $JOBNAME.inp $JOBNAME.$I.inp
		cp $JOBNAME.molden.input $JOBNAME.$I.molden.input
		cp $JOBNAME.log $JOBNAME.$I.log
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
}

export MAIN_DIALOG='

<window window_position="1" title="Tonto Gaussian Orca interface">

 <vbox>

  <hbox homogeneous="True">

    <hbox homogeneous="True">
     <frame>
      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>Welcome to the interface for Hirsfeld Atom fit and Gaussian/Orca</span>"</label></text>
      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>(You need to have coreutils installed on your machine to use this script</span>"</label></text>
      <pixmap>
       <width>40</width>
       <height>40</height>
       <input file>./Tonto_logo.png</input>
      </pixmap>
     </frame>  
    </hbox>

  </hbox>
  
  <frame>
   <hbox>
    <text use-markup="true" wrap="false"><label>Your Tonto executable</label></text>
    <entry>
     <default>tonto</default>
     <variable>TONTO</variable>
    </entry>
   </hbox>

   <hbox>
    <text use-markup="true" wrap="false"><label>Software for SCF calculation</label></text>
    <combobox>
      <variable>SCFCALCPROG</variable>
      <item>Gaussian</item>
      <item>Orca</item>
    </combobox>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Your Gaussian or Orca executable</label></text>
    <entry>
     <default>g09</default>
     <variable>SCFCALC_BIN</variable>
    </entry>
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
    <text label="Select the cif file that you wish to submit" ></text>
    <entry fs-action="file" fs-folder="./"
           fs-filters="*.cif"
           fs-title="Select a cif file">
     <variable>CIF</variable>
    </entry>
    <button>
     <input file stock="gtk-open"></input>
     <action type="fileselect">CIF</action>
    </button>
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
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Wavelenght (in Angstrom)</label></text>
    <entry>
     <default>0.71073</default>
     <variable>WAVE</variable>
    </entry>
   </hbox>

   <hseparator></hseparator>

   <hbox> 
    <text use-markup="true" wrap="false"justify="1"><label>Charge</label></text>
    <spinbutton  range-min="-10"  range-max="10" space-fill="True"  space-expand="True">
	<default>0</default>
	<variable>CHARGE</variable>
    </spinbutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Multiplicity</label></text>
    <spinbutton  range-min="0"  range-max="10"  space-fill="True"  space-expand="True" >
	<default>1</default>
	<variable>MULTIPLICITY</variable>
    </spinbutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Method that you wish to use (Gaussian or Orca format)</label></text>
    <entry>
     <default>HF</default>
     <variable>METHOD</variable>
    </entry>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Basis set that you wish to use (Gaussian or Orca format)</label></text>
    <entry>
     <default>STO-3G</default>
     <variable>BASISSET</variable>
    </entry>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Please enter the F_sigma_cutoff</label></text>
    <entry>
     <default>3</default>
     <variable>FCUT</variable>
    </entry>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Refine H atom isotropically?</label></text>
    <combobox>
      <variable>HADP</variable>
      <item>no</item>
      <item>yes</item>
    </combobox>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Would you like to apply dispersion corrections?</label></text>
    <combobox>
      <variable>DISP</variable>
      <item>no</item>
      <item>yes</item>
    </combobox>
   </hbox>

   <hseparator></hseparator>

   <hbox> 
    <text use-markup="true" wrap="false"justify="1"><label>Number of processors available for the Gaussian or Orca job</label></text>
    <spinbutton  range-min="1"  range-max="100" space-fill="True"  space-expand="True">
	<default>1</default>
	<variable>NUMPROC</variable>
    </spinbutton>
   </hbox>

   <hseparator></hseparator>

   <hbox>
    <text use-markup="true" wrap="false"><label>Memory available for the Gaussian or Orca job (including the unit mb or gb)</label></text>
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



