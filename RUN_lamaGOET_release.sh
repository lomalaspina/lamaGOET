#!/bin/bash
export LC_NUMERIC="en_US.UTF-8"

# Make GNU sed/awk/coreutils available under their plain names, and provide
# the _upper/_lower helpers, so this script behaves the same on Linux and
# macOS.  See lamagoet_shell_env.sh for why this is necessary.
_lamagoet_env_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -r "$_lamagoet_env_dir/lamagoet_shell_env.sh" ]; then
    source "$_lamagoet_env_dir/lamagoet_shell_env.sh"
else
    echo "lamaGOET: cannot find lamagoet_shell_env.sh next to $0" >&2
    echo "If lamaGOET was installed with install.sh, make sure that file was" >&2
    echo "symlinked into the same directory as this script." >&2
    exit 2
fi

_lamagoet_publish_latest_cif() {
	local server=${LAMAGOET_LIVE_CIF_SERVER:-}
	local directory=${LAMAGOET_LIVE_CIF_DIRECTORY:-}
	local port=${LAMAGOET_LIVE_CIF_PORT:-2244}
	local candidate

	[[ -n "$server" && -n "$directory" ]] || return 0
	command -v scp >/dev/null 2>&1 || return 0
	for candidate in \
		"${JOBNAME}.cartesian.cif2" \
		"${JOBNAME}.fractional.cif1" \
		"${JOBNAME}.archive.cif"
	do
		[[ -s "$candidate" ]] || continue
		scp -q -o BatchMode=yes -o ConnectTimeout=10 -P "$port" "$candidate" \
			"${server}:${directory}/${JOBNAME}.latest_tonto.cif" || {
			printf 'lamaGOET: warning: could not publish the latest Tonto CIF to the submitting computer\n' >&2
		}
		return 0
	done
}

# The periodic CP2K implementation is maintained in the monolithic launcher.
# A cluster-side RUN_lamaGOET invocation delegates only CP2K jobs to it, while
# all legacy backends continue through this runner unchanged.
if [[ -f job_options.txt ]]; then
	source ./job_options.txt

# Processor counts are used unquoted as `mpirun -n $NUMPROCTONTO`, so an option
# file that predates them expands to `mpirun -n <binary>`: the -n flag consumes
# the executable path and MPI reports "No executable was specified", which says
# nothing about the real cause. Supply the defaults the schema promises.
NUMPROC=${NUMPROC:-1}
NUMPROCTONTO=${NUMPROCTONTO:-1}

	if [[ -z "${COMPLETESTRUCT:-}" && -n "${COMPLETECIF:-}" ]]; then
		COMPLETESTRUCT=$COMPLETECIF
	fi
	if [[ "${SCFCALCPROG:-}" == "CP2K" ]]; then
		LAMAGOET_MONOLITHIC=${LAMAGOET_MONOLITHIC:-}
		if [[ -z "$LAMAGOET_MONOLITHIC" ]]; then
			if command -v lamaGOET >/dev/null 2>&1; then
				LAMAGOET_MONOLITHIC=$(command -v lamaGOET)
			else
				LAMAGOET_MONOLITHIC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lamaGOET.sh"
			fi
		fi
		if [[ ! -f "$LAMAGOET_MONOLITHIC" ]]; then
			echo "RUN_lamaGOET: CP2K requires the monolithic lamaGOET.sh; set LAMAGOET_MONOLITHIC to its path." >&2
			exit 1
		fi
		exec bash "$LAMAGOET_MONOLITHIC" --run-job-options "$PWD/job_options.txt"
	fi
fi

RUN_NOSPHERA2(){

mkdir $NSA2_COUNTER.NoSphera2_cycle

if [[ "$COMPLETESTRUCT" == "true"  ]]; then
        #Replace label on xyz block for assym unit cif
        #echo "xyz assym"
        EXISTS=$(awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}')
        if [[ ! -z $EXISTS ]]; then
                awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
                awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
                sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.archive.cif 
        fi
        #echo "xyz assym done"

        #Replace label on xyz block for frag unit cif
        #echo "xyz frag"
        awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
        awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
        sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1 
        #echo "xyz frag done"
        
        #Replace label on ADP block for assym unit cif
        #echo "adp assym"
        EXISTS=$(awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}')
        if [[ ! -z $EXISTS ]]; then
                awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
                awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}'  > ATOMS
                sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.archive.cif 
        fi        
        #echo "adp assym done"
        
        #Replace label on ADP block for frag unit cif
        #echo "adp frag"
        awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
        awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}'  > ATOMS
        sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1 
        #echo "adp frag done"
        rm ATOMS ATOMS_NEW
fi

#Add symmetry loop that NoSpherA2 reads
echo "" > SYMMETRY
echo "loop_" >> SYMMETRY
echo "   _space_group_symop_id " >> SYMMETRY
echo "   _space_group_symop_operation_xyz " >> SYMMETRY
#awk '{a[NR]=$0}/^    _symmetry_equiv_pos_as_xyz/{b=NR+1}/^# Unit cell/{c=NR-3}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk -n '{ print NR, $0}' | awk '{gsub(/\ /,"",$2)}'  >> SYMMETRY
awk '{a[NR]=$0}/^    _symmetry_equiv_pos_as_xyz/{b=NR+1}/^# Unit cell/{c=NR-3}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | tr -d \ |  awk -n '{ print NR, $0}' | tr -d \' >> SYMMETRY
#awk '{a[NR]=$0}/^    _symmetry_equiv_pos_as_xyz/{b=NR+1}/^# Unit cell/{c=NR-3}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1  > SYMMETRY_OLD
#sed -i -ne '/'"$(sed -n '1p' SYMMETRY_OLD )"'/ {p; r SYMMETRY' -e 'p; :a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
echo "$(cat SYMMETRY)" >> $JOBNAME.fractional.cif1
echo "$(cat SYMMETRY)" >> $JOBNAME.archive.cif
rm SYMMETRY

NoSphera2.exe -cif $JOBNAME.archive.cif -asym_cif $JOBNAME.fractional.cif1 -wfn $JOBNAME.wfn -hkl $JOBNAME.hkl -acc $NSA2ACC -cpus $NUMPROC > /dev/null
if ! grep -q 'Time Breakdown:' "NoSpherA2.log"; then
	echo "ERROR: NoSpherA2 finished with error, please check the $I.th NoSpherA2.log file for more details" | tee -a $JOBNAME.lst
       	exit 1
else
        mv experimental.tsc $JOBNAME.tsc
       	echo "NoSpherA2 job finish correctly."
       	cp $JOBNAME.wfn  $NSA2_COUNTER.NoSphera2_cycle/$NSA2_COUNTER.$JOBNAME.wfn
       	cp $JOBNAME.tsc  $NSA2_COUNTER.NoSphera2_cycle/$NSA2_COUNTER.$JOBNAME.tsc
       	cp NoSpherA2.log $NSA2_COUNTER.NoSphera2_cycle//$NSA2_COUNTER.NoSpherA2.log
        #sleep 2s
fi

NSA2_COUNTER=$[$NSA2_COUNTER+1]
}

LABELS_IN_XYZ(){
if [[ "$COMPLETESTRUCT" == "true"  ]]; then
        #Replace label on xyz block for xyz 
        awk '{if(NR>2 && $2~/^[0-9]/) print $0}' $JOBNAME.xyz | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
        awk '{if(NR>2 && $2~/^[0-9]/) print $0}' $JOBNAME.xyz | awk 'substr($1,2,2)!~/^[0-9]/{print $0}'  > ATOMS
        sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.xyz

        rm ATOMS ATOMS_NEW 
fi
}

GAUSSIAN_NO_CHARGES(){
echo "%rwf=./$JOBNAME.rwf" > $JOBNAME.com 
echo "%int=./$JOBNAME.int" >> $JOBNAME.com 
echo "%NoSave" >> $JOBNAME.com 
echo "%chk=./$JOBNAME.chk" >> $JOBNAME.com 
echo "%mem=$MEM" >> $JOBNAME.com 
echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
if [ "$SCFCALCPROG" = "optgaussian" ]; then
		OPT=" opt=calcfc"
	OPT=" opt"
fi
if [ "$METHOD" = "rks" ]; then
	echo "# blyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com    
else
	if [ "$METHOD" = "uks" ]; then
		echo "# ublyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	else
		echo "# $METHOD/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
        fi
fi			
echo ""  >> $JOBNAME.com
echo "$JOBNAME" >> $JOBNAME.com
echo "" >>  $JOBNAME.com
echo "$CHARGE $MULTIPLICITY" >>  $JOBNAME.com
awk 'NR>2' $JOBNAME.xyz >>  $JOBNAME.com
echo "" >> $JOBNAME.com 
if [ "$GAUSGEN" = "true" ]; then
	cat basis_gen.txt >> $JOBNAME.com 
	echo "" >> $JOBNAME.com 
fi
echo "./$JOBNAME.wfn" >> $JOBNAME.com 
echo "" >> $JOBNAME.com 
#I=$"1"
echo "Updating wave at gas phase" 
$SCFCALC_BIN $JOBNAME.com
cp Test.FChk $JOBNAME.fchk
sed -i '/^#/d' $JOBNAME.fchk
echo "Updating wave at gas phase done" 
#echo "Gaussian cycle number $I ended"
if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
	echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
	exit 1
fi
}

ORCA_NO_CHARGES(){
if [ "$METHOD" = "rks" ]; then
	echo "! blyp $BASISSETG" > $JOBNAME.inp
elif [ "$METHOD" = "uks" ]; then
	echo "! ublyp $BASISSETG" > $JOBNAME.inp
else
	echo "! $METHOD $BASISSETG" > $JOBNAME.inp
fi
echo "" >> $JOBNAME.inp 
echo "%pal nprocs $NUMPROC end" >> $JOBNAME.inp
echo "" >> $JOBNAME.inp
echo "%output" >> $JOBNAME.inp 
echo "   PrintLevel=Normal" >> $JOBNAME.inp 
echo "   Print[ P_Basis       ] 2" >> $JOBNAME.inp 
echo "   Print[ P_GuessOrb    ] 1" >> $JOBNAME.inp 
echo "   Print[ P_MOs         ] 1" >> $JOBNAME.inp 
echo "   Print[ P_Density     ] 1" >> $JOBNAME.inp 
echo "   Print[ P_SpinDensity ] 1" >> $JOBNAME.inp 
echo "end" >> $JOBNAME.inp 
echo "" >> $JOBNAME.inp 
echo "* xyz $CHARGE $MULTIPLICITY" >> $JOBNAME.inp 
awk 'NR>2' $JOBNAME.xyz >> $JOBNAME.inp 
echo "*" >> $JOBNAME.inp 
if [[ "$GAUSGEN" == "true" ]]; then
	cat basis_gen.txt >> $JOBNAME.inp
	echo "" >> $JOBNAME.inp
fi
#I=$"1"
#echo "Running Orca, cycle number $I" 
if [ -f $JOBNAME.gbw ]; then
        rm $JOBNAME.gbw
fi      
echo "Updating wave at gas phase" 
$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
echo "Updating wave at gas phase done" 
if [[ "$(which orca_2mkl.exe)" == "" ]]; then
	orca_2mkl $JOBNAME -molden  > /dev/null
else 
	orca_2mkl.exe $JOBNAME -molden  > /dev/null
fi
if [[ "$(which orca_2aim.exe)" == "" ]]; then
	orca_2aim $JOBNAME  > /dev/null
else
	orca_2aim.exe $JOBNAME  > /dev/null
fi
NAPONE=$[ $NUMBEROFATOMS + 1 ]
STARTLINE=$(grep -n "  $NAPONE 0" $JOBNAME.molden.input | awk -F: '{print $1}')
ENDLINE=$(grep -n "\[5D\]" $JOBNAME.molden.input | awk -F: '{print $1}')
if [[ "$STARTLINE" != "" && "$ENDLINE" != "" ]]; then
	sed -i "$STARTLINE","$[ $ENDLINE - 1]"'{/.*/d;}' $JOBNAME.molden.input
	sed -i '/Q\ /d' $JOBNAME.molden.input
fi
#echo "Orca cycle number $I ended"
if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
	echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
	exit 1
fi
}

WRITEXYZ(){
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
if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
                       	echo "   write_xyz_file" >> stdin
		else
	                echo "   write_fragment_xyz_file " >> stdin
		fi
        else 
                echo "   write_xyz_file" >> stdin
        fi
else 
        echo "   write_xtal23_xyz_file" >> stdin
fi
echo "   put_cif" >> stdin
if [[ "$COMPLETESTRUCT" == "true" || "$SCFCALCPROG" == "optgaussian" ]]; then
	echo "" >> stdin
	echo "   put_grown_cif" >> stdin
fi
echo "" >> stdin
echo "}" >> stdin 
echo "Updating geometry"
if [[ "$NUMPROCTONTO" != "1" ]]; then
	mpirun -n $NUMPROCTONTO $TONTO	
else
	$TONTO
fi
echo "Updating geometry done"
if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
	if [ -f "$JOBNAME.xyz" ]; then
		sed -i 's/(//g' $JOBNAME.xyz
		sed -i 's/)//g' $JOBNAME.xyz
	fi
fi
#if [[ -f $JOBNAME.cartesian.cif2 ]]; then
if [[ -f $JOBNAME.fractional.cif1 ]]; then
        cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
        cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
        cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
        cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
fi
if [[ "$SCFCALCPROG" == "Gaussian" ]]; then  
        GAUSSIAN_NO_CHARGES
else 
	ORCA_NO_CHARGES
fi
}

#CHECK_ATOM_LABELS(){
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.archive.cif
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
#rm ATOMS ATOMS_NEW
#}

RUN_JANA(){
mkdir $JANA_COUNTER.Jana_cycle

todos *.m*
todos *.m??

 cp $JOBNAME.cif $JANA_COUNTER.Jana_cycle/$JOBNAME.start.cif

echo "Starting Jana cycle number $JANA_COUNTER"
#RUN Jana
$JANAEXE $JOBNAME @Batch.txt

python3 /usr/local/bin/powderHARcifrewrite.py
echo "Jana cycle number $JANA_COUNTER ended"

 cp $JOBNAME.m40 $JANA_COUNTER.Jana_cycle/$JOBNAME.m40
 cp $JOBNAME.m41 $JANA_COUNTER.Jana_cycle/$JOBNAME.m41
 cp $JOBNAME.m70 $JANA_COUNTER.Jana_cycle/$JOBNAME.m70
 cp $JOBNAME.m50 $JANA_COUNTER.Jana_cycle/$JOBNAME.m50
 cp $JOBNAME.m90 $JANA_COUNTER.Jana_cycle/$JOBNAME.m90
 cp $JOBNAME.m80 $JANA_COUNTER.Jana_cycle/$JOBNAME.m80
 cp $JOBNAME.m83 $JANA_COUNTER.Jana_cycle/$JOBNAME.m83
 cp $JOBNAME.m85 $JANA_COUNTER.Jana_cycle/$JOBNAME.m85
 cp $JOBNAME.m95 $JANA_COUNTER.Jana_cycle/$JOBNAME.m95
 cp $JOBNAME.cif $JANA_COUNTER.Jana_cycle/$JOBNAME.cif
 cp Jana2006-Batch.log $JANA_COUNTER.Jana_cycle/"$JOBNAME"_Jana_batch.log

 JANA_COUNTER=$[$JANA_COUNTER+1]
#if [[ "$SCCHARGES" == "true" && "$SCFCALCPROG" != "Tonto" ]]; then 
#       WRITEXYZ
#fi
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
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.gamess.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.inp
	cp $JOBNAME.gamess.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.out
	cp sao  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.sao
	rm ed* 
	rm gamess_input*
	if ! grep -q 'OVERLAP INTEGRALS WRITTEN ON FILE sao' "$JOBNAME.gamess.out"; then
		echo "ERROR: Calculation of overlap integrals with gamessus finished with error, please check the $I.th gamess.out file for more details" | tee -a $JOBNAME.lst
		exit 1
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
			exit 1
		else
			echo "elmodb job finish correctly."
			cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
			cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
			cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
			if [ "$I" != "1" ]; then
				cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
			fi
		fi
		if [[ "$USENOSPHERA2" == "true" ]]; then
#			awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
			echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
	                echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
       		        RUN_NOSPHERA2
        	        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
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
		exit 1
	else
		echo "elmodb job finish correctly."
                if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
		        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                fi
		cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
		cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
		cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
		if [ "$I" != "1" ]; then
			cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
		fi
	fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
#		awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
                echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
	        RUN_NOSPHERA2
                echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
	fi
}

TONTO_TO_ORCA(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for Orca cycle number $I"
	if [ "$SCFCALCPROG" = "optorca" ]; then
		ORCAOPT=" Opt"
	fi
	if [ "$METHOD" = "rks" ]; then
		echo "! blyp $BASISSETG $ORCAOPT" > $JOBNAME.inp
	else
		if [ "$METHOD" = "uks" ]; then
			echo "! ublyp $BASISSETG $ORCAOPT" > $JOBNAME.inp
		else
			echo "! $METHOD $BASISSETG $ORCAOPT" > $JOBNAME.inp
		fi
	fi
	echo "" >> $JOBNAME.inp
	echo "%pal nprocs $NUMPROC end" >> $JOBNAME.inp
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
	if [ "$SCCHARGES" = "true" ]; then 
		echo '% pointcharges "'$JOBNAME'.qxyz"'  >> $JOBNAME.inp
		sed -i '1,12{/.*/d}' cluster_charges 
		sed -i '$ d' cluster_charges
		sed -i -n '1~3p' cluster_charges 
		sed -i '{/^$/d}' cluster_charges 
		LINEONE=$(wc -l cluster_charges | awk '{print $1}')
		echo $LINEONE > $JOBNAME.qxyz
		awk '{printf " %12s  %12s %12s  %12s\n",$4,$1,$2,$3}' cluster_charges >> $JOBNAME.qxyz
                echo "" >> $JOBNAME.qxyz
		echo ""  >> $JOBNAME.inp
		if [[ "$ADDNUCINTER" == "true" ]]; then
			echo "%method" >> $JOBNAME.inp
			echo "   DoEQ true" >> $JOBNAME.inp
			echo "end"  >> $JOBNAME.inp
			echo ""  >> $JOBNAME.inp
		fi
	fi
	echo "* xyz $CHARGE $MULTIPLICITY"  >> $JOBNAME.inp
	awk 'NR>2' $JOBNAME.xyz  >> $JOBNAME.inp
	echo "*"  >> $JOBNAME.inp
	if [[ "$GAUSGEN" == "true" ]]; then
		cat basis_gen.txt >> $JOBNAME.inp
		echo "" >> $JOBNAME.inp
	fi
	echo "Running Orca, cycle number $I" 
        if [ -f $JOBNAME.gbw ]; then
                rm $JOBNAME.gbw
        fi
	$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
	echo "Orca cycle number $I ended"
	if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
		echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "Generation of molden file for Orca cycle number $I"
	if [[ "$(which orca_2mkl.exe)" == "" ]]; then
		orca_2mkl $JOBNAME -molden  > /dev/null
	else 	
		orca_2mkl.exe $JOBNAME -molden  > /dev/null
	fi
	echo "Generation of wfn file for Orca cycle number $I"
	if [[ "$(which orca_2aim.exe)" == "" ]]; then
		orca_2aim $JOBNAME  > /dev/null
	else
		orca_2aim.exe $JOBNAME  > /dev/null
	fi
 	NAPONE=$[ $NUMBEROFATOMS + 1 ]
	STARTLINE=$(grep -n "  $NAPONE 0" $JOBNAME.molden.input | awk -F: '{print $1}')
	ENDLINE=$(grep -n "\[5D\]" $JOBNAME.molden.input | awk -F: '{print $1}')
	if [[ "$STARTLINE" != "" && "$ENDLINE" != "" ]]; then
		sed -i "$STARTLINE","$[ $ENDLINE - 1 ]"'{/.*/d;}' $JOBNAME.molden.input
		sed -i '/Q\ /d' $JOBNAME.molden.input
	fi
#	echo "Orca cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
        NUMATOMWFN=$(grep -m1 " Q " $JOBNAME.wfn | awk '{ print $2 }' )
        NUMATOMWFN=$[$NUMATOMWFN -1]
        awk -v  NUMATOMWFN=$NUMATOMWFN 'NR==2 {gsub($7, NUMATOMWFN, $0); print}1' $JOBNAME.wfn > temp.wfn
        sed -i '2d' temp.wfn
        sed -i '/ Q /d' temp.wfn
        mv temp.wfn $JOBNAME.wfn
	if [[ "$USENOSPHERA2" == "true" ]]; then
		#awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.inp          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
	cp $JOBNAME.qxyz         $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.qxyz
	cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
	cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

TONTO_TO_OCC(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for OCC cycle number $I"
	if [ "$SCFCALCPROG" = "optorca" ]; then
		OPT=" Opt"
	fi
	echo "Running OCC, cycle number $I" 
        if [ -f $JOBNAME.gbw ]; then
                rm $JOBNAME.gbw
        fi
	if [ "$SCCHARGES" = "true" ]; then 
                if [ "$SCDIPOLES" = "true" ]; then       
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $4, $1, $2, $3 }' >> $JOBNAME.qxyz
                else
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;d+=3)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $4, $1, $2, $3 }' >> $JOBNAME.qxyz
                fi
	fi
	if [ "$SCCHARGES" = "true" ]; then 
		$SCFCALC_BIN scf $JOBNAME.xyz --method $METHOD --basis $BASISSETG -o fchk --point-charges $JOBNAME.qxyz > $JOBNAME.out
	else 
		$SCFCALC_BIN scf $JOBNAME.xyz --method $METHOD --basis $BASISSETG -o fchk > $JOBNAME.out
	fi
	echo "OCC cycle number $I ended"
	if ! grep -q 'A job well done' "$JOBNAME.out"; then
		echo "ERROR: OCC job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.xyz          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
#	cp $JOBNAME.owf$JOBNAME.fchk $JOBNAME.fchk
#	cp $JOBNAME.owf.$JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.owf.fchk     $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
        if [ -f "cluster_charges" ]; then
		cp cluster_charges          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.cluster_charges
        fi
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
        if [[ "$POWDER_HAR" == "false" || ( "$POWDER_HAR" == "true" && "$SCFCALCPROG" == "Tonto") ]]; then
	        echo "   read_g09_fchk_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk" >> stdin
        else
	        echo "   read_g09_fchk_file $JOBNAME.fchk" >> stdin
        fi
        echo "" >> stdin
}

READ_ORCA_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
        if [[ "$POWDER_HAR" == "false" || ( "$POWDER_HAR" == "true" && "$SCFCALCPROG" == "Tonto") ]]; then
               	echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
        else       
        	echo "   read_molden_file $JOBNAME.molden.input" >> stdin
        fi
        echo "" >> stdin
}

READ_CRYSTAL_WFN(){
        echo "" >> stdin
#        echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
##        echo "   read_CRYSTAL_XML_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.XML" >> stdin #this one was the one working before
##        echo "   c23_XML_file_name= $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.XML" >> stdin # this is the one working before, exchanging to use the one in the work folder to compat the files.
        echo "   c23_XML_file_name= GenerateXML.XML" >> stdin 
        echo "   process_cif_and_c23_xml" >> stdin 
#       echo "This routine is still being writen, come back later. " | tee -a $JOBNAME.lst
#       unset MAIN_DIALOG
#       exit 0
        echo "" >> stdin
        echo "   name= $JOBNAME" >> stdin 
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
	if [[ $POWDER_HAR == "false" ]]; then 
		if [[ $J == 0 ]]; then 
			if [[ ( "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ) && "$SCFCALCPROG" != "Tonto" ]]; then
#      				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
       				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1" >> stdin
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
#	#			if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" ]]; then
					if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
#						echo "       file_name= 0.tonto_cycle.$JOBNAME/0.$JOBNAME.cartesian.cif2" >> stdin
       				                echo "       file_name= 0.tonto_cycle.$JOBNAME/0.$JOBNAME.fractional.cif1" >> stdin
					else
						echo "       file_name= $CIF" >> stdin
					fi
			else
#                               if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#       				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif" >> stdin
#                               else
#        				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
       				        echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1" >> stdin
#                               fi
        		fi
        	else
#                       if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#       			echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif" >> stdin
#                       else
#        			echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
       				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1" >> stdin
#                       fi
		fi
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
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
        		echo "   process_CIF" >> stdin
		        echo "" >> stdin
                fi
	else 
		echo "       file_name= $CIF" >> stdin
		echo "    }" >> stdin
		echo "" >> stdin
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
        		echo "   process_CIF" >> stdin
	        	echo "" >> stdin
                fi
		COMPLETECIFBLOCK

        fi
#	if [ $J = 1 ]; then 
#		if [[ "$SCCHARGES" == "true" && ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca") ]]; then
#			if [[ "$COMPLETECIF" == "true" ]]; then
#				COMPLETECIFBLOCK	
#			fi
#		fi
#	fi
}

TONTO_BASIS_SET(){
	echo "   basis_directory= $BASISSETDIR" >> stdin
	echo "   basis_name= $BASISSETT" >> stdin
	echo "" >> stdin
}

TONTO_OBSERVED_DENSITY_INPUT(){
	[[ "$SCFCALCPROG" == "Tonto" && ( "${PARTITION_MODEL:-oc-hirshfeld}" == "observed" || "${PARTITION_MODEL:-oc-hirshfeld}" == "oc-observed" ) ]]
}

TONTO_IAM_ONLY_INPUT(){
	[[ "$SCFCALCPROG" == "Tonto" && "$J" == "0" && "$IAMTONTO" == "true" && "$ONLYIAMTONTO" == "true" ]]
}

DISPERSION_COEF(){
	echo "   	 dispersion_coefficients= {" >> stdin
	echo "   	 $(cat DISP_inst.txt)" >> stdin
	echo "   	 }" >> stdin
	echo "" >> stdin
}

WRITE_EXTINCTION_OPTIONS(){
	echo "         refine_extinction= ${EXTI:-no}" >> stdin
	case "${EXTI:-no}" in
		yes|YES|true|TRUE|1|on|ON)
			echo "         extinction_model= ${EXTINCTION_MODEL:-zachariasen}" >> stdin
			if [[ "${EXTINCTION_MODEL:-zachariasen}" == "becker-coppens" ]]; then
				echo "         extinction_type= ${EXTINCTION_TYPE:-type-1}" >> stdin
				echo "         extinction_distribution= ${EXTINCTION_DISTRIBUTION:-gaussian}" >> stdin
				echo "         extinction_anisotropic= ${EXTINCTION_ANISOTROPIC:-false}" >> stdin
				echo "         extinction_mean_path_mm= ${EXTINCTION_MEAN_PATH_MM:-0.3}" >> stdin
			fi
			;;
	esac
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
	WRITE_EXTINCTION_OPTIONS
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
			exit 1
		fi
	fi
	if [[ "$ISFCF" != "true" ]]; then
		echo "         REDIRECT $HKL" >> stdin
	else
		echo "         read_fcf_file $HKL" >> stdin
	fi
	echo "         merg_code= ${MERGCODE:-2}" >> stdin
	if [[ "$FCUT" != "0" ]]; then
		echo "         f_sigma_cutoff= $FCUT" >> stdin
	fi
	if [[ "$MINCORCOEF" != "" ]]; then
		echo "         min_correlation= $MINCORCOEF"  >> stdin
	fi
        if [[ "$USENOSPHERA2" != "true" ]]; then
	        echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
	        echo "         refine_H_U_iso= yes" >> stdin
        fi
	echo "" >> stdin
	echo "         show_fit_output= true" >> stdin
	echo "         show_fit_results= true" >> stdin
	echo "" >> stdin
	echo "      }  " >> stdin
	echo "   }  " >> stdin
	echo "" >> stdin
        if [[ "$SCFCALCPROG" != "Crystal14" && "$DEFRAGNETW" != "true" ]]; then
        	echo "   ! Geometry    " >> stdin
	        echo "   put" >> stdin
        	echo "" >> stdin
        fi
	echo "   IAM_refinement" >> stdin
	echo "" >> stdin
        if [[ "$ONLYIAMTONTO" == "true" ]]; then 
	        echo "}" >> stdin
	        echo "" >> stdin
	        echo "Running Tonto IAM refinement." 
                $TONTO
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit 0
        fi
}

WRITE_DENSITY_PARTITION_MODEL(){
	if [[ "$SCFCALCPROG" != "Tonto" ]]; then
		echo "         partition_model= oc-crystal23" >> stdin
		echo "         stockholder_model= ${STOCKHOLDER_MODEL:-cluster}" >> stdin
		return 0
	fi
	case "${PARTITION_MODEL:-oc-hirshfeld}" in
		auto|tonto|oc-hirshfeld|crystal23|oc-crystal23|"")
			echo "         partition_model= oc-hirshfeld" >> stdin
			;;
		observed|oc-observed)
			echo "         partition_model= oc-observed" >> stdin
			echo "         stockholder_model= ${STOCKHOLDER_MODEL:-cluster}" >> stdin
			echo "         observed_density_shrinkage= ${OBSERVED_DENSITY_SHRINKAGE:-0.5}" >> stdin
			echo "         observed_density_min_TF= ${OBSERVED_DENSITY_MIN_TF:-0.1}" >> stdin
			echo "         observed_zero_phase_sign= ${OBSERVED_ZERO_PHASE_SIGN:-0}" >> stdin
			;;
		*)
			echo "ERROR: Unsupported Tonto PARTITION_MODEL '${PARTITION_MODEL}'. Use oc-hirshfeld or oc-observed." | tee -a "$JOBNAME.lst" >&2
			return 1
			;;
	esac
}

CRYSTAL_BLOCK(){
	echo "" >> stdin
	echo "   crystal= {    " >> stdin
	if [[ "$SCFCALCPROG" == "elmodb" && $J == 0 && "$INITADP" == "false" ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
#	if [[ "$POWDER_HAR" == "true" && $PROFILE_COUNTER -gt 1  ]]; then
#		echo "      REDIRECT tonto.cell" >> stdin
#	fi
	if [[ "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "optorca" ]]; then 
		echo "      REDIRECT tonto.cell" >> stdin
	fi
        if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                echo "      spacegroup= { hermann_mauguin_symbol= "'"'$SPACEGROUPHM'"'" }" >> stdin
        fi
	if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then 
		echo "      xray_data= {   " >> stdin
	        if [[ "$POWDER_HAR" != "true" ]]; then 
                        # Tonto's thermal_smearing_model= keyword is gone. Its job -- choosing
                        # how the density is partitioned before thermal smearing -- now belongs
                        # to partition_model=, written immediately below. The old value
                        # "atom-based" meant one-centre partitioning, which is what the "oc-"
                        # prefix of every current value denotes, so oc-hirshfeld and friends
                        # already carry it. Emitting both would set an invalid value and then
                        # repeat the key.
                        if [[ "$SCFCALCPROG" == "Crystal14" || "$SCFCALCPROG" == "Tonto" ]]; then
				WRITE_DENSITY_PARTITION_MODEL || return 1
                        else
                                echo "         partition_model= oc-hirshfeld" >> stdin
                        fi
                        if [[ "$PLOT_TONTO" == "false" ]]; then
			WRITE_EXTINCTION_OPTIONS
        			echo "         correct_dispersion= $DISP" >> stdin
        			echo "         optimise_scale_factor= true" >> stdin
        		fi
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
				exit 1
			fi
		fi
	        if [[ "$POWDER_HAR" != "true" ]]; then 
			if [[ "$ISFCF" != "true" ]]; then
				echo "         REDIRECT $HKL" >> stdin
			else
				echo "         read_fcf_file $HKL" >> stdin
			fi
	                echo "         merg_code= ${MERGCODE:-2}" >> stdin
	                if [[ "$FCUT" != "0" ]]; then
        		        echo "         f_sigma_cutoff= $FCUT" >> stdin
                        fi
        		if [[ "$PLOT_TONTO" == "false" ]]; then
        			if [[ "$MINCORCOEF" != "" ]]; then
        				echo "         min_correlation= $MINCORCOEF"  >> stdin
        			fi
        			echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
        			echo "         refine_H_U_iso= $HADP" >> stdin
        			if [[ "$SCFCALCPROG" == "Tonto" && "$IAMTONTO" == "true" ]]; then 
        				echo "" >> stdin
        				echo "         show_fit_output= false" >> stdin
        				echo "         show_fit_results= false" >> stdin
        			fi
        			echo "" >> stdin
        			if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
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
        				if [[ "$ADPSONLY" != "true" ]]; then
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
                fi
                if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
		        echo "         do_residual_cube= YES " >> stdin
                fi
		echo "      }  " >> stdin
	fi
	echo "   }  " >> stdin
	echo "" >> stdin
}


PUT_GEOM(){
        if [[ "$SCFCALCPROG" != "Crystal14" && "$DEFRAGNETW" != "true" ]]; then
	        echo "   ! Geometry    " >> stdin
        	echo "   put" >> stdin
        	echo "" >> stdin
        fi
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
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
                        if [[ "$METHOD" == "ub3lyp" || "$METHOD" == "UB3LYP" ]]; then
		                echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= uks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
                		echo "      dft_correlation_functional= b3lypgc" >> stdin
                        elif [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" ]]; then
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
                		echo "      dft_correlation_functional= b3lypgc" >> stdin
                        else
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
                		echo "      dft_correlation_functional= b3lypgc" >> stdin
                        fi
			echo "      output= true " >> stdin
		else
                        if [[ "$METHOD" == "uhf" || "$METHOD" == "UHF" || "$METHOD" == "UKS" || "$METHOD" == "uks" ]]; then
		        	echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
                        elif [[ "$METHOD" == "rhf" || "$METHOD" == "RHF" || "$METHOD" == "RKS" || "$METHOD" == "rks" ]]; then
		        	echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
                        fi
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
		echo "   assign_NOs_to_MOs " >> stdin
		echo "   make_hirshfeld_inputs" >> stdin
		echo "   make_fock_matrix" >> stdin
		echo "" >> stdin
		echo "   ! SC cluster charge SCF" >> stdin
		echo "   scfdata= {" >> stdin
		echo "      initial_density= promolecule" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
                        if [[ "$METHOD" == "ub3lyp" || "$METHOD" == "UB3LYP" ]]; then
		                echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= uks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
        			echo "      dft_correlation_functional= b3lypgc" >> stdin
                        elif [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" ]]; then
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
        			echo "      dft_correlation_functional= b3lypgc" >> stdin
                        else
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
        			echo "      dft_correlation_functional= b3lypgc" >> stdin
                        fi
			echo "      output= true " >> stdin
		else
                        if [[ "$METHOD" == "uhf" || "$METHOD" == "UHF" || "$METHOD" == "UKS" || "$METHOD" == "uks" ]]; then
	                	echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
                        elif [[ "$METHOD" == "rhf" || "$METHOD" == "RHF" || "$METHOD" == "RKS" || "$METHOD" == "rks" ]]; then
	                	echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
                        fi
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
		if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" && "$J" != "0" ]]; then 
	                if [[ "$POWDER_HAR" != "true" ]]; then
			        echo "   ! Make Hirshfeld structure factors" >> stdin
#			        echo "   fit_hirshfeld_atoms" >> stdin
                                if [[ "$SCFCALCPROG" == "Crystal14" && "$DEFRAGNETW" == "true" ]]; then
                                        echo "   phar_defragment" >> stdin
                                fi
			        echo "   ha_fit" >> stdin
        			echo "" >> stdin
	        	fi
                fi
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
                        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
		                       	echo "   write_xyz_file" >> stdin
				else
	                                echo "   write_fragment_xyz_file " >> stdin
				fi
                        else 
                                echo "   write_xyz_file" >> stdin
                        fi
                else 
                        echo "   write_xtal23_xyz_file" >> stdin
                fi
	else
		if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then 
	                if [[ "$POWDER_HAR" != "true" ]]; then
			        echo "   ! Make Hirshfeld structure factors" >> stdin
				if [[ "$SCFCALCPROG" == "Orca" ]]; then
			                echo "   make_scf_density_matrix" >> stdin
			                echo "   assign_NOs_to_MOs " >> stdin
			                echo "   make_hirshfeld_inputs" >> stdin
			                echo "   make_fock_matrix" >> stdin
				fi
#       			echo "   fit_hirshfeld_atoms" >> stdin
                                if [[ "$SCFCALCPROG" == "Crystal14" && "$DEFRAGNETW" == "true" ]]; then
                                        echo "   phar_defragment" >> stdin
                                fi
			        echo "   ha_fit" >> stdin
        			echo "" >> stdin
                        else
                                echo "   put_cif" >> stdin
        		fi
                fi
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
                        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
		                       	echo "   write_xyz_file" >> stdin
				else
	                                echo "   write_fragment_xyz_file " >> stdin
				fi
                        else 
                                echo "   write_xyz_file" >> stdin
                        fi
                else 
                        echo "   write_xtal23_xyz_file" >> stdin
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
        if [[ "$LINEDEP" != "" ]]; then
	        echo "      linear_dependence_tol= $LINEDEP" >> stdin
        fi
	echo "      convergence= 0.001" >> stdin
	echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   scf" >> stdin
	echo "" >> stdin
}

SCF_BLOCK_OBSERVED_TONTO(){
	# oc-observed uses a molecular basis only to build neutral atomic
	# reference densities. It must not run a molecular SCF: the refined
	# structure factors come from the regularized observed density.
	BECKE_GRID
	echo "   ! Atomic reference SCF settings (no molecular SCF command)" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_density= promolecule " >> stdin
	echo "      kind= rhf" >> stdin
	echo "      output= true " >> stdin
	echo "      use_SC_cluster_charges= FALSE" >> stdin
        if [[ "$LINEDEP" != "" ]]; then
	        echo "      linear_dependence_tol= $LINEDEP" >> stdin
        fi
	echo "      convergence= 0.001" >> stdin
	echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	if [[ "$XCWONLY" != "true" && "$PLOT_TONTO" == "false" && "$POWDER_HAR" != "true" ]]; then
		echo "   ! Refine with regularized observed-density atom factors" >> stdin
		echo "   refine_hirshfeld_atoms" >> stdin
		echo "" >> stdin
	fi
}

SCF_BLOCK_REST_TONTO(){
	echo "   ! SC cluster charge SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_MOs= restricted" >> stdin
	if [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" || "$METHOD" == "rks" || "$METHOD" == "RKS" ]]; then
		echo "      kind= rks" >> stdin
	        echo "      output= true " >> stdin
		echo "      dft_exchange_functional= b3lypgx" >> stdin
		echo "      dft_correlation_functional= b3lypgc" >> stdin
	elif [[ "$METHOD" == "blyp" || "$METHOD" == "BLYP" ]]; then
		echo "      kind= rks" >> stdin
	        echo "      output= true " >> stdin
		echo "      dft_exchange_functional= becke88" >> stdin
		echo "      dft_correlation_functional= lyp" >> stdin
	else 
		echo "      kind= $METHOD" >> stdin
	        echo "      output= true " >> stdin
	fi
        if [[ "$LINEDEP" != "" ]]; then
	        echo "      linear_dependence_tol= $LINEDEP" >> stdin
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
	if [[ "$PLOT_TONTO" == "false" ]]; then
	        echo "   scf" >> stdin
	        echo "" >> stdin
        fi
	if [[ "$XCWONLY" != "true" && "$PLOT_TONTO" == "false" && "$POWDER_HAR" != "true" ]]; then
		echo "   ! Make Hirshfeld structure factors" >> stdin
		echo "   refine_hirshfeld_atoms" >> stdin
		echo "" >> stdin
	fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
		echo "   write_aim2000_wfn_file" >> stdin
		echo "" >> stdin
		echo "   put_cif" >> stdin
		echo "" >> stdin
	fi
}

REPORT_TONTO_HAR_CYCLE(){
    case "${SCFCALCPROG:-}" in
        CP2K|Tonto) return 0 ;;
    esac
    if [[ -n "${MAXSHIFT:-}" ]]; then
        printf 'Tonto HAR cycle %s complete: maximum shift/esd = %s\n' \
            "${J:-unknown}" "$MAXSHIFT"
    fi
}

SCF_TO_TONTO(){
	TONTO_HEADER
	if [ "$SCFCALCPROG" = "elmodb" ]; then
		READ_ELMO_FCHK
	fi
	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "optgaussian" && "$POWDER_HAR" == "true" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
	fi
	if [[ "$SCFCALCPROG" == "Gaussian" ||  "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "OCC" ]]; then
		READ_GAUSSIAN_FCHK
	elif [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then
		READ_ORCA_FCHK
#       elif [ "$SCFCALCPROG" = "Crystal14" ]; then
#	        READ_CRYSTAL_WFN
	else
		DEFINE_JOB_NAME
	fi
	echo "" >> stdin
	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" && "$POWDER_HAR" != "true" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
               if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                        TONTO_BASIS_SET
        	        CHARGE_MULT
        	        READ_CRYSTAL_WFN
               fi
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
		if ! TONTO_IAM_ONLY_INPUT; then
			TONTO_BASIS_SET
		fi
		if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
			COMPLETECIFBLOCK
		fi
	fi
#       if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#       	echo "   use_spherical_basis= TRUE" >> stdin
#               TONTO_BASIS_SET
#       fi
	if [[ "$DISP" == "yes" ]]; then 
		DISPERSION_COEF
	fi
        if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
		if ! TONTO_IAM_ONLY_INPUT; then
			CHARGE_MULT
		fi
        fi
	if [[ $J == 0 && "$IAMTONTO" == "true" ]]; then 
		TONTO_IAM_BLOCK
	fi
	CRYSTAL_BLOCK
       	PUT_GEOM
	if [[ "$POWDER_HAR" != "true" ]]; then
		if [[ "$USEBECKE" == "true" ]] && ! TONTO_OBSERVED_DENSITY_INPUT; then
        		BECKE_GRID
        	fi
        	if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
        		SCF_BLOCK_NOT_TONTO
        	fi
        fi
       	if [[ "$SCFCALCPROG" == "Tonto" ]]; then
		if TONTO_OBSERVED_DENSITY_INPUT; then
			SCF_BLOCK_OBSERVED_TONTO
		else
			SCF_BLOCK_PROM_TONTO
			SCF_BLOCK_REST_TONTO
		fi
       	fi
	echo "" >> stdin
	echo "}" >> stdin 
	J=$[ $J + 1 ]
	echo "Running Tonto, cycle number $J" 
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n $NUMPROCTONTO $TONTO	
	else
		$TONTO
	fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
                LABELS_IN_XYZ
        fi
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then
                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
	        	mkdir $J.tonto_cycle.$JOBNAME
                fi
		cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
		cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
		cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive_cov.cif
		sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
		sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
		cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
		cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
		cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
		cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
		cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
		cp $JOBNAME.residual_density,cell.cube $J.tonto_cycle.$JOBNAME/$J.residual_density,cell.cube
                if [[ "$POWDER_HAR" == "true" ]]; then
		        cp $JOBNAME.hkl $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.hkl
                fi
	fi
	INITIALCHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $2}')
#	MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print shift}')
#	MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print atom}')
#	MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$6; param=$7; max=$5}}END{print param}')
# this is getting the last value of the table, BUT! Its not correct to
# use the last value of the table because for every fit the last value
# will be smaller than the convergency criteria and then lamaGOET will
# stop. the fisrt value of the table must be read so we know that the
# wavefuntion is still the same and therefore no changes will happen
# in the geometry, this is an implicit way of checking that the
# convergency is also in the energy level. 
# correct
	# One pass over the last fit table, normalised for either layout.
	_fit_summary=$(FIT_TABLE_SUMMARY)
	MAXSHIFT=$(printf '%s' "$_fit_summary" | cut -f6)
	MAXSHIFTATOM=$(printf '%s' "$_fit_summary" | cut -f7)
	MAXSHIFTPARAM=$(printf '%s' "$_fit_summary" | cut -f8)
	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
		sed -i 's/(//g' $JOBNAME.xyz
		sed -i 's/)//g' $JOBNAME.xyz
	fi
	echo "Tonto cycle number $J ended"
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	REPORT_TONTO_HAR_CYCLE
	if [ $J = 1 ] && [[ "$SCFCALCPROG" == "Tonto" ]]; then
		# Tonto runs the whole refinement loop itself, so there are no
		# lamaGOET cycles to tabulate and the per-cycle table below would be
		# headers with nothing under them. Say where the numbers are instead.
		{
			echo "===================="
			echo "Refinement progress"
			echo "===================="
			echo ""
			echo "Tonto performs the refinement cycles internally, so there is no"
			echo "per-cycle table here. Its own least-squares iterations, and the"
			echo "results of each refinement, are in the sections below and in"
			echo "full in stdout."
			echo ""
		} >> $JOBNAME.lst
	elif [ $J = 1 ]; then
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
#	if [[ "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" && "$SCFCALCPROG" != "Crystal14" || "$SCFCALCPROG" != "OCC" ]]; then 
#		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t""    "$9" \t"$10 }' ) "  >> $JOBNAME.lst  
#	fi
	if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
	        	mkdir $J.tonto_cycle.$JOBNAME
                fi
		cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
		if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
			cp $JOBNAME.residual_density,cell.cube $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.residual_density,cell.cube
		fi
		if [[ "$SCFCALCPROG" != "optgaussian" ]]; then
	                if [ -f $JOBNAME.fractional.cif1 ]; then
#                       if [ -f $JOBNAME.cartesian.cif2 ]; then
				cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
				cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
				cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive_cov.cif
				sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
				sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
				cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
				cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
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
	_lamagoet_publish_latest_cif
}

TONTO_TO_GAUSSIAN(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for Gaussian cycle number $I"
	echo "%rwf=./$JOBNAME.rwf" >  $JOBNAME.com
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
                if [ "$SCDIPOLES" = "true" ]; then       
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                else
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;d+=3)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                fi
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
        cp Test.FChk $JOBNAME.fchk 
        sed -i '/^#/d' $JOBNAME.fchk
	echo "Gaussian cycle number $I ended"
	if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
		echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	if [[ "$USENOSPHERA2" == "true" && "$I" != "1" ]]; then
	        echo "Generation fcheck file for Gaussian cycle number $I"
#		awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
        sed -i '/^#/d' $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk 
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

TONTO_TO_CRYSTAL(){
	I=$[ $I + 1 ]
        if [[ "$SPACEGROUPHM" == "" ]]; then
                SPACEGROUPHM=$( awk '/_symmetry_space_group_name_H-M/ {print $0}' 0.tonto_cycle.$JOBNAME/0.$JOBNAME.cartesian.cif2 | sed "s/'/\:/g" | awk -F ":" '{print $2}' )
        fi
	CELLA=$(grep "a cell parameter ............" stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLB=$(grep "b cell parameter ............" stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLC=$(grep "c cell parameter ............" stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLALPHA=$(grep "alpha angle ................." stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLBETA=$(grep "beta  angle ................." stdout | head -1 | awk '{print $NF}'  | cut -f1 -d"(" )
	CELLGAMMA=$(grep "gamma angle ................." stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	echo "$JOBNAME"  > $JOBNAME.d12 
	echo "CRYSTAL"   >> $JOBNAME.d12
        SPACEGROUPITNUMBER=$(grep "_symmetry_Int_Tables_number" $CIF | tr -d \' | awk '{print $2}' | tr -d '\r')
	if [[ "$SPACEGROUPITNUMBER" == "" ]]; then
                SPACEGROUPITNUMBER=$(grep "_space_group_IT_number" $CIF | tr -d \' | awk '{print $2}' | tr -d '\r')
	        if [[ "$SPACEGROUPITNUMBER" == "" ]]; then
		        echo "ERROR: Space group number not found. Please enter the space group number in your cif with the keyword _symmetry_Int_Tables_number or _space_group_IT_number and restart your job" | tee -a $JOBNAME.lst
		        exit 1
                fi 
	fi
        if [[ "$USEHMSYM" == "true" ]];then 
	        echo "1 $XTALSETTING 0"     >> $JOBNAME.d12
                echo $SPACEGROUPHM >> $JOBNAME.d12
        else
	        echo "0 $XTALSETTING 0"     >> $JOBNAME.d12
                echo $SPACEGROUPITNUMBER  >> $JOBNAME.d12
        fi
        if (( $( bc <<< "$CELLALPHA == 90") )); then
                CELLALPHA2=""
        else
                CELLALPHA2=$CELLALPHA
        fi
        if (( $( bc <<< "$CELLBETA == 90") )); then
                CELLBETA2=""
        else
                CELLBETA2=$CELLBETA
        fi
        if (( $( bc <<< "$CELLGAMMA == 90") )); then
                CELLGAMMA2=""
        else
                CELLGAMMA2=$CELLGAMMA
        fi
        if (( $( bc <<< "$CELLA == $CELLB") )); then
                if (( $( bc <<< "$CELLB == $CELLC") )); then
                        CELLC=""
                fi
                if (( $( bc <<< "$CELLGAMMA == 120") )); then
                        CELLGAMMA2=""
                fi
                CELLB=""
        fi
        echo "$CELLA $CELLB $CELLC $CELLALPHA2 $CELLBETA2 $CELLGAMMA2"  >> $JOBNAME.d12
        sed '2d' $JOBNAME.xyz >> $JOBNAME.d12
#       cat $JOBNAME.xyz  >> $JOBNAME.d12
#       echo "MOLECULE"  >> $JOBNAME.d12
        echo "KEEPSYMM"  >> $JOBNAME.d12
        echo "NOSHIFT"  >> $JOBNAME.d12
        if [[ "$SUPERCON" == "true" ]]; then
                echo "SUPERCON"  >> $JOBNAME.d12
                echo "1. 0. 0."  >> $JOBNAME.d12
                echo "0. 1. 0."  >> $JOBNAME.d12
                echo "0. 0. 1."  >> $JOBNAME.d12
        fi
#       echo "1"  >> $JOBNAME.d12
#       echo "1 0 0 0"  >> $JOBNAME.d12
        if [[ "$GAUSGEN" == "true" || "$BASISSETG" == "gen" ]]; then
                echo "END"  >> $JOBNAME.d12
                cat basis_gen.txt >>  $JOBNAME.d12
                echo "99 0"  >> $JOBNAME.d12
                echo "ENDBS"  >> $JOBNAME.d12
        else
                echo "BASISSET"  >> $JOBNAME.d12
                echo "$BASISSETG"  >> $JOBNAME.d12
        fi
        if [[ "$METHOD" != "rhf" ]]; then
                if [[ "$METHOD" == "uhf" ]]; then
                        echo "$METHOD"  >> $JOBNAME.d12
                else
                        echo "DFT"  >> $JOBNAME.d12
                        echo "$METHOD"  >> $JOBNAME.d12
                        echo "END"  >> $JOBNAME.d12
                fi
        fi
##      echo "END"  >> $JOBNAME.d12 is this extra??
#       echo "XLGRID"  >> $JOBNAME.d12
#       echo "SCFDIR"  >> $JOBNAME.d12
#       echo "BIPOSIZE"  >> $JOBNAME.d12
#       echo "60000000"  >> $JOBNAME.d12
#       echo "EXCHSIZE"  >> $JOBNAME.d12
#       echo "40000000"  >> $JOBNAME.d12
        echo "SHRINK"  >> $JOBNAME.d12
        echo "$SHRINKA $SHRINKB"  >> $JOBNAME.d12
#       echo "LEVSHIFT"  >> $JOBNAME.d12
#       echo "6 1"  >> $JOBNAME.d12
#       echo "TOLINTEG"  >> $JOBNAME.d12
#       echo "7 7 7 7 25"  >> $JOBNAME.d12
        echo "TOLDEE"  >> $JOBNAME.d12
        echo "7"  >> $JOBNAME.d12
        if [[ "$MAXXTALCYCLE" != "" ]]; then
                echo "MAXCYCLE"  >> $JOBNAME.d12
                echo "$MAXXTALCYCLE"  >> $JOBNAME.d12
        fi
        if [[ $I -ge 2 && "$USEGUESS" == "true" ]]; then
		echo "GUESSP" >> $JOBNAME.d12
	fi
       	echo "END"  >> $JOBNAME.d12
#       I=$"1"
	echo "Running Crystal, cycle number $I" 
        if [[ "$NUMPROC" != "1" ]]; then
                cp $JOBNAME.d12 INPUT
        	mpirun -n $NUMPROC $SCFCALC_BIN >& $JOBNAME.out 	
        else
        	if [[ $I -ge 2 && "$USEGUESS" == "true" ]]; then
	        	$SCFCALC_BIN $JOBNAME $JOBNAME
		else
		        $SCFCALC_BIN $JOBNAME
		fi
        fi
	echo "Crystal cycle number $I ended"
        if [[ ! -f GenerateXML.d3  ]]; then
                echo "CRYAPI_OUT"  > GenerateXML.d3
	fi
        echo "Running Crystal properties, cycle number $I" 
        if [[ "$NUMPROC" != "1" ]]; then
                cp fort.9 $JOBNAME.f9
                cp fort.98 $JOBNAME.f98
                runPprop23 $NUMPROC GenerateXML $JOBNAME
        else
                runprop23 GenerateXML $JOBNAME
        fi
	echo "Crystal properties, cycle number $I ended" 
	if ! grep -q 'SCF ENDED - CONVERGENCE ON ENERGY' "$JOBNAME.out"; then
		echo "ERROR: Crystal job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
        if [[ "$I" == "1" ]]; then
                ENERGIA=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $4}')
                RMSD=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $5}' | sed 's/DE//g' )
        	echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
#       else
#       	echo "Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
        fi
	echo "" >> $JOBNAME.lst
#       echo "###############################################################################################" >> $JOBNAME.lst
	echo "Crystal cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
	        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.d12 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.d12
	cp $JOBNAME.f98 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.f98
	cp $JOBNAME.f9 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.f9
#       cp $JOBNAME.d3 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.d3
        gzip -k GenerateXML.XML
	mv GenerateXML.XML.gz $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.XML.gz
	cp $JOBNAME.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
}

GET_FREQ(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Gaussian cycle number $I"
	echo "%rwf=./$JOBNAME.rwf" >  $JOBNAME.com
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
#        echo $J
	awk 'NR>2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	if [ "$SCCHARGES" = "true" ]; then 
#                if [ ! -f gaussian-point-charges ]; then
#                	echo "" > gaussian-point-charges
#                	awk '/Cluster monopole charges and positions/{print p; f=1} {p=$0} /------------------------------------------------------------------------/{c=1} f; c--==0{f=0}' stdout >> gaussian-point-charges
#                	awk '{a[NR]=$0}{b=11}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
#                        echo "" >> $JOBNAME.com
#                else
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
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
        cp Test.FChk $JOBNAME.fchk 
        sed -i '/^#/d' $JOBNAME.fchk
	echo "Gaussian cycle number $I ended"
	if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
		echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "Generation fcheck file for Gaussian cycle number $I"
	if [[ "$USENOSPHERA2" == "true" ]]; then
#		awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
	        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
        sed -i '/^#/d' $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk 
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

GET_FREQ_ORCA(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Orca cycle number $I"
	if [ "$SCFCALCPROG" = "optorca" ]; then
		ORCAOPT=" Opt"
	fi
	if [[ "$SCFCALCPROG" == "optorca" && "$SCCHARGES" == "false" ]]; then
		ONLY_ONE=" Opt"
	fi
	if [ "$METHOD" = "rks" ]; then
		echo "! blyp $BASISSETG $ONLY_ONE FREQ" > $JOBNAME.inp
	else
		if [ "$METHOD" = "uks" ]; then
			echo "! ublyp $BASISSETG $ONLY_ONE FREQ" > $JOBNAME.inp
		else
			echo "! $METHOD $BASISSETG $ONLY_ONE FREQ" > $JOBNAME.inp
		fi
	fi
	echo "" >> $JOBNAME.inp
	echo "%pal nprocs $NUMPROC end" >> $JOBNAME.inp
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
	if [ "$SCCHARGES" = "true" ]; then 
		echo '% pointcharges "'$JOBNAME'.qxyz"'  >> $JOBNAME.inp
		sed -i '1,12{/.*/d}' cluster_charges 
		sed -i '$ d' cluster_charges
		sed -i -n '1~3p' cluster_charges 
		sed -i '{/^$/d}' cluster_charges 
		LINEONE=$(wc -l cluster_charges | awk '{print $1}')
		echo $LINEONE > $JOBNAME.qxyz
		awk '{printf " %12s  %12s %12s  %12s\n",$4,$1,$2,$3}' cluster_charges >> $JOBNAME.qxyz
                echo "" >> $JOBNAME.qxyz
		echo ""  >> $JOBNAME.inp
		if [[ "$ADDNUCINTER" == "true" ]]; then
			echo "%method" >> $JOBNAME.inp
			echo "   DoEQ true" >> $JOBNAME.inp
			echo "end"  >> $JOBNAME.inp
		fi
	fi
	echo "* xyz $CHARGE $MULTIPLICITY"  >> $JOBNAME.inp
	awk 'NR>2' $JOBNAME.xyz  >> $JOBNAME.inp
	if [ "$SCCHARGES" = "true" ]; then 
		echo ""  >> $JOBNAME.inp
	fi
	echo "*"  >> $JOBNAME.inp
	if [[ "$GAUSGEN" == "true" ]]; then
		cat basis_gen.txt >> $JOBNAME.inp
		echo "" >> $JOBNAME.inp
	fi
	echo "Running Orca, cycle number $I" 
        if [ -f $JOBNAME.gbw ]; then
                rm $JOBNAME.gbw
        fi
	$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
	echo "Orca cycle number $I ended"
	if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
		echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "Generation of molden file for Orca cycle number $I"
	if [[ "$(which orca_2mkl.exe)" == "" ]]; then
		orca_2mkl $JOBNAME -molden  > /dev/null
	else 	
		orca_2mkl.exe $JOBNAME -molden  > /dev/null
	fi
	echo "Generation of wfn file for Orca cycle number $I"
	if [[ "$(which orca_2aim.exe)" == "" ]]; then
		orca_2aim $JOBNAME  > /dev/null
	else
		orca_2aim.exe $JOBNAME  > /dev/null
	fi
        NUMATOMWFN=$(grep -m1 " Q " $JOBNAME.wfn | awk '{ print $2 }' )
        NUMATOMWFN=$[$NUMATOMWFN -1]
        awk -v  NUMATOMWFN=$NUMATOMWFN 'NR==2 {gsub($7, NUMATOMWFN, $0); print}1' $JOBNAME.wfn > temp.wfn
        sed -i '2d' temp.wfn
        sed -i '/ Q /d' temp.wfn
        mv temp.wfn $JOBNAME.wfn
	if [[ "$USENOSPHERA2" == "true" ]]; then
		#awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.inp          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
	cp $JOBNAME.qxyz         $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.qxyz
	cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
	cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

_har_abs_diff_le() {
	local first=$1
	local second=$2
	local tolerance=$3
	awk -v a="$first" -v b="$second" -v tol="$tolerance" '
		BEGIN {
			d = a - b
			if (d < 0) d = -d
			exit !(d <= tol)
		}
	'
}

_har_abs_value_le() {
	local value=$1
	local tolerance=$2
	awk -v value="$value" -v tol="$tolerance" '
		BEGIN {
			if (value < 0) value = -value
			exit !(value <= tol)
		}
	'
}

CHECK_WAVEFUNCTION_STALL(){
	local current_energy=$1
	local current_rmsd=$2
	local energy_tolerance=${HAR_ENERGY_REPEAT_TOL:-${CONVTOLE:-0.000001}}
	local rmsd_tolerance=${HAR_SCF_RMSD_TOL:-1.0e-7}
	local reason=""

	HAR_WAVEFUNCTION_STALLED=false
	if [[ -z "$current_energy" ]]; then
		return 0
	fi
	if [[ -n "${HAR_ENERGY_LAST:-}" ]] \
		&& _har_abs_diff_le "$current_energy" "$HAR_ENERGY_LAST" "$energy_tolerance"; then
		HAR_DIRECT_REPEAT_COUNT=$(( ${HAR_DIRECT_REPEAT_COUNT:-0} + 1 ))
		HAR_PERIOD2_REPEAT_COUNT=0
		if (( HAR_DIRECT_REPEAT_COUNT >= 2 )); then
			reason="the SCF energy repeated in consecutive cycles"
		fi
	elif [[ -n "${HAR_ENERGY_PREV2:-}" ]] \
		&& _har_abs_diff_le "$current_energy" "$HAR_ENERGY_PREV2" "$energy_tolerance"; then
		HAR_PERIOD2_REPEAT_COUNT=$(( ${HAR_PERIOD2_REPEAT_COUNT:-0} + 1 ))
		HAR_DIRECT_REPEAT_COUNT=0
		if (( HAR_PERIOD2_REPEAT_COUNT >= 2 )); then
			reason="the SCF energy entered a stable two-cycle oscillation"
		fi
	else
		HAR_DIRECT_REPEAT_COUNT=0
		HAR_PERIOD2_REPEAT_COUNT=0
	fi

	HAR_ENERGY_PREV2=${HAR_ENERGY_LAST:-}
	HAR_ENERGY_LAST=$current_energy
	if [[ -n "$reason" ]]; then
		HAR_WAVEFUNCTION_STALLED=true
		if [[ -n "$current_rmsd" ]] && ! _har_abs_value_le "$current_rmsd" "$rmsd_tolerance"; then
			echo "SCF RMSD $current_rmsd is above the diagnostic tolerance $rmsd_tolerance, but the SCF program terminated normally."
		fi
		echo "Refinement wavefunction is stationary: $reason (energy tolerance $energy_tolerance, RMSD ${current_rmsd:-unavailable})."
		echo "The HAR loop will stop and the final residual density will be calculated."
	fi
}

CHECK_ENERGY(){
	if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then 
		ENERGIA3=$ENERGIA
                ENERGIA2=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' | sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*HF=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
                RMSD2=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log | sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*RMSD=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
#		ENERGIA2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#		RMSD2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
		echo "Gaussian cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
	elif [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then
		ENERGIA2=$(sed -n '/FINAL SINGLE POINT ENERGY/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
		RMSD2=$(sed -n '/Last RMS-Density change/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
		echo "Orca cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
	elif [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                ENERGIA2=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $4}')
                RMSD2=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $5}' | sed 's/DE//g' )
	elif [[ "$SCFCALCPROG" == "OCC" ]]; then
		ENERGIA2=$(sed -n '/^total/p' $JOBNAME.out | awk '{print $2}' | tr -d '\r')
		RMSD2=$( awk '{a[NR]=$0}/restricted spinorbital SCF energy converged after/ {print a[NR-1]}' $JOBNAME.out | awk '{print $3}'| tr -d '\r')
	fi
	DE=$(awk "BEGIN {print $ENERGIA2 - $ENERGIA}")
	ABSDE=$(awk "function abs(x){return (( x < 0.0) ? -x : x)} BEGIN {print abs($ENERGIA2) - abs($ENERGIA)}")
	ABSDE2=$(awk "function abs(x){return (( x < 0.0) ? -x : x)} BEGIN {print abs($ENERGIA2) - abs($ENERGIA3)}")
	DE=$(printf '%.12f' $DE)
	# Cycle, fit iterations, chi2 before and after, R, R_w, largest
	# shift and where it was, parameter and eigenvalue counts.
	printf ' %s\t%s\t%s\t%s\t%s\t%s\t%s\t%s %s\t%s\t%s\t%s\t%s\t%s\n' \
		"$J" \
		"$(printf '%s' "$_fit_summary" | cut -f1)" \
		"$(printf '%s' "$_fit_summary" | cut -f2)" \
		"$(printf '%s' "$_fit_summary" | cut -f3)" \
		"$(printf '%s' "$_fit_summary" | cut -f4)" \
		"$(printf '%s' "$_fit_summary" | cut -f5)" \
		"$MAXSHIFT" "$MAXSHIFTATOM" "$MAXSHIFTPARAM" \
		"$(printf '%s' "$_fit_summary" | cut -f9)" \
		"$(printf '%s' "$_fit_summary" | cut -f10)" \
		"$ENERGIA2" "$RMSD2" "$DE" >> $JOBNAME.lst
	if [[ -z "${HAR_ENERGY_LAST:-}" && -n "${ENERGIA:-}" ]]; then
		HAR_ENERGY_LAST=$ENERGIA
	fi
	CHECK_WAVEFUNCTION_STALL "$ENERGIA2" "$RMSD2"
	ENERGIA=$ENERGIA2
	RMSD=$RMSD2
	echo "Delta E (cycle  $I - $[ I - 1 ]): $DE "
}


APPEND_IAM_RESULTS(){
	# Copy the starting IAM refinement into $JOBNAME.lst.
	#
	# Tonto heads the independent-atom-model refinement "IAM refinement" and
	# the Hirshfeld atom refinement "Structure refinement results". Only the
	# latter was ever copied into the summary, so a job started from a Tonto
	# IAM lost precisely the numbers it was started for: without the IAM there
	# is nothing to compare the HAR against, which is the entire reason for
	# running one. The results were in stdout all along, just not in the file
	# users are told holds the results.
	#
	# lamaGOET also looked for a "Rigid-atom fit results" heading. Current
	# Tonto does not emit that string at all, so those extractions were dead.
	[ -f stdout ] || return 0
	grep -q '^IAM refinement' stdout || return 0
	{
		echo ""
		echo "###############################################################################################"
		echo "                        Independent Atom Model (IAM) refinement                                 "
		echo "###############################################################################################"
		echo ""
		awk '/^IAM refinement/{copy=1}
		     copy && /^Final asymmetric unit parameter values:/{exit}
		     copy' stdout
	} >> $JOBNAME.lst
}

FIT_TABLE_SUMMARY(){
	# Emit one normalised, tab-separated record describing the last
	# least-squares fit in stdout:
	#
	#   iter  chi2_initial  chi2_final  R  R_w  max_shift  atom  param  N_p  N_eig
	#
	# Tonto prints one row per least-squares iteration and then a heading:
	# "IAM refinement" for the starting model, "Structure refinement results"
	# for a Hirshfeld atom refinement. It used to print "Rigid-atom fit
	# results", which lamaGOET looked for; that string no longer appears, so
	# every field below came out empty and the per-cycle table in the summary
	# had headers and no rows.
	#
	# The two tables also differ in shape. The IAM has ten columns and one
	# chi2; the HAR has twelve, leading with a cycle number and carrying both
	# an initial and a final chi2. Normalise here so the caller does not care.
	awk '
		/^IAM refinement$/ || /^Structure refinement results$/ ||
		/^Rigid-atom fit results$/ { heading = NR }
		{ line[NR] = $0 }
		END {
			if (!heading) exit
			for (i = heading - 1; i > 0; i--)
				if (line[i] ~ /^[ \t]*[0-9]+[ \t]/) { last = i; break }
			if (!last) exit
			for (i = last; i > 0; i--)
				if (line[i] !~ /^[ \t]*[0-9]+[ \t]/) { first = i + 1; break }

			maxshift = 0
			for (i = first; i <= last; i++) {
				n = split(line[i], f)
				if (n >= 12) { s = f[7]; a = f[9];  p = f[10] }
				else         { s = f[5]; a = f[7];  p = f[8]  }
				if (s < 0) s = -s
				if (s > maxshift) { maxshift = s; maxatom = a; maxparam = p }
			}

			n = split(line[last], f)
			if (n >= 12) { iter = f[2]; ci = f[3]; cf = f[4]; r = f[5]; rw = f[6] }
			else         { iter = f[1]; ci = f[2]; cf = f[2]; r = f[3]; rw = f[4] }

			printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
			       iter, ci, cf, r, rw, maxshift, maxatom, maxparam,
			       f[n-1], f[n]
		}
	' stdout
}

GET_RESIDUALS(){
	TONTO_HEADER
	DEFINE_JOB_NAME
	if [ "$SCFCALCPROG" = "elmodb" ]; then
		READ_ELMO_FCHK
	fi
	if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "OCC" ]]; then
		READ_GAUSSIAN_FCHK
	elif [ "$SCFCALCPROG" = "Orca" ]; then
		READ_ORCA_FCHK
#	elif [ "$SCFCALCPROG" = "Crystal14" ]; then
#		READ_CRYSTAL_WFN
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
	if [ "$SCFCALCPROG" = "Crystal14" ]; then
		TONTO_BASIS_SET
	fi
		CHARGE_MULT
	if [ "$SCFCALCPROG" = "Crystal14" ]; then
		READ_CRYSTAL_WFN
		CRYSTAL_BLOCK
		DEFINE_JOB_NAME
	fi
	# Rebuild the reflection/xray data before the final residual map. The
	# refined CIF carries the cell and geometry but not the reflection list,
	# so without this the map is calculated from incomplete data. Crystal14
	# has already done it immediately above.
	if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
		CRYSTAL_BLOCK
	fi
	if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
		echo "   scfdata= {" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" && "$METHOD" != "HF" ]]; then
	                if [[ "$METHOD" == "ub3lyp" || "$METHOD" == "UB3LYP" ]]; then
		                echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= uks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
	        		echo "      dft_correlation_functional= b3lypgc" >> stdin
	                elif [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" ]]; then
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
	        		echo "      dft_correlation_functional= b3lypgc" >> stdin
	                else
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
	        		echo "      dft_correlation_functional= b3lypgc" >> stdin
	                fi
			echo "      output= true " >> stdin
		else
	                if [[ "$METHOD" == "uhf" || "$METHOD" == "UHF" || "$METHOD" == "UKS" || "$METHOD" == "uks" ]]; then
		        	echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
	                elif [[ "$METHOD" == "rhf" || "$METHOD" == "RHF" || "$METHOD" == "RKS" || "$METHOD" == "rks" ]]; then
		        	echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
	                fi
			echo "      kind= $METHOD" >> stdin
			echo "      output= true " >> stdin
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
		echo "   assign_NOs_to_MOs " >> stdin
	fi
	echo "   make_structure_factors" >> stdin
	echo "" >> stdin
	echo "   put_minmax_residual_density" >> stdin
	echo "" >> stdin
        echo "   put_fitting_plots" >> stdin
#       echo "   plot_grid= {                           " >> stdin
#       echo "" >> stdin
#       echo "      kind= residual_density_map" >> stdin
#       echo "      use_unit_cell_as_bbox" >> stdin
#       echo "      desired_separation= 0.1 angstrom" >> stdin
#       echo "      plot_format= cell.cube" >> stdin
#       echo "      plot_units= angstrom^-3" >> stdin
#       echo "" >> stdin
#       echo "    }" >> stdin
#       echo "" >> stdin
#       echo "   plot" >> stdin
	echo "" >> stdin
	echo "}" >> stdin 
	echo "Calculating residual density at final geometry" 
	J=$[ $J + 1 ]
        rm -f stdout stde
        local tonto_status=0
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n "$NUMPROCTONTO" "$TONTO" || tonto_status=$?
	else
		"$TONTO" || tonto_status=$?
	fi
        # Validate the final residual calculation. Without this a failed run is
        # reported as a completed refinement.
        if [[ "$tonto_status" -ne 0 ]] || ! grep -q '^Unit cell residual density:' stdout 2>/dev/null; then
                echo "ERROR: final Tonto residual-density calculation failed; inspect stdin and stdout" | tee -a "$JOBNAME.lst" >&2
                return 1
        fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
                LABELS_IN_XYZ
        fi
        if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
        	mkdir $J.tonto_cycle.$JOBNAME
        fi
	cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
	cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
	cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
	cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
	cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME'.residual_density,cell.cube' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.residual_density,cell.cube
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
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n $NUMPROCTONTO $TONTO	
	else
		$TONTO
	fi
	echo "Tonto cycle number $J ended"
        if [ ! -d "$J.XCW_cycle.$JOBNAME" ]; then
	        mkdir $J.XCW_cycle.$JOBNAME
        fi
	cp stdin $J.XCW_cycle.$JOBNAME/$J.stdin
	cp stdout $J.XCW_cycle.$JOBNAME/$J.stdout
	cp $JOBNAME'.cartesian.cif2' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
	cp $JOBNAME'.fractional.cif1' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
	cp $JOBNAME'.archive.cif' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive_cov.cif
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
	cp $JOBNAME'.cartesian.cif2' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
	cp $JOBNAME'.fractional.cif1' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
	cp $JOBNAME'.archive.cif' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fcf' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp $JOBNAME'.archive.fco' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME.residual_density,cell.cube $J.XCW_cycle.$JOBNAME/$J.residual_density,cell.cube
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		exit 1
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
		exit 1
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
#echo "   read_archive molecular_orbitals restricted" >> stdin
	echo "   read_archive MOs r" >> stdin
#echo "   read_archive orbital_energies restricted" >> stdin
	echo "   read_archive MO_energies r" >> stdin
	echo "" >> stdin
			SCF_BLOCK_REST_TONTO
#	echo "   make_scf_density_matrix" >> stdin
#echo "   read_archive density_matrix restricted" >> stdin
	echo "   read_archive density_mx r" >> stdin
	echo "   assign_NOs_to_MOs " >> stdin
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
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n $NUMPROCTONTO $TONTO	
	else
		$TONTO
	fi
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		exit 1
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
	if [[ "$COMPLETESTRUCT" == "true" && "$EXPLICITMOL" == "true" ]]; then
		echo "   cluster= {" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$COMPLETESTRUCT" == "false" ]]; then
		        echo "      generation_method= within_radius" >> stdin
		        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
        		echo "      defragment= $DEFRAGEXPL" >> stdin
                elif [[ "$DOUBLEGROW" == "true" ]]; then
        		echo "      defragment= $COMPLETESTRUCT" >> stdin
                fi
		echo "      make_info" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   create_cluster" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin		
		echo "" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$DOUBLEGROW" == "true" ]]; then
		        echo "   put" >> stdin
        		echo "   put_cif" >> stdin
        		echo "   put_grown_cif" >> stdin
        		echo "" >> stdin
        		echo "}" >> stdin
        		echo "" >> stdin
                        $TONTO
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
	                        if [[ "$J" == "0" ]]; then 
        #                               cp $JOBNAME.cartesian.cif2 defrag.cif
                                        cp $JOBNAME.fractional.cif1 defrag.cif
                                        CIF=defrag.cif
                                fi
                        else
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
                        fi
	                        if [[ "$J" != "0" ]]; then 
                                        DOUBLEGROW=false
                                fi
                        TONTO_HEADER
                        PROCESS_CIF
                        DEFINE_JOB_NAME
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                		TONTO_BASIS_SET
                        fi
        	        echo "   cluster= {" >> stdin
                	echo "      generation_method= within_radius" >> stdin
        	        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
               		echo "      defragment= $DEFRAGEXPL" >> stdin
                	echo "      make_info" >> stdin
        	        echo "   }" >> stdin
        		echo "" >> stdin
                	echo "   create_cluster" >> stdin
        	        echo "" >> stdin
        		echo "   name= $JOBNAME" >> stdin		
                	echo "" >> stdin
               fi
	fi

	if [[ "$COMPLETESTRUCT" == "true" && "$EXPLICITMOL" == "false" ]]; then
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

	if [[ "$COMPLETESTRUCT" == "false" && "$EXPLICITMOL" == "true" ]]; then
		echo "   cluster= {" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$COMPLETESTRUCT" == "false" ]]; then
		        echo "      generation_method= within_radius" >> stdin
		        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
        		echo "      defragment= $DEFRAGEXPL" >> stdin
                elif [[ "$DOUBLEGROW" == "true" ]]; then
        		echo "      defragment= $COMPLETESTRUCT" >> stdin
                fi
		echo "      make_info" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   create_cluster" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin		
		echo "" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$DOUBLEGROW" == "true" ]]; then
		        echo "   put" >> stdin
        		echo "   put_cif" >> stdin
        		echo "   put_grown_cif" >> stdin
        		echo "" >> stdin
        		echo "}" >> stdin
        		echo "" >> stdin
                        $TONTO
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
	                        if [[ "$J" == "0" ]]; then 
        #                               cp $JOBNAME.cartesian.cif2 defrag.cif
                                        cp $JOBNAME.fractional.cif1 defrag.cif
                                        CIF=defrag.cif
                                fi
                        else
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
                        fi
                        if [[ "$J" != "0" ]]; then 
                                DOUBLEGROW=false
                        fi
                        TONTO_HEADER
                        PROCESS_CIF
                        DEFINE_JOB_NAME
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                		TONTO_BASIS_SET
                        fi
        	        echo "   cluster= {" >> stdin
                	echo "      generation_method= within_radius" >> stdin
        	        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
               		echo "      defragment= $DEFRAGEXPL" >> stdin
                	echo "      make_info" >> stdin
        	        echo "   }" >> stdin
        		echo "" >> stdin
                	echo "   create_cluster" >> stdin
        	        echo "" >> stdin
        		echo "   name= $JOBNAME" >> stdin		
                	echo "" >> stdin
               fi
	fi
}



run_script(){
	SECONDS=0
	if [ "$POWDER_HAR" = "true" ]; then
                NSA2_COUNTER=$"1"
                JANA_COUNTER=$"0" ###counter for powder HAR
                if [ ! -d "$JANA_COUNTER.Jana_cycle" ]; then
                        mkdir $JANA_COUNTER.Jana_cycle
                fi
                cp $JOBNAME.m40 $JANA_COUNTER.Jana_cycle/$JOBNAME.m40
                cp $JOBNAME.m41 $JANA_COUNTER.Jana_cycle/$JOBNAME.m41
                cp $JOBNAME.m70 $JANA_COUNTER.Jana_cycle/$JOBNAME.m70
                cp $JOBNAME.m50 $JANA_COUNTER.Jana_cycle/$JOBNAME.m50
                cp $JOBNAME.m90 $JANA_COUNTER.Jana_cycle/$JOBNAME.m90
                cp $JOBNAME.m80 $JANA_COUNTER.Jana_cycle/$JOBNAME.m80
                cp $JOBNAME.m83 $JANA_COUNTER.Jana_cycle/$JOBNAME.m83
                cp $JOBNAME.m85 $JANA_COUNTER.Jana_cycle/$JOBNAME.m85
                cp $JOBNAME.m95 $JANA_COUNTER.Jana_cycle/$JOBNAME.m95
                cp $JOBNAME.cif $JANA_COUNTER.Jana_cycle/$JOBNAME.cif
                python3 /usr/local/bin/powderHARstart.py
                python3 /usr/local/bin/powderHARcifrewrite.py
                JANA_COUNTER=$[$JANA_COUNTER+1]
        fi
	I=$"0"   ###counter for gaussian jobs
	J=$"0"   ###counter for tonto fits
	shopt -s nocasematch	

	if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" && "$POWDER_HAR" != "true" ]]; then 
		HKLEXT=$(echo $HKL | awk -F. '{print $NF}')
		if [[ "$HKLEXT" != "fcf" ]]; then
			# Convert raw SHELX HKLF records to five whitespace-separated
			# columns before adding the Tonto header. SHELX uses fixed widths
			# (4,4,4,8,8), so l and I can legitimately touch. Stop at the
			# 0 0 0 terminator and ignore any .ins/.cif text appended after it.
			if [[ -z "$(grep "reflection_data= {" "$HKL")" && "$WRITEHEADER" = "true" ]]; then
				if ! awk '
					BEGIN {
						number = "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([EeDd][+-]?[0-9]+)?$"
						seen = 0
					}
					{
						sub(/\r$/, "")
						if (length($0) < 12) {
							if (seen) exit
							next
						}
						hs = substr($0,1,4); ks = substr($0,5,4); ls = substr($0,9,4)
						gsub(/[[:space:]]/,"",hs); gsub(/[[:space:]]/,"",ks); gsub(/[[:space:]]/,"",ls)
						if (hs !~ /^[+-]?[0-9]+$/ || ks !~ /^[+-]?[0-9]+$/ || ls !~ /^[+-]?[0-9]+$/) {
							if (seen) exit
							next
						}
						h = hs + 0; k = ks + 0; l = ls + 0
						if (h == 0 && k == 0 && l == 0) exit
						obs = substr($0,13,8); sig = substr($0,21,8)
						gsub(/[[:space:]]/,"",obs); gsub(/[[:space:]]/,"",sig)
						if (obs !~ number || sig !~ number) {
							if (seen) exit 2
							next
						}
						gsub(/[dD]/,"E",obs); gsub(/[dD]/,"E",sig)
						print h, k, l, obs, sig
						seen = 1
					}
					END { if (!seen) exit 2 }
				' "$HKL" > "$JOBNAME.tonto_edited.hkl"; then
					echo "ERROR: Could not parse SHELX fixed-width reflections from $HKL" | tee -a "$JOBNAME.lst"
					rm -f "$JOBNAME.tonto_edited.hkl"
					exit 1
				fi
				cp "$HKL" "$JOBNAME.your_input.hkl"
				cp "$JOBNAME.tonto_edited.hkl" "$HKL"
				rm "$JOBNAME.tonto_edited.hkl"
				echo "WARNING: SHELX HKL was converted for Tonto; the original is $JOBNAME.your_input.hkl"
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
						exit 1
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
		else
			ISFCF=true
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
	if [[ ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "OCC") && "$SCCHARGES" == "true" ]]; then
		DOUBLE_SCF="true"
	fi 
	if [[ ("$SCFCALCPROG" == "Tonto" && "$POWDER_HAR" == "true") && "$SCCHARGES" == "true" ]]; then
		DOUBLE_SCF="true"
	fi 
	if [[ "$COMPLETESTRUCT" == "true" && "$EXPLICITMOL" == "true" ]]; then
		DOUBLEGROW="true"
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
	if [[ "$SCFCALCPROG" != "optgaussian" || "$SCFCALCPROG" != "optorca" ]]; then 
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
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
		echo "Becke grid (not default): $USEBECKE" >> $JOBNAME.lst
		if [[ "$USEBECKE" == "true" ]]; then
			echo "Becke grid accuracy	: $ACCURACY" >> $JOBNAME.lst
			echo "Becke grid pruning scheme	: $BECKEPRUNINGSCHEME" >> $JOBNAME.lst
		fi
	fi
	if [[ "$SCFCALCPROG" != "elmodb" ]]; then 
		echo "Use SC cluster charges 	: $SCCHARGES" >> $JOBNAME.lst
		if [ "$SCCHARGES" = "true" ]; then
			echo "SC cluster charge radius: $SCCRADIUS Angstrom" >> $JOBNAME.lst
			echo "Complete molecules	: $DEFRAG" >> $JOBNAME.lst
		fi
	fi
	echo "Refine position and ADPs: $POSADP" >> $JOBNAME.lst
	echo "Refine positions only	: $POSONLY" >> $JOBNAME.lst
	echo "Refine ADPs only	: $ADPSONLY" >> $JOBNAME.lst
	if [[ "$POSONLY" != "true" ]]; then
		echo "Refine H ADPs 		: $REFHADP" >> $JOBNAME.lst
		if [[ "$REFHADP" == "true" ]]; then
			echo "Refine Hydrogens isot.	: $HADP" >> $JOBNAME.lst
		fi
	fi
	echo "Dispersion correction	: $DISP" >> $JOBNAME.lst
	if [ $DISP = "yes" ]; then
		echo "			  $(cat DISP_inst.txt)" >> $JOBNAME.lst
	fi
	
	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then 
		echo "Only for Gaussian/Orca/OCC job	" >> $JOBNAME.lst
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
#               if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#               fi
		COMPLETECIFBLOCK
		echo "   put" >> stdin 
		echo "" >> stdin
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
                        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
                                	echo "   write_xyz_file" >> stdin
				else
	                                echo "   write_fragment_xyz_file " >> stdin
				fi
                        else 
                                echo "   write_xyz_file" >> stdin
                        fi
                else
                        echo "   write_xtal23_xyz_file" >> stdin
                fi
		echo "   put_cif" >> stdin
		if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" || "$SCFCALCPROG" == "OCC" ]]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		if [[ "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "optorca" ]];then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		echo "" >> stdin
		echo "}" >> stdin 
		echo "Reading cif with Tonto"
		if [[ "$NUMPROCTONTO" != "1" ]]; then
			mpirun -n $NUMPROCTONTO $TONTO	
		else
			$TONTO
		fi
		NUMBEROFATOMS=$(awk '/No. of atoms ............../ {print $5}' stdout )
	        if [[ "$USENOSPHERA2" == "true" ]]; then
                        LABELS_IN_XYZ
                fi
                #there is no refinement here yet!!!!!!
		if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
			sed -i 's/(//g' $JOBNAME.xyz
			sed -i 's/)//g' $JOBNAME.xyz
		fi
		if ! grep -q 'Wall-clock time taken' "stdout"; then
			echo "ERROR: something wrong with your input cif file, please check the stdout file for more details" | tee -a $JOBNAME.lst
			exit 1
		fi
                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
	        	mkdir $J.tonto_cycle.$JOBNAME
                fi
		if [[ ( "$SCFCALCPROG" == "optgaussian"  &&  "$SCCHARGES" == "false" ) || "$SCFCALCPROG" == "optorca"  &&  "$SCCHARGES" == "false" ]]; then 
			cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz
                else
			cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$JOBNAME.starting_geom.xyz
		fi
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
#               if [ -f $JOBNAME.cartesian.cif2 ]; then
                if [ -f $JOBNAME.fractional.cif1 ]; then
			cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
			cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
			sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
			sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
		fi
		awk '{a[NR]=$0}/^Atom coordinates/{b=NR}/^Unit cell information/{c=NR}END{for(d=b-1;d<=c-2;++d)print a[d]}' stdout >> $JOBNAME.lst
		echo "Done reading cif with Tonto"
#is this ok now?if [[ "$SCFCALCPROG" == "elmodb" && ! -z tonto.cell || "$SCFCALCPROG" == "optgaussian" && ! -z tonto.cell  ]]; then
		if [[ ( "$SCFCALCPROG" == "elmodb" && ! -f tonto.cell ) || ( "$SCFCALCPROG" == "optgaussian" && ! -f tonto.cell ) || ( "$SCFCALCPROG" == "optorca" && ! -f tonto.cell ) ]]; then
			CELLA=$(grep "a cell parameter ............" stdout | head -1 | awk '{print $NF}')
			CELLB=$(grep "b cell parameter ............" stdout | head -1 | awk '{print $NF}')
			CELLC=$(grep "c cell parameter ............" stdout | head -1 | awk '{print $NF}')
			CELLALPHA=$(grep "alpha angle ................." stdout | head -1 | awk '{print $NF}')
			CELLBETA=$(grep "beta  angle ................." stdout | head -1 | awk '{print $NF}')
			CELLGAMMA=$(grep "gamma angle ................." stdout | head -1 | awk '{print $NF}')
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
                if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
 	        	TONTO_TO_CRYSTAL
        		SCF_TO_TONTO
 	        	TONTO_TO_CRYSTAL
 	        	CHECK_ENERGY
                fi
		if [[ "$SCFCALCPROG" == "Gaussian" ]] || [[ "$SCFCALCPROG" == "optgaussian"  &&  "$SCCHARGES" == "true" ]]; then 
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Gaussian                                         " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "%rwf=./$JOBNAME.rwf" > $JOBNAME.com 
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
	                cp Test.FChk $JOBNAME.fchk
                        sed -i '/^#/d' $JOBNAME.fchk
			echo "Gaussian cycle number $I ended"
			if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
				echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
				exit 1
			fi
                        ENERGIA=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*HF=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
                        RMSD=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*RMSD=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
#			ENERGIA=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' |  grep "HF=" | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#			RMSD=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
#			echo "Generation fcheck file for Gaussian cycle number $I"
			echo "Gaussian cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
                        # waiting for Bjarke to write any hkl dummy
                        # file with the correct indices
			if [[ "$USENOSPHERA2" == "true" ]]; then
#				awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		                echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
                                if [[ "$SCCHARGES" != "true" ]]; then 
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
				        RUN_NOSPHERA2
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                                fi
			fi
                        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
	        	        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                        fi
			cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
			cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
                        sed -i '/^#/d' $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk 
			cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
			if [[ "$USENOSPHERA2" == "true" ]]; then
				cp $JOBNAME.wfn  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
                                if [[ "$SCCHARGES" != "true" ]]; then 
                                        RUN_JANA
                                fi
			fi
			SCF_TO_TONTO
			TONTO_TO_GAUSSIAN
			CHECK_ENERGY
#		elif [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then  
		elif [[ "$SCFCALCPROG" == "Orca" ]] || [[ "$SCFCALCPROG" == "optorca"  &&  "$SCCHARGES" == "true" ]]; then 
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Orca                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			if [[ "$SCFCALCPROG" == "optorca" ]]; then
				OPT="Opt"
			fi
			if [ "$METHOD" = "rks" ]; then
				echo "! blyp $BASISSETG " > $JOBNAME.inp
				echo "! blyp $BASISSETG " >> $JOBNAME.lst
			elif [ "$METHOD" = "uks" ]; then
				echo "! ublyp $BASISSETG " > $JOBNAME.inp
				echo "! ublyp $BASISSETG " >> $JOBNAME.lst
			else
				echo "! $METHOD $BASISSETG " > $JOBNAME.inp
				echo "! $METHOD $BASISSETG " >> $JOBNAME.lst
			fi
			echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "%pal nprocs $NUMPROC end" | tee -a $JOBNAME.inp $JOBNAME.lst
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
			if [[ "$GAUSGEN" == "true" ]]; then
				cat basis_gen.txt | tee -a $JOBNAME.inp $JOBNAME.lst
				echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			fi
			I=$"1"
			echo "Running Orca, cycle number $I" 
                        if [ -f $JOBNAME.gbw ]; then
                                rm $JOBNAME.gbw
                        fi      
	 		$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
			echo "Orca cycle number $I ended"
			if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
				echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
				exit 1
			fi
			ENERGIA=$(sed -n '/FINAL SINGLE POINT ENERGY/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
			RMSD=$(sed -n '/Last RMS-Density change/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "Generation molden file for Orca cycle number $I"
			if [[ "$(which orca_2mkl.exe)" == "" ]]; then
				orca_2mkl $JOBNAME -molden  > /dev/null
			else 
				orca_2mkl.exe $JOBNAME -molden  > /dev/null
			fi
			if [[ "$(which orca_2aim.exe)" == "" ]]; then
				orca_2aim $JOBNAME  > /dev/null
			else
				orca_2aim.exe $JOBNAME  > /dev/null
			fi
#			echo "Orca cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
# 			This is the first cycle, no charges here yet!!!
#                       NUMATOMWFN=$(grep -m1 " Q " $JOBNAME.wfn | awk '{ print $2 }' )
#                       NUMATOMWFN=$[$NUMATOMWFN -1]
#                       awk -v  NUMATOMWFN=$NUMATOMWFN 'NR==2 {gsub($7, NUMATOMWFN, $0); print}1' $JOBNAME.wfn > temp.wfn
#                       sed -i '2d' temp.wfn
#                       sed -i '/ Q /d' temp.wfn
#                       mv temp.wfn $JOBNAME.wfn
# 			This is the first cycle, no charges here yet!!!
#			NAPONE=$[ $NUMBEROFATOMS + 1 ]
#			STARTLINE=$(grep -n "  $NAPONE 0" $JOBNAME.molden.input | awk -F: '{print $1}')
#			ENDLINE=$(grep -n "\[5D\]" $JOBNAME.molden.input | awk -F: '{print $1}')
#			sed -i "$STARTLINE","$[ $ENDLINE - 1]"'{/.*/d;}' $JOBNAME.molden.input
#			sed -i '/Q\ /d' $JOBNAME.molden.input
			if [[ "$USENOSPHERA2" == "true" && "$SCCHARGES" != "true" ]]; then
		                echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
                                if [[ "$SCCHARGES" != "true" ]]; then 
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
				        RUN_NOSPHERA2
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                                fi
			fi
                        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
		                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                        fi
			cp $JOBNAME.inp          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
			cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
			cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
			if [[ "$USENOSPHERA2" == "true" && "$SCCHARGES" != "true" ]]; then
				cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
                                if [[ "$SCCHARGES" != "true" ]]; then 
                                        RUN_JANA
                                fi
			fi
			SCF_TO_TONTO
			TONTO_TO_ORCA
			CHECK_ENERGY
		fi
		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "optocc" ]]; then  
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting OCC                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			if [[ "$SCFCALCPROG" == "optocc" ]]; then
				OPT="Opt"
			fi
			I=$"1"
			echo "Running OCC, cycle number $I" 
			$SCFCALC_BIN scf $JOBNAME.xyz --method $METHOD --basis $BASISSETG -o fchk > $JOBNAME.out
			echo "OCC cycle number $I ended"
			if ! grep -q 'A job well done' "$JOBNAME.out"; then
				echo "ERROR: OCC job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
				exit 1
			fi
			ENERGIA=$(sed -n '/^total/p' $JOBNAME.out | awk '{print $2}' | tr -d '\r')
			RMSD=$( awk '{a[NR]=$0}/restricted spinorbital SCF energy converged after/ {print a[NR-1]}' $JOBNAME.out | awk '{print $3}'| tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "OCC cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
                        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
		                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                        fi
			cp $JOBNAME.xyz          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
#			cp $JOBNAME.owf.$JOBNAME.fchk $JOBNAME.fchk
#			cp $JOBNAME.owf.$JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
			cp $JOBNAME.owf.fchk     $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
			cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
        		if [ -f "cluster_charges" ]; then
				cp cluster_charges          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.cluster_charges
		        fi
			SCF_TO_TONTO
			TONTO_TO_OCC
			CHECK_ENERGY
		fi
		if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Crystal14"  ]]; then
			if [[ "$DOUBLE_SCF" == "true" ]]; then #I think this whole block is not necessary! need to test
				if [[ "$POWDER_HAR" == "true" ]]; then
                                        RUN_JANA
                                        WRITEXYZ
				        SCF_TO_TONTO
				        if [ "$SCFCALCPROG" = "Gaussian" ]; then  
					        TONTO_TO_GAUSSIAN
        				else 
	        				TONTO_TO_ORCA
		        		fi
                                        RUN_JANA
                                        WRITEXYZ
                                fi
               			SCF_TO_TONTO
				if [ "$SCFCALCPROG" = "Gaussian" ]; then  
					TONTO_TO_GAUSSIAN
				elif [ "$SCFCALCPROG" = "Orca" ]; then 
					TONTO_TO_ORCA
				elif [ "$SCFCALCPROG" = "OCC" ]; then
					TONTO_TO_OCC
				fi
				CHECK_ENERGY
			fi		
		        if [[ "$POWDER_HAR" == "true" ]]; then
				while (( $(echo "$(echo ${DE#-}) > $CONVTOLE" | bc -l) && $( echo  "$JANA_COUNTER <= $MAXPHARCYCLE" | bc -l ) )); do
#	                while (( $( echo "$JANA_COUNTER < $MAXPHARCYCLE" | bc -l )  )); do
                                        RUN_JANA
                                        if [[ "$SCCHARGES" == "true" ]]; then 
                                                WRITEXYZ
                                        fi
				        SCF_TO_TONTO
        				if [ "$SCFCALCPROG" = "Gaussian" ]; then  
	        			        TONTO_TO_GAUSSIAN
        	        		elif [ "$SCFCALCPROG" = "Orca" ]; then 
	                			TONTO_TO_ORCA
					elif [ "$SCFCALCPROG" = "OCC" ]; then
						TONTO_TO_OCC
	                		fi
				        CHECK_ENERGY
                                done
                        else
                                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then  
 		        	        while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) && $( echo "$J <= $MAXCYCLE" | bc -l )  )); do
# 		        	        while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $(echo "$(echo ${DE#-}) > $CONVTOLE" | bc -l) || $( echo "$J <= $MAXCYCLE" | bc -l ) )); do
                                                if [[ "${HAR_WAVEFUNCTION_STALLED:-false}" == "true" ]]; then
                                                        echo "Refinement ended because the wavefunction stopped changing."
                                                        break
                                                fi
				                if [[ $J -ge $MAXCYCLE ]]; then
				                	CHECK_ENERGY
        				        	echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
        				        	break
        				        fi
        				        SCF_TO_TONTO
        				        if [ "$SCFCALCPROG" = "Gaussian" ]; then  
        			        		TONTO_TO_GAUSSIAN
        				        elif [ "$SCFCALCPROG" = "Orca" ]; then  
        			        		TONTO_TO_ORCA
        				        elif [ "$SCFCALCPROG" = "OCC" ]; then  
        			        		TONTO_TO_OCC
        			        	fi
        			        	CHECK_ENERGY
        		        	done
                                 else 
#					echo "I AM IN THE FIRST LOOP XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#					echo maxshif $MAXSHIFT
#					echo convtol $CONVTOL
#					echo DE $DE
#					echo convtoleee $CONVTOLE
 		        	        while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $(echo "$(echo ${DE#-}) > $CONVTOLE" | bc -l) )); do
                                                if [[ "${HAR_WAVEFUNCTION_STALLED:-false}" == "true" ]]; then
                                                        echo "Refinement ended because the wavefunction stopped changing."
                                                        break
                                                fi
				                if [[ $J -ge $MAXCYCLE ]]; then
				                	CHECK_ENERGY
        				        	echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
        				        	break
        				        fi
        				        SCF_TO_TONTO
        			        	TONTO_TO_CRYSTAL
        			        	CHECK_ENERGY
#						echo "I AM HERE!!!"
        		        	done
					GET_RESIDUALS
                                 fi
                        fi
		fi
		if [[ "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "optorca" ]]; then
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
				if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
					GET_FREQ
				elif [[ "$SCFCALCPROG" == "optorca" ]]; then
					GET_FREQ_ORCA
				fi
			else
#     				ONLY_ONE="opt=calcfc"
     				ONLY_ONE="opt"
				if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
					GET_FREQ
				elif [[ "$SCFCALCPROG" == "optorca" ]]; then
					GET_FREQ_ORCA
				fi
			fi
		fi
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		APPEND_IAM_RESULTS
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Final Geometry                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "Energy= $ENERGIA2, RMSD= $RMSD2" >> $JOBNAME.lst
		echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then  
		        if [[ "$POWDER_HAR" != "true" && "$SCFCALCPROG" != "Crystal14" ]]; then  
			        GET_RESIDUALS
			        echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
                        fi
		        if [[ "$XWR" == "true" ]]; then
		        	RUN_XWR
        		fi
		elif [[ "$SCFCALCPROG" == "optgaussian" && "$SCCHARGES" == "true" ]]; then  
			SCF_TO_TONTO
			GET_FREQ
		elif [[ "$SCFCALCPROG" != "optorca" && "$SCCHARGES" == "true" ]]; then  
			SCF_TO_TONTO
			GET_FREQ_ORCA
		fi
		echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		DURATION=$SECONDS
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit
	elif [[ "$SCFCALCPROG" == "Tonto" ]]; then

                if [[  "$SCFCALCPROG" == "Tonto" && "$POWDER_HAR" == "true" ]]; then
		        SCF_TO_TONTO
		        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
		        RUN_NOSPHERA2
		        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                        RUN_JANA
        		while (( $( echo "$JANA_COUNTER < $MAXPHARCYCLE" | bc -l )  )); do
                #               echo "I am here again"
		                SCF_TO_TONTO
		                if [ "$POWDER_HAR" = "true" ]; then
		                        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
                		        RUN_NOSPHERA2
	                	        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                                        RUN_JANA
                                fi
                        done
                else
                        SCF_TO_TONTO
                fi
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		APPEND_IAM_RESULTS
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Final Geometry                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		# Tonto emits one "Structure refinement results" block per refinement,
		# so a job that starts from a Tonto IAM produces two: the IAM first,
		# then the Hirshfeld atom refinement. Record the FIRST match, not the
		# last, or the IAM block is dropped and the summary shows only the HAR
		# under lamaGOET's own "Begin rigid-atom fit" heading. Comparing the
		# two is the whole point of starting from an IAM.
		echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
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
			APPEND_IAM_RESULTS
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Final Geometry                                         " >> $JOBNAME.lst
				echo "###############################################################################################" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		        if [[ "$POWDER_HAR" != "true" ]]; then  
			        GET_RESIDUALS
			        echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
			        echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
                        fi
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
		        	if [[ "$USENOSPHERA2" == "true" ]]; then
		        		cp $JOBNAME.wfn  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
                                        RUN_JANA
		        	fi
		        	SCF_TO_TONTO
	        		GAMESS_ELMODB_OLD_PDB
			done
			echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			APPEND_IAM_RESULTS
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Final Geometry                                         " >> $JOBNAME.lst
				echo "###############################################################################################" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		        if [[ "$POWDER_HAR" != "true" ]]; then  
			        GET_RESIDUALS
			        echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
			        echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
                        fi
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

if [[ "$SCFCALCPROG" == "elmodb" && "$EXIT" == "OK" ]]; then
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

source ./job_options.txt

if [[ "$GAUSGEN" == "true" ]]; then
        if [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then
                # ORCA reads the external $DATA block appended to its input.
                BASISSETG=""
        elif [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then
                BASISSETG="gen"
        fi
fi

if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG="Gaussian"
	echo "SCFCALCPROG=\"$SCFCALCPROG\"" >> job_options.txt
        source ./job_options.txt
fi


if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
        if [[ ! -f "spacegroup.txt"  ]]; then
                echo "RUN_lamaGOET: Crystal23 requires spacegroup.txt from the submitting GUI." >&2
                echo "Open and resubmit the job with GUI_lamaGOET_qt.sh so the CIF setting is staged." >&2
                exit 1
        fi
        SPACEGROUP=$(cat spacegroup.txt | awk -F'=' '{print $2}' )
        SETTING=$(echo "$SPACEGROUP" | awk -F':' '{print $2}' | tr -d ' ')
        if [[ "$SETTING" == "r" ]]; then
                XTALSETTING=1
        else
                XTALSETTING=0
        fi
fi

run_script
