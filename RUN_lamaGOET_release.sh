#!/bin/bash
export LC_NUMERIC="en_US.UTF-8"

UPDATE_FILES_FOR_POWDER(){
# atomic projection cycle #use this name 
# electron density cycle
# profile cycle

mkdir $ED_COUNTER.atomic_projection_cycle
if [ "$ED_COUNTER" = "0" ]; then
        cp $HKL $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.hkl
else
        cp $JOBNAME.hkl $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.hkl
fi
cp $JOBNAME.m40 $PROFILE_COUNTER.profile_cycle/$PROFILE_COUNTER.$JOBNAME.m40

awk '
   !/^[[:space:]]/
   ' $JOBNAME.m40 | awk '
   {if (substr($1,1,1) ~ /^[A-Z]/) print $0}
   ' | awk '
   {if (NF>5) print $0}
' > find_lines

awk '
   !/^[[:space:]]/' $JOBNAME.m40 | awk '
   {if (substr($1,1,1) ~ /^[A-Z]/) print $0}
   ' | awk '
   {if (NF>5) printf "%-9s %2i %2i %2i %s \n", $1, $2, $3, $4, substr($5,1,8)}
' > new

sed -n '
   /# Precise fractional system coordinates/,/# Fractional coordinates/p
' $JOBNAME.archive.cif | awk '
   /^[[:space:]]/
   ' > cut_cif

sed -n '
   /# Precise cartesian axis system ADPs/,/# ADPs/p
' $JOBNAME.archive.cif | awk '
   /^[[:space:]]/
   ' > cut_cif_ADPs

sed -n '
   /# Precise fractional system coordinates/,/# Fractional coordinates/p
' $JOBNAME.archive.cif | awk '
   /^[[:space:]]/
   ' > cut_cif_errors

gawk '
   {if (substr($1,1,1) ~ /^[A-Z]/)
   {
   strtonum($2)
   strtonum($3)
   strtonum($4)
   printf "%8.6f %8.6f %8.6f %s\n", $2, $3, $4, $6
   }
}' cut_cif > new_xyz

#   {if ((substr($1,1,1) ~ /^[0-9]/) || (substr($1,1,1) ~ /^-/) ) 

gawk '
   {if (substr($1,1,1) ~ /^[A-Z]/)
   {
   strtonum($2)
   strtonum($3)
   strtonum($4)
   strtonum($5)
   strtonum($6)
   strtonum($7)
   printf " %8.6f%9.6f%9.6f%9.6f%9.6f%9.6f%s\n", $2, $3, $4, $5, $6, $7,"      0000000000"
   }
}' cut_cif_ADPs > new_ADPs

gawk ' 
   {if (substr($1,1,1) ~ /^[0-9]/)
   {
   strtonum($2)
   strtonum($3)
   strtonum($4)
   printf "%8.6f %8.6f %8.6f %s\n", $1, $3, $4, $6
   }
}' cut_cif_errors > new_xyz_errors

rm cut_cif cut_cif_errors cut_cif_ADPs

paste <(awk '{print $0}' new) <(awk '{print $0}' new_xyz) > merged

paste <(awk '{print $1, "0.000000"}
   ' new) <(awk '{print $0}
   ' new_xyz_errors) > merged_errors

rm new new_xyz new_xyz_errors 

gawk '{
   strtonum($5)
   strtonum($6)
   strtonum($7)
   strtonum($8)
   printf "%-10s%-3i%-3i%-3i%-8.6f%9.6f%9.6f%9.6f\n", 
   $1, $2, $3, $4, $5, $6, $7, $8
}' merged > almost

gawk '{
   strtonum($2)
   strtonum($3)
   strtonum($4)
   strtonum($5)
   printf "%-19s %8.6f %8.6f %8.6f %8.6f\n", 
   $1, $2, $3, $4, $5
}' merged_errors > almost_errors

rm merged merged_errors

NUM_LINES=$(wc -l < almost)

sed -n '
   /s.u. block/,$p
' $JOBNAME.m40 > cut_m40

for ((I=1;I<=$NUM_LINES;++I))
#for I in 1$NUM_LINES
do
   FIND_STRIG=$(awk -v I="$I" -F, 'FNR==I{print $0}' find_lines )
   LINE_STRIG=$(awk -v I="$I" -F, 'FNR==I{print $0}' almost )
   SU_ATOM=$(awk -v I="$I" -F, 'FNR==I{print $1}' find_lines )
   FIND_ERROR=$(awk -v SU_ATOM="$SU_ATOM" -F FNR==NR, '{if ($1=SU_ATOM)
   print $0
   }' cut_m40)
   REP_ERROR=$(awk -v I="$I" -F, 'FNR==I{print $0}' almost_errors)
   sed "s:$FIND_STRIG:$LINE_STRIG:g" $1 > temp

   ADPs_LINE_M40=$(grep -n "$FIND_STRIG" $1 | awk -F: ' {print $1}')
   ADPs_LINE_M40=$[ $ADPs_LINE_M40 + 1]
   NEW_ADP=$(awk -v I="$I" 'FNR==I{print $0}' new_ADPs )
#   awk -v J="$ADPs_LINE_M40" 'FNR==J{ sub($0, "$NEW_ADP" ) }' $1
#   sed '$ADPs_LINE_M40 s:$NEW_ADP:' $1 > $1_out
   awk -v J="$ADPs_LINE_M40" -v ADP="$NEW_ADP" 'FNR==J {$0=ADP} {
   print }' temp > temp2


#  awk -v FIND_STRIG="$FIND_STRIG" -F, '
#  {a[NR]=$0}/^FIND_STRIG/{b=NR+1}END{
#  FNR==b{sub($0, "$(awk -v I="$I" -F, 'FNR==I{print $0}' new_ADPs )" ) } }' $1
   mv temp2 $JOBNAME.m40
   fromdos $JOBNAME.m40
#  sed -i "/\$SU_ATOM/c\\$REP_ERROR" cut_m40 > temp_errors
#  sed "s:$FIND_ERROR:$REP_ERROR:g" cut_m40 > temp_errors

done

rm find_lines almost almost_errors new_ADPs cut_m40 temp temp_errors

cp $JOBNAME.m41 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m41
cp $JOBNAME.m50 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m50
cp $JOBNAME.m70 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m70
cp $JOBNAME.m80 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m80
cp $JOBNAME.m83 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m83
cp $JOBNAME.m85 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m85
cp $JOBNAME.m90 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m90
cp $JOBNAME.m95 $ED_COUNTER.atomic_projection_cycle/$ED_COUNTER.$JOBNAME.m95

python3 hklfromm80.py 
python3 projectioninputfromhar.py

ED_COUNTER=$[$ED_COUNTER+1]
PROFILE_COUNTER=$[$PROFILE_COUNTER+1]

}

GAMESS_ELMODB_OLD_PDB(){
	I=$[ $I + 1 ]
	PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
	echo "title" > $JOBNAME.gamess.inp
	echo "prova $JOBNAME - $BASISSETG - closed shell SCF" >> $JOBNAME.gamess.inp
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
	rm atoms 
	rm atoms_Z 
	rm full
	rm atoms_names
	echo "end" >> $JOBNAME.gamess.inp
	case "6-31g(d,p)" in
	 $BASISSETG ) echo "basis 6-31G**" >> $JOBNAME.gamess.inp;;
	 *) 	case "6-311g(d,p)" in
		 $BASISSETG ) echo "basis 6-311G**" >> $JOBNAME.gamess.inp;;
		 *)	echo "basis $BASISSETG" >> $JOBNAME.gamess.inp;;
		esac;;
	esac
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
		if [[ ! -f "$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' )" ]]; then
			cp $SCFCALC_BIN .
		fi
	
		if [ "$I" = "1" ]; then
			BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
			ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
#this is correct but until the elmo problem is solved I will keep it commented
#			if [[ "$INITADP" == "true" ]];then
#				echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#			else
				echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#			fi
#			if [[ "$INITADP" == "true" ]];then
#				echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$INITADPFILE' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#			else
				echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#			fi
			if [[ "$NTAIL" != "0" ]]; then
				echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
			fi
			if [[ "$NSSBOND" != "0" ]]; then
				echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
			fi			
		else 
#there is a problem with the conversion from fractional to cartesian inside the elmodb program, saving example files in the aga folder 4cut and changing back to always use the xyz. The elmo cannot read the cartesian cif
#			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
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
}

ELMODB(){
	I=$[ $I + 1 ]
	if [[ ! -f "$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' )" ]]; then
		cp $SCFCALC_BIN .
	fi
	if [ "$I" = "1" ]; then
		BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
		ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
#this is correct but until the elmo problem is solved I will keep it commented
#		if [[ "$INITADP" == "true" ]];then
#			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#		else
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#		fi
#		if [[ "$INITADP" == "true" ]];then
#			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$INITADPFILE' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#		else
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#		fi
		if [[ "$NTAIL" != "0" ]]; then
			echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
		fi
		if [[ "$NSSBOND" != "0" ]]; then
			echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
		fi
	else 
#there is a problem with the conversion from fractional to cartesian inside the elmodb program, saving example files in the aga folder 4cut and changing back to always use the xyz. The elmo cannot read the cartesian cif
#		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		if [[ "$NTAIL" != "0" ]]; then
#			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$JOBNAME.fractional.cif1' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
		else
#			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$JOBNAME.fractional.cif1' nssbond=$NSSBOND "'$END'"  " >>
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
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
		mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
		cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
		cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
		cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
		if [ "$I" != "1" ]; then
			cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
		fi
	fi
}

TONTO_TO_ORCA(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for Orca cycle number $I"
	if [ "$METHOD" = "rks" ]; then
		echo "! blyp $BASISSETG" > $JOBNAME.inp
	else
		if [ "$METHOD" = "uks" ]; then
			echo "! ublyp $BASISSETG" > $JOBNAME.inp
		else
			echo "! $METHOD $BASISSETG" > $JOBNAME.inp
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
#                if [ ! -f gaussian-point-charges ]; then
#                	echo "" > gaussian-point-charges
#                	awk '/Cluster monopole charges and positions/{print p; f=1} {p=$0} /------------------------------------------------------------------------/{c=1} f; c--==0{f=0}' stdout >> gaussian-point-charges
#                	awk '{a[NR]=$0}{b=11}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.inp
#                        echo "" >> $JOBNAME.inp
#                else
                	awk '{a[NR]=$0}{b=12}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.inp
                        echo "" >> $JOBNAME.inp
#                fi
#                rm gaussian-point-charges
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

TONTO_HEADER(){
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
}

READ_ELMO_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
	echo "   read_g09_fchk_file $JOBNAME.fchk" >> stdin
        echo "" >> stdin
}

READ_GAUSSIAN_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
	echo "   read_g09_fchk_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk" >> stdin
        echo "" >> stdin
}

READ_ORCA_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
	echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
        echo "" >> stdin
}

DEFINE_JOB_NAME(){
	echo "   name= $JOBNAME" >> stdin
        echo "" >> stdin
}

CHANGE_JOB_NAME(){
	echo "   name= $JOBNAME.XCW" >> stdin
        echo "" >> stdin
}

PROCESS_CIF(){
	echo "   ! Process the CIF" >> stdin
	echo "   CIF= {" >> stdin
	if [ $J = 0 ]; then 
		if [[ "$COMPLETESTRUCT" == "true" && "$SCFCALCPROG" != "Tonto" ]]; then
			echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
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
	elif [ $J = 1 ]; then 
		if [[ "$SCCHARGES" == "true" && ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca") ]]; then
#			if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" ]]; then
				if [[ "$COMPLETESTRUCT" == "true" ]]; then
					echo "       file_name= 0.tonto_cycle.$JOBNAME/0.$JOBNAME.cartesian.cif2" >> stdin
				else
					echo "       file_name= $CIF" >> stdin
				fi
		else
			echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
		fi
	else
		echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
	fi
	echo "    }" >> stdin
	echo "" >> stdin
	echo "   process_CIF" >> stdin
	echo "" >> stdin
}

TONTO_BASIS_SET(){
	echo "   basis_directory= $BASISSETDIR" >> stdin
	echo "   basis_name= $BASISSETT" >> stdin
	echo "" >> stdin
}

DISPERSION_COEF(){
	echo "   	 dispersion_coefficients= {" >> stdin
	echo "   	 $(cat DISP_inst.txt)" >> stdin
	echo "   	 }" >> stdin
	echo "" >> stdin
}

CHARGE_MULT(){
	echo "   charge= $CHARGE" >> stdin       
	echo "   multiplicity= $MULTIPLICITY" >> stdin
        echo "" >> stdin
}

TONTO_IAM_BLOCK(){
	echo ""
	echo "   crystal= {    " >> stdin
	if [[ "$SCFCALCPROG" = "elmodb" && "$INITADP" == "false" ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
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
	if [[ "$MINCORCOEF" != "" ]]; then
		echo "         min_correlation= $MINCORCOEF"  >> stdin
	fi
	echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
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
}

CRYSTAL_BLOCK(){
	echo "" >> stdin
	echo "   crystal= {    " >> stdin
	if [[ "$SCFCALCPROG" == "elmodb" && $J == 0 && "$INITADP" == "false" ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
	if [[ "$SCFCALCPROG" == "optgaussian" ]]; then 
		echo "      REDIRECT tonto.cell" >> stdin
	fi
	if [[ "$SCFCALCPROG" != "optgaussian" ]]; then 
		echo "      xray_data= {   " >> stdin
		echo "         thermal_smearing_model= hirshfeld" >> stdin
		echo "         partition_model= mulliken" >> stdin
		if [[ "$PLOT_TONTO" == "false" ]]; then
			echo "         optimise_extinction= false" >> stdin
			echo "         correct_dispersion= $DISP" >> stdin
			echo "         optimise_scale_factor= true" >> stdin
		fi
		echo "         wavelength= $WAVE Angstrom" >> stdin
		if [[ "$REFANHARM" == "true" && "$PLOT_TONTO" == "false" ]]; then
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
		if [[ "$PLOT_TONTO" == "false" ]]; then
			if [ "$MINCORCOEF" != "" ]; then
				echo "         min_correlation= $MINCORCOEF"  >> stdin
			fi
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
			if [[ "$MAXLSCYCLE" != "" ]]; then
				echo "	 max_iterations= $MAXLSCYCLE" >> stdin 
			fi
		fi
		echo "      }  " >> stdin
	fi
	echo "   }  " >> stdin
	echo "" >> stdin
}

SET_H_ISO(){ 
	echo "	 set_isotropic_h_adps"  >> stdin
	echo "" >> stdin
}

PUT_GEOM(){
	echo "   ! Geometry    " >> stdin
	echo "   put" >> stdin
	echo "" >> stdin
}

BECKE_GRID(){
		echo "   !Tight grid" >> stdin
		echo "   becke_grid = {" >> stdin
		echo "      set_defaults" >> stdin
		echo "      accuracy= $ACCURACY" >> stdin
		echo "      pruning_scheme= $BECKEPRUNINGSCHEME" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
}

SCF_BLOCK_NOT_TONTO(){
	if [[ "$SCCHARGES" == "true" && "$SCFCALCPROG" != "elmodb" ]]; then 
		echo "     ! SC cluster charge SCF" >> stdin
		echo "      scfdata= {" >> stdin
		echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
#		echo "      initial_MOs= existing" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
			echo "      kind= rks " >> stdin
			echo "      output= true " >> stdin
			echo "      dft_exchange_functional= b3lypgx" >> stdin
			echo "      dft_correlation_functional= b3lypgc" >> stdin
		else
			echo "      kind= $METHOD" >> stdin
                        echo "      output= true " >> stdin
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
		echo "   make_hirshfeld_inputs" >> stdin
		echo "   make_fock_matrix" >> stdin
		echo "" >> stdin
		echo "   ! SC cluster charge SCF" >> stdin
		echo "   scfdata= {" >> stdin
		echo "      initial_density= promolecule" >> stdin
		echo "      initial_MOs= restricted " >> stdin # Only for new tonto may 2020
#		echo "      initial_MOs= existing" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
			echo "      kind= rks " >> stdin
			echo "      output= true " >> stdin
			echo "      dft_exchange_functional= b3lypgx" >> stdin
			echo "      dft_correlation_functional= b3lypgc" >> stdin
		else
			echo "      kind= $METHOD" >> stdin
			echo "      output= true " >> stdin
		fi
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
		echo "      put_cluster" >> stdin
		echo "      put_cluster_charges" >> stdin
		echo "" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		if [[ "$SCFCALCPROG" != "optgaussian" && "$J" != "0" ]]; then 
			echo "   ! Make Hirshfeld structure factors" >> stdin
			echo "   fit_hirshfeld_atoms" >> stdin
			echo "" >> stdin
		fi
		echo "   write_xyz_file" >> stdin
		if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
	else
		if [[ "$SCFCALCPROG" != "optgaussian" ]]; then 
			echo "   ! Make Hirshfeld structure factors" >> stdin
			echo "   fit_hirshfeld_atoms" >> stdin
			echo "" >> stdin
		fi
		echo "   write_xyz_file" >> stdin
		if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
	fi
}

SCF_BLOCK_PROM_TONTO(){
	echo "   ! Normal SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_density= promolecule " >> stdin
	echo "      kind= rhf" >> stdin   # this is the promolecule guess, should be always rhf
	echo "      output= true " >> stdin
	echo "      use_SC_cluster_charges= FALSE" >> stdin
	echo "      convergence= 0.001" >> stdin
	echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   scf" >> stdin
	echo "" >> stdin
}

SCF_BLOCK_REST_TONTO(){
	echo "   ! SC cluster charge SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_MOs= restricted" >> stdin
	if [[ "$METHOD" == "b3lyp" ]]; then
		echo "      kind= rks" >> stdin
	        echo "      output= true " >> stdin
		echo "      dft_exchange_functional= b3lypgx" >> stdin
		echo "      dft_correlation_functional= b3lypgc" >> stdin
	else 
		echo "      kind= $METHOD" >> stdin
	        echo "      output= true " >> stdin
	fi
	if [[ "$SCCHARGES" == "true" ]]; then 
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
	else
		echo "      use_SC_cluster_charges= FALSE" >> stdin
	fi
	if [[ "$PLOT_TONTO" == "false" ]]; then
		echo "      convergence= 0.001" >> stdin
		echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	fi
	echo "   }" >> stdin
	echo "" >> stdin
	if [[ "$XCWONLY" != "true" && "$PLOT_TONTO" == "false" ]]; then
		echo "   ! Make Hirshfeld structure factors" >> stdin
		echo "   refine_hirshfeld_atoms" >> stdin
		echo "" >> stdin
	fi
}

SCF_TO_TONTO(){
	TONTO_HEADER
	if [ "$SCFCALCPROG" = "elmodb" ]; then
		READ_ELMO_FCHK
	fi
	if [[ "$SCFCALCPROG" == "Gaussian" ||  "$SCFCALCPROG" == "optgaussian" ]]; then
		READ_GAUSSIAN_FCHK
	elif [ "$SCFCALCPROG" = "Orca" ]; then
		READ_ORCA_FCHK
	else
		DEFINE_JOB_NAME
	fi
	echo "" >> stdin
	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "optgaussian" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
	fi
	if [[ $J -gt 0 && "$SCFCALCPROG" == "elmodb" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
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
	fi
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
		TONTO_BASIS_SET
		if [[ "$COMPLETECIF" == "true"  ]]; then
			COMPLETECIFBLOCK
		fi
	fi
	if [[ "$DISP" == "yes" ]]; then 
		DISPERSION_COEF
	fi
		CHARGE_MULT
	if [[ $J == 0 && "$IAMTONTO" == "true" ]]; then 
		TONTO_IAM_BLOCK
	fi
	CRYSTAL_BLOCK
	if [[ "$HADP" == "yes" ]]; then 
		SET_H_ISO
	fi
		PUT_GEOM
	if [[ "$USEBECKE" == "true" ]]; then 
		BECKE_GRID
	fi
	if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
		SCF_BLOCK_NOT_TONTO
	fi
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then
		SCF_BLOCK_PROM_TONTO
		SCF_BLOCK_REST_TONTO
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
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then
		mkdir $J.tonto_cycle.$JOBNAME
		sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
		cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
		cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
		cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
		cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
		cp $JOBNAME.residual_density_map,cell.cube $J.tonto_cycle.$JOBNAME/$J.residual_density_map,cell.cube
	fi
	INITIALCHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $2}')
#	MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print shift}')
#	MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print atom}')
#	MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print param}')
	MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk '{ gsub("-","",$0); print $0 }' | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print shift}')
	MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk '{ gsub("-","",$0); print $0 }' | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print atom}')
	MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk '{ gsub("-","",$0); print $0 }' |awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print param}')
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
	fi
	if [[ "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" ]]; then 
		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t""    "$9" \t"$10 }' ) "  >> $JOBNAME.lst  
	fi
	if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
		mkdir $J.tonto_cycle.$JOBNAME
		cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
		if [[ "$SCFCALCPROG" != "optgaussian" ]]; then
	                if [ -f $JOBNAME.cartesian.cif2 ]; then
				sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
				cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
				cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
				cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
				cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
			fi
		fi
		if [[ "$SCFCALCPROG" != "elmodb" &&  "$SCCHARGES" == "true" ]]; then
			cp cluster_charges $J.tonto_cycle.$JOBNAME/$J.cluster_charges
#			cp gaussian-point-charges $J.tonto_cycle.$JOBNAME/$J.gaussian-point-charges
		fi
	fi
}

TONTO_TO_GAUSSIAN(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for Gaussian cycle number $I"
	echo "%rwf=./$JOBNAME.rwf" >> $JOBNAME.com
	echo "%int=./$JOBNAME.int" >> $JOBNAME.com
	echo "%NoSave" >> $JOBNAME.com
	echo "%chk=./$JOBNAME.chk" > $JOBNAME.com
	echo "%mem=$MEM" >> $JOBNAME.com
	echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
	if [ "$METHOD" = "rks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT blyp/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT blyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "uks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT ublyp/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT ublyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "rhf" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT rhf/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT rhf/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	else
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT $METHOD/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT $METHOD/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	fi
	echo "" >> $JOBNAME.com
	echo "$JOBNAME" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
	awk 'NR>2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	if [ "$SCCHARGES" = "true" ]; then 
#                if [ ! -f gaussian-point-charges ]; then
#                	echo "" > gaussian-point-charges
#                	awk '/Cluster monopole charges and positions/{print p; f=1} {p=$0} /------------------------------------------------------------------------/{c=1} f; c--==0{f=0}' stdout >> gaussian-point-charges
#                	awk '{a[NR]=$0}{b=11}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
#                        echo "" >> $JOBNAME.com
#                else
                	awk '{a[NR]=$0}{b=12}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                        echo "" >> $JOBNAME.com
#                fi
#                rm gaussian-point-charges
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
     	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
}

GET_FREQ(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Gaussian cycle number $I"
	echo "%rwf=./$JOBNAME.rwf" >> $JOBNAME.com
	echo "%int=./$JOBNAME.int" >> $JOBNAME.com
	echo "%NoSave" >> $JOBNAME.com
	echo "%chk=./$JOBNAME.chk" > $JOBNAME.com
	echo "%mem=$MEM" >> $JOBNAME.com
	echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
	#echo "# rb3lyp/$BASISSETG output=wfn" >> $JOBNAME.com
	if [ "$METHOD" = "rks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE blyp/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE blyp/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "uks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE ublyp/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE ublyp/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "rhf" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE rhf/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE rhf/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	else
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE $METHOD/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE $METHOD/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	fi
	echo "" >> $JOBNAME.com
	echo "$JOBNAME" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
        echo $J
	awk 'NR>2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	if [ "$SCCHARGES" = "true" ]; then 
#                if [ ! -f gaussian-point-charges ]; then
#                	echo "" > gaussian-point-charges
#                	awk '/Cluster monopole charges and positions/{print p; f=1} {p=$0} /------------------------------------------------------------------------/{c=1} f; c--==0{f=0}' stdout >> gaussian-point-charges
#                	awk '{a[NR]=$0}{b=11}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
#                        echo "" >> $JOBNAME.com
#                else
                	awk '{a[NR]=$0}{b=12}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                        echo "" >> $JOBNAME.com
#                fi
#                rm gaussian-point-charges
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
     	mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
}
CHECK_ENERGY(){
	if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then 
                ENERGIA2=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' | sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*HF=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
                RMSD2=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log | sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*RMSD=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
#		ENERGIA2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#		RMSD2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
		echo "Gaussian cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
	elif [ "$SCFCALCPROG" = "Orca" ]; then
		ENERGIA2=$(sed -n '/Total Energy       :/p' $JOBNAME.log | awk '{print $4}' | tr -d '\r')
		RMSD2=$(sed -n '/Last RMS-Density change/p' $JOBNAME.log | awk '{print $5}' | tr -d '\r')
		echo "Orca cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
	fi
		DE=$(awk "BEGIN {print $ENERGIA2 - $ENERGIA}")
		DE=$(printf '%.12f' $DE)
		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "    "$9" \t"$10 }' )  $ENERGIA2   $RMSD2   \t$DE"   >> $JOBNAME.lst  
		ENERGIA=$ENERGIA2
		RMSD=$RMSD2
		echo "Delta E (cycle  $I - $[ I - 1 ]): $DE "
}

CHECKCONV(){
FINALPARAMESD=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $5}')
}

GET_RESIDUALS(){
	TONTO_HEADER
	DEFINE_JOB_NAME
	if [ "$SCFCALCPROG" = "elmodb" ]; then
		READ_ELMO_FCHK
	fi
	if [ "$SCFCALCPROG" = "Gaussian" ]; then
		READ_GAUSSIAN_FCHK
	elif [ "$SCFCALCPROG" = "Orca" ]; then
		READ_ORCA_FCHK
	else
		DEFINE_JOB_NAME
	fi
	echo "" >> stdin
		PROCESS_CIF
		DEFINE_JOB_NAME
	if [ "$SCFCALCPROG" = "Tonto" ]; then 
		TONTO_BASIS_SET
	fi
	if [ "$DISP" = "yes" ]; then 
		DISPERSION_COEF
	fi
		CHARGE_MULT
		CRYSTAL_BLOCK
	echo "   scfdata= {" >> stdin
	echo "      initial_MOs= restricted" >> stdin  #Only for new tonto may 2020
#	echo "      initial_MOs= existing" >> stdin
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
	J=$[ $J + 1 ]
        if [[ "$NUMPROC" != "1" ]]; then
		mpirun -n $NUMPROC $TONTO	
	else
		$TONTO
	fi
	mkdir $J.tonto_cycle.$JOBNAME
	cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
	cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
	cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
	cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME'.residual_density_map,cell.cube' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.residual_density_map,cell.cube
}

XCW_SCF_BLOCK(){
	echo "   ! More accuracy" >> stdin
	echo "   output_style_options= {" >> stdin
	echo "      real_precision= 8" >> stdin
	echo "      real_width= 20" >> stdin
	echo "   }" >> stdin
	echo "   " >> stdin
	SCF_BLOCK_PROM_TONTO
#	if [[ "$XCWONLY" == "false" ]]; then 
#		echo "   read_archive molecular_orbitals restricted" >> stdin
#		echo "   read_archive orbital_energies restricted" >> stdin
#		echo "   read_archive density_matrix restricted" >> stdin
#		echo "   " >> stdin
#	fi
	echo "   scfdata= {" >> stdin
	echo "   " >> stdin
	echo "     initial_density=   restricted" >> stdin
	echo "     kind=            xray_$METHODXCW" >> stdin
        echo "     output= true " >> stdin
	echo "     direct=          yes" >> stdin
	echo "     convergence= 0.001" >> stdin
	echo "     use_SC_cluster_charges= $SCCHARGESXCW" >> stdin
	if [[ "$SCCHARGESXCW" == "true" ]]; then
		echo "     cluster_radius= $SCCRADIUSXCW angstrom" >> stdin
	fi
	echo "   " >> stdin
	echo "     diis= {                     ! This is the extrapolation procedure" >> stdin
	echo "       save_iteration=  2" >> stdin
	echo "       start_iteration= 4" >> stdin
	echo "       keep=            8" >> stdin
	echo "        convergence_tolerance= 0.0002" >> stdin
	echo "     }" >> stdin
	echo "   " >> stdin
	echo "     max_iterations=  200         ! The maximum number of SCF interation" >> stdin
	echo "   " >> stdin
	echo "     use_damping=     YES         ! These are used to damp the SCF interation process " >> stdin
	echo "     damp_factor=     0.50        ! by including 20% of the previous result  " >> stdin
	echo "     damp_finish=     3 " >> stdin
	echo "      " >> stdin
	echo "     use_level_shift= YES " >> stdin
	echo "     !level_shift=    1.0         ! This is another form of damping " >> stdin
	echo "     !level_shift_finish= 3 " >> stdin
	echo "     initial_lambda=  $LAMBDAINITIAL       ! These specify the "lambda value" " >> stdin
	echo "     lambda_step=     $LAMBDASTEP          ! used to mix the energy with the chi^2 " >> stdin
	echo "     lambda_max=      $LAMBDAMAX " >> stdin
	echo "   } " >> stdin
	echo "" >> stdin
	echo "   scf " >> stdin
	echo "    " >> stdin
	echo "} " >> stdin
}

XCW(){
	TONTO_HEADER
	if [[ "$XWR" == "true" ]]; then 
		CHANGE_JOB_NAME
	else
		DEFINE_JOB_NAME
	fi
	CHARGE_MULT
	PROCESS_CIF
	if [[ "$XWR" == "true" ]]; then 
		CHANGE_JOB_NAME
	else
		DEFINE_JOB_NAME
	fi
	echo "   basis_directory= $BASISSETDIRXCW" >> stdin
	echo "   basis_name= $BASISSETTXCW" >> stdin
	echo "" >> stdin
	if [[ "$COMPLETESTRUCT" == "true"  ]]; then
		COMPLETECIFBLOCK
	fi
	CRYSTAL_BLOCK
	if [[ "$USEBECKE" == "true" ]]; then 
		BECKE_GRID
	fi
	XCW_SCF_BLOCK
	J=$[ $J + 1 ]
	echo "Runing Tonto, cycle number $J" 
        if [[ "$NUMPROC" != "1" ]]; then
		mpirun -n $NUMPROC $TONTO	
	else
		$TONTO
	fi
	echo "Tonto cycle number $J ended"
	mkdir $J.XCW_cycle.$JOBNAME
	cp stdin $J.XCW_cycle.$JOBNAME/$J.stdin
	cp stdout $J.XCW_cycle.$JOBNAME/$J.stdout
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
	cp $JOBNAME'.cartesian.cif2' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
	cp $JOBNAME'.archive.cif' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fcf' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp $JOBNAME'.archive.fco' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME.residual_density_map,cell.cube $J.XCW_cycle.$JOBNAME/$J.residual_density_map,cell.cube
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
	fi
#for f in *,restricted; do cp $f "$J.fit_cycle.$JOBNAME/$J.${f%}"; done
}

BOTTOM_PLOT(){
	if [ "$USECENTER" = "true" ]; then
		echo "      centre_atom= $CENTERATOM" >> stdin
		echo "      x_axis_atoms= $XAXIS" >> stdin
		echo "      y_axis_atoms= $YAXIS" >> stdin
		echo "      x_width= $WIDTHX Angstrom" >> stdin
		echo "      y_width= $WIDTHY Angstrom" >> stdin
		echo "      z_width= $WIDTHZ Angstrom" >> stdin
	else 
		echo "      use_unit_cell_as_bbox" >> stdin
	fi
	if [ "$USESEPARATION" = "true" ]; then
		echo "      desired_separation= $SEPARATION angstrom" >> stdin
	elif [ "$USEALLPOINTS" = "true" ]; then
		echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
	else
		echo "ERROR: Please enter cube size information" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
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
}

PLOTS(){
	TONTO_HEADER
	PROCESS_CIF
	COMPLETECIFBLOCK
	DEFINE_JOB_NAME
	TONTO_BASIS_SET
	CHARGE_MULT
	CRYSTAL_BLOCK
	PUT_GEOM
	if [[ "$USEBECKE" == "true" ]]; then 
		BECKE_GRID
	fi
	echo "   read_archive molecular_orbitals restricted" >> stdin
	echo "   read_archive orbital_energies restricted" >> stdin
	echo "" >> stdin
	SCF_BLOCK_REST_TONTO
	echo "   make_scf_density_matrix" >> stdin
	echo "   make_structure_factors" >> stdin
	echo "" >> stdin
	if [ "$DEFDEN" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= deformation_density" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$DFTXCPOT" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= dft_xc_potential" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$DENS" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= electron_density" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$LAPL" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= laplacian" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$NEGLAPL" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= negative_laplacian" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$PROMOL" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= promolecule_density" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$RESDENS" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= residual_density_map" >> stdin
		BOTTOM_PLOT
	fi
	echo "}" >> stdin 
        if [[ "$NUMPROC" != "1" ]]; then
		mpirun -n $NUMPROC $TONTO	
	else
		$TONTO
	fi
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		unset MAIN_DIALOG
		exit 0
	fi
}

RUN_XWR(){
	XCW	
	echo "" >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "                                     RESIDUALS AFTER XCW                                       " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
}

COMPLETECIFBLOCK(){
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
}

run_script(){
	SECONDS=0
	if [ "$POWDER_HAR" = "true" ]; then
                cp *.m40 $JOBNAME.m40
                ED_COUNTER=$"0" ###counter for powder HAR
                PROFILE_COUNTER=$"0" ###counter for powder HAR
        HAR_COUNTER=$"0" ###counter for powder HAR
	I=$"0"   ###counter for gaussian jobs
	J=$"0"   ###counter for tonto fits
	shopt -s nocasematch	

	if [ "$SCFCALCPROG" != "optgaussian" ]; then 
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
		if [[ -z "$(awk ' NF<5 && NF>2 {print $0}' $HKL)" ]]; then
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
	fi

	if [[ "$PLOT_TONTO" == "true" ]]; then
		PLOTS
		exit 0
		exit
	fi	
	if [[ "$XCWONLY" == "true" ]]; then
		XCW
		exit 0
		exit
	fi
	if [[ ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "ORCA") && "$SCCHARGES" == "true" ]]; then
		DOUBLE_SCF="true"
	fi 
	echo "###############################################################################################" > $JOBNAME.lst
	echo "                                           lamaGOET                                            " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "Job started on:" >> $JOBNAME.lst
	date >> $JOBNAME.lst
	echo "User Inputs: " >> $JOBNAME.lst
	echo "Tonto executable	: $TONTO"  >> $JOBNAME.lst 
	echo "$($TONTO -v)" >> $JOBNAME.lst 
	echo "SCF program		: $SCFCALCPROG" >> $JOBNAME.lst
	if [ "$SCFCALCPROG" != "Tonto" ]; then 
		echo "SCF executable		: $SCFCALC_BIN" >> $JOBNAME.lst
	fi
	echo "Job name		: $JOBNAME" >> $JOBNAME.lst
	echo "Input cif		: $CIF" >> $JOBNAME.lst
	if [ "$SCFCALCPROG" != "optgaussian" ]; then 
		echo "Input hkl		: $HKL" >> $JOBNAME.lst
		echo "Wavelenght		: $WAVE" Angstrom >> $JOBNAME.lst
		echo "F_sigma_cutoff		: $FCUT" >> $JOBNAME.lst
	fi
	echo "Tol. for shift on esd	: $CONVTOL" >> $JOBNAME.lst
	echo "Charge			: $CHARGE" >> $JOBNAME.lst
	echo "Multiplicity		: $MULTIPLICITY" >> $JOBNAME.lst
	if [ "$SCFCALCPROG" = "Tonto" ]; then 
		echo "Level of theory 	: $METHOD/$BASISSETT" >> $JOBNAME.lst
		echo "Basis set directory	: $BASISSETDIR" >> $JOBNAME.lst
	else
		echo "Level of theory 	: $METHOD/$BASISSETG" >> $JOBNAME.lst
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
	fi
	
	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then 
		echo "Only for Gaussian/Orca job	" >> $JOBNAME.lst
		echo "Number of processor 	: $NUMPROC" >> $JOBNAME.lst
		echo "Memory		 	: $MEM" >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Starting Geometry                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
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
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
		COMPLETECIFBLOCK
		echo "   put" >> stdin 
		echo "" >> stdin
		echo "   write_xyz_file" >> stdin
		if [[ "$COMPLETESTRUCT" == "true" || "$SCFCALCPROG" == "optgaussian" ]]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		echo "" >> stdin
		echo "}" >> stdin 
		echo "Reading cif with Tonto"
		if [[ "$NUMPROC" != "1" ]]; then
			mpirun -n $NUMPROC $TONTO	
		else
			$TONTO
		fi
		INITIALCHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $2}')
#		MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print shift}')
#		MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print atom}')
#		MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print param}')
		MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk '{ gsub("-","",$0); print $0 }' | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print shift}')
		MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk '{ gsub("-","",$0); print $0 }' | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print atom}')
		MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk '{ gsub("-","",$0); print $0 }' |awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print param}')
		if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
			sed -i 's/(//g' $JOBNAME.xyz
			sed -i 's/)//g' $JOBNAME.xyz
		fi
		if ! grep -q 'Wall-clock time taken' "stdout"; then
			echo "ERROR: something wrong with your input cif file, please check the stdout file for more details" | tee -a $JOBNAME.lst
			unset MAIN_DIALOG
			exit 0
		fi
		mkdir $J.tonto_cycle.$JOBNAME
		if [[ "$SCFCALCPROG" == "optgaussian"  &&  "$SCCHARGES" == "false" ]]; then 
			cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz
                else
			cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$JOBNAME.starting_geom.xyz
		fi
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
                if [ -f $JOBNAME.cartesian.cif2 ]; then
			sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
			cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
		fi
		awk '{a[NR]=$0}/^Atom coordinates/{b=NR}/^Unit cell information/{c=NR}END{for(d=b-1;d<=c-2;++d)print a[d]}' stdout >> $JOBNAME.lst
		echo "Done reading cif with Tonto"
#is this ok now?if [[ "$SCFCALCPROG" == "elmodb" && ! -z tonto.cell || "$SCFCALCPROG" == "optgaussian" && ! -z tonto.cell  ]]; then
		if [[ ( "$SCFCALCPROG" == "elmodb" && ! -f tonto.cell ) || ( "$SCFCALCPROG" == "optgaussian" && ! -f tonto.cell ) ]]; then
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
#is this ok now?if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then 
		if [[ "$SCFCALCPROG" == "Gaussian" ]] || [[ "$SCFCALCPROG" == "optgaussian"  &&  "$SCCHARGES" == "true" ]]; then 
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Gaussian                                         " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "%rwf=./$JOBNAME.rwf" > $JOBNAME.com 
			echo "%rwf=./$JOBNAME.rwf" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%int=./$JOBNAME.int" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%NoSave" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%chk=./$JOBNAME.chk" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%mem=$MEM" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%nprocshared=$NUMPROC" | tee -a $JOBNAME.com $JOBNAME.lst
			if [ "$SCFCALCPROG" = "optgaussian" ]; then
#				OPT=" opt=calcfc"
				OPT=" opt"
			fi
			if [ "$METHOD" = "rks" ]; then
				echo "# blyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" | tee -a $JOBNAME.com $JOBNAME.lst    
			else
				if [ "$METHOD" = "uks" ]; then
					echo "# ublyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" | tee -a $JOBNAME.com $JOBNAME.lst
				else
					echo "# $METHOD/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" | tee -a $JOBNAME.com $JOBNAME.lst
			        fi
			fi			
			echo ""  | tee -a $JOBNAME.com $JOBNAME.lst
			echo "$JOBNAME" | tee -a $JOBNAME.com $JOBNAME.lst
			echo "" | tee -a  $JOBNAME.com $JOBNAME.lst
			echo "$CHARGE $MULTIPLICITY" | tee -a  $JOBNAME.com $JOBNAME.lst
			awk 'NR>2' $JOBNAME.xyz | tee -a  $JOBNAME.com $JOBNAME.lst
			echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			if [ "$GAUSGEN" = "true" ]; then
		        	cat basis_gen.txt | tee -a $JOBNAME.com  $JOBNAME.lst
				echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			fi
			echo "./$JOBNAME.wfn" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			I=$"1"
			echo "Running Gaussian, cycle number $I" 
			$SCFCALC_BIN $JOBNAME.com
			echo "Gaussian cycle number $I ended"
			if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
				echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
				unset MAIN_DIALOG
				exit 0
			fi
                        ENERGIA=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*HF=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
                        RMSD=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*RMSD=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
#			ENERGIA=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' |  grep "HF=" | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#			RMSD=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "Generation fcheck file for Gaussian cycle number $I"
			echo "Gaussian cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
	     		mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
			cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
			cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
			cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
			SCF_TO_TONTO
			TONTO_TO_GAUSSIAN
			CHECK_ENERGY
		elif [ "$SCFCALCPROG" = "Orca" ]; then  
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Orca                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			if [ "$METHOD" = "rks" ]; then
				echo "! blyp $BASISSETG" > $JOBNAME.inp
				echo "! blyp $BASISSETG" >> $JOBNAME.lst
			elif [ "$METHOD" = "uks" ]; then
				echo "! ublyp $BASISSETG" > $JOBNAME.inp
				echo "! ublyp $BASISSETG" >> $JOBNAME.lst
			else
				echo "! $METHOD $BASISSETG" > $JOBNAME.inp
				echo "! $METHOD $BASISSETG" >> $JOBNAME.lst
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
		if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca"  ]]; then
			if [[ "$DOUBLE_SCF" == "true" ]]; then 
				SCF_TO_TONTO
				if [ "$SCFCALCPROG" = "Gaussian" ]; then  
					TONTO_TO_GAUSSIAN
				else 
					TONTO_TO_ORCA
				fi
				CHECK_ENERGY
			fi		
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
				if [[ $J -ge $MAXCYCLE ]]; then
					CHECK_ENERGY
					echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
					break
				fi
				SCF_TO_TONTO
				if [ "$POWDER_HAR" = "true" ]; then
                                   UPDATE_FILES_FOR_POWDER
                                fi
				if [ "$SCFCALCPROG" = "Gaussian" ]; then  
					TONTO_TO_GAUSSIAN
				else 
					TONTO_TO_ORCA
				fi
				CHECK_ENERGY
			done
		fi
		if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
			if [[ "$SCCHARGES" == "true" ]];then
#			while (( ($(awk "BEGIN {print $DE > $CONVTOL}") | bc -l ) || $( echo "$J <= 1" | bc -l )  )); do
				while (( $(echo "$(echo ${DE#-}) > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
					if [[ $J -ge $MAXCYCLE ]];then
						CHECK_ENERGY
						echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
						break
					fi
					SCF_TO_TONTO
					if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then  
						TONTO_TO_GAUSSIAN
					else 
						TONTO_TO_ORCA
					fi
					CHECK_ENERGY
				done
			else
#     				ONLY_ONE="opt=calcfc"
				OPT=" opt"
				GET_FREQ
			fi
		fi
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Final Geometry                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "Energy= $ENERGIA2, RMSD= $RMSD2" >> $JOBNAME.lst
		echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		if [[ "$SCFCALCPROG" != "optgaussian" ]]; then  
			GET_RESIDUALS
			echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
		        if [[ "$XWR" == "true" ]]; then
		        	RUN_XWR
        		fi
		elif [[ "$SCFCALCPROG" == "optgaussian" && "$SCCHARGES" == "true" ]]; then  
			SCF_TO_TONTO
			GET_FREQ
		fi
		echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		DURATION=$SECONDS
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit
	elif [[ "$SCFCALCPROG" == "Tonto" ]]; then
		SCF_TO_TONTO
		if [ "$POWDER_HAR" = "true" ]; then
                        UPDATE_FILES_FOR_POWDER
                fi
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Final Geometry                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo " $(awk '{a[NR]=$0}/^Structure refinement results/{b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		if [[ "$XWR" == "true" ]]; then
			RUN_XWR
		fi
		DURATION=$SECONDS
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit
	else
		if [ "$USEGAMESS" = "false" ]; then    
			ELMODB
			SCF_TO_TONTO
			ELMODB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
			if [[ $J -ge $MAXCYCLE ]];then
				echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
				break
			fi
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
			GET_RESIDUALS
			echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
			if [[ "$XWR" == "true" ]]; then
				RUN_XWR
			fi
			DURATION=$SECONDS
			echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
			echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
			exit
		else 
			GAMESS_ELMODB_OLD_PDB
			SCF_TO_TONTO
			GAMESS_ELMODB_OLD_PDB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
			if [[ $J -ge $MAXCYCLE ]];then
				echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
				break
			fi
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
			GET_RESIDUALS
			echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
			if [[ "$XWR" == "true" ]]; then
				RUN_XWR
			fi
			DURATION=$SECONDS
			echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
			echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
			exit
		fi
	fi
}

if [[ "$SCFCALCPROG" = "elmodb" && "$EXIT" = "OK" ]]; then
	if [[ ! -f "$( echo $CIF | awk -F "/" '{print $NF}' )" ]]; then
		cp $CIF .
	fi
	if [[ ! -z $(diff -ZB $PDB $JOBNAME.cut.pdb) ]]; then
		PDB=$JOBNAME.cut.pdb	
		echo "PDB=\"$PDB\"" >> job_options.txt
	else
		PDB=$( echo $CIF | awk -F "/" '{print $NF}' ) 
		echo "PDB=\"$PDB\"" >> job_options.txt
	fi
fi

if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG="Gaussian"
	echo "SCFCALCPROG=\"$SCFCALCPROG\"" >> job_options.txt
fi

if [ "$GAUSGEN" = "true" ]; then
	BASISSETG="gen"
#	sed -i '/BASISSETG=/c\BASISSETG=\"'$BASISSETG'"' job_options.txt
fi

if [ "$GAUSSEMPDISP" = "true" ]; then
	GAUSSEMPDISPKEY="EmpiricalDispersion=gd3bj"
fi

if [ "$GAUSSREL" = "true" ]; then
	INT="int=dkh"
	echo "INT=\"$INT\"" >> job_options.txt
fi

source job_options.txt

run_script
