#!/bin/bash -x
#	bsky.fr\Note sur k8s
#	https://raw.githubusercontent.com/jbsky/jbsky/master/script/k8s-lxc-install.sh
#
#	Modifier TARGET_USER et VERSION

TARGET_USER=newbe
VERSION="5:19.03.5~3-0~debian-buster"

install=(
	resolvconf
	apt-transport-https
	ca-certificates
	curl
	gnupg2
	software-properties-common

)

swapoff -a
[[ "${TARGET_USER}" == "" ]] && exit 1
[[ "${VERSION}" == "" ]] && exit 2

apt-get update && apt install ${install[@]} --no-install-recommends -y

echo "Installation Docker..."

curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
 
apt-get update && apt-get install docker-ce=${VERSION} docker-ce-cli=${VERSION} containerd.io -y




# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker



adduser ${TARGET_USER} docker


apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl


cat > /usr/local/bin/kmsg << EOF
#!/bin/bash
ln -s /dev/console /dev/kmsg
EOF
chmod +x /usr/local/bin/kmsg
cat > /etc/systemd/system/kmsg.service << EOF
[Service]
ExecStart=/usr/local/bin/kmsg
EOF
systemctl enable kmsg.service
systemctl start kmsg.service
