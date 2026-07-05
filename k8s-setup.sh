#!/usr/bin/env bash
#
# k8s-setup.sh — Bootstrap a Kubernetes node with kubeadm + CRI-O on Ubuntu
#
# Usage:
#   sudo NODE_ROLE=master ./k8s-setup.sh
#   sudo NODE_ROLE=node   ./k8s-setup.sh
#
# (If NODE_ROLE isn't set, you'll be prompted for it.)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo $0)"
  exit 1
fi

NODE_ROLE="${NODE_ROLE:-}"
if [[ -z "$NODE_ROLE" ]]; then
  read -p "Node role (master/node): " NODE_ROLE
fi

echo "Prepare host for k8s"
apt update &> /dev/null
apt-get install curl apt-transport-https git iptables-persistent -y &> /dev/null

mkdir -p /etc/apt/keyrings

cat > /etc/modules-load.d/k8s.conf <<EOF
br_netfilter
overlay
EOF

modprobe br_netfilter
modprobe overlay

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "Install container runtime"
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list
apt update &> /dev/null
apt install -y cri-o &> /dev/null

echo "Install k8s tools"
VERSION="v1.34.0"
KUBERNETES_VERSION=1.34

wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin

curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt update &> /dev/null
apt install -y kubelet kubeadm kubectl &> /dev/null
systemctl enable crio &> /dev/null
systemctl start crio.service > /dev/null

if [[ "$NODE_ROLE" == "master" ]]; then
  kubeadm init --pod-network-cidr=10.244.0.0/16 &> /dev/null
  INIT_CMD=$(kubeadm token create --print-join-command)
  read -p "HOME PATH: " USER_HOME
  read -p "USER NAME: " USER_NAME
  read -p "USER GROUP: " USER_GROUP
  mkdir -p $USER_HOME/.kube
  cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  chown $USER_NAME:$USER_GROUP $USER_HOME/.kube/config
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.25.7/Documentation/kube-flannel.yml
  echo "$INIT_CMD"
elif [[ "$NODE_ROLE" == "node" ]]; then
  read -p "JOIN COMMAND: " JOIN_CMD
  eval "$JOIN_CMD"
else
  echo "Wrong role"
  exit 1
fi

