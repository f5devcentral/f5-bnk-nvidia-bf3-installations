Install Host Software

Create a directory for example `dpu-install` to prepare for installation.

Download the [install-host.sh](assets/scripts/install-host.sh) and modify the following default variables

??? note "Show content of install-host.sh"
    ``` bash
    ---8<--- "assets/scripts/install-host.sh"
    ```


|Variable | Description | Default|
| :----- | :----- | :----- |
| `MGMT_NET`| Management Network CIDR for host and DPU | `10.144.0.0/16` |
| `PF_INT` | Host PF 1 netdev name. This is the port connected to **Internal** network| enp83s0f1np1 |

!!! note
    Only use PF 1 for the variable `PF_INT`. Do not use `np0`.


Then run the script on the host machine.

```bash {title="Host Software Installation", data-copy-strip="^(host# )"}

host# chmod +x install-host.sh && ./install-host.sh
```

!!! note
    The script initalizes Kubernetes cluster also using `kubeadm init` it should only run on Controller node.