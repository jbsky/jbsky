#!/bin/bash

######
#

chpasswd=/usr/sbin/chpasswd
addgroup=/usr/sbin/addgroup
adduser=/usr/sbin/adduser
mkfs=/usr/sbin/mkfs.ext4


## On remplie ces valeurs ##

TARGET_USER=newbe
USER_PASSWORD=password
DEPOT=mirror.local.domain
SSHKEY=""

## FIN ##

[[ $(/usr/bin/id -u) -ne 0 ]]&& echo "Not running as root" && exit -1
[[ "${TARGET_USER}" == "" ]] && exit 1
[[ "${USER_PASSWORD}" == "" ]] && exit 2
[[ "${DEPOT}" == "" ]] && exit 3
[[ "${SSHKEY}" == "" ]] && exit 4


adduser $TARGET_USER --shell /bin/bash \
   --gecos 'webmaster user' \
   --group \
   --disabled-password

useradd $TARGET_USER -s /bin/bash -p '*' -g webmaster

cat /proc/1/environ | tr '\0' '\n' |grep "container=lxc"

if [[ "$?" != "0" ]]; then
	# LXC = 0
	echo "none /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab 
	
	dd if=/dev/zero of=/var/tmp.partition bs=1024 count=500000
	${mkfs} /var/tmp.partition
	
	echo "/var/tmp.partition /tmp ext4 rw,nosuid,nodev,noexec,errors=remount-ro 0 1" >> /etc/fstab 

fi

################"
#
#	SSH
#
# install key :
mkdir -p /home/${TARGET_USER}/.ssh
cat >> /home/${TARGET_USER}/.ssh/authorized_keys << EOF
EOF
chown ${TARGET_USER}: /home/${TARGET_USER}/.ssh -R
###################################"
#
#	APT
#
# write source
cat > /etc/apt/sources.list << EOF
deb http://${DEPOT}/debian buster main contrib non-free
deb http://${DEPOT}/debian buster-updates main contrib non-free
deb http://${DEPOT}/debian buster-backports main contrib non-free

# security updates
deb http://security.debian.org buster/updates main contrib

EOF

# drop recommends & suggest

cat >> /etc/apt/apt.conf << EOF

APT::Install-Recommends "false";
APT::Install-Suggests "false";

EOF

apt update

apt install lsof curl sudo bash-completion wget -y 


${addgroup} admin
${adduser} ${TARGET_USER} admin
echo "%admin  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

${chpasswd} -c SHA512 -s 200000 <<<${TARGET_USER}:${USER_PASSWORD}




wget https://raw.githubusercontent.com/jbsky/jbsky/master/script/lbsa.sh
chmod +x ./lbsa.sh

	cat > /etc/ssh/sshd_config << EOF
ListenAddress 0.0.0.0
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 30
PermitRootLogin no
StrictModes yes
MaxAuthTries 4
MaxSessions 3
PubkeyAuthentication yes
HostbasedAuthentication no
IgnoreRhosts yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AllowAgentForwarding yes
AllowTcpForwarding no
X11Forwarding no
X11UseLocalhost yes
PermitTTY yes
PrintMotd no
PrintLastLog yes
UsePrivilegeSeparation yes
UseDNS no
MaxStartups 3
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server
RhostsRSAAuthentication no
DenyUsers root
DenyGroups root
Protocol 2
EOF


passwd -dl root
chage -E-1 root


chmod 600 /etc/ssh/moduli
chmod 600 /etc/ssh/sshd_config
chmod 600 /etc/ssh/ssh_config
chmod 600 /etc/ssh/ssh_host_rsa_key.pub
chmod 600 /etc/ssh/ssh_host_ecdsa_key.pub
chmod 600 /etc/ssh
chmod 600 /etc/gshadow-
chmod 600 /etc/group-
chmod 600 /etc/shadow-
chmod 600 /etc/passwd-
chgrp root /etc/shadow-
chgrp root /etc/gshadow-
