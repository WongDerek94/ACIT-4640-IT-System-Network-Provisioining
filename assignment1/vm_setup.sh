#!/bin/bash -x

# This script will be run from WSL to:
# 1.  securely transfers the files necessary for application setup
# 2.  connects via SSH to the virtual machine using user admin to run the installation script

echo "Starting VM Setup Script"

# Copy over setup files and run installation script on vm
scp -r ./setup admin@todoapp:~/setup

#  SSH using admin with SSH key
ssh -t todoapp 'cd ~/setup && ./install_script.sh && exit; exec $SHELL'

echo "Setup Script completed"