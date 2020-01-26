#!/bin/bash

LOGIN_USER="admin"
APP_USER="todoapp"


# This script will be run from WSL to:
# 1.  securely transfer the files necessary for application setup
# 2.  connect via SSH to the virtual machine using user admin to run the installation script

echo "Starting VM Setup Script"

# Copy over setup files and run installation script on vm
scp -r ./setup "${LOGIN_USER}@${APP_USER}:~/"

#  SSH using admin with SSH key
ssh -t "${APP_USER}" 'cd ~/setup && sudo ./install_script.sh && exit; exec $SHELL'

echo "Setup Script completed"
exit 0