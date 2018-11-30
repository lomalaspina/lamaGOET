#!/bin/bash
Encoding=UTF-8

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
#    		if [[ ! -f "elmodb.exe" ]]; then
		if [[ ! -f "$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' )" ]]; then
			cp $SCFCALC_BIN .
		fi
	
		if [ "$I" = "1" ]; then
#			PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
			BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
			ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			if [[ "$NTAIL" != "0" ]]; then
				echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
			fi
			if [[ "$NSSBOND" != "0" ]]; then
				echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
			fi			
		else 
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' ntail=$NTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			if [[ "$NTAIL" != "0" ]]; then
				echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
			fi
			if [[ "$NSSBOND" != "0" ]]; then
				echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
			fi
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
#	if [[ ! -f "elmodb.exe" ]]; then
	if [[ ! -f "$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' )" ]]; then
		cp $SCFCALC_BIN .
	fi
	if [ "$I" = "1" ]; then
#		PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
		BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
		ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		if [[ "$NTAIL" != "0" ]]; then
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
		else
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
		fi
		if [[ "$NSSBOND" != "0" ]]; then
			echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
		fi
	else 
		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSET' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		if [[ "$NTAIL" != "0" ]]; then
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
		else
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
		fi
		if [[ "$NSSBOND" != "0" ]]; then
			echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
		fi
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
	#	if [[ "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" && "$COMPLETECIF" != "true" ]]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		if [ $J = 0 ]; then 
			if [[ "$COMPLETECIF" == "true" && "$SCFCALCPROG" != "Tonto" ]]; then
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
	fi
	if [[ $J -eq 0 && "$SCFCALCPROG" == "elmodb" && "$INITADP" == "true" ]]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		echo "       file_name= $INITADPFILE" >> stdin
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
		if [[ $J == 0 && "$COMPLETECIF" == "true" && "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" ]]; then
			echo "   cluster= {" >> stdin
			echo "      defragment= $COMPLETECIF" >> stdin
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
		if [[ "$SCFCALCPROG" = "elmodb" && "$INITADP" == "false" ]]; then
			echo "      REDIRECT tonto.cell" >> stdin
		fi
	#	if [ "$COMPLETECIF" = "true" ]; then
	#		echo "      defragment= $COMPLETECIF" >> stdin
	#		echo "      make_info" >> stdin
	#		echo "      put_cluster_info" >> stdin
	#	fi
		echo "      xray_data= {   " >> stdin
		echo "         optimise_extinction= false" >> stdin
		echo "         correct_dispersion= $DISP" >> stdin
		echo "         wavelength= $WAVE Angstrom" >> stdin
		if [ "$REFANHARM" == "true" ]; then
			if [[ "$THIRDORD" == "false" && "$FOURTHORD" == "true" ]]; then
				echo "         refine_4th_order_only= true " >> stdin
				echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
			elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "true" ]]; then
				echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
			elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "false" ]]; then
				echo "         refine_3rd_order_for_atoms= { $ANHARMATOMS } " >> stdin
			else 
				echo "ERROR: Please select at least one of the anharmonic terms to refine" | tee -a $JOBNAME.lst
				unset MAIN_DIALOG
				exit 0
			fi
		fi
		echo "         REDIRECT $HKL" >> stdin
		echo "         f_sigma_cutoff= $FCUT" >> stdin
		echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
#		echo "         refine_H_U_iso= $HADP" >> stdin
		echo "         refine_H_U_iso= yes" >> stdin
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
	if [[ "$SCFCALCPROG" == "elmodb" && $J == 0 && "$INITADP" == "false" ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
#	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "Tonto" ]]; then
#		if [ $COMPLETECIF = "true" ]; then 
#			echo "      REDIRECT tonto.cell" >> stdin
#		fi
#	fi
	#if [[ $J = 0 && "$COMPLETECIF" = "true" ]]; then
	#	echo "      defragment= $COMPLETECIF" >> stdin
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
		if [[ "$THIRDORD" == "false" && "$FOURTHORD" == "true" ]]; then
			echo "         refine_4th_order_only= true " >> stdin
			echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
		elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "true" ]]; then
			echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
		elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "false" ]]; then
			echo "         refine_3rd_order_for_atoms= { $ANHARMATOMS } " >> stdin
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
			echo "	 refine_H_positions= $REFHPOS" >> stdin 
		fi
	fi
	if [ "$REFNOTHING" = "true" ]; then
		echo "	 refine_nothing_for_atoms= { $ATOMLIST }" >> stdin 
	fi
	if [ "$REFUISO" = "true" ]; then
		echo "	 refine_u_iso_for_atoms= { $ATOMUISOLIST }" >> stdin 
	fi
	if [ "$MAXLSCICLE" ]; then
		echo "	 max_iterations= $MAXLSCICLE" >> stdin 
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
		if [[ "$SCCHARGES" == "true" && "$SCFCALCPROG" != "elmodb" ]]; then 
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
#			echo "   fit_hirshfeld_atoms_lamaGOET" >> stdin
			echo "" >> stdin
			echo "   write_xyz_file" >> stdin
		else
			echo "   ! Make Hirshfeld structure factors" >> stdin
			echo "   fit_hirshfeld_atoms" >> stdin
#			echo "   fit_hirshfeld_atoms_lamaGOET" >> stdin
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
		echo "      kind= rhf" >> stdin   # this is the promolecule guess, should be always rhf
#		if [ "$METHOD" = "b3lyp" ]; then
#			echo "      kind= rks " >> stdin
#			echo "      dft_exchange_functional= b3lypgx" >> stdin
#			echo "      dft_correlation_functional= b3lypgc" >> stdin
#		else 
#			echo "      kind= $METHOD" >> stdin
#		fi
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
		if [ "$METHOD" = "b3lyp" ]; then
			echo "      kind= rks" >> stdin
			echo "      dft_exchange_functional= b3lypgx" >> stdin
			echo "      dft_correlation_functional= b3lypgc" >> stdin
		else 
			echo "      kind= $METHOD" >> stdin
		fi
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
	$TONTO
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
	   		echo "# blyp/$BASISSET Charge nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
		else
			echo "# blyp/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "uks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# ublyp/$BASISSET Charge nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
		else
			echo "# ublyp/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "rhf" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# HF/$BASISSET Charge nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
		else
			echo "# HF/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
	        fi
	else
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $METHOD/$BASISSET Charge nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
		else
			echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" >> $JOBNAME.com
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
#	formchk $JOBNAME.chk $JOBNAME.fchk
     	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
#	cp $JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
}

######################  Gaussian done ########################

######################  Begin check energy ########################

CHECK_ENERGY(){
	if [ "$SCFCALCPROG" = "Gaussian" ]; then 
#		ENERGIA2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r') # exchanging for another one where I join the lines 2x more.
		ENERGIA2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#this one was not working whenever relativistics was used in gaussian, the bottom one works.
#		RMSD2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $2}'| tr -d '\r')
		RMSD2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
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

# function to get the residual density, only needed for scf program different than tonto, since we remove the residual calculation from inside the fits.
GET_RESIDUALS(){
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!                        This stdin was written with lamaGOET                             !!!" >> stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!   This stdin is only to get the residual density after the HAR using an SCF program     !!!" >> stdin
	echo "!!!   that is different than Tonto. A cube file containing the residual density will be     !!!" >> stdin
	echo "!!!                         written where the units are e/A^3.                              !!!" >> stdin
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
	if [ "$SCFCALCPROG" != "elmodb" ]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		echo "       file_name= $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
	fi
	if [ "$SCFCALCPROG" == "elmodb" ]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		echo "       file_name= $J.fit_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
	fi
	if [ "$SCFCALCPROG" = "Tonto" ]; then 
		echo "   basis_directory= $BASISSETDIR" >> stdin
		echo "   basis_name= $BASISSETT" >> stdin
		echo "" >> stdin
	fi
	if [ "$DISP" = "yes" ]; then 
		echo "   	 dispersion_coefficients= {" >> stdin
		echo "   	 $(cat DISP_inst.txt)" >> stdin
		echo "   	 }" >> stdin
		echo "" >> stdin
	fi
	echo "   charge= $CHARGE" >> stdin       
	echo "   multiplicity= $MULTIPLICITY" >> stdin
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
	echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
	echo "" >> stdin
	echo "      }  " >> stdin
	echo "   }  " >> stdin
	echo "" >> stdin
	echo "   ! Geometry    " >> stdin
	echo "   put" >> stdin
	echo "" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_MOs= existing" >> stdin
	if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
		echo "      kind= rks " >> stdin
		echo "      dft_exchange_functional= b3lypgx" >> stdin
		echo "      dft_correlation_functional= b3lypgc" >> stdin
	else
		echo "      kind= $METHOD" >> stdin
	fi
	echo "      use_SC_cluster_charges= $SCCHARGES" >> stdin
	if [ "$SCCHARGES" == "true" ]; then 
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
		echo "      save_cluster_charges= true" >> stdin
	fi
	echo "      convergence= 0.001" >> stdin
	echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   make_scf_density_matrix" >> stdin
	echo "   make_structure_factors" >> stdin
	echo "" >> stdin
	echo "   put_minmax_residual_density" >> stdin
	echo "" >> stdin
	echo "   plot_grid= {                           " >> stdin
	echo "" >> stdin
	echo "      kind= residual_density_map" >> stdin
	echo "      use_unit_cell_as_bbox" >> stdin
	echo "      desired_separation= 0.1 angstrom" >> stdin
	echo "      plot_format= cell.cube" >> stdin
	echo "      plot_units= angstrom^-3" >> stdin
	echo "" >> stdin
	echo "    }" >> stdin
	echo "" >> stdin
	echo "   plot" >> stdin
	echo "" >> stdin
	echo "}" >> stdin 
	echo "Calculating residual density at final geometry" 
	$TONTO
}

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

	if [ "$PLOT_TONTO" = "true" ]; then
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
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
		echo "   basis_directory= $BASISSETDIR" >> stdin
		echo "   basis_name= $BASISSETT" >> stdin
		echo "" >> stdin
		echo "   charge= $CHARGE" >> stdin       
		echo "   multiplicity= $MULTIPLICITY" >> stdin
		echo "" >> stdin
		echo "   crystal= {    " >> stdin
 		echo "      xray_data= {   " >> stdin
		echo "         wavelength= $WAVE Angstrom" >> stdin
		echo "         REDIRECT $HKL" >> stdin
		echo "         f_sigma_cutoff= $FCUT" >> stdin
		echo "      }  " >> stdin
		echo "   }  " >> stdin
		echo "" >> stdin
		echo "   ! Geometry    " >> stdin
		echo "   put" >> stdin
		echo "" >> stdin
		if [ "$USEBECKE" = "true" ]; then 
			echo "   !Tight grid" >> stdin
			echo "   becke_grid = {" >> stdin
			echo "      set_defaults" >> stdin
			echo "      accuracy= $ACCURACY" >> stdin
			echo "      pruning_scheme= $BECKEPRUNINGSCHEME" >> stdin
			echo "   }" >> stdin
			echo "" >> stdin
		fi
		echo "   read_archive molecular_orbitals restricted" >> stdin
		echo "   read_archive orbital_energies restricted" >> stdin
		echo "" >> stdin
		echo "   ! SC cluster charge SCF" >> stdin
		echo "   scfdata= {" >> stdin
		echo "      initial_MOs= restricted" >> stdin
		if [ "$METHOD" = "b3lyp" ]; then
			echo "      kind= rks" >> stdin
			echo "      dft_exchange_functional= b3lypgx" >> stdin
			echo "      dft_correlation_functional= b3lypgc" >> stdin
		else 
			echo "      kind= $METHOD" >> stdin
		fi
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
		echo "   make_scf_density_matrix" >> stdin
		echo "" >> stdin
		if [ "$DEFDEN" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= deformation_density" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
		if [ "$DFTXCPOT" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= dft_xc_potential" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
		if [ "$DENS" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= electron_density" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
		if [ "$LAPL" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= laplacian" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
		if [ "$NEGLAPL" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= negative_laplacian" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
		if [ "$PROMOL" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= promolecule_density" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
		if [ "$RESDENS" = "true" ]; then
			echo "   plot_grid= {" >> stdin
			echo "      kind= residual_density_map" >> stdin
			echo "      use_unit_cell_as_bbox" >> stdin
			if [ -z $SEPARATION ]; then
				echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
			else
				echo "      desired_separation= $SEPARATION angstrom" >> stdin
			fi
			echo "      plot_format= cell.cube" >> stdin
			if [ "$PLOT_ANGS" = "true" ]; then
				echo "      plot_units= angstrom^-3" >> stdin
			fi
			echo "" >> stdin
			echo "    }" >> stdin
			echo "" >> stdin
			echo "   plot" >> stdin
			echo "" >> stdin
		fi
	echo "}" >> stdin 
	$TONTO
	exit 0
	exit
	fi

	#writing the lst file
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
		if [ "$COMPLETECIF" = "true" ]; then
			echo "   cluster= {" >> stdin
			echo "      defragment= $COMPLETECIF" >> stdin
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
		if [ "$COMPLETECIF" = "true" ]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		#echo "###############################################################################################" >> $JOBNAME.lst
		###echo "   put_cif" >> stdin
		echo "" >> stdin
		echo "}" >> stdin 
		echo "Reading cif with Tonto"
		$TONTO
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
		if [ "$COMPLETECIF" = "true" ]; then
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
				echo "# blyp/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" | tee -a $JOBNAME.com $JOBNAME.lst    
			else
				if [ "$METHOD" = "uks" ]; then
					echo "# ublyp/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" | tee -a $JOBNAME.com $JOBNAME.lst
				else
					echo "# $METHOD/$BASISSET nosymm output=wfn 6D 10F Fchk $INT" | tee -a $JOBNAME.com $JOBNAME.lst
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
			ENERGIA=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
			RMSD=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
#exchanged this line by the one above, better way of cuting it because the bottom one would crash with relativistics.
#			RMSD=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $2}' | tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "Generation fcheck file for Gaussian cycle number $I"
#			formchk $JOBNAME.chk $JOBNAME.fchk
			echo "Gaussian cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
	     		mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
			cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
#			cp $JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
			cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
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
			if [[ $J -gt 50 ]];then
				CHECK_ENERGY
				echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
				break
			fi
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
		GET_RESIDUALS
		###commented but working, will change because the residual data is not being printed in the .lst file
		###echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Analysis of the Hirshfeld atom fit/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
#		get the residual density running tonto once, only needed if not using tonto for the scf			
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
		GET_RESIDUALS
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
			if [[ $J -gt 50 ]];then
				CHECK_ENERGY
				echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
				break
			fi
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
			GET_RESIDUALS
			echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
#			get the residual density running tonto once, only needed if not using tonto for the scf			
			DURATION=$SECONDS
			echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
			echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
			exit
		else 
			GAMESS_ELMODB_OLD_PDB
			SCF_TO_TONTO
			GAMESS_ELMODB_OLD_PDB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
			if [[ $J -gt 50 ]];then
				CHECK_ENERGY
				echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
				break
			fi
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
			GET_RESIDUALS
			echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
#			get the residual density running tonto once, only needed if not using tonto for the scf			
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

export MAIN_DIALOG='

	<window window_position="1" title="lamaGOET">

	 <vbox scrollable="true" space-expand="true" space-fill="true" height="600" width="850" >
	
	  <hbox homogeneous="True" >
	
	    <hbox homogeneous="True">
	     <frame>
	      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>Welcome to the interface for Hirshfeld Atom fit and Gaussian/Orca/Elmodb</span>"</label></text>
	      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>(You need to have coreutils installed on your machine to use this script)</span>"</label></text>
	      <pixmap>
	       <width>40</width>
	       <height>40</height>
	       <input file>/usr/local/include/Tonto_logo.png</input>
	      </pixmap>
	     </frame>  
	    </hbox>
	
	  </hbox>

  	 <notebook 
		tab-labels="Main|Advanced Settings|Total XWR|Tools|Elmodb advanced specific|Plots"
		xx-tab-labels="which will be shown on tabs"

		> 	  
         <vbox>       
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
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETECIF</action>
	        <action>if false disable:COMPLETECIF</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true enable:GAUSGEN</action>
	        <action>if false disable:GAUSGEN</action>
	        <action>if true enable:GAUSSREL</action>
	        <action>if false disable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
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
	        <action>if true disable:GAMESS</action>
	        <action>if false enable:BASISSETDIR</action>
	        <action>if true disable:BASISSETT</action>
	        <action>if false enable:BASISSETT</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETECIF</action>
	        <action>if false disable:COMPLETECIF</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true disable:GAUSGEN</action>
	        <action>if false enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if false enable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
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
	        <action>if true disable:GAMESS</action>
	        <action>if true disable:MEM</action>
	        <action>if true disable:NUMPROC</action>
	        <action>if false enable:MEM</action>
	        <action>if false enable:NUMPROC</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETECIF</action>
	        <action>if false disable:COMPLETECIF</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true disable:GAUSGEN</action>
	        <action>if false enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if false enable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
	      </radiobutton>
	      <radiobutton space-fill="True"  space-expand="True">
	        <label>elmodb</label>
	        <default>false</default>
	        <action>if true echo 'SCFCALCPROG="elmodb"'</action>
	        <action>if true enable:NTAIL</action>
	        <action>if false disable:NTAIL</action>
	        <action>if true enable:MEM</action>
	        <action>if true enable:NUMPROC</action>
	        <action>if true enable:SCFCALC_BIN</action>
	        <action>if true enable:BASISSETDIR</action>
	        <action>if false disable:MEM</action>
	        <action>if false disable:NUMPROC</action>
	        <action>if false disable:SCFCALC_BIN</action>
	        <action>if false disable:BASISSETDIR</action>
	        <action>if true disable:BASISSETT</action>
	        <action>if false enable:BASISSETT</action>
	        <action>if true disable:SCCHARGES</action>
	        <action>if false enable:SCCHARGES</action>
	        <action>if true enable:ELMOLIB</action>
	        <action>if false disable:ELMOLIB</action>
	        <action>if true disable:XHALONG</action>
	        <action>if false enable:XHALONG</action>
	        <action>if true disable:COMPLETECIF</action>
	        <action>if false enable:COMPLETECIF</action>
	        <action>if true enable:USEGAMESS</action>
	        <action>if false disable:USEGAMESS</action>
	        <action>if true disable:GAUSGEN</action>
	        <action>if false enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if false enable:GAUSSREL</action>
	        <action>if true enable:MANUALRESIDUE</action>
	        <action>if false disable:MANUALRESIDUE</action>
	        <action>if true enable:NSSBOND</action>
	        <action>if false disable:NSSBOND</action>
	        <action>if true enable:INITADP</action>
	        <action>if false disable:INITADP</action>
	      </radiobutton>

	   </hbox>
	
	    <checkbox active="false" space-fill="True"  space-expand="True" sensitive="false">
	     <label>Use Gamess for calculation of overlap integrals</label>
	      <variable>USEGAMESS</variable>
	        <action>if true enable:GAMESS</action>
	        <action>if false disable:GAMESS</action>
	    </checkbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="Tonto executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
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
	    <text label="Gaussian, Orca or elmodb executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
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
	    <text label="gamess_int executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
	    <entry sensitive="false" fs-action="file" fs-folder="./"
	           fs-filters="gamess_int"
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
	    <text label="basis sets directory" ></text>
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
	    <text use-markup="true" wrap="false"><label>Job name(one word)</label></text>
	    <entry>
	     <default>my_job</default>
	     <variable>JOBNAME</variable>
	    </entry>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="cif or pdb file" has-tooltip="true" tooltip-markup="ONLY use pdb file if you are using elmodb!!!" space-expand="false"></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-filters="*.cif|*.pdb"
	           fs-title="Select a cif or pdb file">
	     <variable>CIF</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">CIF</action>
	    </button>
	
	    <checkbox active="false" has-tooltip="true" tooltip-markup="Make sure you will enter the correct charge and multiplicity" space-fill="True"  space-expand="True" sensitive="true">
	     <label>Complete molecule(s) in the cif </label>
	      <variable>COMPLETECIF</variable>
	    </checkbox>
	
	   </hbox>
	
	   <hseparator></hseparator>

	   <hbox>

	    <checkbox active="false" has-tooltip="true" tooltip-markup="Make sure you will enter the correct charge and multiplicity" space-fill="True"  space-expand="True" sensitive="false">
	     <label>Load initial ADPs from cif</label>
	      <variable>INITADP</variable>
	        <action>if true enable:INITADPFILE</action>
	        <action>if false disable:INITADPFILE</action>
	    </checkbox>

	    <text label="cif file" has-tooltip="true" tooltip-markup="This should have the same geometry as the pdb file!!!" space-expand="false"></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-filters="*.cif"
	           fs-title="Select a cif file" sensitive="false">
	     <variable>INITADPFILE</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">INITADPFILE</action>
	    </button>
	
	
	   </hbox>

	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="hkl file" space-expand="false" ></text>
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
	    <text use-markup="true" wrap="TRUE" space-expand="false"><label>Wavelenght (in Angstrom)</label></text>
	    <entry>
	     <default>0.71073</default>
	     <variable>WAVE</variable>
	    </entry>
	
	    <text use-markup="true" wrap="TRUE" space-expand="FALSE"><label>F/sigma cutoff</label></text>
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
	    <combobox allow-empty="true" has-tooltip="true" tooltip-markup="'"'rhf'"' - Restricted Hartree-Fock, 
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
	     <item>b3lyp</item>
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

	    <checkbox active="false" space-fill="True"  space-expand="True">
	     <label>Input external basis set manualy </label>
	      <variable>GAUSGEN</variable>
	      <action>if true disable:BASISSET</action>
	      <action>if false enable:BASISSET</action>
	    </checkbox>

	    <checkbox active="false" space-fill="True"  space-expand="True">
	     <label>Use relativistic method </label>
	      <variable>GAUSSREL</variable>
	    </checkbox>

	   </hbox>

	   <hseparator></hseparator>
	
	   <hbox>
	
	    <text><label>Enter manually for Gaussian, Orca or elmodb!</label> </text>
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
           
           <hbox>
	    <checkbox active="false" space-fill="True"  space-expand="True">
	        <label>Refine nothing for atoms:</label>
	        <default>true</default>
	        <variable>REFNOTHING</variable>
	        <action>if true enable:ATOMLIST</action>
	        <action>if false disable:ATOMLIST</action>
	    </checkbox>
	    <text use-markup="true" wrap="false" ><label>atom labels:</label></text>
	    <entry sensitive="false">
	     <variable>ATOMLIST</variable>
	    </entry>
           </hbox>
	
	   <hseparator></hseparator>

           <hbox>
	    <checkbox active="false" space-fill="True"  space-expand="True">
	        <label>Refine these atoms isotropically:</label>
	        <default>true</default>
	        <variable>REFUISO</variable>
	        <action>if true enable:ATOMUISOLIST</action>
	        <action>if false disable:ATOMUISOLIST</action>
	    </checkbox>
	    <text use-markup="true" wrap="false" ><label>atom labels:</label></text>
	    <entry sensitive="false">
	     <variable>ATOMUISOLIST</variable>
	    </entry>
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

	    <checkbox sensitive="true" space-fill="True"  space-expand="True">
	     <label>Refine anharmonic ADPs</label>
	      <variable>REFANHARM</variable>
	      <action>if true enable:ANHARMATOMS</action>
	      <action>if false disable:ANHARMATOMS</action>
	      <action>if true enable:THIRDORD</action>
	      <action>if false disable:THIRDORD</action>
	      <action>if true enable:FOURTHORD</action>
	      <action>if false disable:FOURTHORD</action>
	    </checkbox>
	
	    <text use-markup="true" wrap="false"  ><label>Atom labels</label></text>
	    <entry has-tooltip="true" tooltip-markup="as in the cif" sensitive="false">
	     <variable>ANHARMATOMS</variable>
	    </entry>
	
	    <checkbox sensitive="false">
	     <label>3rd Order</label>
	     <default>false</default>
	      <variable>THIRDORD</variable>
	    </checkbox>

	    <checkbox sensitive="false">
	     <label>4rd Order</label>
	     <default>false</default>
	      <variable>FOURTHORD</variable>
	    </checkbox>
	   </hbox>
	
	
	   <hseparator></hseparator>
	
	   <hbox>
	
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
	     <label>Elongate X-H bond lengths ?</label>
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
	    <text xalign="0" use-markup="true" wrap="false"><label>Apply dispersion corrections?</label></text>
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
	    <text xalign="0" use-markup="true" has-tooltip="true" tooltip-markup="(including the unit mb or gb. For elmodb only in mb without unit!)" wrap="false"><label>Memory available for the Gaussian, Orca or elmodb job</label></text>
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
         <vbox>
 
	  <frame>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Conv. tol. for shift on esd</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
	     <default>0.010000</default>
	     <variable>CONVTOL</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Max. number of iteration (for each L.S. cicle):</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
	     <variable>MAXLSCICLE</variable>
	    </entry>
	
	   </hbox>
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

	  </frame>
         </vbox>

	 <vbox visible="false">
	  <frame>
   	  <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>How many lambda values would you like to use?</label></text>
	    <spinbutton  range-min="1"  range-max="100" space-fill="True"  space-expand="True">
		<default>1</default>
		<variable>LAMBDA</variable>
	    </spinbutton>
	   </hbox>
 
	  </frame>
	 </vbox>

	 <vbox visible="false">
	  <frame>
   	  <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>How many lambda values would you like to use?</label></text>
	    <spinbutton  range-min="1"  range-max="100" space-fill="True"  space-expand="True">
		<default>1</default>
		<variable>LAMBDA</variable>
	    </spinbutton>
	   </hbox>
 
	  </frame>
	 </vbox>

	 <vbox visible="true">
	  <frame>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Number of dissulfide bonds:</label></text>
           <spinbutton  range-min="0"  range-max="1000" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $NSSBOND ]; then echo "$NSSBOND"; else (echo "0"); fi</input>
	    <variable>NSSBOND</variable>
	    <action condition="command_is_true( [ $NSSBOND -gt 0 ] && echo true )">enable:SSBONDATOMS</action>
	    <action condition="command_is_false( [ $NSSBOND -eq 0 ] && echo false )">disable:SSBONDATOMS</action>
	   </spinbutton>
	   </hbox>

	   <hbox>
	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Enter the residue information manually:</label></text>
 	    <edit space-expand="true" space-fill="true" sensitive="false">
	    <action condition="command_is_true( [ $NSSBOND -gt 0 ] && echo true )">enable:SSBONDATOMS</action>
	    <action condition="command_is_false( [ $NSSBOND -eq 0 ] && echo false )">disable:SSBONDATOMS</action>
             <default>"
   3  40
   4  32
  16  26"</default>
             <variable>SSBONDATOMS</variable>
      	     <width>350</width><height>150</height>
             <action  condition="file_is_false(ntail.txt)">touch ntail.txt</action>
    	    </edit>
	   </hbox>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Enter number of tailor made residues:</label></text>
           <spinbutton  range-min="0"  range-max="100" space-fill="True"  space-expand="True" sensitive="false">
	    <default>0</default>
	    <variable>NTAIL</variable>
	      <action condition="command_is_true( [ $NTAIL -gt 0 ] && echo true )">enable:ATAIL</action>
	      <action condition="command_is_false( [ $NTAIL -eq 0 ] && echo false )">disable:ATAIL</action>
	      <action condition="command_is_true( [ $FRTAIL -gt 0 ] && echo true )">enable:FRTAIL</action>
	      <action condition="command_is_false( [ $FRTAIL -eq 0 ] && echo false )">disable:FRTAIL</action>
	   </spinbutton>
	   </hbox>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Enter number of tailor made residues:</label></text>
           <spinbutton  range-min="0"  range-max="1000" space-fill="True"  space-expand="True" sensitive="false">
	    <default>100</default>
	    <variable>ATAIL</variable>
	   </spinbutton>
	   </hbox>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Enter number of tailor made residues:</label></text>
           <spinbutton  range-min="0"  range-max="1000" space-fill="True"  space-expand="True" sensitive="false">
	    <default>200</default>
	    <variable>FRTAIL</variable>
	   </spinbutton>
	   </hbox>

	   <hbox>
	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Enter the residue information manually:</label></text>
 	    <edit space-expand="true" space-fill="true" sensitive="false">
             <default>
" 
ALE   0   17  .t.        !Input for the first tailor-made residue 
		
CA        1    1   .f.     N   CA  C     
N         1    1   .f.     CA  N   H1     
C         1    1   .f.     CA  C   O     
O         3    1   .f.     C   O   OXT     
OXT       3    1   .f.     C   OXT O
CB        1    1   .f.     CA  CB  HB1   
CA_HA     1    2   .f.     CA  HA  C    
CA_N      1    2   .f.     CA  N   HA     
N_H1      1    2   .f.     N   H1  CA
N_H2      1    2   .f.     N   H2  CA
N_H3      1    2   .f.     N   H3  CA  
CA_C      1    2   .f.     CA  C   O     
C_O_OXT   4    3   .f.     C   O   OXT      
CA_CB     1    2   .f.     CA  CB  C    
CB_HB1    1    2   .f.     CB  HB1 CA   
CB_HB2    1    2   .f.     CB  HB2 CA   
CB_HB3    1    2   .f.     CB  HB3 CA 
 "
             </default>
	     <variable>MANUALRESIDUE</variable>
      	     <width>350</width><height>350</height>
             <action  condition="file_is_false(ntail.txt)">touch ntail.txt</action>
    	    </edit>
	   </hbox>
 
	  </frame>
	 </vbox>

	 <vbox visible="true">
	  <frame>

	   <hbox>
	
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" >
	     <label>Only plot properties from Tonto restricted files</label>
	     <variable>PLOT_TONTO</variable>		
	     <default>false</default>
	     <action>if true enable:DEFDEN</action>
	     <action>if true enable:DFTXCPOT</action>
	     <action>if true enable:DENS</action>
	     <action>if true enable:LAPL</action>
	     <action>if true enable:NEGLAPL</action>
	     <action>if true enable:PROMOL</action>
	     <action>if true enable:RESDENS</action>
	     <action>if false disable:DEFDEN</action>
	     <action>if false disable:DFTXCPOT</action>
	     <action>if false disable:DENS</action>
	     <action>if false disable:LAPL</action>
	     <action>if false disable:NEGLAPL</action>
	     <action>if false disable:PROMOL</action>
	     <action>if false disable:RESDENS</action>
	    </checkbox>
	   </hbox> 

	   <hbox>
	    <text xalign="0" use-markup="true" wrap="true"justify="1" space-fill="True"  space-expand="True"><label>Please select the property to plot:</label></text>
	   </hbox> 

	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>deformation_density</label>
	     <variable>DEFDEN</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>dft_xc_potential</label>
	     <variable>DFTXCPOT</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>electron_density</label>
	     <variable>DENS</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>laplacian</label>
	     <variable>LAPL</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>negative_laplacian</label>
	     <variable>NEGLAPL</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>promolecule_density</label>
	     <variable>PROMOL</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 

	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>residual_density_map</label>
	     <variable>RESDENS</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 

	   <hseparator></hseparator>

	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True">
  	     <label>Cube file in Angstroms</label>
	     <variable>PLOT_ANGS</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	  <hbox space-expand="false" space-fill="false">
	   <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Desired point separation (in Angstrom)</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
	     <variable>SEPARATION</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  <hbox space-expand="false" space-fill="false">
	   <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Or number of points in X, Y and Z (in Angstrom)</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
	     <default>10</default>
	     <variable>PTSX</variable>
	    </entry>
	    <entry space-expand="true">
	     <default>10</default>
	     <variable>PTSY</variable>
	    </entry>
	    <entry space-expand="true">
	     <default>10</default>
	     <variable>PTSZ</variable>
	    </entry>
	   </hbox>
	   </hbox>
	  </frame>
	 </vbox>

	 </notebook>
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

#checking if job_options file exists for tests
if [ -f job_options.txt  ]; then
	source job_options.txt
	if [[ "$TESTS" != "true" ]]; then
		gtkdialog --program=MAIN_DIALOG > job_options.txt
	else
		if [[ "$SCFCALCPROG" == "elmodb" && "$EXIT" == "OK" ]]; then
			PDB=$( echo $CIF | awk -F "/" '{print $NF}' ) 
		fi
	fi
else
	gtkdialog --program=MAIN_DIALOG > job_options.txt
fi

source job_options.txt
#rm job_options.txt
echo "" > $JOBNAME.lst
if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG="Gaussian"
	echo "SCFCALCPROG=\"$SCFCALCPROG\"" >> job_options.txt
fi


if [ "$GAUSGEN" = "true" ]; then
    BASISSET="gen"
    zenity --entry --title="New basis set" --text="Enter or paste the basis set in the gaussian format as: \n !!NO EMPTY LINE!! \n C 0 \n S 5 \n exponent1 coefficient1 \n exponent2 coefficient2 \n exponent3 coefficient3 \n exponent4 coefficient4 \n exponent5 coefficient5 \n **** \n !!NO EMPTY LINE!! \n (Repeat this for all shells and all elements) " > basis_gen.txt
    sed -i '/BASISSET=/c\BASISSET=\".\/'$BASISSET'"' job_options.txt
fi

if [ "$GAUSSREL" = "true" ]; then
    INT="int=dkh"
    echo "INT=\"$INT\"" >> job_options.txt
fi

if [[ "$DISP" = "yes" && "$EXIT" = "OK" ]]; then
	zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	while [ $? -eq 1 ]; do 
		zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	done
fi

if [[ "$SCFCALCPROG" == "elmodb" && "$EXIT" == "OK" ]]; then
	if [[ ! -f "$( echo $CIF | awk -F "/" '{print $NF}' )" ]]; then
		cp $CIF .
	fi
	PDB=$( echo $CIF | awk -F "/" '{print $NF}' ) 
	echo "PDB=\"$PDB\"" >> job_options.txt
	if [[ ! -f "tonto.cell" ]]; then
		#extracting information from pdb file into new jobname.pdb file (only for elmodb)
		# is tehre a cell in the pdb?
		if [[ ! -z $(awk '$1 ~ /CRYST1/ {print $0}'  $PDB) ]]; then
			CELLA=$(awk '$1 ~ /CRYST1/ {print $2}'  $PDB)
			CELLB=$(awk '$1 ~ /CRYST1/ {print $3}'  $PDB)
			CELLC=$(awk '$1 ~ /CRYST1/ {print $4}'  $PDB)
			CELLALPHA=$(awk '$1 ~ /CRYST1/ {print $5}'  $PDB)
			CELLBETA=$(awk '$1 ~ /CRYST1/ {print $6}'  $PDB)
			CELLGAMMA=$(awk '$1 ~ /CRYST1/ {print $7}'  $PDB)
			SPACEGROUP=$(awk '$1 ~ /CRYST1/ {print $0}' $PDB | awk ' {print substr($0,index($0,$8),--NF)}')
#####this one works with mac and linux
#awk '$1 ~ /CRYST1/ {print $0}' 1ejg.pdb | awk ' {print substr($0,index($0,$8),--NF)}'
# this one works on linux but not on mac!
#awk '$1 ~ /CRYST1/ {print $0}' 1ejg.pdb | awk '{print substr($0,index($0,$8))}' | awk 'NF{NF-=1};1'
# falta verificar se é vazio la em baixo
	  		echo "      spacegroup= { hermann_mauguin_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		else
			SPACEGROUP
			CELLA=$(awk -F'|' '{print $1}'  crystal_data.txt )
			CELLB=$(awk -F'|' '{print $2}'  crystal_data.txt )
			CELLC=$(awk -F'|' '{print $3}'  crystal_data.txt )
			CELLALPHA=$(awk -F'|' '{print $4}'  crystal_data.txt )
			CELLBETA=$(awk -F'|' '{print $5}'  crystal_data.txt )
			CELLGAMMA=$(awk -F'|' '{print $6}'  crystal_data.txt )
			SPACEGROUP=$(cat spacegroup.txt | awk -F'=' '{print $3}' )
			rm spacegroup.txt
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
		# are there more lines in the pdb then the ATOM lines?
		if [[ ! -z $(awk '$1 !~ /ATOM/ && ! /HETATM/ && ! /END/ {print $0}'  $PDB) ]]  ; then
			awk '$1 ~ /ATOM/ {print $0}'  $PDB > $JOBNAME.cut.pdb
			awk '$1 ~ /HETATM/ {print $0}'  $PDB > $JOBNAME.cut.pdb
			echo "END" >> $JOBNAME.cut.pdb
			if [[ ! -z $(diff -ZB $PDB $JOBNAME.cut.pdb) ]]; then
				PDB=$JOBNAME.cut.pdb	
			fi
		fi
	fi
fi

#	gtkdialog --program=dispersion_coef > DISP_instructions.txt

if [ "$EXIT" = "OK" ]; then
        tail -f $JOBNAME.lst | zenity --title "Job output file - this file will auto-update, scroll down to see later results." --no-wrap --text-info --width 1024 --height 800 --font='DejaVu Sans Mono' &
#	zenity --title="Tonto job status" --text-info --no-wrap --filename=$JOBNAME.lst &
	run_script
else
	unset MAIN_DIALOG
	clear
	exit 0
fi

