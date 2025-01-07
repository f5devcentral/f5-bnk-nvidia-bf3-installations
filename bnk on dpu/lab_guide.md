# F5 Titan BIG-IP Next for Kubernetes Install Instructions on Nvidia BlueField-3

- [F5 Titan BIG-IP Next for Kubernetes Install Instructions on Nvidia BlueField-3](#f5-titan-big-ip-next-for-kubernetes-install-instructions-on-nvidia-bluefield-3)
  - [Introduction](#introduction)
  - [BIG-IP Next for Kubernetes Overview](#big-ip-next-for-kubernetes-overview)
    - [Data Plane (TMM)](#data-plane-tmm)
    - [Control Plane](#control-plane)
  - [Lab Setup and Prerequisites](#lab-setup-and-prerequisites)
    - [Deployment Strategy](#deployment-strategy)
    - [Hardware](#hardware)
      - [AUX Cable](#aux-cable)
      - [Network Optics](#network-optics)
      - [GPU (Optional)](#gpu-optional)
      - [DPU](#dpu)
    - [Software Prerequisites](#software-prerequisites)
  - [Installation Steps](#installation-steps)
    - [Prepare the Hosts](#prepare-the-hosts)
      - [Install DOCA Software](#install-doca-software)
      - [Configure Rshim service and interface.](#configure-rshim-service-and-interface)
      - [Configure Virtual Function on host](#configure-virtual-function-on-host)
      - [Install Kubernetes Prerequisites](#install-kubernetes-prerequisites)
      - [Prepare for DPU Install](#prepare-for-dpu-install)
    - [Configure Kubernetes Cluster](#configure-kubernetes-cluster)
    - [Install BIG-IP Next for Kubernetes](#install-big-ip-next-for-kubernetes)

## Introduction

This guide will help you setup and install F5 BIG-IP Next for
Kubernetes (BIG-IP Next for Kubernetes) on a platform with an Nvidia BlueField-3 DPU.

The NVIDIA DOCA™ Framework enables rapidly creating and managing
applications and services on top of the BlueField networking platform,
leveraging industry-standard APIs. For more information please refer to [DOCA Documentation](https://docs.nvidia.com/doca/sdk/nvidia+doca+overview/index.html).

## BIG-IP Next for Kubernetes Overview

BIG-IP Next for Kubernetes consists of two primary components:

1. **Data Plane**: Handling traffic processing and rules.
2. **Control Plane**: Monitors the Kubernetes cluster state and dynamically updates the Data Plane components.

### Data Plane (TMM)
At the heart of Data Plane is the Traffic Management Microkernel (TMM). Which is responsible for processing network traffic entering and leaving the Kubernetes cluster, as well as integrating with the infrastructure beyond the cluster.
The TMM and it's supporting components are deployed on the Nvidia BlueField-3 (BF3) DPU, fully utilizing its resources and offload engine, and freeing the CPU resources on the host for other tasks.

### Control Plane
The Control Plane runs on the Host CPU worker node or generic workload worker nodes. It also acts as a controller for Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/)

## Lab Setup and Prerequisites

The following section describes implementation details for a lab setup.

### Deployment Strategy
For the purpose of this document, the diagram below illustrates a high-level deployment strategy for BIG-IP Next for Kubernetes on Nvidia BlueField-3 DPU. It assumes a specific Nvidia BlueField-3 networking configuration, utilizing Scalable Functions, Virtual Functions, and Open vSwitch (OVS) to connect the DPU, Host, and external uplink ports.

This lab guide configures a single Kubernetes cluster that includes Hosts and DPUs as worker nodes. It assumes that one of the hosts will act as a Kuberentes controller (and allows workload deployment) while other hosts and DPUs join the cluster as worker nodes.


![bnk-lab-diagram](media/nvidia_bnk_lab_diagram.svg)

There are three main networks in the diagram:\
**Management Network:** The main underlay network for the Kubernetes cluster CNI and has the default gateway to reach internet. Both Host and the Nvidia BF-3 DPU are connected to this network and has addresses configured through DHCP.\
**Internal Network:** Represents an internal network path between the host deployed services and the BNK Dataplane deployed in the DPU. This network will be utilized to route ingress and egress traffic for workload deployed on the host through BNK Dataplane.\
**External Network:** The external network represents an "external-to-the-cluster" infrastructure network segment to reach external services/destinations.

The Test Servers represent clients and servers that are reachable on different segments of the network.\
>_This could also be a single server connected to both Internal and External networks_

### Hardware

This lab guide was tested on the following hardware configurations:
>Note: The hardware list below serves as example for tested platforms. Only one of those or any other Nvidia DPU-3 compatible system is required for this guide.\
>**Note: The Test Servers are not included.**


**DELL Poweredge R750 (AMD64)**

> RAM: 512GB \
> CPU: 96 Cores \
> Storage: 21TB

**Supermicro LB26-R16R12 (ARM64)**

> RAM: 128GB \
> CPU: 96 Cores \
> Storage: 20TB

**Supermicro HGX AS-4125GS-TNRT (AMD64)**

> RAM: 768GB
> CPU: 128 Cores
> Storage: 12TB

**Supermicro MGX ARS-111GL-NHR (ARM64) Supermicro**

> RAM: 512GB \
> CPU: 72Cores \
> Storage: 1.5TB

#### AUX Cable

>**HGX :** Part Numbers - CBL-PWEX-1040 and CBL-PWEX-1148-20
\
>**MGX :** Part Number - CBL-PWEX-1040

The following aux power cable parts also were tested on the Dell servers: \
[Amazon.com: BestParts New 12Pin to 8+8](https://www.amazon.com/BestParts-Compatible-PowerEdge-R750XS-16inches/dp/B0BKKBXQVH) \
[Pin GPU Power Cable Compatible with Dell PowerEdge R750 R750XS R7525 Server 16inches DPHJ8 : Electronics](https://www.amazon.com/BestParts-Compatible-PowerEdge-R750XS-16inches/dp/B0BKKBXQVH)

#### Network Optics

The following network optics were tested on the DPU ports.

**MGX & HGX :** 200Gb SR4 Ethernet Only - [NVIDIA Ethernet MMA1T00-VS Compatible QSFP56 200GBASE-SR4 850nm 100m DOM MPO12/UPC MMF Optical Transceiver Module, Support 4 x 50G-SR - FS.com](https://www.fs.com/products/139695.html)

**Dell R750 :** [F5 Networks F5-UPG-QSFP28-SR4 Compatible QSFP28 100GBASE-SR4 850nm](https://www.fs.com/products/84350.html?attribute=60343&id=3526322) \
[100m DOM MPO-12/UPC MMF Optical Transceiver Module, Support 4 x 25G-SR - FS.com](https://www.fs.com/products/84350.html?attribute=60343&id=3526322)

#### GPU (Optional)

**HGX** = Nvidia H100 (x86)

**MGX** = NVIDIA GH200 (arm64)

#### DPU

**Model :** B3220 Single-Slot FHHL w/ Crypto enabled\
**NVIDIA OPN :** 900-9D3B6-00CV-AA0\
**PSID :** MT_0000000884


### Software Prerequisites

This lab guide will walk you through one setup method of Kubernetes cluster using kubeadm. The guide assumes that you have Ubuntu 22.04 installed on the host machine and the Nvidia BlueField-3 is running in the default DPU mode, and uplink port links set to ETH.

The following list of software is provided should you choose to install Kubernetes cluster differently than described in this guide.



Organizing software requirements for a multi-node Kubernetes cluster involves structuring the information in a way that ensures clarity, maintainability, and completeness for all stakeholders. Here’s a good approach:

| Software             | Version | Node/Selector | Reference |
| :------------------- | :------ | :------------ | :-------- |
| Ubuntu OS            | 22.04   | Host          | DPU OS will be installed as part of bf-bundle.
| DOCA Host            | 2.8+    | Host          | [NVIDIA DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/nvidia+doca+installation+guide+for+linux/index.html)
| BF Bundle BFB        | 2.8+    | DPU           | [Nvidia DOCA Downloads](https://developer.nvidia.com/doca-downloads?deployment_platform=BlueField&deployment_package=BF-Bundle&Distribution=Ubuntu&version=22.04&installer_type=BFB) |
| Kubelet              | 1.29+   | Host and DPU  | [Kubernetes Kubeadm guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
| Kubeadm              | 1.29+   | Host and DPU  |                                               
| Kubectl              | 1.29+   | Host and DPU  |                                               
| Containerd           | 1.7.22+ | Host and DPU  | [Containerd Getting Started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
| cert-manager         | 1.16.1+ | Host and DPU  | [Cert-manager installation](https://cert-manager.io/docs/installation/)
| SR-IOV Device Plugin | 3.7.0+  | DPU           | [SR-IOV Device Plugin](https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin?tab=readme-ov-file#quick-start)
| Multus               | 4.1.0+  | Host and DPU  | [Multus quick install](https://github.com/k8snetworkplumbingwg/multus-cni#quickstart-installation-guide)
| Calico               | 3.28.1+ | Host and DPU  | [Calico](https://github.com/projectcalico/calico)



## Installation Steps

### Prepare the Hosts

All Host machines are assumed here to have Ubuntu 22.04.\
Perform these steps on **all hosts** you would like to join to the cluster.


#### Install DOCA Software

First verify that the Nvidia Bluefield-3 card is installed on the host. For example use `lspci`

```shell
host# lspci | grep BlueField-3
e2:00.0 Ethernet controller: Mellanox Technologies MT43244 BlueField-3 integrated ConnectX-7 network controller (rev 01)
e2:00.1 Ethernet controller: Mellanox Technologies MT43244 BlueField-3 integrated ConnectX-7 network controller (rev 01)
e2:00.2 DMA controller: Mellanox Technologies MT43244 BlueField-3 SoC Management Interface (rev 01)
```

Clean up any previous DOCA packages

```shell
host# for f in $( dpkg --list | grep doca | awk '{print $2}' ); do echo $f ; apt remove --purge $f -y ; done
host# /usr/sbin/ofed_uninstall.sh --force
host# sudo apt-get autoremove
```

Install DOCA-all or DOCA-net.\
>Note: Make sure to select the correct architecture for the host. In this example it is x86_64.

These instructions are from [DOCA software download site](https://developer.nvidia.com/doca-downloads?deployment_platform=Host-Server&deployment_package=DOCA-Host&target_os=Linux)

```shell
host# export DOCA_URL="https://linux.mellanox.com/public/repo/doca/2.9.1/ubuntu22.04/x86_64/"
host# curl https://linux.mellanox.com/public/repo/doca/GPG-KEY-Mellanox.pub | gpg --dearmor > /etc/apt/trusted.gpg.d/GPG-KEY-Mellanox.pub
host# echo "deb [signed-by=/etc/apt/trusted.gpg.d/GPG-KEY-Mellanox.pub] $DOCA_URL ./" > /etc/apt/sources.list.d/doca.list
host# sudo apt-get update
host# sudo apt-get -y install doca-all
```

#### Configure Rshim service and interface.

RShim establlishes communication channel between the host and DPU. After installing DOCA all or DOCA networking, make sure rshim service is enabled and started.

```shell
host# sudo systemctl enable rshim --now
```

And verify the rshim status

```shell
host# # sudo systemctl status rshim
● rshim.service - rshim driver for BlueField SoC
     Loaded: loaded (/lib/systemd/system/rshim.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2024-12-15 18:46:43 UTC; 1 week 2 days ago
       Docs: man:rshim(8)
   Main PID: 3675 (rshim)
      Tasks: 12 (limit: 629145)
     Memory: 2.5M
        CPU: 4h 52min 6.859s
     CGroup: /system.slice/rshim.service
             └─3675 /usr/sbin/rshim

Dec 15 18:46:43 node6 rshim[3675]: pcie-0000:e2:00.2 enable
Dec 15 18:46:44 node6 rshim[3675]: rshim0 attached
```

The Rshim driver exposes a virtual interface named `tmfifo_net0` and the default network configuration for the DPU tmfifo interface is `192.168.100.2/30`\


Configure an IP address on the host `tmfifo_net0` interface as a way to connect to DPU if needed.
```shell
host# ip addr add 192.168.100.1/30 dev tmfifo_net0
```

To persist the configuration create the file `/etc/netplan/50-tmfifo.yaml`
```shell
host# cat << EONETPLAN > /etc/netplan/50-tmfifo.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    tmfifo_net0:
      dhcp4: no
      addresses:
        - 192.168.100.1/30
EONETPLAN
host# netplan apply
```
<details><summary>For more than 1 DPU on the same host</summary>

If the host has more than 1 DPU attached you will see one `tmfifo_netX` interface per DPU, for example: `tmfifo_net0` and `tmfifo_net1`.\
Adjust the netplan configuration to create a bridge including the tmfifo virtual interfaces and configure the IP address on the bridge.
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    tmfifo_net0:
      dhcp4: no
      dhcp6: no
    tmfifo_net1:
      dhcp4: no
      dhcp6: no
  bridges:
    br0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 192.168.100.1/29
      interfaces:
        - tmfifo_net0
        - tmfifo_net1
```
</details>

For more information on DOCA installation see [DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/nvidia+doca+installation+guide+for+linux/index.html).

#### Configure Virtual Function on host

As the lab diagram shows, we will configure one Virtual Function on pf1 to connect to internal network.

Using netplan to persist configuration on hosts accross reboots.

1. Create netplan file

>**NOTE:** The netplan config file assumes that pf1 netdevice name is `enp83s0f1np1` please change as needed.\
The IP address `192.168.20.41/24` should be adjusted per node. It is provided as example in compliance with the lab diagram.

```bash
host# cat << EOL > etc/netplan/10-vf-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp83s0f1np1:
      dhcp4: no
      virtual-function-count: 1
    enp83s0f1v0:
      link: enp83s0f1np1
      dhcp4: no
      addresses:
        - 192.168.20.41/24
```

2. Apply the network configuration and verify config
```bash
host# netplan apply
host# ip -br a show dev enp83s0f1v0
enp83s0f1v0      UP             192.168.20.41/24 fe80::34ad:f6ff:fedc:df7b/64
```

#### Install Kubernetes Prerequisites

Use the following script to install Kubernetes components and prereqs.


```bash
#!/bin/sh

# Script to prepare and install Kubernetes on the host machine.

# Run this as root, use 
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Please rerun with sudo. Exiting."
  exit 1
fi

# Variables
K8S_VERSION="1.29"
CONTAINERD_VERSION="1.7.23"
RUNC_VERSION="1.2.1"
TMP_DIR=$(mktemp -d)


ARCH="unknown" # Auto detected
get_system_arch() {
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
}

install_runc() {
    curl -LO https://github.com/opencontainers/runc/releases/download/v$CONTAINERD_VERSION/runc.$ARCH
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
            binaryName = "/usr/local/bin/runc"
EOL

    curl -L -o /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    systemctl daemon-reload
    systemctl enable --now containerd
}

install_kubernetes_components() {
    apt-get update && apt-get install -y apt-transport-https ca-certificates curl gpg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
    cat << EOL > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
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



pushd $TMP_DIR

# 1. Get current system architecture
get_system_arch

# 2. Install runc
install_runc

# 3. Install containerd
install_containerd

# 4. Install and init Kubernetes
install_kubernetes_components

popd

# 5. Cleanup temp dir
rm -rf "$TMP_DIR"
```

#### Prepare for DPU Install

>**Important** These instuctions use `rshim` to install bf bundle and must be performed on all hosts in the cluster that have a DPU attached.

1. Create a work directory on the host to prepare for DPU installation

```bash
host# mkdir dpu-install && cd dpu-install
```

2. Download bf-bundle from [Nvidia DOCA download](https://developer.nvidia.com/doca-downloads?deployment_platform=BlueField&deployment_package=BF-Bundle&Distribution=Ubuntu&version=22.04&installer_type=BFB)

3. Create a file named `bf.conf.template` and add the following content to it.

```bash
# UPDATE_DPU_OS - Update/Install BlueField Operating System (Default: yes)
UPDATE_DPU_OS="yes"

ubuntu_PASSWORD='{{PASSWORD}}'
###############################################################################
# Other misc configuration
###############################################################################

# MAC address of the rshim network interface (tmfifo_net0).
NET_RSHIM_MAC={{NET_RSHIM_MAC}}

# bfb_modify_os – SHELL function called after the file system is extracted on the target partitions.
# It can be used to modify files or create new files on the target file system mounted under
# /mnt. So the file path should look as follows: /mnt/<expected_path_on_target_OS>. This
# can be used to run a specific tool from the target OS (remember to add /mnt to the path for
# the tool).

bfb_modify_os()
{
    # Set hostname
    local hname="{{HOSTNAME}}"
    echo ${hname} > /mnt/etc/hostname
    echo "127.0.0.1 ${hname}" >> /mnt/etc/hosts

    # Overwrite the tmfifo_net0 interface to set correct IP address
    # This is relevant in case of multiple DPU system.
    cat << EOFNET > /mnt/var/lib/cloud/seed/nocloud-net/network-config
version: 2
renderer: NetworkManager
ethernets:
  tmfifo_net0:
    dhcp4: false
    addresses:
      - {{IP_ADDRESS}}/{{IP_MASK}}
  oob_net0:
    dhcp4: true
EOFNET

    # Modules for kubernetes and DPDK
    cat << EOFMODULES >> /mnt/etc/modules-load.d/custom.conf
overlay
br_netfilter
vfio_pci
EOFMODULES

    # sysctl settings for kubernets
    cat << EOFSYSCTL >> /mnt/etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOFSYSCTL

    # Provision hugepages as part of grub boot
    # Default to 2M hugepage size and provision 24.5 GB of hugepages
    # TMM requires 1.5GB of hugepages per thread (CPU core) totaling
    # 24GB to run on all 16 threads of the DPU.
    local hpage_grub="default_hugepagesz=2MB hugepagesz=2M hugepages=12544"
    sed -i -E "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\")(.*)\"|\1${hpage_grub}\"|" /mnt/etc/default/grub
    ilog "$(chroot /mnt env PATH=$PATH /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg)"

    # Provision SF to be used by the TMM on each PF
    for pciid in $(lspci -nD 2> /dev/null | grep 15b3:a2d[26c] | awk '{print $1}')
        do
            cat << EOFSF >> /mnt/etc/mellanox/mlnx-sf.conf
/sbin/mlnx-sf --action create --device $pciid --sfnum 1 --hwaddr $(uuidgen | sed -e 's/-//;s/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
EOFSF
        done
    # OVS changes
    # 1. Change bridge names to follow internal document as sf_external for pf0
    #    and sf_internal for pf1.
    sed -i -E "s|^(OVS_BRIDGE1=\")(.*)\"|\1sf_external\"|" /mnt/etc/mellanox/mlnx-ovs.conf
    sed -i -E "s|^(OVS_BRIDGE2=\")(.*)\"|\1sf_internal\"|" /mnt/etc/mellanox/mlnx-ovs.conf
    # 2. Add the new created SFs, "sfnum 1" to their corresponding bridges.
    #    Also include the virtual functions that are going to be created on host.
    #    These vfs may not exist yet.
    sed -i -E "s|^(OVS_BRIDGE1_PORTS=\")(.*)\"|\1\2 en3f0pf0sf1\"|" /mnt/etc/mellanox/mlnx-ovs.conf
    sed -i -E "s|^(OVS_BRIDGE2_PORTS=\")(.*)\"|\1\2 en3f1pf1sf1 pf1vf0\"|" /mnt/etc/mellanox/mlnx-ovs.conf

    # Cloud-init for upgrading containerd and runc
    cat << EOFCLOUDINIT >> /mnt/var/lib/cloud/seed/nocloud-net/user-data
write_files:
  - path: /etc/containerd/config.toml
    content: |
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
                  binaryName = "/usr/local/bin/runc"
  - path: /etc/apt/sources.list.d/kubernetes.list
    content: |
      deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /
  - path: /var/tmp/setup-script.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      TMPDIR=$(mktemp -d)
      systemctl stop containerd kubelet kubepods.slice
      rm -rf /var/lib/containerd/*
      rm -rf /run/containerd/*
      rm -f /usr/lib/systemd/system/kubelet.service.d/90-kubelet-bluefield.conf
      curl --output-dir ${TMPDIR} -LO https://github.com/opencontainers/runc/releases/download/v1.2.1/runc.arm64
      install -m 755 ${TMPDIR}/runc.arm64 /usr/local/sbin/runc
      curl --output-dir ${TMPDIR} -LO https://github.com/containerd/containerd/releases/download/v1.7.23/containerd-1.7.23-linux-arm64.tar.gz
      tar Czxvf /usr/local/ ${TMPDIR}/containerd-1.7.23-linux-arm64.tar.gz
      /usr/local/bin/ctr oci spec > /etc/containerd/cri-base.json
      curl -L -o /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
      systemctl daemon-reload
      systemctl enable --now containerd
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      apt-get update && apt-get install -y kubelet kubeadm kubectl
      systemctl daemon-reload
      systemctl enable --now containerd
      
      rm -rf ${TMPDIR}

runcmd:
  - [ /var/tmp/setup-script.sh ]
EOFCLOUDINIT
}

# bfb_post_install()
# {
#     log ===================== bfb_post_install =====================
#     mst start
#     mst_device=$(/bin/ls /dev/mst/mt*pciconf0 2> /dev/null)
#     # Setting SF enable per Nvidia documentation
#     # Ref: https://docs.nvidia.com/doca/sdk/nvidia+bluefield+dpu+scalable+function+user+guide/index.html
#     # and DPDK documentation
#     # Ref: https://doc.dpdk.org/guides-21.11/nics/mlx5.html
#     log "Setting SF enable and BAR size for $mst_device"
#     for mst_device in /dev/mst/mt*pciconf*
#     do
#       log "Disable port owner from ARM side for $mst_device"
#       mlxconfig -y -d $mst_device s PF_BAR2_ENABLE=0 PER_PF_NUM_SF=1 PF_TOTAL_SF=252 PF_SF_BAR_SIZE=12
#     done
# }
```

4. Create script file `create-bf-config.sh` and copy the below script content to it.
The script will produce custom DPU bf configuration file(s) to be used when installing the bf-bundle. This should work for cases of single and more than 1 DPU on the host.

```bash
#!/bin/bash

generate_config() {
    local hostname=$1
    local password=$2
    local ip_address=$3
    local ip_mask=$4
    local output_file=$5
    local net_rshim_mac=$6

    sed -e "s/{{HOSTNAME}}/${hostname}/g" \
        -e "s|{{PASSWORD}}|${password}|g" \
        -e "s/{{IP_ADDRESS}}/${ip_address}/g" \
        -e "s/{{IP_MASK}}/${ip_mask}/g" \
        -e "s/{{NET_RSHIM_MAC}}/${net_rshim_mac}/g" \
        bf.conf.template > "${output_file}"
}

read -p "Enter the number of DPUs (default: 1): " num_dpus
num_dpus=${num_dpus:-1}
read -p "Enter the base hostname (default: dpu): " base_hostname
base_hostname=${base_hostname:-dpu}
echo "Enter the Ubuntu password minimum 12 characters (e.g. 'a123456AbCd!'): "
# Password policy reference: https://docs.nvidia.com/networking/display/bluefielddpuosv490/default+passwords+and+policies#src-3432095135_DefaultPasswordsandPolicies-UbuntuPasswordPolicy
read -s clear_password
ubuntu_password=$(openssl passwd -1 "${clear_password}")
read -p "Enter tmfifo_net IP subnet mask. Useful if you have more than 1 DPU (default: 30): " ip_mask
ip_mask=${ip_mask:-30}

base_ip=${base_ip:-192.168.100}

for ((i=1; i<=num_dpus; i++)); do
    hostname="${base_hostname}-${i}"
    ip_address="${base_ip}.$(( i + 1 ))"
    net_rshim_mac=00:1a:ca:ff:ff:1${i}
    output_file="bfb_config_${hostname}.conf"

    echo "Generating configuration for ${hostname} with IP ${ip_address}..."
    generate_config "${hostname}" "${ubuntu_password}" "${ip_address}" "${ip_mask}" "${output_file}" "${net_rshim_mac}"
    cat << EOL
Configuration for ${hostname} is ${output_file}
To use the config run:
bfb-install --rshim rshim$(( i - 1 )) --config ${output_file} --bfb <bf-bundle-path>
EOL
done
```

5. Ensure the script is executable
```bash
host# chmod +x create-bf-config.sh
```

6. Use the script to generate DPU bf.conf files. For example:

```bash
host# ./create-bf-config.sh 
Enter the number of DPUs (default: 1): 
Enter the base hostname (default: dpu): nvidia-lab-dpu
Enter the Ubuntu password minimum 12 characters (e.g. 'a123456AbCd!'): 
Enter tmfifo_net IP subnet mask. Useful if you have more than 1 DPU (default: 30): 
Generating configuration for nvidia-lab-dpu-1 with IP 192.168.100.2...
Configuration for nvidia-lab-dpu-1 is bfb_config_nvidia-lab-dpu-1.conf
To use the config run:
bfb-install --rshim rshim0 --config bfb_config_nvidia-lab-dpu-1.conf --bfb <bf-bundle-path>

```
the above produced a bf config file named `bfb_config_nvidia-lab-dpu-1.conf` which we will be using to customize the bf-bundle installation.

At this point the files under `dpu-install` directory should look like the following:
```bash
dpu-install
├── bfb_config_nvidia-lab-dpu-1.conf
├── bf-bundle-2.9.0-83_24.10_ubuntu-22.04_dev.20241121.bfb
├── bf.conf.template
└── create-bf-config.sh
```

7. Run the `bfb-install` command to install and prepare DPU

```bash
host# bfb-install --rshim0 --config bfb_config_nvidia-lab-dpu-1.conf --bfb bf-bundle-2.9.0-83_24.10_ubuntu-22.04_dev.20241121.bfb
```

### Configure Kubernetes Cluster

Now that all Hosts and DPUs prerequisites are completed, we will start Kubernetes configuration

1. Initialize Kubernetes cluster on the **Controller Host** machine as follows:

```bash
host# cat << EOL > kube-init.sh
#!/bin/bash

# Change the MGMT_NET variable to the management network CIDR
# that will include both the host mgmt IP and DPU oob_net0 mgmt IP.
MGMT_NET="10.144.0.0/16"
kubeadm init --pod-network-cidr=10.244.0.0/16
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get node
echo "Installing Calico CNI ..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=cidr="$MGMT_NET"
kubectl wait --for=condition=Ready pods --all-namespaces --timeout=300s
kubectl get pod --all-namespaces
EOL
host# chmod +x kube-init.sh && ./kube-init.sh
```

> NOTE: The Controller Host is now setup to run kubectl. From this point forward any `kubectl` command should be run on the Controller Host.

Copy the `kubeadm join` command. For example:

```bash
host# kubeadm token create --print-join-command
kubeadm join 10.144.50.50:6443 --token z8fvlo.ztt3mrepmjoiw2pe --discovery-token-ca-cert-hash sha256:3cdfd53eb85a23a1700f834ca9aa487aa7f455bfdcbadcb8ed470160ce9c2977
```

2. Join all other Hosts and DPUs

Run the `kubeadm join` command copied from the controller on other Hosts and DPUs.

Hosts example:
```bash
host# kubeadm join 10.144.50.50:6443 --token z8fvlo.ztt3mrepmjoiw2pe --discovery-token-ca-cert-hash sha256:3cdfd53eb85a23a1700f834ca9aa487aa7f455bfdcbadcb8ed470160ce9c2977
```

DPU example:
```bash
dpu# kubeadm join 10.144.50.50:6443 --token z8fvlo.ztt3mrepmjoiw2pe --discovery-token-ca-cert-hash sha256:3cdfd53eb85a23a1700f834ca9aa487aa7f455bfdcbadcb8ed470160ce9c2977
```

3. Install Multus
```bash
host# kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
```

4. Install SR-IOV Device Plugin\

First we create the configmap for SR-IOV Device plugin to find and assign the scalable functions that were created as part of the DPU installation.\
Create a file named `sriov-configmap.yaml` with the following content:
```yaml
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
```
Then apply the configmap:
```bash
host# kubectl apply -f sriov-configmap.yaml
```

And install the SR-IOV Device Plugin

```bash
host# kubectl apply -f https://raw.github.com/k8snetworkplumbingwg/sriov-network-device-plugin/master/deployments/sriovdp-daemonset.yaml
host# kubectl patch daemonset kube-sriov-device-plugin -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"effect": "NoSchedule", "operator": "Exists"}]}]'
```

5. Install Cert Manager
```bash
host# helm repo add jetstack https://charts.jetstack.io --force-update
host# helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.1 --set crds.enabled=true --set featureGates=ServerSideApply=true
```
Configure self-signing issuer for cert-manager by applying the following file

```yaml
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
```
6. Install Gateway API CRDs

BIG-IP Next for Kubernetes acts as Kubernetes Gateway API controller.

```bash
host# kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/experimental-install.yaml
```




### Install BIG-IP Next for Kubernetes

The Kubernetes cluster is now ready for BIG-IP Next for Kubernetes installation.

1. Create required namespace

There are two main Kubernetes namespaces categories we use in this guide; Product, and Tenant namespaces.

**Product Namespaces**\
For the purposes of this lab guide, the BIG-IP Next for Kubernetes product will use 2 namespaces
  - **f5-utils:** All shared components for BIG-IP Next installation will use this namespace.
  - **default:** Operator, BIG-IP Next control plane, and BIG-IP Next Dataplane components will use this namespace.

**Tenant Namespaces**\
These are namespaces used for Tenant workload. At the moment these namespaces must exist prior to install. In future releases that may not be required.\
In this guide we will have two Tenant namespaces, `red` and `blue`.

Create required namespaces:
```bash
host# for ns in f5-utils red blue; do kubectl create ns $ns; done
```


2. Download and extract the auth key to F5 Artifactory Repository (FAR) where all software will be installed from
   - Login to the [MyF5](https://my.f5.com/).
   - Navigate to Resources and click Downloads.
   - Click checkbox to accept the End User License Agreement and Program Terms, then click Next.
   - Choose BIG-IP_Next from the Select a Product Family Group drop-down.
   - Select BIG-IP Next for Kubernetes from the Product Line drop-down.
   - Choose `1.9.2` from the Product Version drop-down menu.
   - Select the `f5-far-auth-key.tgz` file from the download file list.
   - Choose a location from the `Download location` drop-down menu and click Download.
   - The `f5-far-auth-key.tgz` file contains a Service Account Key that is in base64 format and used for logging into FAR.
   - `tar zxvf f5-far-auth-key.tgz` will expand file named `cne_pull_64.json`

3. Login to FAR helm registery using the auth key
```bash
host# cat cne_pull_64.json | helm registry login -u _json_key_base64 --password-stdin https://repo.f5.com
```
4. Create Kubernetes Pull Secret

Use the following script to create pull secret from the file `cne_pull_64.json` in both `default` and `f5-utils` namespaces.
```bash
#!/bin/bash

# Read the content of pipeline.json into the SERVICE_ACCOUNT_KEY variable
SERVICE_ACCOUNT_KEY=$(cat cne_pull_64.json)
# Create the SERVICE_ACCOUNT_K8S_SECRET variable by appending "_json_key_base64:" to the base64 encoded SERVICE_ACCOUNT_KEY
SERVICE_ACCOUNT_K8S_SECRET=$(echo "_json_key_base64:${SERVICE_ACCOUNT_KEY}" | base64 -w 0)
# Create the secret.yaml file with the provided content
cat << EOF > far-secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: far-secret
data:
  .dockerconfigjson: $(echo "{\"auths\": {\
\"repo.f5.com\":\
{\"auth\": \"$SERVICE_ACCOUNT_K8S_SECRET\"}}}" | base64 -w 0)
type: kubernetes.io/dockerconfigjson
EOF

kubectl -n f5-utils apply -f far-secret.yaml
kubectl -n default apply -f far-secret.yaml
```

5. Cluster Wide Controller requirements

The Cluster Wide Controller (CWC) component manages license registeration and debug API. In this release there are some manual requirements that are needed. Follow [F5 guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/2.0.0-LA/cwc-certificate.html) to generate and install required certificates and ConfigMap.

6. Download and copy Scalable Function CNI Binary

F5 created a CNI binary used here to move Scalable Function netdevice and RDMA devices inside of the dataplane container. This CNI is invoked by Multus delegation when attaching the Dataplane component to defined networks.

```bash
host# helm pull oci://repo.f5.com/utils/f5-eowyn  --version 2.0.0-LA.1-0.0.11
host# tar zxvf f5-eowyn-2.0.0-LA.1-0.0.11.tgz 
f5-eowyn/
f5-eowyn/sf
f5-eowyn/Chart.yaml
```
The `sf` CNI must be copied to all DPU nodes in the `/opt/cni/bin/` directory. For example:

```bash
host# scp f5-eowyn/sf root@<dpu-ip>:/opt/cni/bin/
```

7. Configure Network Attachment Definitions

Now that the CNI binary is installed we can configure Multus Network Attachment Definitions based on the configuration used in SR-IOV Device Plugin ConfigMap and using the `sf` CNI.\
Apply the following configuration to the default namespace.
```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: sf-external
  annotations:
    k8s.v1.cni.cncf.io/resourceName: nvidia.com/bf3_p0_sf
spec:
  config: '{
  "type": "sf",
  "cniVersion": "0.3.1",
  "name": "sf-external",
  "ipam": {},
  "logLevel": "debug",
  "logFile": "/var/log/sf/sf-external.log"
}'

---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: sf-internal
  annotations:
    k8s.v1.cni.cncf.io/resourceName: nvidia.com/bf3_p1_sf
spec:
  config: '{
  "type": "sf",
  "cniVersion": "0.3.1",
  "name": "sf-internal",
  "ipam": {},
  "logLevel": "debug",
  "logFile": "/var/log/sf/sf-internal.log"
}'
```
Which will create two network attachments for internal and external scalable functions.
