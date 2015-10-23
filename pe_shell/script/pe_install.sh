#!/usr/bin/env bash
# This bootstraps Puppet on CentOS 6.x
# It has been tested on CentOS 6.3 64bit

set -e

FILEDIR='/vagrant'
TARDIR="$FILEDIR/tar"
ANSWERDIR="$FILEDIR/answer"
WORKDIR='/tmp'
#PE_TAR='puppet-enterprise-3.8.0-el-7-x86_64.tar.gz'
#PE_TAR='puppet-enterprise-2015.2.0-el-7-x86_64.tar.gz'
PE_TAR='puppet-enterprise-2015.2.2-el-7-x86_64.tar.gz'
PE_ANSWERS='puppet-enterprise-answers'
#PE_INSTALLERDIR='puppet-enterprise-3.8.0-el-7-x86_64'
#PE_INSTALLERDIR='puppet-enterprise-2015.2.0-el-7-x86_64'
PE_INSTALLERDIR='puppet-enterprise-2015.2.2-el-7-x86_64'
PE_PORTS='80 443 4433 4435 8140 61613'

#REPO_URL="https://yum.puppetlabs.com/el/6.5/products/x86_64/puppetlabs-release-6-10.noarch.rpm"
#download_URL=https://pm.puppetlabs.com/cgi-bin/download.cgi?dist=el&rel=7&arch=x86_64&ver=latest

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if sudo systemctl | grep -q pe-puppetserver.service; then
# if which puppet > /dev/null 2>&1; then
  echo "Puppet is already installed...."
  exit 0
fi

# Copy files to /tmp directory
echo "Copy files to $WORKDIR...."
[ -f "$WORKDIR/$PE_TAR" ] || cp $TARDIR/$PE_TAR $WORKDIR/.
[ -f "$WORKDIR/$PE_ANSWERS" ] || cp $ANSWERDIR/$PE_ANSWERS $WORKDIR/.

# Change directory to working directory
echo "Changing to $WORKDIR directory...."
cd $WORKDIR 

# Set ownership and permissions
echo "Setting ownership and permissions on $WORKDIR/$PE_TAR and $WORKDIR/$PE_ANSWERS...."
chown root:root $WORKDIR/$PE_TAR
chown root:root $WORKDIR/$PE_ANSWERS
chmod 444 $WORKDIR/$PE_TAR
chmod 444 $WORKDIR/$PE_ANSWERS

# Set hostname in puppet enterprise answer file
echo 'Configuring Puppet Enterprise answer file with hostname....'
sed -i "s/<HOSTNAME>/$HOSTNAME/g" $WORKDIR/$PE_ANSWERS

# Add hostname and ip to /etc/hosts
echo 'Configuring /etc/hosts file....'
echo $1 $2 ${2%%.*} >> /etc/hosts
# if ! grep -q $HOSTNAME "/etc/hosts"; then
# IP_ADDRESS=$(ip a s enp0s8 | grep '/24' | cut -d / -f1 | awk '{print $2}')
# echo $IP_ADDRESS $HOSTNAME ${HOSTNAME%%.*} >> /etc/hosts
# fi

# Open ports in firewall
echo "Opening firewall ports...."
if systemctl status firewalld | grep disabled; then 
  systemctl enable firewalld
fi
if systemctl status firewalld | grep dead; then 
  systemctl start firewalld
fi
for i in $PE_PORTS; do
  firewall-cmd --zone=public --add-port=$i/tcp --permanent
done
firewall-cmd --reload

# Install puppet labs package repos
echo "Installing Puppet Labs package repos...."
yum localinstall http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm -y

# Install the additional packages
echo "Installing required packages...."
# yum install bc deltarpm hiera -y
yum install bc deltarpm httpd -y
systemctl enable httpd

# Extract files from tar ball
echo "Untaring the $PE_TAR file...." 
tar -zxvf $PE_TAR

# Install puppet enterprise
echo 'Installing Puppet Enterprise....'
cd $WORKDIR/$PE_INSTALLERDIR
START=$(date +%s.%N)
sudo ./puppet-enterprise-installer -A $WORKDIR/$PE_ANSWERS
END=$(date +%s.%N)
DIFF=$(echo "$END - $START" | bc)
echo "Time taken to run installer $DIFF seconds...."

# Install hiera for puppet enterprise
# echo "Adding hiera to puppet enterprise...."
# sudo /usr/local/bin/puppet resource package hiera ensure=installed

# Install puppet labs repo
# echo "Configuring PuppetLabs repo..."
# repo_path=$(mktemp)
# wget --output-document=${repo_path} ${REPO_URL} 2>/dev/null
# rpm -i ${repo_path} >/dev/null

# # Install Puppet...
# echo "Installing puppet"
# yum install -y puppet > /dev/null

echo "Puppet Enterprise installed!"