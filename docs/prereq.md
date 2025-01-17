# Prerequisites

## Software

This lab guide will walk you through setup of Kubernetes cluster using kubeadm. The guide assumes that you have Ubuntu 22.04 installed on the host machine and the Nvidia BlueField-3 is running in the default DPU mode, and uplink port links set to `ETH`.

!!! note
    The following table is provided as guidance if software installation is prefered outside of this guide.


| Software             | Version | Node/Selector | Installed in this Guide | Reference |
| :------------------- | :------ | :------------ | ----------------------- | :-------- |
| DOCA                 | 2.8+    | Host          | **Yes** | [NVIDIA DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/nvidia+doca+installation+guide+for+linux/index.html)
| BF Bundle BFB        | 2.8+    | DPU           | **Yes** | [Nvidia DOCA Downloads](https://developer.nvidia.com/doca-downloads?deployment_platform=BlueField&deployment_package=BF-Bundle&Distribution=Ubuntu&version=22.04&installer_type=BFB) |
| Kubelet              | 1.29+   | Host and DPU  | **Yes** | [Kubernetes Kubeadm guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
| Kubeadm              | 1.29+   | Host and DPU  | **Yes** |                                               
| Kubectl              | 1.29+   | Host and DPU  | **Yes** |                                               
| Containerd           | 1.7.22+ | Host and DPU  | **Yes** | [Containerd Getting Started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
| cert-manager         | 1.16.1+ | Host and DPU  | **Yes** | [Cert-manager installation](https://cert-manager.io/docs/installation/)
| SR-IOV Device Plugin | 3.7.0+  | DPU           | **Yes** | [SR-IOV Device Plugin](https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin?tab=readme-ov-file#quick-start)
| Multus               | 4.1.0+  | Host and DPU  | **Yes** | [Multus quick install](https://github.com/k8snetworkplumbingwg/multus-cni#quickstart-installation-guide)
| Calico               | 3.28.1+ | Host and DPU  | **Yes** | [Calico](https://github.com/projectcalico/calico)



## Hardware

This lab guide was tested on the following hardware configurations:

!!! note
    The hardware list below serves as example based on tested platforms. Only one of those or any other Nvidia DPU-3 compatible system is required for this guide.

| Vendor             | Model | CPU Architecture | # of Cores| RAM | Storage |
| :------------------- | :------ | :------------ | :-------- | :----- | :----- |
| Dell | Poweredge R750 | x86_64 | 96 | 512 GB | 21 TB |
| Supermicro | LB26-R16R12 | aarch64 | 96 | 512 GB | 20 TB |
| Supermicro | HGX AS-4125GS-TNRT | x86_64 | 128 | 768 GB | 12 TB |
| Supermicro | MGX ARS-111GL-NHR | aarch64 | 72 | 512 GB | 1.5 TB |


### AUX Cable

**HGX :** Part Numbers - CBL-PWEX-1040 and CBL-PWEX-1148-20

**MGX :** Part Number - CBL-PWEX-1040

**Dell :** [Amazon.com: BestParts New 12Pin to 8+8 Pin GPU Power Cable Compatible with Dell PowerEdge R750 R750XS R7525 Server 16inches DPHJ8 : Electronics](https://www.amazon.com/BestParts-Compatible-PowerEdge-R750XS-16inches/dp/B0BKKBXQVH)

### Network Optics

The following network optics were tested on the DPU ports.

**MGX & HGX :** 200Gb SR4 Ethernet Only - [NVIDIA Ethernet MMA1T00-VS Compatible QSFP56 200GBASE-SR4 850nm 100m DOM MPO12/UPC MMF Optical Transceiver Module, Support 4 x 50G-SR - FS.com](https://www.fs.com/products/139695.html)

**Dell R750 :** [F5 Networks F5-UPG-QSFP28-SR4 Compatible QSFP28 100GBASE-SR4 850nm](https://www.fs.com/products/84350.html?attribute=60343&id=3526322) \
[100m DOM MPO-12/UPC MMF Optical Transceiver Module, Support 4 x 25G-SR - FS.com](https://www.fs.com/products/84350.html?attribute=60343&id=3526322)

### GPU (Optional)

**HGX** = Nvidia H100 (x86)

**MGX** = NVIDIA GH200 (arm64)

### DPU

**Model :** B3220 Single-Slot FHHL w/ Crypto enabled

**NVIDIA OPN :** 900-9D3B6-00CV-AA0

**PSID :** MT_0000000884

