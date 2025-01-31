#!/bin/bash -x

generate_bluefield_config() {
    bf_conf_template=$(cat << 'EOFBFTEMPLATE'
# UPDATE_DPU_OS - Update/Install BlueField Operating System (Default: yes)
UPDATE_DPU_OS="yes"
 
# ubuntu_PASSWORD - Hashed password to be set for "ubuntu" user during BFB installation process.
# Relevant for Ubuntu BFB only. (Default: is not set)
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
    ##sed -i -E "s|^(OVS_BRIDGE1_PORTS=\")(.*)\"|\1\2 en3f0pf0sf1 pf0vf0\"|" /mnt/etc/mellanox/mlnx-ovs.conf
    ##sed -i -E "s|^(OVS_BRIDGE2_PORTS=\")(.*)\"|\1\2 en3f1pf1sf1 pf1vf0\"|" /mnt/etc/mellanox/mlnx-ovs.conf

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
                  binaryName = "/usr/local/sbin/runc"
  - path: /var/tmp/setup-script.sh
    permissions: '0755'
    encoding: base64
    content: |
      IyEvYmluL2Jhc2gKClRNUERJUj0kKG1rdGVtcCAtZCkKL3Vzci9zYmluL250cHdhaXQgLXYKc3lzdGVtY3RsIHN0b3AgY29udGFpbmVyZCBrdWJlbGV0IGt1YmVwb2RzLnNsaWNlCnJtIC1yZiAvdmFyL2xpYi9jb250YWluZXJkLyoKcm0gLXJmIC9ydW4vY29udGFpbmVyZC8qCnJtIC1mIC91c3IvbGliL3N5c3RlbWQvc3lzdGVtL2t1YmVsZXQuc2VydmljZS5kLzkwLWt1YmVsZXQtYmx1ZWZpZWxkLmNvbmYKYXB0IC15IHB1cmdlIGt1YmVsZXQga3ViZWFkbSB8fCB0cnVlCmN1cmwgLS1vdXRwdXQtZGlyICR7VE1QRElSfSAtTE8gaHR0cHM6Ly9naXRodWIuY29tL29wZW5jb250YWluZXJzL3J1bmMvcmVsZWFzZXMvZG93bmxvYWQvdjEuMi4xL3J1bmMuYXJtNjQKaW5zdGFsbCAtbSA3NTUgJHtUTVBESVJ9L3J1bmMuYXJtNjQgL3Vzci9sb2NhbC9zYmluL3J1bmMKY3VybCAtLW91dHB1dC1kaXIgJHtUTVBESVJ9IC1MTyBodHRwczovL2dpdGh1Yi5jb20vY29udGFpbmVyZC9jb250YWluZXJkL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjcuMjMvY29udGFpbmVyZC0xLjcuMjMtbGludXgtYXJtNjQudGFyLmd6CnRhciBDenh2ZiAvdXNyL2xvY2FsLyAke1RNUERJUn0vY29udGFpbmVyZC0xLjcuMjMtbGludXgtYXJtNjQudGFyLmd6Ci91c3IvbG9jYWwvYmluL2N0ciBvY2kgc3BlYyA+IC9ldGMvY29udGFpbmVyZC9jcmktYmFzZS5qc29uCmN1cmwgLUwgLW8gL2V0Yy9zeXN0ZW1kL3N5c3RlbS9jb250YWluZXJkLnNlcnZpY2UgaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NvbnRhaW5lcmQvY29udGFpbmVyZC9tYWluL2NvbnRhaW5lcmQuc2VydmljZQpzeXN0ZW1jdGwgZGFlbW9uLXJlbG9hZApzeXN0ZW1jdGwgZW5hYmxlIC0tbm93IGNvbnRhaW5lcmQKbWtkaXIgLXAgL2V0Yy9hcHQva2V5cmluZ3MKY3VybCAtZnNTTCBodHRwczovL3BrZ3MuazhzLmlvL2NvcmU6L3N0YWJsZTovdjEuMjkvZGViL1JlbGVhc2Uua2V5IHwgZ3BnIC0tZGVhcm1vciAtbyAvZXRjL2FwdC9rZXlyaW5ncy9rdWJlcm5ldGVzLWFwdC1rZXlyaW5nLmdwZwphcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkga3ViZWxldCBrdWJlYWRtIGt1YmVjdGwKc3lzdGVtY3RsIGRhZW1vbi1yZWxvYWQKc3lzdGVtY3RsIGVuYWJsZSAtLW5vdyBrdWJlbGV0CnJtIC1yZiAke1RNUERJUn0K

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
EOFBFTEMPLATE
)
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
        echo "$bf_conf_template" | sed -e "s/{{HOSTNAME}}/${hostname}/g" \
            -e "s|{{PASSWORD}}|${ubuntu_password}|g" \
            -e "s/{{IP_ADDRESS}}/${ip_address}/g" \
            -e "s/{{IP_MASK}}/${ip_mask}/g" \
            -e "s/{{NET_RSHIM_MAC}}/${net_rshim_mac}/g" \
            > "${output_file}"
        cat << EOL
Configuration for ${hostname} is ${output_file}
To use the config run:
bfb-install --rshim rshim$(( i - 1 )) --config ${output_file} --bfb <bf-bundle-path>
EOL
done
}


generate_bluefield_config