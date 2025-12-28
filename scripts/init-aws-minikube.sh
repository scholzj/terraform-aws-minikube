#!/bin/bash

exec &> /var/log/init-aws-minikube.log

set -o verbose
set -o errexit
set -o pipefail

export KUBEADM_TOKEN=${kubeadm_token}
export DNS_NAME=${dns_name}
export IP_ADDRESS=${ip_address}
export CLUSTER_NAME=${cluster_name}
export AWS_REGION=${aws_region}
export ADDONS="${addons}"
export KUBERNETES_VERSION="${kubernetes_version}"
export KUBERNETES_REPO_VERSION="v1.35"
export CRIO_VERSION="1.35.0"
export CRIO_REPO_VERSION="v1.35"

# Set this only after setting the defaults
set -o nounset

# We needed to match the hostname expected by kubeadm an the hostname used by kubelet
LOCAL_IP_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FULL_HOSTNAME="$(curl -s http://169.254.169.254/latest/meta-data/hostname)"

# Make DNS lowercase
DNS_NAME=$(echo "$DNS_NAME" | tr 'A-Z' 'a-z')

########################################
########################################
# Install CRI-O
########################################
########################################
cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_REPO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_REPO_VERSION/rpm/repodata/repomd.xml.key
EOF

dnf install -y container-selinux cri-o-$CRIO_VERSION

systemctl enable crio
systemctl start crio

swapoff -a
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sysctl --system

########################################
########################################
# Install Kubernetes components
########################################
########################################
sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_REPO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_REPO_VERSION/rpm/repodata/repomd.xml.key
EOF

yum install -y kubectl kubelet-$KUBERNETES_VERSION kubeadm-$KUBERNETES_VERSION kubernetes-cni

# Start services
systemctl enable kubelet
systemctl start kubelet

########################################
########################################
# Install Helm
########################################
########################################

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

########################################
########################################
# Initialize the Kube cluster
########################################
########################################

# Initialize the master
cat >/tmp/kubeadm.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
bootstrapTokens:
  - groups:
      - system:bootstrappers:kubeadm:default-node-token
    token: $KUBEADM_TOKEN
    ttl: 0s
    usages:
      - signing
      - authentication
nodeRegistration:
  criSocket: unix:///var/run/crio/crio.sock
  imagePullPolicy: IfNotPresent
  kubeletExtraArgs:
    - name: cloud-provider
      value: external
    - name: read-only-port
      value: "10255"
  name: $FULL_HOSTNAME
  taints:
    - effect: NoSchedule
      key: node-role.kubernetes.io/master
localAPIEndpoint:
  advertiseAddress: $LOCAL_IP_ADDRESS
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
apiServer:
  certSANs:
    - $DNS_NAME
    - $IP_ADDRESS
    - $LOCAL_IP_ADDRESS
    - $FULL_HOSTNAME
  extraArgs:
    - name: feature-gates
      value: "ImageVolume=true,InPlacePodVerticalScaling=true"
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager:
  extraArgs:
    - name: cloud-provider
      value: external
    - name: feature-gates
      value: "ImageVolume=true,InPlacePodVerticalScaling=true"
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
kubernetesVersion: v$KUBERNETES_VERSION
networking:
  dnsDomain: cluster.local
  podSubnet: 172.16.0.0/16
  serviceSubnet: 10.96.0.0/12
scheduler:
  extraArgs:
    - name: feature-gates
      value: "ImageVolume=true,InPlacePodVerticalScaling=true"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
featureGates:
  ImageVolume: true
  InPlacePodVerticalScaling: true
---
EOF

kubeadm reset --force
kubeadm init --config /tmp/kubeadm.yaml

# Use the local kubectl config for further kubectl operations
export KUBECONFIG=/etc/kubernetes/admin.conf

# Allow all apps to run on master
kubectl taint nodes --all node-role.kubernetes.io/master-

# Allow load balancers to route to master
kubectl label nodes --all node-role.kubernetes.io/master-

# Allow loadbalancers to route to master nodes
kubectl label nodes --all node.kubernetes.io/exclude-from-external-load-balancers-

########################################
########################################
# Install Flannel networking
########################################
########################################
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
helm upgrade --install --repo https://flannel-io.github.io/flannel/ flannel --set podCidr="172.16.0.0/16" --namespace kube-flannel flannel

########################################
########################################
# Install the AWS Cloud Provider and CSI driver
########################################
########################################

# AWS Cloud provider
kubectl create -f https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/aws-cloud-provider/aws-cloud-provider.yaml
# The Helm chart currently does not work due to outdated RBAC
# helm install --repo https://kubernetes.github.io/cloud-provider-aws --set "image.tag=v1.32.1,args={--v=2,--cloud-provider=aws,--use-service-account-credentials=true,--configure-cloud-routes=false}" aws-cloud-controller-manager aws-cloud-controller-manager
kubectl rollout status daemonset aws-cloud-controller-manager -n kube-system --timeout 300s

# AWS CSI Driver
helm upgrade --install --repo https://kubernetes-sigs.github.io/aws-ebs-csi-driver --namespace kube-system aws-ebs-csi-driver aws-ebs-csi-driver

# Create the Storage Class
cat <<EOF | kubectl apply -f -
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: aws-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
  csi.storage.k8s.io/fstype: xfs
reclaimPolicy: Delete
allowVolumeExpansion: true
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: aws-gp2
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp2
  encrypted: "true"
  csi.storage.k8s.io/fstype: xfs
reclaimPolicy: Delete
allowVolumeExpansion: true
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: aws-st1
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: st1
  encrypted: "true"
  csi.storage.k8s.io/fstype: xfs
reclaimPolicy: Delete
allowVolumeExpansion: true
---
EOF

########################################
########################################
# Create user and kubeconfig files
########################################
########################################

# Allow the user to administer the cluster
kubectl create clusterrolebinding admin-cluster-binding --clusterrole=cluster-admin --user=admin

# Prepare the kubectl config file for download to client (IP address)
export KUBECONFIG_OUTPUT=/home/ec2-user/kubeconfig_ip
kubeadm kubeconfig user --client-name admin --config /tmp/kubeadm.yaml > $KUBECONFIG_OUTPUT
chown ec2-user:ec2-user $KUBECONFIG_OUTPUT
chmod 0600 $KUBECONFIG_OUTPUT

cp /home/ec2-user/kubeconfig_ip /home/ec2-user/kubeconfig
sed -i "s/server: https:\/\/.*:6443/server: https:\/\/$IP_ADDRESS:6443/g" /home/ec2-user/kubeconfig_ip
sed -i "s/server: https:\/\/.*:6443/server: https:\/\/$DNS_NAME:6443/g" /home/ec2-user/kubeconfig
chown ec2-user:ec2-user /home/ec2-user/kubeconfig
chmod 0600 /home/ec2-user/kubeconfig

########################################
########################################
# Install addons
########################################
########################################
for ADDON in $ADDONS
do
  curl $ADDON | envsubst | bash
done
