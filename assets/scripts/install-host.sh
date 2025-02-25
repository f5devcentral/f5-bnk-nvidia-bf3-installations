#!/bin/bash

set -euo pipefail

DEBUG=0

if [[ ${DEBUG} -eq 1 ]]; then
  set -x
fi

# defaults

# Change the MGMT_NET variable to the management network CIDR
# that will include both the host mgmt IP and DPU oob_net0 mgmt IP.
MGMT_NET="10.144.0.0/16"

# Change this variable to point to the correct PF1 interface
# name on the host.
PF_INT=enp83s0f1np1
VF_INT=${PF_INT/%np1/v0}

DOCA_VERSION=2.9.1
K8S_VERSION="1.29"
CONTAINERD_VERSION="1.7.23"
RUNC_VERSION="1.2.1"


arch=$(uname -m)
case "$arch" in
x86_64)
    ARCH="amd64"
    ;;
aarch64)
    ARCH="arm64"
    ;;
*)
    echo "Unsupported system architecture: $arch"
    exit 1
    ;;
esac


install_doca_all() {
  for f in $( dpkg --list | awk '/doca/ {print $2}' ); do
    echo "Uninstalling package $f"
    apt remove --purge "$f" -y || true
  done
  /usr/sbin/ofed_uninstall.sh --force || true
  apt-get -y autoremove
  DOCA_URL="https://linux.mellanox.com/public/repo/doca/2.9.1/ubuntu22.04/$arch/"
  curl https://linux.mellanox.com/public/repo/doca/GPG-KEY-Mellanox.pub | gpg --yes --dearmor > /etc/apt/trusted.gpg.d/GPG-KEY-Mellanox.pub
  echo "deb [signed-by=/etc/apt/trusted.gpg.d/GPG-KEY-Mellanox.pub] $DOCA_URL ./" > /etc/apt/sources.list.d/doca.list
  apt-get update
  apt-get -y install rshim
  systemctl enable rshim --now
  cat << EONETPLAN > /etc/netplan/50-tmfifo.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    tmfifo_net0:
      dhcp4: no
      addresses:
        - 192.168.100.1/30
EONETPLAN
  chmod 600 /etc/netplan/50-tmfifo.yaml
  netplan apply
  sleep 5
}

configure_virtual_function() {
  # TODO: add script to automatically discover PFs and adds a virtual
  # function to pf1.
  cat << EOFVFCONF > /etc/netplan/10-vf-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $PF_INT:
      dhcp4: no
      virtual-function-count: 1
    $VF_INT:
      link: $PF_INT
      dhcp4: no
      addresses:
        - 192.168.20.41/24
EOFVFCONF
  chmod 600 /etc/netplan/10-vf-config.yaml
  netplan apply
  sleep 5
}

install_runc() {
    curl -LO https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$ARCH
    install -m 755 runc.$ARCH /usr/local/sbin/runc

}

install_containerd() {
    mkdir -p /etc/containerd
    curl -LO https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-$ARCH.tar.gz

    tar Czxvf /usr/local/ containerd-$CONTAINERD_VERSION-linux-$ARCH.tar.gz

    /usr/local/bin/ctr oci spec > /etc/containerd/cri-base.json
    cat << EOL > /etc/containerd/config.toml
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"
oom_score = 0
[grpc]
  max_recv_message_size = 16777216
  max_send_message_size = 16777216
[debug]
  address = ""
  level = "info"
  format = ""
  uid = 0
  gid = 0
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.10"
    max_container_log_line_size = 16384
    enable_unprivileged_ports = false
    enable_unprivileged_icmp = false
    enable_selinux = false
    disable_apparmor = false
    tolerate_missing_hugetlb_controller = true
    disable_hugetlb_controller = true
    image_pull_progress_timeout = "5m"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      snapshotter = "overlayfs"
      discard_unpacked_layers = true
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          runtime_engine = ""
          runtime_root = ""
          base_runtime_spec = "/etc/containerd/cri-base.json"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            systemdCgroup = true
            binaryName = "/usr/local/sbin/runc"
EOL

    curl -L -o /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    systemctl daemon-reload
    systemctl enable --now containerd
}

install_kubernetes_components() {
    apt-get update && apt-get install -y apt-transport-https ca-certificates curl gpg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
    cat << EOL > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv6.conf.default.forwarding=1
fs.inotify.max_user_watches=2099999999
fs.inotify.max_user_instances=2099999999
fs.inotify.max_queued_events=2099999999
EOL
    sysctl --system
    echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
    modprobe br_netfilter
    swapoff -a
    sed -i.backup '/swap/d' /etc/fstab
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    systemctl enable --now kubelet
}


init_kubernetes() {
    kubeadm init --pod-network-cidr=10.244.0.0/16
    mkdir -p $HOME/.kube
    cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    kubectl get node
    echo "Installing Calico CNI ..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
    cat << EOFCALICO | kubectl apply -f -
---
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - name: default-ipv4-ippool
      blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
    bgp: Disabled
    nodeAddressAutodetectionV4:
      cidrs:
      - "$MGMT_NET"
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOFCALICO
    # Wait for Calico system to start installation and create the calico-system namespace.
    sleep 30
    kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
    kubectl get pod --all-namespaces
    echo "Adding node annotation for internal static route"
    for node in $(kubectl get node -o name); do
      kubectl annotate --overwrite $node 'k8s.ovn.org/node-primary-ifaddr={"ipv4":"192.168.20.41"}'
    done
    kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
    kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s
    cat << 'EOSRIOVCONF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sriovdp-config
  namespace: kube-system
data:
  config.json: |
    {
        "resourceList": [
            {
                 "resourceName": "bf3_p0_sf",
                  "resourcePrefix": "nvidia.com",
                  "deviceType": "auxNetDevice",
                  "selectors": [{
                      "vendors": ["15b3"],
                      "devices": ["a2dc"],
                      "pciAddresses": ["0000:03:00.0"],
                      "pfNames": ["p0#1"],
                      "auxTypes": ["sf"]
                  }]
              },
              {
                 "resourceName": "bf3_p1_sf",
                  "resourcePrefix": "nvidia.com",
                  "deviceType": "auxNetDevice",
                  "selectors": [{
                      "vendors": ["15b3"],
                      "devices": ["a2dc"],
                      "pciAddresses": ["0000:03:00.1"],
                      "pfNames": ["p1#1"],
                      "auxTypes": ["sf"]
                  }]
              }
        ]
    }
EOSRIOVCONF
    kubectl apply -f https://raw.github.com/k8snetworkplumbingwg/sriov-network-device-plugin/master/deployments/sriovdp-daemonset.yaml
    kubectl patch daemonset kube-sriov-device-plugin -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"effect": "NoSchedule", "operator": "Exists"}]}]'

    helm repo add jetstack https://charts.jetstack.io --force-update
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.1 --set crds.enabled=true --set featureGates=ServerSideApply=true
    cat << 'EOFCERTMGRCONF' | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
    name: selfsigned-cluster-issuer
spec:
    selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
    name: bnk-ca
    namespace: cert-manager
spec:
    isCA: true
    commonName: bnk-ca
    secretName: bnk-ca
    issuerRef:
        name: selfsigned-cluster-issuer
        kind: ClusterIssuer
        group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
    name: bnk-ca-cluster-issuer
spec:
  ca:
    secretName: bnk-ca
EOFCERTMGRCONF

    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
    kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s

}


export DEBIAN_FRONTEND=noninteractive

trap 'unset DEBIAN_FRONTEND' ERR EXIT

# 1. Install DOCA software
install_doca_all

# 2. Install runc
install_runc

# 3. Install containerd
install_containerd

# 4. Install and init Kubernetes
install_kubernetes_components

# 5. Init Kubernetes Controller node and install required services.
init_kubernetes

# 6. Configure virtual function on PF1
configure_virtual_function

echo "======================"
echo "Installation complete."

unset DEBIAN_FRONTEND
