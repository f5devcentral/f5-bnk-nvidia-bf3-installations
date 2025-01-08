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
    - [Configure BIG-IP Next for Kubernetes](#configure-big-ip-next-for-kubernetes)
      - [Configure underlay network.](#configure-underlay-network)
      - [Egress path configuration](#egress-path-configuration)
      - [Configuration for Service Access from outside (ingress)](#configuration-for-service-access-from-outside-ingress)

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

There are three main networks in the diagram:

**Management Network:** The main underlay network for the Kubernetes cluster CNI and has the default gateway to reach internet. Both Host and the Nvidia BF-3 DPU are connected to this network and has addresses configured through DHCP.

**Internal Network:** Represents an internal network path between the host deployed services and the BNK Dataplane deployed in the DPU. This network will be utilized to route ingress and egress traffic for workload deployed on the host through BNK Dataplane.

**External Network:** The external network represents an "external-to-the-cluster" infrastructure network segment to reach external services/destinations.

The Test Servers represent clients and servers that are reachable on different segments of the network.
>_This could also be a single server connected to both Internal and External networks_

### Hardware

This lab guide was tested on the following hardware configurations:
>Note: The hardware list below serves as example for tested platforms. Only one of those or any other Nvidia DPU-3 compatible system is required for this guide.
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

Install DOCA-all or DOCA-net.
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

The Rshim driver exposes a virtual interface named `tmfifo_net0` and the default network configuration for the DPU tmfifo interface is `192.168.100.2/30`


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

4. Install SR-IOV Device Plugin

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

The Cluster Wide Controller (CWC) component manages license registeration and debug API. In this release there are some manual requirements that are needed. The steps also can be found in [F5 guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/2.0.0-LA/cwc-certificate.html) to generate and install required certificates and ConfigMap.

Generate certificates that will be used to communicate with CWC component API, by pulling the script from F5 repo then generating certs for the f5-utils namespace service as follows.

5.1. Pull and extract the chart containing cert generation scripts
```bash
host# helm pull oci://repo.f5.com/utils/f5-cert-gen --version 0.9.1
Pulled: repo.f5.com/utils/f5-cert-gen:0.9.1
Digest: sha256:89d283a7b2fef651a29baf1172c590d45fbd1e522fa90207ecd73d440708ad34

host# tar zxvf f5-cert-gen-0.9.1.tgz 
cert-gen/
cert-gen/LICENSE
cert-gen/README.md
cert-gen/tls_gen/
cert-gen/tls_gen/tls-gen.md
cert-gen/tls_gen/__pycache__/
cert-gen/tls_gen/__pycache__/cli.cpython-39.pyc
cert-gen/tls_gen/__pycache__/info.cpython-39.pyc
cert-gen/tls_gen/__pycache__/__init__.cpython-39.pyc
cert-gen/tls_gen/__pycache__/verify.cpython-39.pyc
cert-gen/tls_gen/__pycache__/paths.cpython-39.pyc
cert-gen/tls_gen/__pycache__/extension_gen.cpython-39.pyc
cert-gen/tls_gen/__pycache__/gen.cpython-39.pyc
cert-gen/tls_gen/cli.py
cert-gen/tls_gen/extension_gen.py
cert-gen/tls_gen/__init__.py
cert-gen/tls_gen/paths.py
cert-gen/tls_gen/info.py
cert-gen/tls_gen/verify.py
cert-gen/tls_gen/gen.py
cert-gen/gen_cert.sh
cert-gen/Chart.yaml
cert-gen/openssl-cert-gen/
cert-gen/openssl-cert-gen/client-cert.conf
cert-gen/openssl-cert-gen/README.md
cert-gen/openssl-cert-gen/csr.conf
cert-gen/openssl-cert-gen/client-csr.conf
cert-gen/openssl-cert-gen/server-cert.conf
cert-gen/openssl-cert-gen/gen-yaml.sh
cert-gen/openssl-cert-gen/gen-certs.sh
cert-gen/basic/
cert-gen/basic/profile.py
cert-gen/basic/.DS_Store
cert-gen/basic/openssl.cnf
cert-gen/basic/grpc/
cert-gen/basic/grpc/grpc-service.ext
cert-gen/basic/grpc/validation-service.ext
cert-gen/basic/grpc/f5-fqdn-resolver.ext
cert-gen/basic/grpc/client.ext
cert-gen/basic/grpc/grpc.mk
cert-gen/basic/CertificateGenerator.md
cert-gen/basic/Makefile
cert-gen/common.mk
```
5.2. Generate the API self-signed certificates. At the end of this step the script would have generated to main secret files Generating `cwc-license-certs.yaml` and `cwc-license-client-certs.yaml`

```bash
host# sh cert-gen/gen_cert.sh -s=api-server -a=f5-spk-cwc.f5-utils -n=1
------------------------------------------------------------------
Service                   = api-server
Subject Alternate Name    = f5-spk-cwc.f5-utils
Working directory         = /root/bnk-dpu-install/api-server-secrets
------------------------------------------------------------------
rm: cannot remove '/root/bnk-dpu-install/api-server-secrets': No such file or directory
Generating Secrets ...
python3 profile.py regenerate --password "" \
--common-name f5net \
--client-alt-name client \
--server-alt-name f5-spk-cwc.f5-utils \
--days-of-validity 3650 \
--client-certs 1 \
--key-bits 2048 
Creating 1 client extensions...
Will generate a root CA and two certificate/key pairs (server and client)
=>	[openssl_req]
.+.......+.....+.............+..+.+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*...............+.+..+....+..............+......+...+.+..+.......+.....+...+.......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*..............+...+.....+.+..+............+.......+...........+.........+.+............+..................+.....+....+.........+.....+.+...+.....+.+.........+...........+......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*..+..........+...........+.+.....+.+.....+....+......+.....+....+...+......+..+.......+..+..........+........+...+............+.......+.........+......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-----
=>	[openssl_x509]
Will generate leaf certificate and key pair for server
Using f5net for Common Name (CN)
Using parent certificate path at /root/bnk-dpu-install/cert-gen/basic/testca/cacert.pem
Using parent key path at /root/bnk-dpu-install/cert-gen/basic/testca/private/cakey.pem
Will use RSA...
=>	[openssl_genpkey]
..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*....+.........+..+......+............+.+..+....+........+.+.....+......+.........+.+......+..+...+.......+........+...+.......+.....+.......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*..........+...+...+..................+......+.+...............+..+......+.+......+..+......+.+.....+.+.....+.........+....+.........+..+....+..+...+.........+...+..................+............+....+......+.....+...+....+........+...+.......+...+...........+...+.+......+......+.........+.....+.+..+.............+..+......+......+......+....+......+...+..+..........+..+..........+.....+.+..+...+....+...+.....+....+.........+.....+......+....+...........+...+..........+...+.....+.........+.+.........+........+..........+...............+............+.....+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
...+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.+.........+......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.+...................+......+..+.+.....+.....................+...+..........+..+.........+....+...+..+...+...............+.......+........+...+.+.....+.........+.+.....+.+.........+...+.....+......+....+...+........+.....................+...+...+.............+.....+....+..+...+.+.....+...............+......+.+............+...+........+......+...+.+...........................+..............+...............+.+..+.+......+........+...+....+.....+.+..............+...+...+.............+.....+.+...+...+........+....+...+...+.....+......+...+......+.+...+..+......+...+.+.....+.+.....+........................+.........+.+......+..+.+..+.......+...+..+.......+.........+..+....+...............+...+........+............+.......+...+.....+...+.......+........+........................+.+........+.+.....+.+..+.......+......+..............+.+..+..........+...............+...+............+..+...+.......+......+...+..+.........+......+.............+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
=>	[openssl_req]
-----
=>	[openssl_ca]
Using configuration from /tmp/tmpnso_b2s4
801B7E13897F0000:error:0700006C:configuration file routines:NCONF_get_string:no value:../crypto/conf/conf_lib.c:315:group=<NULL> name=unique_subject
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'f5net'
organizationName      :ASN.1 12:'server'
localityName          :ASN.1 12:'$$$$'
Certificate is to be certified until Jan  5 18:51:43 2035 GMT (3650 days)

Write out database with 1 new entries
Data Base Updated
=>	[openssl_pkcs12]
Will generate leaf certificate and key pair for client
Using f5net for Common Name (CN)
Using parent certificate path at /root/bnk-dpu-install/cert-gen/basic/testca/cacert.pem
Using parent key path at /root/bnk-dpu-install/cert-gen/basic/testca/private/cakey.pem
Will use RSA...
=>	[openssl_genpkey]
......+.+......+...+..+....+...+..+...+...+...+...............+............+............+.+.........+...+........+....+...........+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.....+.+........+......+....+......+.....+.+.....+...+....+...........+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.....+.+..+..........+..+.......+.........+......+.....+....+.....+.........+..........+..+.+........+..........+..+.........+....+..+...+.......+........+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.............+.........+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.+.........+.+...........+.+...+.....+.......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*......+.......+..+..........+.........+.....+.......+.........+.....................+..+...+....+...+...+.....+.........+....+............+...+..............+......+.......+.....+...+.....................+.+..+......+.+....................+.+...+..+...............+...............+...+.+...+...........+.+...+......+......+......+..+............+...+......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
=>	[openssl_req]
-----
=>	[openssl_ca]
Using configuration from /tmp/tmpnso_b2s4
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'f5net'
organizationName      :ASN.1 12:'client'
localityName          :ASN.1 12:'$$$$'
Certificate is to be certified until Jan  5 18:51:44 2035 GMT (3650 days)

Write out database with 1 new entries
Data Base Updated
=>	[openssl_pkcs12]
Done! Find generated certificates and private keys under ./result!
python3 profile.py verify --client-certs 1 
Will verify generated server certificate against the CA...
Will verify server certificate against root CA
/root/bnk-dpu-install/cert-gen/basic/result/server_certificate.pem: OK
Will verify generated client certificate against the CA...
Will verify client certificate against root CA
/root/bnk-dpu-install/cert-gen/basic/result/client_certificate.pem: OK
Copying secrets ...
Generating /root/bnk-dpu-install/cwc-license-certs.yaml
Generating /root/bnk-dpu-install/cwc-license-client-certs.yaml

```

5.3. Install secrets.
```bash
host# kubectl apply -f cwc-license-certs.yaml -n f5-utils
host# kubectl apply -f cwc-license-client-certs.yaml -n f5-utils
```

5.4. Install qkview config map file.
```bash
host# cat << EOF | kubectl -n f5-utils apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
   name: cwc-qkview-cm
EOF
```

5.4. Install Json Key Set for license activation

```bash
host# cat << EOF | kubectl -n f5-utils apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cpcl-key-cm
  namespace: f5-utils
data:
  jwt.key: |
    {
        "keys": [
            {
                "kid": "v1",
                "alg": "RS512",
                "kty": "RSA",
                "n": "26FcA1269RC6WNgRghIB7X772zTTts02NsqqN-_keSz5FVq1Ekg151NFu_53Tgz1FGsUiX4OUj-fOmuhK9uzkQv0zYZgXY6zmRo_9P-QgiycuFo7DWquDwEx4rZiMxXwlA9ER56s8PDdbXyfi3ceMV-aUQZFqMiU6gOTl5d7uMfskocPF4ja8ZRrLlXAzzRIR62VgbQa-3sT0_SZ4w1ME4eLzO1yb-Ex9va4JnwToVLSKfsZp6jYs9nvAGjZ8aN2_lzBx8uiZ1HQozGqcf0AEjU-FEY73Umvmyvzd4woQLQlbvyrRtL9_IkL2ySdQ9Znh2lXBdsmA9cLz4ZAYPdmvcjsyBaZmh15EOkczpVVan1_VVD4o28uLDpzQVDk_GNUYoZIRsuOzuKvzih0gkv-StH29umHbdKXrUhlMWM1zyaxz8gkHatn-g5uh70WwVwqPtfHaNrQ0fFiWoyGVOA_-XqsJWA9NLJorewp9HOVlyF8qzu5s9cFO4UGQas0fF2QR9QvhgCymK7iWbEFF3PXqUQTLfFsITgix3mmeXVYC3ODsPKvcFhNBqQxmeXM04N2XMLluz2qp581NUJygWAAfq7la0ylDJ1MtefyESD8SBs1at2a8kSEBJCdCtAuNX2q33JjxQP3AiGvHcKEAjd1uaNeSgdHC93BzT3u0gbh2Ok",
                "e": "AQAB",
                "x5c": [
                    "MIIFqDCCBJCgAwIBAgIRAK+LbrS2gkaJSeoUQpMK0LswDQYJKoZIhvcNAQELBQAwgacxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApXYXNoaW5ndG9uMRowGAYDVQQKDBFGNSBOZXR3b3JrcywgSW5jLjEeMBwGA1UECwwVQ2VydGlmaWNhdGUgQXV0aG9yaXR5MTUwMwYDVQQDDCxGNSBTVEcgSXNzdWluZyBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgVEVFTSBWMTEQMA4GA1UEBwwHU2VhdHRsZTAeFw0yMTEwMTEyMzI0NTFaFw0yNjEwMTEwMDI0NTFaMIGBMQswCQYDVQQGEwJVUzETMBEGA1UECAwKV2FzaGluZ3RvbjEQMA4GA1UEBwwHU2VhdHRsZTEaMBgGA1UECgwRRjUgTmV0d29ya3MsIEluYy4xDTALBgNVBAsMBFRFRU0xIDAeBgNVBAMMF0Y1IFNURyBURUVNIEpXVCBBdXRoIHYxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA26FcA1269RC6WNgRghIB7X772zTTts02NsqqN+/keSz5FVq1Ekg151NFu/53Tgz1FGsUiX4OUj+fOmuhK9uzkQv0zYZgXY6zmRo/9P+QgiycuFo7DWquDwEx4rZiMxXwlA9ER56s8PDdbXyfi3ceMV+aUQZFqMiU6gOTl5d7uMfskocPF4ja8ZRrLlXAzzRIR62VgbQa+3sT0/SZ4w1ME4eLzO1yb+Ex9va4JnwToVLSKfsZp6jYs9nvAGjZ8aN2/lzBx8uiZ1HQozGqcf0AEjU+FEY73Umvmyvzd4woQLQlbvyrRtL9/IkL2ySdQ9Znh2lXBdsmA9cLz4ZAYPdmvcjsyBaZmh15EOkczpVVan1/VVD4o28uLDpzQVDk/GNUYoZIRsuOzuKvzih0gkv+StH29umHbdKXrUhlMWM1zyaxz8gkHatn+g5uh70WwVwqPtfHaNrQ0fFiWoyGVOA/+XqsJWA9NLJorewp9HOVlyF8qzu5s9cFO4UGQas0fF2QR9QvhgCymK7iWbEFF3PXqUQTLfFsITgix3mmeXVYC3ODsPKvcFhNBqQxmeXM04N2XMLluz2qp581NUJygWAAfq7la0ylDJ1MtefyESD8SBs1at2a8kSEBJCdCtAuNX2q33JjxQP3AiGvHcKEAjd1uaNeSgdHC93BzT3u0gbh2OkCAwEAAaOB8jCB7zAJBgNVHRMEAjAAMB8GA1UdIwQYMBaAFLDdK33QD9FdLnrVFw+ZAkQUayxCMB0GA1UdDgQWBBQw/hNgf2AoJAF086NV7JGQj+B2NzAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMHMGA1UdHwRsMGowaKBmoGSGYmh0dHA6Ly9jcmwtdGVlbS1zdGctb3JlLWY1LnMzLnVzLXdlc3QtMi5hbWF6b25hd3MuY29tL2NybC85ZGFmNGVlNy1iOGNkLTRiODEtOWE0MC00YjU3MGY0N2VhYWUuY3JsMA0GCSqGSIb3DQEBCwUAA4IBAQApzkSnsfuNSMHxVmL78pOQ+Rxkz1uYSVT0k1W45iufVmP0ixd8hFPcfb8u1RoHZ/58Gl52JPCudAB2sc4k/lHNT9cKL4w5F8LybB8uNJXikAqzu4HFobRYMiPtVQ7M8cFz5SgvGclxzBAbZzK5u5xZuGSkI6tG9l+D5JhW2LesRuQSBQniBgRhmtAJB7SXuZ2sNKsq04h7DWcpdjCSferymeCOLQcgy5F3ragKML8zyuNeKqtvZnUzJElKoU8G+Oo7MQXO7P5n6HX0NLfqqisv8CfSJUZTa1IRcfFUDJrcHtCgzingalzLLKzyelqR+YeY+j21jwVdnDVZIkFid2He",
                    "MIIFDjCCAvagAwIBAgIBBTANBgkqhkiG9w0BAQsFADCBhDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRgwFgYDVQQKEw9GNSBOZXR3b3JrcyBJbmMxHjAcBgNVBAsTFUNlcnRpZmljYXRlIEF1dGhvcml0eTEuMCwGA1UEAxMlRjUgSW50ZXJtZWRpYXRlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0xODEyMTMxOTU3NDlaFw0yODEyMTAxOTU3NDlaMIGnMQswCQYDVQQGEwJVUzETMBEGA1UECAwKV2FzaGluZ3RvbjEaMBgGA1UECgwRRjUgTmV0d29ya3MsIEluYy4xHjAcBgNVBAsMFUNlcnRpZmljYXRlIEF1dGhvcml0eTE1MDMGA1UEAwwsRjUgU1RHIElzc3VpbmcgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IFRFRU0gVjExEDAOBgNVBAcMB1NlYXR0bGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC1zQVzFAkzJdDMk+blcmQ506+GhWZOoe32rSWpkztdH7nYHtE6ITx44nHErRLOXXcYsf8nQZyV2RiE5Gyxwvdg3ClC9XqfT702FxFWLPpD/I53cRZasYH3dFfdvDztEOlTsUrMfo7Bzfh7ZMaMkBczHno0DdP61lp6pfzsQRLSfdaWxLKkCxc3P2xDUyx9F7uX3lXsT042OuiZpoCrMumO53hmvw6ZtP6mH7d6dM7nhYhTIGxRMYrzEAHKl+JM0Jnaabwxw4UBMkxozxP+kLvDXrwLADjMslEuVeq1r7WwNa33y8aXfBUZpDCgJKfYvvPQIUD5d6ui0v7vwAQRgX/fAgMBAAGjZjBkMB0GA1UdDgQWBBSw3St90A/RXS561RcPmQJEFGssQjAfBgNVHSMEGDAWgBRz1uVFvQMN0SWZ8zjGfQLZ+vrt6TASBgNVHRMBAf8ECDAGAQH/AgEBMA4GA1UdDwEB/wQEAwIBhjANBgkqhkiG9w0BAQsFAAOCAgEABB8ygsfvpId2OPMh3jnTtEpfcJy80yu7vFVSMDQ/4xKTBSR0iFcCNmMJ8i4PL0E8RqFzcsUaG9Rq2uyiW71Y/+QiC0/xN8pXTua9zH1aYPLKTa62IB5Dnfax+QccNCehCAoJ/W4yVeY9/nHbSlYt8+eOMSdUJf/hcaPuHbLs6rJI9GHo9CNeBtWH0q+Xw3rRAXSrNXMg+CRE55JOVaDdzRUOEdf962Pd/MRN7+Sypyj2dR9rCJ/SKxf0HQr6NOGSAc3QbLun0bzew/0Nlww8UpCXV/ABiBFUBDvIhapMQqoErMuPm0CvqBdVCWafOa8qylHHOCkEUxTlxtk3WTwEI4RcrHnHVO4eIkstLe8+4HvKvCwXwoDlcms44lIzQpoPvVclkYYKH0d9GjY1dDSXxYeIm7aPeA6VutQoTd8ozKqZFjueESJB7JATC1q5PSiOhNIUr1d9Y7CbTpLWAl7ktJt5yZlcJBd3+5wztuCtwfQncjERRl8Sey3UuCjD836E7d4ZPldKUaJpDKpdzXIiiwDWCTL3G1iPBz+O1YyPAoQz6NFUsiHDnuIaGMfYLouf0ltuHTBwzcQbkFtH7PeY5Qwts617AQBy5lCJ3HLdJ9Hg3CwTXlBqFR+T/8vF0n6+AuE0ZFjmbJYJs0m4EObk0IOcex4ft33fPDEFWRJpHIs=",
                    "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",
                    "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"
                ],
                "use": "sig"
            }
        ]
    }
EOF
```

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
Which will create two network attachments for internal and external scalable functions as described in the lab diagram.

8. Install BIG-IP Next for Kubernetes Operator in default namespace

```bash
host# helm install orchestrator oci://repo.f5.com/charts/orchestrator \
        --version v0.0.25-0.0.96 \
        --set global.imagePullSecrets[0].name=far-secret \
        --set image.repository=repo.f5.com/images \
        --set image.pullPolicy=Always
```

The operator helps in installing BIG-IP Next for Kubernetes software. It requires two Custom Resources to be defined for the installation.\
**`SPKInfrastructure`** to describe dataplane infrastructure connections and settings AND\
**`SPKInstance`** Declared state and configuration of the BIG-IP Next for Kubernetes components

9. Apply the `SPKInfrastructure` resource, which will include refernces to the Network Attachment Definitions created earlier, and the resources provisioned for these networks as configured in the SR-IOV device plugin section.

```bash
host# cat << EOF | kubectl apply -f -
apiVersion: charts.k8s.f5net.com/v1alpha1
kind: SPKInfrastructure
metadata:
  name: bnk-dpu-infra
spec:
  networkAttachment:
  - name: default/sf-external
  - name: default/sf-internal
  platformType: other
  hugepages: true
  sriovResources:
    nvidia.com/bf3_p0_sf: "1"
    nvidia.com/bf3_p1_sf: "1"
  wholeClusterMode: "enabled"
  calicoRouter: "default"
  egress:
    json:
      ipPoolCidrInfo:
        ipPoolList:
        - name: pod_cidr_ipv4
          value: "10.244.0.0/16"
EOF
```
10. Add taint and label to all DPU nodes where the dataplane daemonset should be deployed.
```bash
# Do the following for all DPU nodes replace <dpu-node-name> with appropriate worker node name.
host# kubectl taint node <dpu-node-name> dpu=true:NoSchedule
host# kubectl label node <dpu-node-name> app=f5-tmm
```

11. Apply the `SPKInstance` which will install the product components.
>_**NOTE:**_ This SPKInstance CR also includes JWT license token valid through December 2025. Intended for Nvidia use only, please do not share.

The `SPKInstance` configured here will start

```bash
host# cat << EOF | kubectl apply -f -
apiVersion: charts.k8s.f5net.com/v1alpha1
kind: SPKInstance
metadata:
  name: bnk-dpu
  namespace: default
spec:
  controller:
    watchNamespace: red, blue
  cwc:
    cpclConfig:
      jwt: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCIsImtpZCI6InYxIiwiamt1IjoiaHR0cHM6Ly9wcm9kdWN0LXRzdC5hcGlzLmY1bmV0d29ya3MubmV0L2VlL3YxL2tleXMvandrcyJ9.eyJzdWIiOiJUU1QtZGVmNTg1NmItN2UwOC00MDhlLTlhZWYtMGZjNGJjMmVkMTk4IiwiaWF0IjoxNzM2MTg0NDY5LCJpc3MiOiJGNSBJbmMuIiwiYXVkIjoidXJuOmY1OnRlZW0iLCJqdGkiOiI4ZDFjOWZmMS1jYzUzLTExZWYtYWQ4Yy00ZjQ0MDFkZDUxOWEiLCJmNV9vcmRlcl90eXBlIjoicGFpZCIsImY1X3NhdCI6MTc2NDU0NzIwMH0.JdhZeVjhvZL5seVnNM3vDDOGRMzgcs08EV7sahulQPbaLAkAvJc94I-n_rjQUZtASi5zOk8qBDoXzdhRwa6LCefQu5fE1dFFVykzJ6FWfY2HvF8fRdDPa-kvV9O5Y9prhNNM1g9C4lN3IneK1w3KkH6ZPuhEAQmcS4sEkTVsVa2m174Br8RxHRYJAqX3-E-ZjEU7LCrQrLIce-8zll6tM1dDwGNpA71OqP_XLsereCsRtRLQYNbiqhMz8d80pItkkdvvaIfm3S18l4K3O-czp4VoT6IbJPprS3gq3lFKTWdZ1kdSCUvRYtAT8AQpzSIc_ZNL66aP8GqqsQgsSM8H880NMoCo0tZZXCmnE1fO78nuflKtBVfyOae5j3vGzYSWRqXZGVihp3Kaefmo04mVIOtfc0fyDEzn40mGJil5rwoCp1s2HkLqMX8kMMjGSxBICMrtuluGcA4oAZ8ds6Y_BwLaq39nv2BFrx6YNYjeY93A-7LyBMuriKF3oE3qjlwIxb8dTdyZ8JZRvh52PMVga3PimLYXVQlGU7m7PjwuOJt_8PP7MPk-EsnuvpqcTRt1ezccosyXDLFG527jUucGVMtODK7Jmba1RDL4kSqw03JLsd5djiI_IZMJ8TTO3txfEz21C3Nu22LfzCshmVYpkVHOdcbKj0PcpkiFmzYZ_YQ
      operationMode: connected
  global:
    certmgr:
      issuerRef:
        group: cert-manager.io
        kind: ClusterIssuer
        name: bnk-ca-cluster-issuer
    imagePullSecrets:
    - name: far-secret
    imageRepository: repo.f5.com/images
    logging:
      fluentbitSidecar:
        fluentd:
          port: "54321"
  spkInfrastructure: bnk-dpu-infra
  spkManifest: unused
  afm:
    enabled: true
    pccd:
      enabled: true
      blob:
        maxFwBlobSizeMb: "512"
        maxNatBlobSizeMb: "512"
  tmm:
    replicaCount: 1
    nodeAssign:
      nodeSelector:
        app: f5-tmm
      tolerations:
        - key: "dpu"
          value: "true"
          operator: "Equal"
    palCPUSet: "8-15"
    usePhysMem: true
    tmmMapresHugepages: 6144
    resources:
      limits:
        cpu: "8"
        hugepages-2Mi: 13Gi 
        memory: 2Gi
    debug:
      enabled: true
      resources:
        limits:
          cpu: 200m
          memory: 100Mi
        requests:
          cpu: 200m
          memory: 100Mi
    xnetDPDKAllow:
    - auxiliary:mlx5_core.sf.4,dv_flow_en=2
    - auxiliary:mlx5_core.sf.5,dv_flow_en=2
    blobd:
      enabled: true
      resources:
        limits:
          cpu: "1"
          memory: "1Gi"
        requests:
          cpu: "1"
          memory: "1Gi"
    dynamicRouting:
      enabled: false
      configMapName: spk-bgp
    tmrouted:
      resources:
        limits:
          cpu: "300m"
          memory: "512Mi"
        requests:
          cpu: "300m"
          memory: "512Mi"
    tmmRouting:
      resources:
        limits:
          cpu: "700m"
          memory: "512Mi"
        requests:
          cpu: "700m"
          memory: "512Mi"
    sessiondb:
      useExternalStorage: "true"
EOF
```

Ensure that all pods in default and f5-utils namespaces are healthy. This can take up to 5 minutes.

### Configure BIG-IP Next for Kubernetes

BIG-IP Next for Kubernetes dataplane componenet (TMM) configures and performs all it's networking stack tasks in user-space and attaches to Scalable Functions interfaces using DPDK driver.\
TMM network is configured through Custom Resources and we will use some of them to configure the installation in accordance with the lab guide diagram.

#### Configure underlay network.

These are the IP addresses directly connected to the network segments/infrastructure. To configure underlay addresses we use the `F5SPKVlan` Custom Resource.

The `F5SPKVlan` resources below configure two _untagged_ VLANs **internal** connected to the internal network segment and **external** connected to the external network segment.\
The IP address lists for IPv4 and IPv6 are the underlay IP addresses that will be reachable through these network segments. Since we have 3 DPU nodes we need at least 3 IP addresses in the list where one of them will be assigned to each TMM.

>NOTE: `tag: 0` means untagged VLAN. Change that value to a VLAN tag if needed.

>NOTE: Only one *untagged* VLAN is allowed per interface. And multiple *tagged* VLANs are allowed per interface. All configured tagged VLANs on all interfaces must have unique tag value, i.e. one can not use the same VLAN tag on two different interfaces.

```bash
host# cat << EOF | kubectl apply -f -
---
apiVersion: "k8s.f5net.com/v1"
kind: F5SPKVlan
metadata:
  name: internal
spec:
  name: internal
  interfaces:
    - "1.2"
  tag: 0
  selfip_v4s:
    - 192.168.20.201
    - 192.168.20.202
    - 192.168.20.203
  prefixlen_v4: 24
  selfip_v6s:
    - 2001::192:168:20:201
    - 2001::192:168:20:202
    - 2001::192:168:20:203
  prefixlen_v6: 112
  auto_lasthop: "AUTO_LASTHOP_ENABLED"
  internal: true
---
apiVersion: "k8s.f5net.com/v1"
kind: F5SPKVlan
metadata:
  name: external
spec:
  name:  external
  interfaces:
    - "1.1"
  tag: 0
  selfip_v4s:
    - 192.168.10.201
    - 192.168.10.202
    - 192.168.10.203
  prefixlen_v4: 24
  selfip_v6s:
    - 2001::192:168:10:201
    - 2001::192:168:10:202
    - 2001::192:168:10:203
  prefixlen_v6: 112
  auto_lasthop: "AUTO_LASTHOP_ENABLED"
```

When network interfaces are connected to the TMM such as the (scalable functions in this case connected to the TMM through the Network Attachment Definition), these interfaces get assigned index numbers based on the order they are configured in such as `1.1` and so forth. In the `F5SPKVlan` configuration above note `interfaces` section referencing `1.1` and `1.2`.

Here is a quick description on how the interfaces map in this particular lab guide.
>NOTE: Please note that this description is a simplified overview of the interface naming assignment for clarity on this particular lab guide.
  - Network Attachments configured with names `sf-internal` and `sf-external`
  - The `SPKInfrastructure` CR connects these interfaces as follows
    ```yaml
    networkAttachment:
    - name: default/sf-external
    - name: default/sf-internal
    ```
    where the order is `sf-external` then `sf-internal`
  - First network `sf-external` gets assigned `1.1` and `sf-internal` assigned `1.2`

Validate network configuration by checking CR status

```bash
host# kubectl get f5-spk-vlan
NAME       READY   MESSAGE                                AGE
external   True    CR config sent to all grpc endpoints   30h
internal   True    CR config sent to all grpc endpoints   30h
```

#### Egress path configuration

This lab guide assumes there will be two namespaces for tenant workload **red** and **blue** and that their egress/ingress is configured through VXLAN overlay. The following diagram shows tenant VXLAN config with focus on the **red** tenant knowing that blue tenant would be the same.

![bnk-lab-tenant-vxlan](media/nvidia_bnk_lab_diagram_egress_vxlan.svg)

1. Configure VXLAN overlay
To configure this we use `F5SPKVxlan` CR which establishes the overlay configurations to the host, a `F5SPKSnatpool` CR to set IP addresses used for SNATing egress traffic towards the network infrastructure, and `F5SPKEgress` CR that assigns the egress rules for namespace to specific VXLAN.

The following `F5SPKVxlan` CRs configures two VXLANs **red** with VNI 100 and **blue** with VNI 200

>NOTE: The virtual function created on host on PF1 is assumed to be `enp83s0f1v0` in this guide. Replace every instance of `enp83s0f1v0` with the actual configured host-side virtual function.

>NOTE: The `remote_nodes` represent the host nodes only. Modify the list to properly reflect cluster node names and configured IP addresses as required. DPU nodes are not required here since workload is only expected on the host.

```yaml
---
apiVersion: "k8s.f5net.com/v1"
kind: F5SPKVxlan
metadata:
  name: "red"
spec:
  name: "red"
  port: 4789
  key: 100
  # Interface name on host nodes that is used for underlay.
  # This is the previously configured Virtual Functionon PF1.
  remote_interface_name: "enp83s0f1v0"
  # Host nodes
  remote_nodes:
     # host node name in Kubernetes cluster.
   - node_name: "host-1"
     # Underlay IP address as configured on virtual function.
     # Change if different in your infrastructure.
     node_ip: "192.168.20.41"
     # Mac address and IP addresses that will be assigned to the
     # Host side VXLAN overlay interface.
     peer_mac: "00:f5:00:00:00:02"
     peerip_v4: "198.18.100.1"
     peerip_v6: "fd50::192:18:100:1"
   - node_name: "host-2"
     node_ip: "192.168.20.42"
     peer_mac: "00:f5:00:00:00:03"
     peerip_v4: "198.18.100.2"
     peerip_v6: "fd50::192:18:100:2"
   - node_name: "host-3"
     node_ip: "192.168.20.43"
     peer_mac: "00:f5:00:00:00:04"
     peerip_v4: "198.18.100.3"
     peerip_v6: "fd50::192:18:100:3"
  local_ips:
   - "192.168.20.201"
   - "192.168.20.202"
   - "192.168.20.203"
  selfip_v4s:
   - "198.18.100.201"
   - "198.18.100.202"
   - "198.18.100.203"
  prefixlen_v4: 24
  selfip_v6s:
   - "fd50::192:18:100:201"
   - "fd50::192:18:100:202"
   - "fd50::192:18:100:203"
  prefixlen_v6: 112
---
apiVersion: "k8s.f5net.com/v1"
kind: F5SPKVxlan
metadata:
  name: "blue"
spec:
  name: "blue"
  port: 4789
  key: 200
  remote_interface_name: "enp83s0f1v0"
  remote_nodes:
   - node_name: "host-1"
     node_ip: "192.168.10.41"
     peer_mac: "00:f5:01:00:00:02"
     peerip_v4: "198.18.200.1"
     peerip_v6: "fd50::192:18:200:1"
   - node_name: "host-2"
     node_ip: "192.168.10.42"
     peer_mac: "00:f5:01:00:00:03"
     peerip_v4: "198.18.200.2"
     peerip_v6: "fd50::192:18:200:2"
   - node_name: "host-3"
     node_ip: "192.168.10.43"
     peer_mac: "00:f5:01:00:00:04"
     peerip_v4: "198.18.200.3"
     peerip_v6: "fd50::192:18:200:3"
  local_ips:
   - "192.168.20.201"
   - "192.168.20.202"
   - "192.168.20.203"
  selfip_v4s:
   - "198.18.200.201"
   - "198.18.200.202"
   - "198.18.200.203"
  prefixlen_v4: 24
  selfip_v6s:
   - "fd50::192:18:200:201"
   - "fd50::192:18:200:202"
   - "fd50::192:18:200:203"
  prefixlen_v6: 112
```

2. Configure SNATPool

the `addressList` section is a list of lists of SNAT IP addresses that are assigned to each TMM. Since we have 3 TMMs here, we will create 3 lists one for each TMM.

The SNAT addresess are unique per TMM. And they are picked based on the closest IP address to the nexthop (gateway or direct network) for intended destination.

```yaml
---
apiVersion: "k8s.f5net.com/v1"
kind: F5SPKSnatpool
metadata:
  name: "red-snat"
spec:
  name: "red-snat"
  addressList:
    - - 192.168.10.221
      - 2001::192:168:10:221
      - 192.168.20.221
      - 2001::192:168:20:221
    - - 192.168.10.222
      - 2001::192:168:10:222
      - 192.168.20.222
      - 2001::192:168:20:222
    - - 192.168.10.223
      - 2001::192:168:10:223
      - 192.168.20.223
      - 2001::192:168:20:223
---
apiVersion: "k8s.f5net.com/v1"
kind: F5SPKSnatpool
metadata:
  name: "blue-snat"
spec:
  name: "blue-snat"
  addressList:
    - - 192.168.10.231
      - 2001::192:168:10:231
      - 192.168.20.231
      - 2001::192:168:20:231
    - - 192.168.10.232
      - 2001::192:168:10:232
      - 192.168.20.232
      - 2001::192:168:20:232
    - - 192.168.10.233
      - 2001::192:168:10:233
      - 192.168.20.233
      - 2001::192:168:20:233
```
3. Configure `F5SPKEgress` to assign tenants egress to their prespective VXLAN

```yaml
---
apiVersion: k8s.f5net.com/v3
kind: F5SPKEgress
metadata:
  name: red-egress
spec:
  dualStackEnabled: true
  snatType: SRC_TRANS_SNATPOOL
  egressSnatpool: red-snat
  pseudoCNIConfig:
    namespaces:
      - red
    # Routing default pod interface eth0.
    # Assumes pod does not have additional interfaces configured.
    appPodInterface: eth0
    # Name of VXLAN interface created on the host
    # This is basically the same name as the VXLAN name in CR.
    appNodeInterface: red
    # Name of VXLAN interface on TMM which is the VXLAN CR name.
    vlanName: red
---
apiVersion: k8s.f5net.com/v3
kind: F5SPKEgress
metadata:
  name: blue-egress
spec:
  dualStackEnabled: true
  snatType: SRC_TRANS_SNATPOOL
  egressSnatpool: blue-snat
  pseudoCNIConfig:
    namespaces:
      - blue
    appPodInterface: eth0
    appNodeInterface: blue
    vlanName: blue
```

#### Configuration for Service Access from outside (ingress)

BIG-IP Next for Kubernetes is also a controller for Kubernetes Gateway API. In the following example we will deploy a simple Nginx service in the **red** tenant namespace and advertise it's service to the infrastructure.

The following diagram represents the service ingress path.

![bnk_ingress_vxlan](media/nvidia_bnk_lab_diagram_ingress_vxlan.svg)

1. Deploy nginx to the red namespace.

```bash
host# cat << EOF | kubectl -n red apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx-tcp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-tcp
  template:
    metadata:
      labels:
        app: nginx-tcp
    spec:
      nodeSelector:
        node-role.kubernetes.io/gpu: ""
      containers:
      - name: nginx-tcp
        image: nginx:latest
        ports:
        - containerPort: 80
        imagePullPolicy: IfNotPresent
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-app-svc
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx-tcp
EOF
```
2. Expose the service to network

The gateway CRs below cause TMM to configure and expose virtual server at IP `192.168.10.100` port `80` as the diagram suggested.

>NOTE: For simplicity an IP address from the same subnet as the test server/client was used but this can be any IP address as long as the server/client is properly routed through one of the TMM's VLAN addresses.

>NOTE: In this configuration, the TMM will use SNAT-AUTOMAP feature which means it will SNAT external client IP addresses when communicating with backend endpoints with TMM's own IP address _not_ an address from snatpool.

```bash
host# cat << EOF | kubectl -n red apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: f5-gateway-class
  namespace: red
spec:
  controllerName: "f5.com/f5-gateway-controller"
  description: "F5 BIG-IP Kubernetes Gateway"
---
apiVersion: gateway.k8s.f5net.com/v1
kind: Gateway
metadata:
  name: my-l4route-tcp-gateway
  namespace: red
spec:
  addresses:
  - type: "IPAddress"
    value: 192.168.10.100
  gatewayClassName: f5-gateway-class
  listeners:
  - name: nginx
    protocol: TCP
    port: 80
    allowedRoutes:
      kinds:
      - kind: L4Route
---
apiVersion: gateway.k8s.f5net.com/v1
kind: L4Route
metadata:
  name: l4-tcp-app
  namespace: red
spec:
  protocol: TCP
  parentRefs:
  - name: my-l4route-tcp-gateway
    sectionName: nginx
  rules:
  - backendRefs:
    - name: nginx-app-svc
      namespace: red
      port: 80
EOF
```