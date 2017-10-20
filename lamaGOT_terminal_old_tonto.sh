#!/bin/bash
GAUSSIAN_TO_TONTO(){
echo "Writing Tonto stdin"
echo "{ " > stdin
echo "" >> stdin
echo "   read_g09_fchk_file $NAME.fchk" >> stdin
echo "" >> stdin
echo "   charge= $CHARGE" >> stdin       
echo "   multiplicity= $MULTIPLICITY" >> stdin
echo "" >> stdin
echo "   name= $NAME" >> stdin
echo "" >> stdin
echo "   ! Process the CIF" >> stdin
echo "   CIF= {" >> stdin
#if ( $J -gt 0 ); then
echo "       file_name= $NAME.$J.cartn-fragment.cif" >> stdin
#else
#echo "       file_name= $CIF" >> stdin
#fi
echo "    }" >> stdin
echo "" >> stdin
echo "   process_CIF" >> stdin
echo "" >> stdin
echo "   name= $NAME" >> stdin
echo "" >> stdin
echo "   basis_directory= $BASISSETDIR" >> stdin
echo "   basis_name= $BASISSET" >> stdin
echo "" >> stdin
echo "   crystal= {    " >> stdin
echo "      xray_data= {   " >> stdin
echo "         thermal_smearing_model= hirshfeld" >> stdin
echo "         partition_model= mulliken" >> stdin
echo "         optimise_extinction= false" >> stdin
echo "         correct_dispersion= $DISP" >> stdin
if [ "$DISP" = "yes" ]; then 
	echo "   dispersion_coefficients= {" >> stdin
	for ((L=0; i<${#XDISP[]*]}; L++));
	do
	    echo "      ${XDISP[L]}" >> stdin
	done
	echo "   }" >> stdin
fi
echo "         optimise_scale_factor= true" >> stdin
echo "         wavelength= $WAVE Angstrom" >> stdin
echo "         REDIRECT $HKL.hkl" >> stdin
echo "         f_sigma_cutoff= $FCUT" >> stdin
echo "         refine_H_U_iso= $HADP" >> stdin
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
echo "}" >> stdin 
J=$[ $J + 1 ]
echo "Runing Tonto, cycle number $J" 
$TONTO
echo "Tonto cycle number $J ended"
if [ $J = 1 ]; then 
	#awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout 
	echo "====================" >> $NAME.lst
	echo "Begin rigid-atom fit" >> $NAME.lst
	echo "====================" >> $NAME.lst
	echo "" >> $NAME.lst
	echo "_________________________________________________________________________________________________________________________________" >> $NAME.lst
	echo "" >> $NAME.lst
	echo "Cycle   Fit         chi2         R       R_w        Max.     Max.  No. of  No. of     Energy         RMSD         Delta " >> $NAME.lst
	echo "       Iter                                        Shift    Shift  params   eig's    at final      at final       Energy " >> $NAME.lst
	echo "                                                    /esd    param          near 0     Geom.          Geom.                " >> $NAME.lst
	echo "" >> $NAME.lst
	echo "_________________________________________________________________________________________________________________________________" >> $NAME.lst
	echo "" >> $NAME.lst
#	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)    $ENERGIA   $RMSD   $ENERGY "  >> $NAME.lst
fi
#	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)"  >> $NAME.lst
#echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)    $ENERGIA2   $RMSD2   $DE"  >> $NAME.lst
cp stdout stdout.$J
cp $NAME.cartn-fragment.cif $NAME.$J.cartn-fragment.cif
}
#######################################################################
TONTO_TO_GAUSSIAN(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Gaussian cycle number $I"
	echo "%chk=./$NAME.chk" > $NAME.com
	echo "%rwf=./$NAME.rwf" >> $NAME.com
	echo "%int=./$NAME.int" >> $NAME.com
	echo "%mem=$MEM" >> $NAME.com
	echo "%nprocshared=$NUMPROC" >> $NAME.com
	#echo "# rb3lyp/$BASISSET output=wfn" >> $NAME.com
	if [ "$METHOD" = "rks" ]; then
		echo "# b3lyp/$BASISSET  nosymm output=wfn 6D 10F" | tee -a $NAME.com $NAME.lst
	fi
	echo "# $METHOD/$BASISSET  nosymm output=wfn 6D 10F" >> $NAME.com
	echo "" >> $NAME.com
	echo "$NAME" >> $NAME.com
	echo "" >> $NAME.com
	echo "$CHARGE $MULTIPLICITY" >> $NAME.com
	awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+4;d<=c-4;++d)print a[d]}' $NAME.cartn-fragment.cif | awk -v OFS='\t' 'NR%2==0 {print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' >> $NAME.com 
#	sleep 15 #check if needed
#	awk '{a[NR]=$0}/^_atom_site_Cartn_U_iso_or_equiv_esd/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $NAME.cartn-fragment.cif | awk 'NR%2==1 {print $1, $2, $3, $4}' >> $NAME.com 
	echo "" >> $NAME.com
	echo "./$NAME.wfn" >> $NAME.com
	echo "" >> $NAME.com
	echo "Runing Gaussian, cycle number $I"
	$GAUSSIAN $NAME.com
	echo "Gaussian cycle number $I ended"
	echo "Generation fcheck file for Gaussian cycle number $I"
	formchk $NAME.chk $NAME.fchk
	cp $NAME.com $NAME.$I.com
	cp $NAME.fchk $NAME.$I.fchk
	cp $NAME.log $NAME.$I.log
}
######################  Gaussian done ########################
######################  Begin check energy ########################
CHECK_ENERGY(){
	ENERGIA2=$(sed 's/^ //' $NAME.log | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
	RMSD2=$(sed 's/^ //' $NAME.log | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $2}'| tr -d '\r')
	echo "Gaussian cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
#	DE=$(($ENERGIA - $ENERGIA2))
###	DE=$(echo "$ENERGIA2 - $ENERGIA" | bc)
	DE=$(awk "BEGIN {print $ENERGIA2 - $ENERGIA}")
#	DE=$(echo "$ENERGIA - $ENERGIA2" | bc)
#	DRMSD=$(($RMSD - $RMSD2))
	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)    $ENERGIA2   $RMSD2   $DE"  >> $NAME.lst
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
I=$"0"
J=$"0"
echo "Welcome to the interface for Hirsfeld Atom fit and Gaussian" 
echo "(You need to have coreutils installed on your machine to use this script)"
echo ""
echo "Please type the name of your Tonto executable [tonto]"
read TONTO
if [[ -z "$TONTO" ]]; then
	TONTO=$"tonto"
fi
echo "Please type the name of your Gaussian executable [g09]"
read GAUSSIAN
if [[ -z "$GAUSSIAN" ]]; then
	GAUSSIAN=$"g09"
fi
echo "Please type the name of the name for the job (one word)"
echo ""
read NAME
echo "Please type the name of the cif file that you wish to submit (without extension)" #| tee -a "$NAME.lst"
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
echo "Please enter the basis set that you wish to use [STO-3G]"
echo ""
read BASISSET
if [[ -z "$BASISSET" ]]; then
	BASISSET=$"STO-3G"
fi
echo "Please enter the method that you wish to use (rhf or rks) [rhf]"
echo ""
read METHOD
if [[ -z "$METHOD" ]]; then
	METHOD=$"rhf"
fi
echo "Please enter the basis set directory [/usr/local/bin/basis_sets]"
echo ""
read BASISSETDIR
if [[ -z "$BASISSETDIR" ]]; then
	BASISSETDIR=$"/usr/local/bin/basis_sets"
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
	echo "Please enter one atom type, f' and f'' values per line (empty line if no more to inform):"
	echo ""
	while [ ! ${finished} ]
	do
		read line
		if [ "$line" = "" ]; then
			finished=true
		else
			XDISP=("${XDISP[@]}" $line)
		fi
	done
fi
echo "Please enter the number of processors available for the Gaussian job [1]"
echo ""
read NUMPROC
if [[ -z "$NUMPROC" ]]; then
	NUMPROC=$"1"
fi
echo "Please enter the memory available for the Gaussian job (including the unit mb or gb) [1gb]"
echo ""
read MEM
if [[ -z "$MEM" ]]; then
	MEM=$"1gb"
fi
#####################################################################################################
SECONDS=0
echo "###############################################################################################" > $NAME.lst
echo "                                     TONTO - GAUSSIAN                                          " >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
echo "Job started on:" >> $NAME.lst
date >> $NAME.lst
echo "User Inputs: " >> $NAME.lst
echo "Tonto executable	: $TONTO"  >> $NAME.lst 
#awk 'NR==7 { print }' stdout >> $NAME.lst      #print the tonto version, but there is no stdout yet
echo "Gaussian executable	: $GAUSSIAN" >> $NAME.lst
echo "Job name		: $NAME" >> $NAME.lst
echo "Input cif		: $CIF.cif" >> $NAME.lst
echo "Input hkl		: $HKL.hkl" >> $NAME.lst
echo "Wavelenght		: $WAVE" >> $NAME.lst
echo "F_sigma_cutoff		: $FCUT" >> $NAME.lst
echo "Charge			: $CHARGE" >> $NAME.lst
echo "Multiplicity		: $MULTIPLICITY" >> $NAME.lst
echo "Level of theory 	: $METHOD/$BASISSET" >> $NAME.lst
echo "Basis set directory	: $BASISSETDIR" >> $NAME.lst
echo "Refine Hydrogens anis.	: $HADP" >> $NAME.lst
echo "Dispersion correction	: $DISP" >> $NAME.lst
if [ $DISP = "yes" ]; then
	for loop in { 1..$NUMATOMTYPE }
		do
		echo "Dispersion coefficients	:  ${ATOMTYPE[loop]} ${FP[loop]} ${FPP[loo]}" >> $NAME.lst
	done	
fi
echo "Only for Gaussian job	" >> $NAME.lst
echo "Number of processor 	: $NUMPROC" >> $NAME.lst
echo "Memory		 	: $MEM" >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
echo "                                     Starting Geometry                                         " >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
#####################################################################################################
###################### Begin extracting XYZ with tonto and input to gaussian ########################
#sed '/^# Cartesian axis system ADPs$/,$d' $CIF.cif > cut.cif
sed -e '/# Tonto-specific key and data/,/# Standard CIF keys and data/d' $CIF.cif > cut.cif
echo "{ " > stdin
echo "" >> stdin
echo "   ! Process the CIF" >> stdin
echo "   CIF= {" >> stdin
echo "       file_name= cut.cif" >> stdin
echo "    }" >> stdin
echo "" >> stdin
echo "   process_CIF" >> stdin
echo "" >> stdin
echo "   name= $NAME" >> stdin
echo "" >> stdin
echo "   put" >> stdin 
#echo "###############################################################################################" >> $NAME.lst
echo "   put_cif" >> stdin
echo "" >> stdin
echo "}" >> stdin 
echo "Reading cif with Tonto"
$TONTO
awk '{a[NR]=$0}/^Atom coordinates/{b=NR}/^Unit cell information/{c=NR}END{for(d=b-1;d<=c-1;++d)print a[d]}' stdout >> $NAME.lst
echo "Done reading cif with Tonto"
rm cut.cif
cp $NAME.cartn-fragment.cif $NAME.$J.cartn-fragment.cif
echo "###############################################################################################" >> $NAME.lst
echo "                                     Starting Gaussian                                         " >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
echo "%chk=./$NAME.chk" > $NAME.com 
echo "%chk=./$NAME.chk" >> $NAME.lst 
echo "%rwf=./$NAME.rwf" | tee -a $NAME.com  $NAME.lst
echo "%int=./$NAME.int" | tee -a $NAME.com  $NAME.lst
echo "%mem=$MEM" | tee -a $NAME.com  $NAME.lst
echo "%nprocshared=$NUMPROC" | tee -a $NAME.com $NAME.lst
if [ "$METHOD" = "rks" ]; then
	echo "# b3lyp/$BASISSET  nosymm output=wfn 6D 10F" | tee -a $NAME.com $NAME.lst
fi
echo "# $METHOD/$BASISSET  nosymm output=wfn 6D 10F" | tee -a $NAME.com $NAME.lst
echo ""  | tee -a $NAME.com $NAME.lst
echo "$NAME" | tee -a $NAME.com $NAME.lst
echo "" | tee -a  $NAME.com $NAME.lst
echo "$CHARGE $MULTIPLICITY" | tee -a  $NAME.com $NAME.lst
awk '{a[NR]=$0}/^_atom_site_Cartn_disorder_group/{b=NR}/^# ==========================/{c=NR}END{for(d=b+1;d<=c-4;++d)print a[d]}' $NAME.cartn-fragment.cif | awk -v OFS='\t' '{print $1, $2, $3, $4}' | awk '{gsub("[(][^)]*[)]","")}1 {print }' | tee -a $NAME.com $NAME.lst
#awk '{a[NR]=$0}/^Atom\ coordinates/{b=NR}/^Atomic\ displacement\ parameters\ \(ADPs\)/{c=NR}END{for(d=b+11;d<=c-4;++d)print a[d]}' stdout | awk 'NR%2==1 {print $2, $4, $5, $6}' > test.txt 
#awk '{gsub("[(][^)]*[)]","")}1 {print }' test.txt >> $NAME.com
#rm test.txt
echo "" | tee -a $NAME.com  $NAME.lst
echo "./$NAME.wfn" | tee -a $NAME.com  $NAME.lst
echo "" | tee -a $NAME.com  $NAME.lst
###################### End extracting XYZ with tonto and input to gaussian ########################
###################### Begin first gaussian single point calculation and storing energy and RMSD ########################
I=$"1"
echo "Runing Gaussian, cycle number $I" 
$GAUSSIAN $NAME.com
echo "Gaussian cycle number $I ended"
ENERGIA=$(sed 's/^ //' $NAME.log | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
RMSD=$(sed 's/^ //' $NAME.log | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $2}' | tr -d '\r')
echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $NAME.lst
echo "" >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
echo "Generation fcheck file for Gaussian cycle number $I"
formchk $NAME.chk $NAME.fchk
echo "Gaussian cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
cp $NAME.com $NAME.$I.com
cp $NAME.fchk $NAME.$I.fchk
cp $NAME.log $NAME.$I.log
###################### End first gaussian single point calculation and storing energy and RMSD ########################
###################### Begin first tonto fit ########################
GAUSSIAN_TO_TONTO
###################### First fit done start refeed gaussian ########################
TONTO_TO_GAUSSIAN
CHECK_ENERGY
######################  Iterative begins ########################

#echo "6.421e-09" | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}' | bc  #aqui aparece um numero em notacao cientifica e a condicao nao pode ser testada, o comando acima transforma ele em float mas nao ta funcionando

#awk -v a="$DE" -v b="0.00001" 'BEGIN{print (a > b)}'
while [ "$(awk -v a="$DE" -v b="0.0001" 'BEGIN{print (a > b)}')" = 1 ]; do
#while [ "$(echo "${DE=$(printf "%f", "$DE")} >= 0.000001" | bc -l)" -eq 1 ]; do    
	GAUSSIAN_TO_TONTO
	TONTO_TO_GAUSSIAN
	CHECK_ENERGY
done
echo "_________________________________________________________________________________________________________________________________" >> $NAME.lst
echo "" >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
echo "                                     Final Geometry                                         " >> $NAME.lst
echo "###############################################################################################" >> $NAME.lst
echo "" >> $NAME.lst
echo "Energy= $ENERGIA2, RMSD= $RMSD2" >> $NAME.lst
echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Analysis of the Hirshfeld atom fit/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $NAME.lst
DURATION=$SECONDS
echo "Job ended, elapsed time:" | tee -a $NAME.lst
echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $NAME.lst
exit
# falta incluir os residuos do stdout na lst file.
