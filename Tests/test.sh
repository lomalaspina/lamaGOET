#!/bin/bash

J=0	
while :
do
echo $J
J=$[ $J + 1]
echo $J
if [[ $J -gt 50 ]];then
	echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
	break
fi
done
echo "I print this"
