#!/bin/bash

# This script will run on host machine through WSL to:
#     1.  Call vbox_setup.sh to create the virtual box and provision the network/infrastructure
#     2.  Start the PXE server
#     3.  Copy over the necessary files to the PXE server
#     4.  Boot the TODO virtual machine
#     5.  Turn off the PXE server when installation is complete

# This is a shortcut function that makes it shorter and more readable
VBM_PATH=$(which VBoxManage.exe)
vbmg () { "${VBM_PATH}" "$@"; }

# Global Constants
export NET_NAME="NET_4640"
export APP_SERVER_NAME="TODO"
PXE_SERVER_NAME="PXE_4640"
PXE_SSH_HOST_CONFIG_NAME="pxe"
APP_SSH_HOST_CONFIG_NAME="todoapp"
TODO_VM_PK_NAME="admin_id_rsa.pub"

# Check to see if vm is up and available.  Blocks further script execution until, virtual machine is up.
function wait_vm_startup {
    local host_config_name=$1
    while /bin/true; do
        ssh -o ConnectTimeout=2 -q "${host_config_name}" exit
        if [ $? -ne 0 ]; then
            echo "${host_config_name} server is not up, sleeping..."
            sleep 2
        else
            echo "${host_config_name} server up"
            break
        fi
    done
}

# Check that the PXE server is connected to the NAT network before starting
function start_pxe_server () {
    vbmg showvminfo "${PXE_SERVER_NAME}" | grep "${NET_NAME}"
    if [[ $? -ne 0 ]]; then
        echo "PXE server is not connected to the right NAT network: ${NET_NAME}"
        echo "Modifying now.."
        vbmg modifyvm "${PXE_SERVER_NAME}" --natnetwork1 "${NET_NAME}"
    else
        echo "PXE is connected to: ${NET_NAME}"
    fi
    echo "Starting PXE server"
    vbmg startvm "${PXE_SERVER_NAME}"
}

# Wait for PXE server to be up and available
# Copy over the necessary files to the PXE server
function setup_pxe_environment () {
    wait_vm_startup "${PXE_SSH_HOST_CONFIG_NAME}"

    # Transfer SSH public key 
    scp ~/.ssh/"${TODO_VM_PK_NAME}" "${PXE_SSH_HOST_CONFIG_NAME}":/var/www/lighttpd/files/
    if [ $? -eq 0 ]; then
        echo "Private key transferred"
    else  
        echo "Private key failed to transfer"
        vbmg controlvm ${PXE_SERVER_NAME} acpipowerbutton
    fi

    # Transfer kickstart file
    scp ./setup/ks.cfg "${PXE_SSH_HOST_CONFIG_NAME}":/var/www/lighttpd/files/
    if [ $? -eq 0 ]; then
        echo "Kickstart file transferred"
    else
        echo "Kickstart file failed to transfer"
        vbmg controlvm ${PXE_SERVER_NAME} acpipowerbutton
    fi
}

# Boot the TODO virtual machine and install CentOS7
# Turn off PXE server when installation is complete
function pxe_install () {
    vbmg startvm "${APP_SERVER_NAME}"
    wait_vm_startup "${APP_SSH_HOST_CONFIG_NAME}"
    vbmg controlvm ${PXE_SERVER_NAME} acpipowerbutton
}

# Main script execution

echo "Starting Service Setup script..."

# Create the TODO virtual machine, connected to the NET_4640 network, ready to boot from the network
./setup/vbox_setup.sh

# Install CentOS from PXE server
start_pxe_server
setup_pxe_environment
pxe_install

# Install application on TODO virtual machine, restart when install is complete
./setup/vm_setup.sh
vbmg controlvm "${APP_SERVER_NAME}" reset

echo "Service Setup completed!"

# Remove exported global variables
unset NET_NAME
unset APP_SERVER_NAME

exit 0