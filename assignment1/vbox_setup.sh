#!/bin/bash -x

# This is a shortcut function that makes it shorter and more readable
vbmg () { /mnt/c/Program\ Files/Oracle/VirtualBox/VBoxManage.exe "$@"; }

#Global constants
NET_NAME="NET_4640"
VM_NAME="4640"
NETWORK_IP="192.168.230.0/24"
VM_NETWORK_IP="192.168.230.10"
HOST_SSH_PORT="12022"
VM_SSH_PORT="22"
HOST_HTTP_PORT="12080"
VM_WEB_PORT="80"

# This function will clean the NAT network and the virtual machine
clean_all () {
    vbmg natnetwork remove --netname "${NET_NAME}"
    vbmg unregistervm "${VM_NAME}" --delete
}

# This function will create a network to attach to the virtual machine in addition to port forwarding
# ... host to machine ports.  Ensures DHCP is off.
create_network () {
    vbmg natnetwork add --netname "${NET_NAME}" --network "${NETWORK_IP}" --enable --dhcp off \
                        --port-forward-4 "ssh:tcp:[]:${HOST_SSH_PORT}:[${VM_NETWORK_IP}]:${VM_SSH_PORT}" \
                        --port-forward-4 "http:tcp:[]:${HOST_HTTP_PORT}:[${VM_NETWORK_IP}]:${VM_WEB_PORT}"
}

# This function will:
#   1.  Create a CentOS Linux VM
#   2.  Provision VM infrastructure (compute, storage) and network
#   3.  VDI specified within VM file directory
#   4.  Two types of storage controllers are created (optical, hdd); VDI attached to sata controller
create_vm () {
    vbmg createvm --name "${VM_NAME}" --ostype "RedHat_64" --register
    vbmg modifyvm ${VM_NAME} --cpus 1 --memory 1024 \
                             --nic1 natnetwork \
                             --natnetwork1 "${NET_NAME}" \
                             --audio none \

    VM_CONFIG_FILE=$(vbmg showvminfo "${VM_NAME}" | grep "Config file" | cut -d ':' -f2- | sed 's/^[[:space:]]*//g' | sed 's/\\/\//g' )
    VM_DIR=$(dirname "${VM_CONFIG_FILE}")
    
    vbmg createmedium disk --format VDI --filename "${VM_DIR}/${VM_NAME}.vdi"  --size 10000
    
    vbmg storagectl "${VM_NAME}" --name "IDE" --add ide --controller PIIX4 --portcount 2 \
                                 --bootable on

    vbmg storagectl "${VM_NAME}" --name "SATA" --add sata --controller IntelAhci --portcount 30 \
                                 --bootable on

    vbmg storageattach "${VM_NAME}" --storagectl IDE --port 1 --device 0 --medium emptydrive

    vbmg storageattach "${VM_NAME}" --storagectl SATA --port 0 --device 0 --medium "${VM_DIR}/${VM_NAME}.vdi" --type hdd
}

echo "Starting script..."

clean_all
create_network
create_vm

echo "DONE!"