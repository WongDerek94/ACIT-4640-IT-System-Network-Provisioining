#!/bin/bash -x

# This script will run on host machine through WSL to:
#     1.  Create the virtual box and provision the network/infrastructure

# This is a shortcut function that makes it shorter and more readable
VBM_PATH=$(which VBoxManage.exe)
vbmg () { "${VBM_PATH}" "$@"; }

# Global constants
NETWORK_IP="192.168.230.0/24"
VM_NETWORK_IP="192.168.230.10"
PXE_NETWORK_IP="192.168.230.200"
HOST_TO_PXE_SSH_PORT="12222"
HOST_TO_TODO_SSH_PORT="12022"
VM_SSH_PORT="22"
HOST_HTTP_PORT="12080"
VM_WEB_PORT="80"

# clean_all will clean the NAT network and the virtual machine
clean_all () {
    vbmg natnetwork remove --netname "${NET_NAME}"
    vbmg unregistervm "${APP_SERVER_NAME}" --delete 2>/dev/null
}

# create_network will create a network to attach to the virtual machine in addition to port forwarding
# ... host to machine ports.  Ensures DHCP is off.
create_network () {
    vbmg natnetwork add --netname "${NET_NAME}" --network "${NETWORK_IP}" --enable --dhcp off \
                        --port-forward-4 "ssh-todo:tcp:[]:${HOST_TO_TODO_SSH_PORT}:[${VM_NETWORK_IP}]:${VM_SSH_PORT}" \
                        --port-forward-4 "http:tcp:[]:${HOST_HTTP_PORT}:[${VM_NETWORK_IP}]:${VM_WEB_PORT}" \
                        --port-forward-4 "ssh-pxe:tcp:[]:${HOST_TO_PXE_SSH_PORT}:[${PXE_NETWORK_IP}]:${VM_SSH_PORT}"
}

# create_vm will:
#   1.  Create a CentOS Linux VM
#   2.  Provision VM infrastructure (compute, storage) and network
#   3.  VDI specified within VM file directory
#   4.  Two types of storage controllers are created (optical, hdd); VDI attached to sata controller
create_vm () {
    vbmg createvm --name "${APP_SERVER_NAME}" --ostype "RedHat_64" --register
    vbmg modifyvm ${APP_SERVER_NAME} --cpus 1 --memory 1536 \
                             --nic1 natnetwork \
                             --natnetwork1 "${NET_NAME}" \
                             --audio none \
                             --boot1 disk \
                             --boot2 net \
                             --boot3 none

    VM_CONFIG_FILE=$(vbmg showvminfo "${APP_SERVER_NAME}" | grep "Config file" | cut -d ':' -f2- | sed 's/^[[:space:]]*//g' | sed 's/\\/\//g' )
    VM_DIR=$(dirname "${VM_CONFIG_FILE}")
    
    vbmg createmedium disk --format VDI --filename "${VM_DIR}/${APP_SERVER_NAME}.vdi"  --size 10000
    
    vbmg storagectl "${APP_SERVER_NAME}" --name "IDE" --add ide --controller PIIX4 --portcount 2 \
                                 --bootable on

    vbmg storagectl "${APP_SERVER_NAME}" --name "SATA" --add sata --controller IntelAhci --portcount 30 \
                                 --bootable on

    vbmg storageattach "${APP_SERVER_NAME}" --storagectl IDE --port 1 --device 0 --medium emptydrive

    vbmg storageattach "${APP_SERVER_NAME}" --storagectl SATA --port 0 --device 0 --medium "${VM_DIR}/${APP_SERVER_NAME}.vdi" --type hdd
}

echo "Starting Provisioining script..."

clean_all
create_network
create_vm

echo "Provisioning Completed!"
exit 0