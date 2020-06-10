#!/bin/bash

DIR=$(pwd)

# Install libvirt kvm
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils wget

CIRROS_IMAGE_VER='0.4.0'
CIRROS_IMAGE_FILE="cirros-${CIRROS_IMAGE_VER}-x86_64-disk.img"
CIRROS_IMAGE_URL="http://download.cirros-cloud.net/${CIRROS_IMAGE_VER}/${CIRROS_IMAGE_FILE}"

# Download cirros image
if [ ! -f $CIRROS_IMAGE_FILE ]; then
  wget -O "${CIRROS_IMAGE_FILE}" "$CIRROS_IMAGE_URL"
fi

# create libvirt domain xml
cat <<EOF | tee nested-kvm.xml
<domain type='kvm'>
  <name>nested-kvm-001</name>
  <vcpu>2</vcpu>
  <memory unit='M'>64</memory>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <boot dev='hd'/>
  </os>
  <clock offset='utc'/>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file="${DIR}/${CIRROS_IMAGE_FILE}"/>
      <target dev='hda' bus='ide'/>
    </disk>
    <graphics type='vnc' port='5900' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <serial type='pty'>
      <target port='0'/>
      <alias name='serial0'/>
    </serial>
  </devices>
</domain>
EOF

# create & start VM
tmp=$(sudo virsh list --all | grep nested-kvm-001 | awk '{print $2}')
if [ "x$tmp" == "xnested-kvm-001" ]; then
  while true; do
    echo "Found exsiting VM nested-kvm-001."
    read -p "Do you want to DESTROY the existing VM and contitue(y/n)? " yn
    case $yn in
      [Yy]*) sudo virsh destroy nested-kvm-001; break;;
      [Nn]*) exit;;
      *) echo "Please answer yes or no.";;
    esac
  done
fi
sudo virsh create nested-kvm.xml

# check if VM created
tmp=$(sudo virsh list --all | grep nested-kvm-001 | awk '{print $2}')
if [ "x$tmp" == "x" ]; then
  echo "FAILURE! VM nested-kvm-001 is not created!"
  exit 1
fi

# check if VM is in running state
sleep 2
tmp=$(sudo virsh list --all | grep nested-kvm-001 | awk '{print $3}')
if [ "x$tmp" = "xrunning" ]; then
  echo "Success. Please use the following command to connect to console"
  echo "sudo virsh console nested-kvm-001"
else
  echo "FAILURE! VM nested-kvm-001 is not in running state!"
  echo "---------------------------------"
  echo "QEMU log is:"
  sudo cat /var/log/libvirt/qemu/nested-kvm-001.log
  exit 1
fi


