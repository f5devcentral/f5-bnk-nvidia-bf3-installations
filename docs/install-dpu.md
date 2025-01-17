# Install DPU Software

In the same directory `dpu-install` created in previous step.

## 1. Download BF Bundle

The BlueField bundle includes Operating System, Drivers, and DPU software tools. [Nvidia DOCA download](https://developer.nvidia.com/doca-downloads?deployment_platform=BlueField&deployment_package=BF-Bundle&Distribution=Ubuntu&version=22.04&installer_type=BFB)


## 2. Create bf config

The [dpu-config.sh](assets/scripts/dpu-config.sh) script will produce a BlueField install config file.

??? note "Show content of dpu-config.sh"
    ``` bash
    ---8<-- "assets/scripts/dpu-config.sh"
    ```

``` console title="DPU Installation"
host# chmod +x dpu-config.sh && ./dpu-config.sh
Enter the number of DPUs (default: 1): 1
Enter the base hostname (default: dpu): test-lab
Enter the Ubuntu password minimum 12 characters (e.g. 'a123456AbCd!'): 
Enter tmfifo_net IP subnet mask. Useful if you have more than 1 DPU (default: 30): 
Generating configuration for test-lab-1 with IP 192.168.100.2...
Configuration for test-lab-1 is bfb_config_test-lab-1.conf
To use the config run:
bfb-install --rshim rshim0 --config bfb_config_test-lab-1.conf --bfb <bf-bundle-path>
```

The script produced a file named `bfb_config_test-lab-1.conf` based on input.

## 3. Install BF Bundle

Use `bfb-install` tool to install the bf-bundle. The following example assumes bf-bundle `bf-bundle-2.9.0-83_24.10_ubuntu-22.04_dev.20241121.bfb`

``` console title="Install bf-bundle on DPU"
host# bfb-install --rshim rshim0 --config bfb_config_test-lab-1.conf --bfb bf-bundle-2.9.0-83_24.10_ubuntu-22.04_dev.20241121.bfb
```

Follow status of DPU installation on `/dev/rshim0/misc` until DPU is reported ready.

``` console
host# cat /dev/rshim0/misc 
DISPLAY_LEVEL   2 (0:basic, 1:advanced, 2:log)
BF_MODE         Unknown
BOOT_MODE       1 (0:rshim, 1:emmc, 2:emmc-boot-swap)
BOOT_TIMEOUT    300 (seconds)
USB_TIMEOUT     40 (seconds)
DROP_MODE       0 (0:normal, 1:drop)
SW_RESET        0 (1: reset)
DEV_NAME        pcie-0000:53:00.2
DEV_INFO        BlueField-3(Rev 1)
OPN_STR         N/A
UP_TIME         9628(s)
SECURE_NIC_MODE 0 (0:no, 1:yes)
FORCE_CMD       0 (1: send Force command)
---------------------------------------
            Log Messages
---------------------------------------
INFO[PSC]: PSC BL1 START
INFO[BL2]: start
INFO[BL2]: boot mode (emmc)
INFO[BL2]: VDD_CPU: 870 mV
INFO[BL2]: VDDQ: 1120 mV
INFO[BL2]: DDR POST passed
INFO[BL2]: UEFI loaded
INFO[BL31]: start
INFO[BL31]: lifecycle GA Secured
INFO[BL31]: runtime
INFO[BL31]: MB ping success
INFO[UEFI]: eMMC init
INFO[UEFI]: eMMC probed
INFO[UEFI]: UPVS valid
INFO[UEFI]: PCIe enum start
INFO[UEFI]: PCIe enum end
INFO[UEFI]: UEFI Secure Boot (disabled)
INFO[UEFI]: PK configured
INFO[UEFI]: Redfish enabled
INFO[UEFI]: DPU-BMC RF credentials not found
INFO[UEFI]: exit Boot Service
INFO[MISC]: Linux up
INFO[MISC]: DPU is ready
```

## 4. Join the DPU to the Kubernetes cluster

### 4.1. Get the join token from controller node/host

``` console
host# kubeadm token create --print-join-command
kubeadm join 10.144.50.50:6443 --token z8fvlo.ztt3mrepmjoiw2pe --discovery-token-ca-cert-hash sha256:3cdfd53eb85a23a1700f834ca9aa487aa7f455bfdcbadcb8ed470160ce9c2977
```

### 4.2. Join the Kubernetes cluster on the DPU

``` console
dpu# kubeadm join 10.144.50.50:6443 --token z8fvlo.ztt3mrepmjoiw2pe --discovery-token-ca-cert-hash sha256:3cdfd53eb85a23a1700f834ca9aa487aa7f455bfdcbadcb8ed470160ce9c2977
```