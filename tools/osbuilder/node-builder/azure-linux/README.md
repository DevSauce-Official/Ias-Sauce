# Overview

This guide enables to build and evaluate the underlying software stack for Kata Containers on AKS and for Confidential Containers on AKS using Azure Linux.
The underlying software stack referred to in this guide will stretch from containerd to lower layers, for instance, enabling to deploy Kata (Confidential) Containers via the OCI interface, or deploying a local kubelet, or leveraging AKS' Kubernetes solution.

In the following, the terms Kata and Kata-CC refer to Kata Containers on AKS and Confidential Containers on AKS, respectively.

# Pre-requirements

While build can happen in any Azure Linux based environment, the stack can only be evaluated in Azure Linux environments on top of AMD SEV-SNP - the details here are omitted:
- Deploy an Azure Linux VM via `az vm create` using a [CC vm size SKU](https://learn.microsoft.com/en-us/azure/virtual-machines/dcasccv5-dcadsccv5-series)
  - Example: `az vm create --resource-group <rg_name> --name <vm_name> --os-disk-size-gb <e.g. 60> --public-ip-sku Standard --size <e.g. Standard_DC4as_cc_v5> --admin-username azureuser --ssh-key-values <ssh_pubkey> --image <MicrosoftCBLMariner:cbl-mariner:...> --security-type Standard`
- Deploy a [Confidential Containers for AKS cluster](https://learn.microsoft.com/en-us/azure/aks/deploy-confidential-containers-default-policy) via `az aks create`. Note, this way the bits built in this guide will already be present on the cluster's Azure Linux based nodes.
  - Deploy a debugging pod onto one of the nodes, SSH onto the node.
- Not validated for evaluation: Install [Azure Linux](https://github.com/microsoft/azurelinux) on a bare metal machine supporting AMD SEV-SNP.

To only build the stack, we refer to the official [Azure Linux GitHub page](https://github.com/microsoft/azurelinux) to set up Azure Linux.

The following steps assume the user has direct console access on the environnment that was set up.

# Deploy required virtualization packages (e.g., VMM, SEV-SNP capable kernel and Microsoft Hypervisor)

Note: This step can be skipped if your environment was set up through `az aks create`

Install relevant packages and modify the grub configuration to boot into the SEV-SNP capable kernel `kernel-mshv` upon next reboot:
```
sudo dnf -y makecache
sudo dnf -y install kata-packages-host

boot_uuid=$(sudo grep -o -m 1 '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}' /boot/efi/boot/grub2/grub.cfg)

sudo sed -i -e 's@load_env -f \$bootprefix\/mariner.cfg@load_env -f \$bootprefix\/mariner-mshv.cfg\nload_env -f $bootprefix\/mariner.cfg\n@'  /boot/grub2/grub.cfg

sudo sed -i -e 's@menuentry "CBL-Mariner"@menuentry "Dom0" {\n    search --no-floppy --set=root --file /HvLoader.efi\n    chainloader /HvLoader.efi lxhvloader.dll MSHV_ROOT=\\\\Windows MSHV_ENABLE=TRUE MSHV_SCHEDULER_TYPE=ROOT MSHV_X2APIC_POLICY=ENABLE MSHV_SEV_SNP=TRUE MSHV_LOAD_OPTION=INCLUDETRACEMETADATA=1\n    boot\n    search --no-floppy --fs-uuid '"$boot_uuid"' --set=root\n    linux $bootprefix/$mariner_linux_mshv $mariner_cmdline_mshv $systemd_cmdline root=$rootdevice\n    if [ -f $bootprefix/$mariner_initrd_mshv ]; then\n    initrd $bootprefix/$mariner_initrd_mshv\n    fi\n}\n\nmenuentry "CBL-Mariner"@'  /boot/grub2/grub.cfg
```

Reboot the system:
```sudo reboot```

Note: We currently use a [forked version](https://github.com/microsoft/confidential-containers-containerd/tree/tardev-v1.7.7) of `containerd` called `containerd-cc` which is installed as part of the `kata-packages-host` package. This containerd version is based on stock containerd with patches to support the Confidential Containers on AKS use case.

# Add Kata(-CC) handler configuration snippets to containerd configuration

Note: This step can be skipped if your environment was set up through `az aks create`.

An editor like `vim` may need to be installed, for example:
`sudo dnf -y install vim`

Set the following containerd configuration in `/etc/containerd/config.toml`:

```
sudo tee /etc/containerd/config.toml 2&>1 <<EOF
version = 2
oom_score = 0
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "mcr.microsoft.com/oss/kubernetes/pause:3.6"
  [plugins."io.containerd.grpc.v1.cri".containerd]
      disable_snapshot_annotations = false
    default_runtime_name = "runc"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      BinaryName = "/usr/bin/runc"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.untrusted]
      runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.untrusted.options]
      BinaryName = "/usr/bin/runc"
  [plugins."io.containerd.grpc.v1.cri".cni]
    bin_dir = "/opt/cni/bin"
    conf_dir = "/etc/cni/net.d"
    conf_template = "/etc/containerd/kubenet_template.conf"
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
  [plugins."io.containerd.grpc.v1.cri".registry.headers]
    X-Meta-Source-Client = ["azure/aks"]
[metrics]
  address = "0.0.0.0:10257"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  runtime_type = "io.containerd.kata.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.katacli]
  runtime_type = "io.containerd.runc.v1"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.katacli.options]
  NoPivotRoot = false
  NoNewKeyring = false
  ShimCgroup = ""
  IoUid = 0
  IoGid = 0
  BinaryName = "/usr/bin/kata-runtime"
  Root = ""
  CriuPath = ""
  SystemdCgroup = false
[proxy_plugins]
  [proxy_plugins.tardev]
    type = "snapshot"
    address = "/run/containerd/tardev-snapshotter.sock"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-cc]
  snapshotter = "tardev"
  runtime_type = "io.containerd.kata-cc.v2"
  privileged_without_host_devices = true
  pod_annotations = ["io.katacontainers.*"]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-cc.options]
    ConfigPath = "/opt/confidential-containers/share/defaults/kata-containers/configuration-clh-snp.toml"
EOF
```

Restart containerd:

```sudo systemctl restart containerd```

# Install general build dependencies

```
sudo dnf -y makecache
sudo dnf install -y git vim golang rust build-essential protobuf-compiler protobuf-devel expect openssl-devel clang-devel libseccomp-devel parted qemu-img btrfs-progs-devel device-mapper-devel cmake fuse-devel jq curl kata-packages-uvm-build kernel-uvm-devel
```

# Optional: Build and deploy the containerd fork from scratch

```
git clone --depth 1 --branch tardev-v1.7.7 https://github.com/microsoft/confidential-containers-containerd.git
pushd confidential-containers-containerd/
GODEBUG=1 make
popd
```

Overwrite existing containerd binary, restart service:
```
sudo cp -a -S .bak -b confidential-containers-containerd/bin/containerd /usr/bin/containerd
sudo systemctl restart containerd
```

# Build and install the Kata(-CC) host and guest components

Clone the Microsoft's fork of the kata-containers repository:
```git clone --depth 1 --branch mahuber/reproducible-builds https://github.com/microsoft/kata-containers.git```

To build and install Kata Containers for AKS components, run:
```
pushd kata-containers/tools/osbuilder/node-builder/azure-linux
make all
sudo make deploy
popd
```

To build and install Confidential Containers for AKS, use the `all-confpods` and `deploy-confpods` targets:
```
pushd kata-containers/tools/osbuilder/node-builder/azure-linux
make all-confpods
sudo make deploy-confpods
popd
```

The `all[-confpods]` target runs the `clean[-confpods]`, `package[-confpods]` and `uvm[-confpods]` targets in a single step (the `uvm` target depends on the `package` target). The `deploy[-confpods]` target moves the build artifacts to proper places.

Note: For incremental build and deployment of both Kata and Kata-CC artifacts, first run the `make all` and `make deploy` commands to build and install the Kata Containers for AKS components, and then `make all-confpods` and `make deploy-confpods` to build and install the Confidential Containers for AKScomponents, or vice versa.

# Run Kata (Confidential) Containers

## Run via CRI or via containerd API

Use e.g. `crictl` (or `ctr`) to schedule Kata (Confidential) containers, referencing either the Kata or Kata-CC handlers.

Note: On Kubernetes nodes, pods created via `crictl` will be deleted by the control plane.

The following sets of commands serve as a general reference for installing `crictl` and setting up some basic CNI to run pods:
- Install `crictl`, set runtime endpoint in `crictl` configuration:

  ```
  sudo dnf -y install cri-tools
  sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
  ```

- Install CNI binaries and set a sample CNI config:

  ```
  sudo dnf -y install cni
  sudo mv /etc/cni/net.d/99-loopback.conf.sample /etc/cni/net.d/99-loopback.conf
  sudo tee /etc/cni/net.d/10-mynet.conf 2&>1 <<EOF
  {
          "cniVersion": "0.2.0",
          "name": "mynet",
          "type": "bridge",
          "bridge": "cni0",
          "isGateway": true,
          "ipMasq": true,
          "ipam": {
                  "type": "host-local",
                  "subnet": "10.22.0.0/16",
                  "routes": [
                          { "dst": "0.0.0.0/0" }
                  ]
          }
  }
  EOF
  ```

  The `10-mynet` configuration file example is derived from: `https://github.com/containernetworking/cni`

- Create a pod manifest (and apply policy), simple example:

  ```
  cat << EOF > sample-pod.yaml
  apiVersion: v1
  kind: Pod
  metadata:
    namespace: busybox-ns
    name: busybox
    uid: busybox-id
  spec:
    containers:
    - image: docker.io/library/busybox:latest
      name: busybox
  EOF
  ```

- Run a runc, Kata, or Kata-CC pod with `crictl`:

  `sudo crictl runp -T 30s -r runc sample-pod.yaml`

  `sudo crictl runp -T 30s -r kata sample-pod.yaml`

  `sudo crictl runp -T 30s -r kata-cc sample-pod.yaml`

- Decommission pods:

  `sudo crictl pods`

  `sudo crictl stopp <pod_id>`

  `sudo crictl rmp <pod_id>`

Examples for `ctr` for runc, vanilla Kata and Kata-CC pods:
- `sudo ctr image pull --snapshotter=tardev docker.io/library/busybox:latest`
- `sudo ctr run --cni --runtime io.containerd.run.kata.v2 --runtime-config-path /usr/share/defaults/kata-containers/configuration.toml -t --rm docker.io/library/busybox:latest hello sh`
- `sudo ctr run --cni --runtime io.containerd.run.kata-cc.v2 --runtime-config-path /opt/confidential-containers/share/defaults/kata-containers/configuration-clh-snp.toml --snapshotter tardev -t --rm docker.io/library/busybox:latest hello sh`

Example with `ctr` for runc pods:
- `sudo ctr image pull docker.io/library/busybox:latest`
- `sudo ctr run --cni --runtime io.containerd.run.runc.v2 -t --rm docker.io/library/busybox:latest hello sh`

For further usage we refer to the upstream `crictl` (or `ctr`) and CNI documentation.

## Run via Kubernetes

If your environment was set up through `az aks create` the respective node is ready to run Kata (Confidential) Containers as AKS Kubernetes pods.
Other types of Kubernetes clusters should work as well - but this document doesn't cover how to set-up those clusters.

Next, apply the kata and kata-cc runtime classes on the machine that holds your kubeconfig file:
```
cat << EOF > runtimeClass-kata-cc.yaml
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
    name: kata-cc
handler: kata-cc
overhead:
    podFixed:
        memory: "160Mi"
        cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
EOF

cat << EOF > runtimeClass-kata.yaml
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
    name: kata
handler: kata
overhead:
    podFixed:
        memory: "160Mi"
        cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
EOF

kubectl apply -f runtimeClass-kata-cc.yaml -f runtimeClass-kata.yaml
```

And label your node appropriately:
```
kubectl label node <nodename> katacontainers.io/kata-runtime=true
```

# Build attestation scenarios
The build artifacts include an IGVM file and a so-called reference measurement file (unsigned). The IGVM file is being loaded into memory measured by the AMD SEV-SNP PSP (when a Confidental Container is started). With this and with the Kata security policy feature, attestation scenarios can be built: the reference measurement (often referred to as 'endorsement') can, for example, be signed by a trusted party (such as Microsoft in Confidential Containers on AKS) and be compared with the actual measurement part of the attestation report. The latter can be retrieved through respective system calls inside the Kata Confidential Containers Guest VM.

An example for an attestation scenario through Microsoft Azure Attestation is presented in [Attestation in Confidential containers on Azure Container Instances](https://learn.microsoft.com/en-us/azure/container-instances/confidential-containers-attestation-concepts).
Documentation for leveraging the Kata security policy feature can be found in [Security policy for Confidential Containers on Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/confidential-computing/confidential-containers-aks-security-policy).
