#!/bin/bash

# Check if the path is already set in the .bashrc file
if grep -Fxq 'export PATH=$PATH:~/go/bin' ~/.bashrc
then
  # The path is already set, do nothing
  :
else
  # The path is not set, add it to the .bashrc file
  echo 'export PATH=$PATH:~/lorde/go/bin' >> ~/.bashrc
fi

# Reload the .bashrc file to apply the changes
source ~/.bashrc

#this script automatically adds go/bin to path
#

