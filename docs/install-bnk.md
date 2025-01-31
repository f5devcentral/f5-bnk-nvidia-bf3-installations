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

<div class="grid" markdown>

- Login to the [MyF5](https://my.f5.com/).
- Navigate to __Resources__ and click __Downloads__. ![myf5](assets/images/myf5-downloads.png){ align=right }
- Ensure account is selected then review the [End User License Agreement](https://www.f5.com/pdf/customer-support/end-user-license-agreement.pdf) and the [Program Terms](https://www.f5.com/pdf/customer-support/program-terms.pdf) and click to check the box for `I have read and agreed to the terms of the End User License Agreement and Program Terms.` ![alt text](assets/images/myf5-license-agreement.png)
- For Group select __BIT-IP_Next__, and __Service Proxy for Kubernetes (SPK)__ in Product Line, and __1.9.2__ for Product Version. ![MyF5 Select Product Family](assets/images/myf5-spk-192.png)
- Select __f5-far-auth-key.tgz__ to download. ![MyF5 Select FAR File](assets/images/myf5-select-far.png)
- Choose a location to download from and then download the file or copy link and download on the host linux. ![MyF5 Download FAR Auth](assets/images/myf5-download-far-auth.png)
- Copy the downloaded file `zxvf f5-far-auth-key.tgz` to host dpu-install directory and expand to see a file named `cne_pull_64.json`. That is the file that contains FAR authentication key.
- Use the [far-kubernetes-secret.sh](assets/scripts/far-kubernetes-secret.sh) generate and install required Kubernetes pull secrets for FAR images.
      ``` console
      host# ./far-kubernetes-secret.sh
      ```
- Login to FAR helm registery from host terminal where kubectl and helm commands are available
      ``` console
      host# cat cne_pull_64.json | helm registry login -u _json_key_base64 --password-stdin https://repo.f5.com
      ```
</div>


## 4. Cluster Wide Controller requirements

The Cluster Wide Controller (CWC) component manages license registeration and debug API. In this release there are some manual requirements that are needed. The steps also can be found in [F5 guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/2.0.0-LA/cwc-certificate.html) to generate and install required certificates and ConfigMap.

Generate certificates that will be used to communicate with CWC component API, by pulling the script from F5 repo then generating certs for the f5-utils namespace service as follows.

- Pull and extract the chart containing cert generation scripts
    Install required package "make"
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
    host#
    ```
    ```
    ```console
    host# helm pull oci://repo.f5.com/utils/f5-cert-gen --version 0.9.1
    Pulled: repo.f5.com/utils/f5-cert-gen:0.9.1
    Digest: sha256:89d283a7b2fef651a29baf1172c590d45fbd1e522fa90207ecd73d440708ad34
    ```

    ```console
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

    ```bash
    host# kubectl apply -f cwc-license-certs.yaml -n f5-utils
    host# kubectl apply -f cwc-license-client-certs.yaml -n f5-utils
    ```

- Install qkview config map file.
    ```bash
    host# cat << EOF | kubectl -n f5-utils apply -f -
    apiVersion: v1
    kind: ConfigMap
    metadata:
       name: cwc-qkview-cm
    EOF
    ```

- Install Json Key Set for license activation

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

## 5. Scalable Function CNI Binary

F5 created a CNI binary used here to move Scalable Function netdevice and RDMA devices inside of the dataplane container. This CNI is invoked by Multus delegation when attaching the Dataplane component to defined networks.

```bash
host# helm pull oci://repo.f5.com/utils/f5-eowyn  --version 2.0.0-LA.1-0.0.11
host# tar zxvf f5-eowyn-2.0.0-LA.1-0.0.11.tgz 
f5-eowyn/
f5-eowyn/sf
f5-eowyn/Chart.yaml
```
!!! note
    The `sf` CNI must be copied to all DPU nodes in the `/opt/cni/bin/` directory. For example:

```bash
host# scp f5-eowyn/sf root@<dpu-ip>:/opt/cni/bin/
```

## 6. Configure Network Attachment Definitions

Now that the CNI binary is installed we can configure Multus Network Attachment Definitions based on the configuration used in SR-IOV Device Plugin ConfigMap and using the `sf` CNI.\
Apply the [network-attachments.yaml](assets/config/network-attachments.yaml) configuration to the default namespace.

This step will create two network attachment definitions for internal and external scalable functions as described in the lab diagram.

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
    ---8<-- "assets/config/infrastructure-cr.yaml"
    ```

### `SPKInstance` Custom Resource

Download or copy the [instance-cr.yaml](assets/config/instance-cr.yaml) file and modify the `jwt:` with your license token obtained from MyF5.

??? note "Show SPKInstance content"
    ``` yaml
    ---8<-- "assets/config/instance-cr.yaml"
    ```

Ensure that all pods in `default` and `f5-utils` namespaces are healthy. This can take up to 10 minutes.
