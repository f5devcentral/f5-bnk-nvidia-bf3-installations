# Setup F5 BIG-IP Next for Kubernetes

The Kubernetes cluster is now ready for BIG-IP Next for Kubernetes installation.

## 1. Taint and Label

This lab assumes that DPU is dedicated for BNK installation. In order to prevent other general workload from scheduling on DPU node add the following taint.

!!! note
    Replace <dpu-node-name> with DPU node name.

``` console
host# kubectl taint node <dpu-node-name> dpu=true:NoSchedule
```

In this lab, BNK Dataplane is going to be installed as a Kubernetes daemonset and scheduled on nodes with the label `app=f5-tmm`.
Add the label to DPU node

``` console
host# kubectl label node <dpu-node-name> app=f5-tmm
```


## 2. Kubernetes Namespaces

The two main Kubernetes namespaces categories we use in this guide; Product, and Tenant namespaces.

### Product Namespaces

Used to install core components of BNK. In this lab guide, the BIG-IP Next for Kubernetes product will use 2 namespaces

  - **f5-utils:** All shared components for BIG-IP Next installation will use this namespace.
  - **default:** Operator, BIG-IP Next control plane, and BIG-IP Next Dataplane components will use this namespace.

!!! note
    `default` namespace is available by default after Kubernetes installation.
    We need to create only the `f5-utils` namespace.

``` console title="Create Product Namespaces"
host# kubectl create ns f5-utils
```

### Tenant Namespaces

F5 BNK watches specific Kubernetes namespaces for tenant services onboarding and configuring ingress/egress paths for these services.

!!! note
    As of the writing of this document BNK requires the namespaces to be created to product installation. This requirement may change in future.

In this guide we use two tenant namespaces, `red` and `blue`.

Create required namespaces:
``` console title="Create Tenant Namespaces"
host# for ns in red blue; do kubectl create ns $ns; done
```

## 3. Authentication with F5 Artifact Registery (FAR)

To access BNK product images, you must authenticate with the F5 Artifact Registry (FAR). In this section, we will go through obtaining the authentication key and creating Kubernetes pull secret.


1. Login to the [MyF5](https://my.f5.com/).
2. Navigate to __Resources__ and click __Downloads__. ![myf5](assets/images/myf5-downloads.png){ align=right }
3. Ensure account is selected then review the [End User License Agreement](https://www.f5.com/pdf/customer-support/end-user-license-agreement.png) and the [Program Terms](https://www.f5.com/pdf/customer-support/program-terms.png) and click to check the box for `I have read and agreed to the terms of the End User License Agreement and Program Terms.` ![alt text](assets/images/myf5-license-agreement.png)
4. For Group select __BIT-IP_Next__, and __Service Proxy for Kubernetes (SPK)__ in Product Line, and __1.9.2__ for Product Version. ![MyF5 Select Product Family](assets/images/myf5-spk-192.png)
5. Select __f5-far-auth-key.tgz__ to download. ![MyF5 Select FAR File](assets/images/myf5-select-far.png)
6. Choose a location to download from and then download the file or copy link and download on the host linux. ![MyF5 Download FAR Auth](assets/images/myf5-download-far-auth.png)
7. Copy the downloaded file `zxvf f5-far-auth-key.tgz` to host dpu-install directory and expand to see a file named `cne_pull_64.json`. That is the file that contains FAR authentication key.
8. Use the [far-kubernetes-secret.sh](assets/scripts/far-kubernetes-secret.sh) generate and install required Kubernetes pull secrets for FAR images.
    ``` console
    host# ./far-kubernetes-secret.sh
    ```
9. Login to FAR helm registery from host terminal where kubectl and helm commands are available
    ``` console
    host# cat cne_pull_64.json | helm registry login -u _json_key_base64 --password-stdin https://repo.f5.com
    ```


## 4. Cluster Wide Controller requirements

The Cluster Wide Controller (CWC) component manages license registeration and debug API. In this release there are some manual requirements that are needed. The steps also can be found in [F5 guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/2.0.0-LA/cwc-certificate.html) to generate and install required certificates and ConfigMap.

Generate certificates that will be used to communicate with CWC component API, by pulling the script from F5 repo then generating certs for the f5-utils namespace service as follows.

- Pull and extract the chart containing cert generation scripts
    Install required package "make"
    ```console
    host# apt-get install -y make
    ```

    ??? note "Example Output"
        ```console
        host# apt-get install -y make
        Reading package lists... Done
        Building dependency tree... Done
        Reading state information... Done
        Suggested packages:
          make-doc
        The following NEW packages will be installed:
          make
        0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
        Need to get 180 kB of archives.
        After this operation, 426 kB of additional disk space will be used.
        Get:1 http://archive.ubuntu.com/ubuntu jammy/main amd64 make amd64 4.3-4.1build1 [180 kB]
        Fetched 180 kB in 1s (218 kB/s)
        Selecting previously unselected package make.
        (Reading database ... 80515 files and directories currently installed.)
        Preparing to unpack .../make_4.3-4.1build1_amd64.deb ...
        Unpacking make (4.3-4.1build1) ...
        Setting up make (4.3-4.1build1) ...
        Processing triggers for man-db (2.10.2-1) ...
        Scanning processes...
        Scanning linux images...
        ```

    ```console
    host# helm pull oci://repo.f5.com/utils/f5-cert-gen --version 0.9.1
    host# tar zxvf f5-cert-gen-0.9.1.tgz
    ```   

    ??? note "Example Output"
        ```console
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

- Generate the API self-signed certificates. At the end of this step the script would have generated to main secret files Generating `cwc-license-certs.yaml` and `cwc-license-client-certs.yaml`

    ```console
    host# sh cert-gen/gen_cert.sh -s=api-server -a=f5-spk-cwc.f5-utils -n=1
    ```

    ??? note "Example Output"
        ```console
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

- Install secrets.

    ```console
    host# kubectl apply -f cwc-license-certs.yaml -n f5-utils
    host# kubectl apply -f cwc-license-client-certs.yaml -n f5-utils
    ```

- Install the [cwc-qkview-cm.yaml](assets/config/cwc-qkview-cm.yaml) qkview config map file.
    ```yaml
    ---8<--- "assets/config/cwc-qkview-cm.yaml"
    ```

- Install the [cpcl-non-prod.yaml](assets/config/cpcl-non-prod.yaml) file that contains Json Key Set for license activation

    ```yaml
    ---8<--- "assets/config/cpcl-non-prod.yaml"
    ```

## 5. Scalable Function CNI Binary

F5 created a CNI binary used here to move Scalable Function netdevice and RDMA devices inside of the dataplane container. This CNI is invoked by Multus delegation when attaching the Dataplane component to defined networks.

```console
host# helm pull oci://repo.f5.com/utils/f5-eowyn  --version 2.0.0-LA.1-0.0.11
host# tar zxvf f5-eowyn-2.0.0-LA.1-0.0.11.tgz
```

??? note "Example Output"
    ```console
    host# tar zxvf f5-eowyn-2.0.0-LA.1-0.0.11.tgz
    f5-eowyn/
    f5-eowyn/sf
    f5-eowyn/Chart.yaml
    ```

!!! note
    The `sf` CNI must be copied to all DPU nodes in the `/opt/cni/bin/` directory. For example:

```console
host# scp f5-eowyn/sf root@<dpu-ip>:/opt/cni/bin/
```

## 6. Configure Network Attachment Definitions

Now that the CNI binary is installed we can configure Multus Network Attachment Definitions based on the configuration used in SR-IOV Device Plugin ConfigMap and using the `sf` CNI.\
Apply the [network-attachments.yaml](assets/config/network-attachments.yaml) configuration to the default namespace.

This step will create two network attachment definitions for internal and external scalable functions as described in the lab diagram.

## 7. (Optional) Install Grafana and Prometheus

Using Prometheus and Grafana to collect and visualize the metrics.

### Install Prometheus

Prometheus example for this lab is defined in the [prometheus.yaml](assets/config/prometheus.yaml) file.

```yaml
---8<--- "assets/config/prometheus.yaml"
```

Apply the file in default namespace

```bash
host# kubectl apply -f prometheus.yaml
```
### Install Grafana

Grafana example for this lab is defined in the [grafana.yaml](assets/config/grafana.yaml) file.

```yaml
---8<--- "assets/config/grafana.yaml"
```

Apply the file in default namespace

```bash
host# kubectl apply -f grafana.yaml
```

#### Grafana Dashboard

An example Grafana dashboard is provided in the [grafana-dashboard.json](assets/config/grafana-dashboard.json) file.

```json
---8<--- "assets/config/grafana-dashboard.json"
```

Import the dashboard into Grafana

```bash
host# kubectl -n grafana port-forward svc/grafana 3000:3000 &
host# curl -X POST -H 'Content-Type: application/json' -d @grafana-dashboard.json http://admin:admin@localhost:3000/api/dashboards/db
```

## 7. Install BIG-IP Next for Kubernetes Operator in default namespace

The operator helps in installing BIG-IP Next for Kubernetes software. It requires two Custom Resources to be defined for the installation. **`SPKInfrastructure`** to describe dataplane infrastructure connections, and  **`SPKInstance`** which declares the state and configuration of the BNK product installation.

### Install the Operator chart

```bash
host# helm install orchestrator oci://repo.f5.com/charts/orchestrator \
        --version v0.0.25-0.0.96 \
        --set global.imagePullSecrets[0].name=far-secret \
        --set image.repository=repo.f5.com/images \
        --set image.pullPolicy=Always
```

### `SPKInfrastructure` Custom Resource

`SPKInfrastructure` resource includes refernces to the Network Attachment Definitions created earlier, and the resources provisioned for these networks as configured in the SR-IOV device plugin section.

The `SPKInfrastructure` resources is defined here [infrastructure-cr.yaml](assets/config/infrastructure-cr.yaml).

??? note "Show SPKInfrastructure content"
    ``` yaml
    ---8<--- "assets/config/infrastructure-cr.yaml"
    ```

### Install required Otel Certificates

Otel service requires certificates to be installed with specific name. These certs will be used for TLS communication between Otel and Prometheus.

Certificate requests for this lab can be found at [otel-certs.yaml](assets/config/otel-certs.yaml).

```yaml
---8<--- "assets/config/otel-certs.yaml"
```

Apply the certificates to the default namespace.

```bash
host# kubectl apply -f otel-certs.yaml
```


### `SPKInstance` Custom Resource

Download or copy the [instance-cr-otel.yaml](assets/config/instance-cr-otel.yaml) file and modify the `jwt:` with your license token obtained from MyF5.

??? note "Show SPKInstance content"
    ``` yaml
    ---8<--- "assets/config/instance-cr.yaml"
    ```

Ensure that all pods in `default` and `f5-utils` namespaces are healthy. This can take up to 10 minutes.
