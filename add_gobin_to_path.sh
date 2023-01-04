#!/bin/bash
#script automatically adds go/bin to path saving you some time
# Check if the path is already set in the .bashrc file
if grep -Fxq 'export PATH=$PATH:~/go/bin' ~/.bashrc
then
  # The path is already set, do nothing
  :
else
  # The path is not set, add it to the .bashrc file
# Add /home/user/go/bin to the PATH environment variable
  echo 'export PATH=$PATH:/home/user/go/bin' >> ~/.bashrc
  echo 'export PATH=$PATH:/home/user/go/bin' >> ~/.zshrc
fi
# Reload the Bash and Zsh shells to apply the changes
source ~/.bashrc
source ~/.zshrc


