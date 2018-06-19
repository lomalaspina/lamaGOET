#!/bin/bash

source job_options.txt

GAMESS_ELMODB_OLD_PDB(){
	I=$[ $I + 1 ]
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
	if [ "$I" = "1" ]; then
		awk '$1 ~ /ATOM/ {printf "%f\t %f\t %f\t %s\t %s\n", $6, $7, $8, "carga", $3}' $CIF > atoms
	else
		awk 'NR > 2 {printf "%f\t %f\t %f\t %s\t %s\n", $2, $3, $4, "carga", $1}' $JOBNAME.xyz > atoms		
	fi
	awk '{print $5}' atoms | gawk 'BEGIN { FS = "" } {print $1}' | awk '{ if ($1 == "N") print "7.0"; else if ($1 == "H") print "1.0"; else if ($1 == "O") print "8.0"; else if ($1 == "C") print "6.0"; else if ($1 == "S") print "16.0"; }' > atoms_Z
	awk '{print $5}' atoms | gawk 'BEGIN { FS = "" } {print $1}' > atoms_names
	awk 'FNR==NR{a[NR]=$1;next}{$4=a[FNR]}1' atoms_Z atoms > full
	cp full atoms
	awk 'FNR==NR{a[NR]=$1;next}{$5=a[FNR]}1' atoms_names atoms > full
	awk '{printf "%f\t %f\t %f\t %s\t %s\n", $1, $2, $3, $4, $5}' full >> $JOBNAME.gamess.inp
#	awk '{printf "%8.3f\t %8.3f\t %8.3f\t %s\t %s\n", $1, $2, $3, $4, $5}' full >> $JOBNAME.gamess.inp
	#awk '$1 ~ /ATOM/ {printf "%f\t %f\t %f\t %s\t %s\n", $6, $7, $8, "carga", $3} ' $CIF >> $JOBNAME.gamess.inp
	rm atoms 
	rm atoms_Z 
	rm full
	rm atoms_names
	echo "end" >> $JOBNAME.gamess.inp
	case "6-31g(d,p)" in
	 $BASISSET ) echo "basis 6-31G**" >> $JOBNAME.gamess.inp;;
	 *) 	case "6-311g(d,p)" in
		 $BASISSET ) echo "basis 6-311G**" >> $JOBNAME.gamess.inp;;
		 *)	echo "basis $BASISSET" >> $JOBNAME.gamess.inp;;
		esac;;
	esac
#	if [ $BASISSET == "6-31g(d,p)" ]; then
#		echo "basis 6-31G**" >> $JOBNAME.gamess.inp
#	elif [ $BASISSET == "6-311g(d,p)" ]; then
#		echo "basis 6-311G**" >> $JOBNAME.gamess.inp
#	else
#		echo "basis $BASISSET" >> $JOBNAME.gamess.inp
#	fi
	echo "runtype scf" >> $JOBNAME.gamess.inp
	echo "scftype rhf" >> $JOBNAME.gamess.inp
	echo "enter " >> $JOBNAME.gamess.inp
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
		echo "Calculation of overlap integrals with gamess done, writing elmodb input files"
#		if [[ ! -e "LIBRARIES" ]]; then
#			ln -s $ELMOLIB LIBRARIES
#		fi
    		if [[ ! -f "elmodb.exe" ]]; then
#		if [[ ! -f "$SCFCALC_BIN" ]]; then
			cp $SCFCALC_BIN .
		fi
	
		if [ "$I" = "1" ]; then
#			PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
			BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
			ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' "'$END'"  " >> $JOBNAME.elmodb.inp
		else 
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' "'$END'"  " >> $JOBNAME.elmodb.inp
		fi
		echo "Running elmodb"
		./$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' ) < $JOBNAME.elmodb.inp > $JOBNAME.elmodb.out
		if ! grep -q 'CONGRATULATIONS: THE ELMO-TRANSFERs ENDED GRACEFULLY!!!' "$JOBNAME.elmodb.out"; then
			echo "ERROR: elmodb finished with error, please check the $I.th elmodb.out file for more details" | tee -a $JOBNAME.lst
			unset MAIN_DIALOG
			exit 0
		else
			echo "elmodb job finish correctly."
			cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
			cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
			cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
			if [ "$I" != "1" ]; then
				cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
			fi
		fi
	fi
	
	#elmo part finished here, now we will run gaussian only once to obtain a formated fchk file that will be edited with the results from elmo
	#if [ "$I" = "1" ]; then
	#	echo "Writing fchk file with Gaussian"
	#	echo "%chk=./$JOBNAME.chk" > $JOBNAME.com
	#	echo "%rwf=./$JOBNAME.rwf" >> $JOBNAME.com
	#	echo "%int=./$JOBNAME.int" >> $JOBNAME.com
	#	echo "%mem=$MEM" >> $JOBNAME.com
	#	echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
	#BEWARE only rhf for elmodb
	#	echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F" >> $JOBNAME.com
	#	echo "" >> $JOBNAME.com
	#	echo "$JOBNAME" >> $JOBNAME.com
	#	echo "" >> $JOBNAME.com
	#	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
	#       awk '$1 ~ /ATOM/ {printf "%s\t %8.3f\t %8.3f\t %8.3f\n", substr($3,1,1), $6, $7, $8}' $CIF >> $JOBNAME.com
	#	echo "" >> $JOBNAME.com
	#	echo "./$JOBNAME.wfn" >> $JOBNAME.com
	#	echo "" >> $JOBNAME.com
	#	echo "Runing Gaussian, cycle number $I"
	#	g09 $JOBNAME.com
	#	echo "Gaussian cycle number $I ended"
	#	if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
	#		echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
	#		unset MAIN_DIALOG
	#		exit 0
	#	fi
	#	echo "Generation fcheck file for Gaussian cycle number $I"
	#	formchk $JOBNAME.chk $JOBNAME.fchk
	#fi
	#sed -i -ne '/Alpha MO coefficients/ {p; r MOs' -e ':a; n; /Total SCF Density/ {p; b}; ba}; p' $JOBNAME.fchk
	#sed -i -ne '/Total SCF Density/ {p; r DMAT' -e ':a; n; /Mulliken Charges/ {p; b}; ba}; p' $JOBNAME.fchk
	#cp  $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
}

ELMODB(){
	I=$[ $I + 1 ]
	#if [[ ! -e "LIBRARIES" ]]; then
	#	ln -s $ELMOLIB LIBRARIES
	#fi
	if [[ ! -f "elmodb.exe" ]]; then
		cp $SCFCALC_BIN .
	fi
	if [ "$I" = "1" ]; then
#		PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
		BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
		ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' "'$END'"  " >> $JOBNAME.elmodb.inp
	else 
		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' "'$END'"  " >> $JOBNAME.elmodb.inp
	fi
	./$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' ) < $JOBNAME.elmodb.inp > $JOBNAME.elmodb.out
	if ! grep -q 'CONGRATULATIONS: THE ELMO-TRANSFERs ENDED GRACEFULLY!!!' "$JOBNAME.elmodb.out"; then
		echo "ERROR: elmodb finished with error, please check the $I.th elmodb.out file for more details" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
	else
		mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
		cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
		cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
		cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
		if [ "$I" != "1" ]; then
			cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
		fi
	fi
}

CHECK_ELMO(){
	LINES=$(wc -l < $JOBNAME.elmodb.out | tr -d '\r')
	PERCENT1=$[ LINES / 100 ]
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
	echo "Running Orca, cycle number $I" 
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
#	echo "Writing Tonto stdin"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!                        This stdin was written with lamaGOET                             !!!" >> stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!                    script written by Lorraine Andrade Malaspina                         !!!" >> stdin
	echo "!!!                        contact: lorraine.malaspina@gmail.com                            !!!" >> stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> stdin
	echo "{ " >> stdin
	echo "" >> stdin
	echo "   keyword_echo_on" >> stdin
	echo "" >> stdin
	if [ "$SCFCALCPROG" = "elmodb" ]; then
	        echo "   name= $JOBNAME" >> stdin 
	        echo "" >> stdin
		echo "   read_g09_fchk_file $JOBNAME.fchk" >> stdin
	fi
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
	if [ "$SCFCALCPROG" != "elmodb" ]; then
	#	if [[ "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" && "$COMPLETESTRUCT" != "true" ]]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		if [ $J = 0 ]; then 
			if [[ "$COMPLETESTRUCT" == "true" && "$SCFCALCPROG" != "Tonto" ]]; then
				echo "       file_name= $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
			else
				echo "       file_name= $CIF" >> stdin
			fi
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
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
	fi
	if [[ $J -gt 0 && "$SCFCALCPROG" == "elmodb" ]]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		echo "       file_name= $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
	#cp $JOBNAME'_cartesian.cif2' $JOBNAME.cartesian.cif2
	#echo "       file_name= $JOBNAME.cartesian.cif2" >> stdin
	#else
	#echo "       file_name= $CIF" >> stdin
	fi
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
	if [ "$SCFCALCPROG" != "elmodb" ]; then
		if [[ $J == 0 && "$COMPLETESTRUCT" == "true" && "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" ]]; then
			echo "   cluster= {" >> stdin
			echo "      defragment= $COMPLETESTRUCT" >> stdin
			echo "      make_info" >> stdin
			echo "   }" >> stdin
			echo "" >> stdin
			echo "   create_cluster" >> stdin
			echo "" >> stdin
			echo "   name= $JOBNAME" >> stdin		
			echo "" >> stdin
		fi
	fi
	echo "   charge= $CHARGE" >> stdin       
	echo "   multiplicity= $MULTIPLICITY" >> stdin
	if [[ $J == 0 && "$IAMTONTO" == "true" ]]; then 
		echo ""
		echo "   crystal= {    " >> stdin
		if [ "$SCFCALCPROG" = "elmodb" ]; then
			echo "      REDIRECT tonto.cell" >> stdin
		fi
	#	if [ "$COMPLETESTRUCT" = "true" ]; then
	#		echo "      defragment= $COMPLETESTRUCT" >> stdin
	#		echo "      make_info" >> stdin
	#		echo "      put_cluster_info" >> stdin
	#	fi
		echo "      xray_data= {   " >> stdin
		echo "         optimise_extinction= false" >> stdin
		echo "         correct_dispersion= $DISP" >> stdin
		echo "         wavelength= $WAVE Angstrom" >> stdin
		if [ "$REFANHARM" == "true" ]; then
			if [[ "$THIRDORD" == "true" && "$FOURTHORD" == "true" ]]; then
				echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
			elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "false" ]]; then
				echo "         refine_3rd_order_for_atoms= { $ANHARMATOMS } " >> stdin
			elif [[ "$THIRDORD" == "false" && "$FOURTHORD" == "true" ]]; then
				echo "         refine_4th_order_only= { $ANHARMATOMS } " >> stdin
			else 
				echo "ERROR: Please select at least one of the anharmonic terms to refine" | tee -a $JOBNAME.lst
				unset MAIN_DIALOG
				exit 0
			fi
		fi
		echo "         REDIRECT $HKL" >> stdin
		echo "         f_sigma_cutoff= $FCUT" >> stdin
		echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
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
	if [[ "$SCFCALCPROG" == "elmodb" && $J == 0 ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
#	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "Tonto" ]]; then
#		if [ $COMPLETESTRUCT = "true" ]; then 
#			echo "      REDIRECT tonto.cell" >> stdin
#		fi
#	fi
	#if [[ $J = 0 && "$COMPLETESTRUCT" = "true" ]]; then
	#	echo "      defragment= $COMPLETESTRUCT" >> stdin
	#	echo "      make_info" >> stdin
	#	echo "      put_cluster_info" >> stdin
	#fi
	echo "      xray_data= {   " >> stdin
	echo "         thermal_smearing_model= hirshfeld" >> stdin
	echo "         partition_model= mulliken" >> stdin
	echo "         optimise_extinction= false" >> stdin
	echo "         correct_dispersion= $DISP" >> stdin
	echo "         optimise_scale_factor= true" >> stdin
	echo "         wavelength= $WAVE Angstrom" >> stdin
	if [ "$REFANHARM" == "true" ]; then
		if [[ "$THIRDORD" == "true" && "$FOURTHORD" == "true" ]]; then
			echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
		elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "false" ]]; then
			echo "         refine_3rd_order_for_atoms= { $ANHARMATOMS } " >> stdin
		elif [[ "$THIRDORD" == "false" && "$FOURTHORD" == "true" ]]; then
			echo "         refine_4th_order_only= { $ANHARMATOMS } " >> stdin
		else 
			echo "ERROR: Please select at least one of the anharmonic terms to refine" | tee -a $JOBNAME.lst
			unset MAIN_DIALOG
			exit 0
		fi
	fi
	echo "         REDIRECT $HKL" >> stdin
	echo "         f_sigma_cutoff= $FCUT" >> stdin
	echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
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
		if [[ "$SCCHARGES" = "true" && "$SCFCALCPROG" != "elmodb" ]]; then 
			echo "     ! SC cluster charge SCF" >> stdin
			echo "      scfdata= {" >> stdin
			echo "      initial_MOs= existing" >> stdin
			if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
				echo "      kind= rks " >> stdin
				echo "      dft_exchange_functional= b3lypgx" >> stdin
				echo "      dft_correlation_functional= b3lypgc" >> stdin
			else
				echo "      kind= $METHOD" >> stdin
			fi
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
			if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
				echo "      kind= rks " >> stdin
				echo "      dft_exchange_functional= b3lypgx" >> stdin
				echo "      dft_correlation_functional= b3lypgc" >> stdin
			else
				echo "      kind= $METHOD" >> stdin
			fi
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
	fi
	if [ "$SCFCALCPROG" = "Tonto" ]; then
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
	echo "Running Tonto, cycle number $J" 
	if [[ "$NUMPROC" != "1" ]]; then
		mpirun -n $NUMPROC $TONTO	
	else
		$TONTO
	fi
	INITIALCHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $2}')
	MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print shift}')
	MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print atom}')
	MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print param}')
	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
		sed -i 's/(//g' $JOBNAME.xyz
		sed -i 's/)//g' $JOBNAME.xyz
	fi
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
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "Cycle   Fit      initial        final            R              R_w              Max.           Max.      No. of     No. of     Energy         RMSD         Delta " >> $JOBNAME.lst
		echo "       Iter       chi2          chi2                                             Shift          Shift     params     eig's    at final      at final       Energy " >> $JOBNAME.lst
		echo "                                                                                 /esd           param                near 0     Geom.          Geom.                " >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
	#	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-5]}' stdout)    $ENERGIA   $RMSD   $ENERGY "  >> $JOBNAME.lst
	fi
	if [[ "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" ]]; then 
		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t""    "$8" \t"$9 }' ) "  >> $JOBNAME.lst  
	fi
#	echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1"\t"}' ) $INITIALCHI $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t"$2"\t"$3"\t"$4}') $(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print "\t"$5"    "$6" "$7}') $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t"$8"\t"$9 }' ) "  >> $JOBNAME.lst    
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
		if [[ "$SCFCALCPROG" != "elmodb" &&  "$SCCHARGES" == "true" ]]; then
			cp gaussian-point-charges $J.fit_cycle.$JOBNAME/$J.gaussian-point-charges
		fi
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
	   		echo "# blyp/$BASISSET Charge nosymm output=wfn 6D 10F $INT" >> $JOBNAME.com
		else
			echo "# blyp/$BASISSET nosymm output=wfn 6D 10F $INT" >> $JOBNAME.com
	        fi
	else
		if [ "$METHOD" = "uks" ]; then
			if [ "$SCCHARGES" = "true" ]; then 
		   		echo "# ublyp/$BASISSET Charge nosymm output=wfn 6D 10F $INT" >> $JOBNAME.com
			else
				echo "# ublyp/$BASISSET nosymm output=wfn 6D 10F $INT" >> $JOBNAME.com
		        fi
		else
			if [ "$SCCHARGES" = "true" ]; then 
		   		echo "# $METHOD/$BASISSET Charge nosymm output=wfn 6D 10F $INT" >> $JOBNAME.com
			else
				echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F $INT" >> $JOBNAME.com
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
	if [ "$GAUSGEN" = "true" ]; then
	        cat basis_gen.txt >> $JOBNAME.com
		echo "" >> $JOBNAME.com
	fi
	echo "./$JOBNAME.wfn" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "Running Gaussian, cycle number $I"
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
		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "    "$8" \t"$9 }' )  $ENERGIA2   $RMSD2   \t$DE"   >> $JOBNAME.lst  
#		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t""    "$8" \t"$9 }' )  $ENERGIA2   $RMSD2   \t$DE"   >> $JOBNAME.lst  
#		echo " $J  $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout)    $ENERGIA2   $RMSD2   $DE"  >> $JOBNAME.lst
		ENERGIA=$ENERGIA2
		RMSD=$RMSD2
		echo "Delta E (cycle  $I - $[ I - 1 ]): $DE "
###		echo "Delta E (cycle  $I - $[ I - 1 ]): $DE (convergency will reach when Delta E is smaller than 0.0001)"
	#	J=$[ $J + 1 ]
	#	echo "Running Tonto, cycle number $J"
	#	$TONTO
	#	echo "Tonto cycle number $I ended"
	#	cp stdout stdout.$J
}


CHECKCONV(){
#FINALPARAMESD=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $5}') This is from the last line
FINALPARAMESD=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $5}')
}
######################  End check energy ########################

run_script(){
	SECONDS=0
	I=$"0"   ###counter for gaussian jobs
	J=$"0"   ###counter for tonto fits
	shopt -s nocasematch	

	#removing  0 0 0 line 
	if [[ ! -z $(awk '{if (($1) == "0" && ($2) == "0" && ($3) == "0" ) print}' $HKL) ]]; then
		awk '{if (($1) != "0" && ($2) != "0" && ($3) != "0" ) print}' $HKL > $JOBNAME.tonto_edited.hkl
	fi
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
	
	# writing header on hkl
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
	
	if [[ -z "$(grep "reflection_data= {" $HKL)" ]]; then
		echo "You are missing the tonto header in the hkl file."
	fi

	#writing the lst file
	echo "###############################################################################################" > $JOBNAME.lst
	echo "                                           lamaGOT                                             " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "Job started on:" >> $JOBNAME.lst
	date >> $JOBNAME.lst
	echo "User Inputs: " >> $JOBNAME.lst
	echo "Tonto executable	:  $TONTO"  >> $JOBNAME.lst 
	echo "$($TONTO -v)" >> $JOBNAME.lst 
	#awk 'NR==7 { print }' stdout >> $JOBNAME.lst      #print the tonto version, but there is no stdout yet
	echo "SCF program		: $SCFCALCPROG" >> $JOBNAME.lst
	if [ "$SCFCALCPROG" != "Tonto" ]; then 
		echo "SCF executable		: $SCFCALC_BIN" >> $JOBNAME.lst
	fi
	echo "Job name		: $JOBNAME" >> $JOBNAME.lst
	echo "Input cif		: $CIF" >> $JOBNAME.lst
	echo "Input hkl		: $HKL" >> $JOBNAME.lst
	echo "Wavelenght		: $WAVE" Angstrom >> $JOBNAME.lst
	echo "F_sigma_cutoff		: $FCUT" >> $JOBNAME.lst
	echo "Tol. for shift on esd	: $CONVTOL" >> $JOBNAME.lst
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
			echo "Refine Hydrogens isot.	: $HADP" >> $JOBNAME.lst
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
	
	#writing in the lst file FOR GAUSSIAN or ORCA only
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
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > stdin
		echo "!!!                                                                                         !!!" >> stdin
		echo "!!!                        This stdin was written with lamaGOET                             !!!" >> stdin
		echo "!!!                                                                                         !!!" >> stdin
		echo "!!!                    script written by Lorraine Andrade Malaspina                         !!!" >> stdin
		echo "!!!                        contact: lorraine.malaspina@gmail.com                            !!!" >> stdin
		echo "!!!                                                                                         !!!" >> stdin
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> stdin
		echo "{ " >> stdin
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
		if [ "$COMPLETESTRUCT" = "true" ]; then
			echo "   cluster= {" >> stdin
			echo "      defragment= $COMPLETESTRUCT" >> stdin
			echo "      make_info" >> stdin
			echo "   }" >> stdin
			echo "" >> stdin
			echo "   create_cluster" >> stdin
			echo "" >> stdin
			echo "   name= $JOBNAME" >> stdin		
			echo "" >> stdin
		fi
		echo "   put" >> stdin 
		echo "" >> stdin
		echo "   write_xyz_file" >> stdin
		if [ "$COMPLETESTRUCT" = "true" ]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		#echo "###############################################################################################" >> $JOBNAME.lst
		###echo "   put_cif" >> stdin
		echo "" >> stdin
		echo "}" >> stdin 
		echo "Reading cif with Tonto"
		if [[ "$NUMPROC" != "1" ]]; then
			mpirun -n $NUMPROC $TONTO	
		else
			$TONTO
		fi
		INITIALCHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $2}')
		MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print shift}')
		MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print atom}')
		MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print param}')
		if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
			sed -i 's/(//g' $JOBNAME.xyz
			sed -i 's/)//g' $JOBNAME.xyz
		fi
		if ! grep -q 'Wall-clock time taken' "stdout"; then
			echo "ERROR: something wrong with your input cif file, please check the stdout file for more details" | tee -a $JOBNAME.lst
			unset MAIN_DIALOG
			exit 0
		fi
		mkdir $J.fit_cycle.$JOBNAME
		cp $JOBNAME.xyz $J.fit_cycle.$JOBNAME/$JOBNAME.starting_geom.xyz
		cp stdin $J.fit_cycle.$JOBNAME/$J.stdin
		cp stdout $J.fit_cycle.$JOBNAME/$J.stdout
		cp $JOBNAME'.cartesian.cif2' $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
		awk '{a[NR]=$0}/^Atom coordinates/{b=NR}/^Unit cell information/{c=NR}END{for(d=b-1;d<=c-2;++d)print a[d]}' stdout >> $JOBNAME.lst
		echo "Done reading cif with Tonto"
		if [ "$COMPLETESTRUCT" = "true" ]; then
			CELLA=$(grep "a cell parameter ............" stdout | awk '{print $NF}')
			CELLB=$(grep "b cell parameter ............" stdout | awk '{print $NF}')
			CELLC=$(grep "c cell parameter ............" stdout | awk '{print $NF}')
			CELLALPHA=$(grep "alpha angle ................." stdout | awk '{print $NF}')
			CELLBETA=$(grep "beta  angle ................." stdout | awk '{print $NF}')
			CELLGAMMA=$(grep "gamma angle ................." stdout | awk '{print $NF}')
			SPACEGROUP=$(grep "Hall symbol" stdout | gawk 'BEGIN { FS = " ................ " } {print $NF}')
	  		echo "      spacegroup= { hall_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		fi
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
			#this is the first SCF so no charges in!
			if [ "$METHOD" = "rks" ]; then
				echo "# blyp/$BASISSET nosymm output=wfn 6D 10F $INT" | tee -a $JOBNAME.com $JOBNAME.lst    
			else
				if [ "$METHOD" = "uks" ]; then
					echo "# ublyp/$BASISSET nosymm output=wfn 6D 10F $INT" | tee -a $JOBNAME.com $JOBNAME.lst
				else
					echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F $INT" | tee -a $JOBNAME.com $JOBNAME.lst
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
			if [ "$GAUSGEN" = "true" ]; then
		        	cat basis_gen.txt | tee -a $JOBNAME.com  $JOBNAME.lst
				echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			fi
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
			echo "Running Gaussian, cycle number $I" 
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
		elif [ "$SCFCALCPROG" = "Orca" ]; then  
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Orca                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			if [ "$METHOD" = "rks" ]; then
				echo "! blyp $BASISSET" > $JOBNAME.inp
				echo "! blyp $BASISSET" >> $JOBNAME.lst
			elif [ "$METHOD" = "uks" ]; then
				echo "! ublyp $BASISSET" > $JOBNAME.inp
				echo "! ublyp $BASISSET" >> $JOBNAME.lst
			else
				echo "! $METHOD $BASISSET" > $JOBNAME.inp
				echo "! $METHOD $BASISSET" >> $JOBNAME.lst
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
			echo "Running Orca, cycle number $I" 
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
		###################### First fit done start refeed gaussian ########################
		######################  Iterative begins ########################
		
		#echo "6.421e-09" | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}' | bc  #aqui aparece um numero em notacao cientifica e a condicao nao pode ser testada, o comando acima transforma ele em float mas nao ta funcionando
	
		#awk -v a="$DE" -v b="0.00001" 'BEGIN{print (a > b)}'
		while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
###		while [ "$(awk -F'\t' 'function abs(x){return ((x < 0.0) ? -x : x)} BEGIN{print (abs('$DE') > 0.0001)}')" = 1 ]; do
		#while [ "$(echo "${DE=$(printf "%f", "$DE")} >= 0.000001" | bc -l)" -eq 1 ]; do  
			SCF_TO_TONTO
			if [ "$SCFCALCPROG" = "Gaussian" ]; then  
				TONTO_TO_GAUSSIAN
			else 
				TONTO_TO_ORCA
			fi
			CHECK_ENERGY
		done
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
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
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
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
		if [ "$USEGAMESS" = "false" ]; then    
			ELMODB
#		        CHECK_ELMO
			SCF_TO_TONTO
			ELMODB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
#			while [[ "$(diff $JOBNAME.elmodb.out $[ I - 1 ].$SCFCALCPROG.cycle.$JOBNAME/$[ I - 1 ].$JOBNAME.elmodb.out | wc -l )" -gt $PERCENT1 ]]; do
				SCF_TO_TONTO
				ELMODB
			done
			echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
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
			GAMESS_ELMODB_OLD_PDB
			SCF_TO_TONTO
			GAMESS_ELMODB_OLD_PDB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
#			while [[ "$(diff $JOBNAME.elmodb.out $[ I - 1 ].$SCFCALCPROG.cycle.$JOBNAME/$[ I - 1 ].$JOBNAME.elmodb.out | wc -l )" -gt $PERCENT1 ]]; do
				SCF_TO_TONTO
				GAMESS_ELMODB_OLD_PDB
			done
			echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
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

run_script
