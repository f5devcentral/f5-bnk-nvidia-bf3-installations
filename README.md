# Lab Guide - F5 Titan BIG-IP Next for Kubernetes Install Instructions on Nvidia BlueField-3

This guide is published at https://f5devcentral.github.io/f5-bnk-nvidia-bf3-installations/

Updated here for Version v2.1.0

## Installer Requirements

- Linux or OSX host (server or VM)
- CLI tools: ansible make git sshpass yq

## Cluster Requirements

- 2 Ubuntu 22.04 servers with one NVIDIA Bluefield-3 DPU each
- Both DPU high speed ports connected via Link Aggregation (LACP fast) to Leaf switch
- DPU OOB Ethernet ports connected via mgmt switch to both Ubuntu servers
- Public Internet access from DPU and Ubuntu servers
- DHCP service on mgmt network for DPU OOB port. The server and DPU IP addresses must be set in
inventory/f5-bnk-cluster/hosts.yml 

## Deployment

Check/set inventory/f5-bnk-cluster/hosts.yml variables and set the server and DPU's OOB IP addresses

### DPU

The DPU nodes are imaged from the server hosting the DPUs. The required NVIDIA DOCA networking package
can be installed on all servers via ansible

```
make doca
```

BFB image is automatically downloaded and installed using the config template [dpu/bf-template.conf](dpu/bf-template.conf) via
ansible. Enter the desired ubuntu password for the DPU OS, must be at least 12 characters long, when asked.

```
$ make dpu
Bluefield-3 DPU set user ubuntu password (at least 12 characters):
PLAY [Image BlueField DPUs] *************************************************************************************************************************************************************************************

TASK [Ensure working dirs exist] ********************************************************************************************************************************************************************************
ok: [worker2] => (item=/var/tmp)
ok: [worker1] => (item=/var/tmp)
ok: [worker1] => (item=/var/tmp)
ok: [worker2] => (item=/var/tmp)

TASK [Import DPU ubuntu plain password from environment (if present)] *******************************************************************************************************************************************
ok: [worker1]
ok: [worker2]

TASK [Derive DPU_UBUNTU_PASSWORD_HASH from plain (sha512_crypt)] ************************************************************************************************************************************************
ok: [worker1]
ok: [worker2]

TASK [Set per-node paths and hostname (and expose BFB_CONFIG)] **************************************************************************************************************************************************
ok: [worker1]
ok: [worker2]
. . .

TASK [Download BFB image unless already present] ****************************************************************************************************************************************************************
ok: [worker2]
ok: [worker1]

TASK [Run bfb-install with rshim0] ******************************************************************************************************************************************************************************
ok: [worker2]
ok: [worker1]

TASK [Wait until DPU worker1-dpu is reachable via ping] *********************************************************************************************************************************************************
ok: [worker2 -> localhost]
ok: [worker1 -> localhost]

TASK [Install our controller’s SSH public key on the DPU] *******************************************************************************************************************************************************
changed: [worker2 -> localhost]
changed: [worker1 -> localhost]

PLAY RECAP ******************************************************************************************************************************************************************************************************
worker1                    : ok=19   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
worker2                    : ok=16   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

You can monitor imaging progress from the server via DPU serial console `sudo screen /dev/rshim0/console 115200`. Exit with `Ctrl-A :quit`.

The generated DPU used during the imaging process are stored locally for reference:

```
$ ls inventory/f5-bnk-cluster/artifacts/dpu-configs/
worker1-dpu.conf        worker2-dpu.conf
```

Once completed, ssh into each DPU. Access is granted without asking for a password now.

Verify that DPU LAG interface bond0 is up and both member links are active:

```
$ ./scripts/bond0_full_report.sh worker1-dpu        # or IP address

─── worker1-dpu Bond “bond0” ────────────────────────────────────────────────────────────────────────
Driver                v5.15.0-1060-bluefield
Mode                  IEEE 802.3ad Dynamic link aggregation
Hash Policy           layer3+4 (1)
MII Status            up
LACP active           on
LACP rate             fast
Min links             0
System priority       65535
System MAC address    ea
MII Status            up
Active Aggregator ID  2
MII Status            up
Active Aggregator ID  2

IFACE  MII  SPD    DUPLEX  FAIL  AGGID | A_PNUM A_KEY     A_STATE    | P_PNUM P_KEY     P_STATE    | PARTNER_MAC
p1     Status: 200G   full    1     2     | 1      31        activity,timeout,aggregation,sync,collecting,distributing | 1      31        activity,timeout,aggregation,sync,collecting,distributing | d2
p0     Status: 200G   full    1     2     | 2      31        activity,timeout,aggregation,sync,collecting,distributing | 2      31        activity,timeout,aggregation,sync,collecting,distributing | d2
```

Check links or power cycle the server hosting the DPU if this is the very first time LAG has been enabled on this DPU, then check again.

```
$ rm ~/.ssh/known_hosts

$ ssh ubuntu@worker1-dpu
The authenticity of host '192.168.68.79 (192.168.68.79)' can't be established.
ED25519 key fingerprint is SHA256:K0XtfiEuHOMp90zInuYoq/aoTK2SJry6KFmySuZd6uM.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.68.79' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-1060-bluefield aarch64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Thu Oct  2 12:56:21 UTC 2025
. . .

```

### Cluster

```
$ make cluster
```

Check cluster via kubectl

```
$ export KUBECONFIG=$PWD/inventory/f5-bnk-cluster/artifacts/admin.conf

$ kubectl get node -o wide
NAME          STATUS   ROLES           AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION          CONTAINER-RUNTIME
worker1       Ready    control-plane   3m36s   v1.32.8   192.168.68.104   <none>        Ubuntu 22.04.5 LTS   5.15.0-157-generic      containerd://2.0.6
worker1-dpu   Ready    <none>          2m47s   v1.32.8   192.168.68.79    <none>        Ubuntu 22.04.5 LTS   5.15.0-1060-bluefield   containerd://2.0.6
worker2       Ready    <none>          3m      v1.32.8   192.168.68.101   <none>        Ubuntu 22.04.5 LTS   5.15.0-157-generic      containerd://2.0.6
Worker2-dpu   Ready    <none>          2m47s   v1.32.8   192.168.68.96    <none>        Ubuntu 22.04.5 LTS   5.15.0-1060-bluefield   containerd://2.0.6
```

### Destroy Cluster

```
$ make clean-all
```

