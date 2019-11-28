#!/bin/bash

sudo cp llama.png /usr/local/include/
sudo apt-get install gtk+-2.0 -y
sudo apt-get install libgtk2.0-dev -y
sudo apt-get install gtkdialog -y
sudo apt-get install gawk -y
sudo apt-get install zenity -y
cd gtkdialog-0.8.3
./configure
make
sudo make install
cd ..
LOCALDIR=$(pwd)
cd /usr/local/bin
sudo ln -s $LOCALDIR/lamaGOET lamaGOET
cd $LOCALDIR
