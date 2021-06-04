#! /usr/bin/bash
set -e # Exit if any command fails
unalias grep # only needed if grep is aliased .bashrc or similar

# Default names and paths (TO DO: use command line arguments)
name_server=test_vm # name of virtual machine
path_key=~/.ssh/id_rsa.pub # path of local SSH public key to be uploaded
name_key=mykey # key name once uploaded to NREC
security_group=SSH_ICMP_all # name of project's security group

# Create security group and rules (https://docs.nrec.no/security-groups.html)
if ! openstack security group list | grep -q "$security_group"; then
    openstack security group create --description "Allow incoming SSH and ICMP" $security_group
    openstack security group rule create --ethertype IPv4 --protocol icmp --remote-ip 0.0.0.0/0 $security_group
    openstack security group rule create --ethertype IPv4 --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0 $security_group
fi

# Upload public SSH key (https://docs.nrec.no/ssh.html)
if ! openstack keypair list | grep -q "$name_key"; then
    openstack keypair create --public-key $path_key $name_key
    echo "Public SSH key uploaded to NREC"
fi

# Instance creation (https://docs.nrec.no/create-virtual-machine.html)
if ! openstack server list | grep -q $name_server; then
    openstack server create --image "GOLD Ubuntu 20.04 LTS" \
                            --flavor m1.small \
                            --security-group $security_group \
                            --security-group default \
                            --key-name $name_key \
                            --nic net-id=dualStack $name_server
fi

# Get virtual machine's IP address and add it to SSH known hosts
address=`openstack server list | grep "$name_server" | grep -oP 'dualStack=\K([0-9\.]+)'`
ssh-keyscan -H $address >> ~/.ssh/known_hosts

# Install dependencies and clone repositories on virtual machine
scp {install_*.sh,requirements_*.txt,.vimrc} ubuntu@$address:~/
ssh ubuntu@$address chmod 700 install_*.sh
ssh ubuntu@$address ./install_dependencies.sh
ssh ubuntu@$address ./install_platform.sh

# Create, attach and mount storage volume
# TO DO

# Mount cluster storage via sshfs (needed to create data for new sites?)
# TO DO

# Print login information
echo "NREC machine IP address: $address"
echo "To login, type: ssh ubuntu@$address"
