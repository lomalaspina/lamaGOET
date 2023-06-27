#!/bin/bash

sudo cp llama.png /usr/local/include/
sudo apt-get install gtk+-2.0 -y
sudo apt-get install libgtk2.0-dev -y
sudo apt-get install gtkdialog -y
sudo apt-get install gawk -y
sudo apt-get install zenity -y
cd gtkdialog-0.8.3
cd src
cp gtkdialog gtkdialog_pre_compiled
cd ..
./configure
make
sudo make install
cd ..
LOCALDIR=$(pwd)
cd /usr/local/bin
if test -f "gtkdialog"; then
    echo "gtkdialog compiled correctly."
else 
    sudo ln -s $LOCALDIR/gtkdialog-0.8.3/src/gtkdialog_pre_compiled gtkdialog
fi
sudo ln -s $LOCALDIR/lamaGOET.sh lamaGOET
sudo ln -s $LOCALDIR/RUN_lamaGOET_release.sh RUN_lamaGOET
sudo ln -s $LOCALDIR/GUI_lamaGOET_release.sh GUI_lamaGOET
##sudo ln -s $LOCALDIR/hklfromm80.py hklfromm80.py
##sudo ln -s $LOCALDIR/projectioninputfromhar.py projectioninputfromhar.py 
#sudo ln -s $LOCALDIR/powderHARstart.py powderHARstart.py
#sudo ln -s $LOCALDIR/powderHARcifrewrite.py powderHARcifrewrite.py
cd $LOCALDIR
