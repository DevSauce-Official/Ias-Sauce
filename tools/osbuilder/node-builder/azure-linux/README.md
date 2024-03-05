# Overview

This guide enables to reproduce and evaluate the underlying software stack for Confidential Containers on AKS using Azure Linux.
The underlying software stack referred to in this guide will stretch from containerd to lower layers, for instance, enabling to deploy Kata (Confidential) Containers via the OCI interface, or deploying a local kubelet, or leveraging AKS' Kubernetes solution.

# Pre-requirements

Reproduction can happen in various environments - the details here are omitted:
- Install [Azure Linux](https://github.com/microsoft/azurelinux) on a bare metal machine supporting AMD SEV-SNP (unverified)
- Deploy an Azure Linux VM via `az vm create` using a [CC vm size SKU](https://learn.microsoft.com/en-us/azure/virtual-machines/dcasccv5-dcadsccv5-series) (ex. `--os-sku AzureLinux --node-vm-size Standard_DC4as_cc_v5`)
- Deploy a [Confidential Containers for AKS cluster](https://learn.microsoft.com/en-us/azure/aks/deploy-confidential-containers-default-policy) via `az aks create`. Note, this way the bits built in this guide will already be present on the cluster's Azure Linux based nodes.
  - Deploy a debugging pod on one of the nodes, SSH onto the node.

The following steps assume the user has direct console access on the environnment that was set up.

# Deploy required virtualization packages (e.g., VMM, kernel and Microsoft Hypervisor)

Note: This step can be skipped if your environment was set up through `az aks create`

Install relevant packages:
```sudo dnf -y install kata-packages-host```

Edit the grub config to boot into the SEV SNP capable kernel upon next reboot:
```
boot_uuid=$(sudo grep -o -m 1 '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}' /boot/efi/boot/grub2/grub.cfg)

sudo sed -i -e 's@load_env -f \$bootprefix\/mariner.cfg@load_env -f \$bootprefix\/mariner-mshv.cfg\nload_env -f $bootprefix\/mariner.cfg\n@'  /boot/grub2/grub.cfg

sudo sed -i -e 's@menuentry "CBL-Mariner"@menuentry "Dom0" {\n    search --no-floppy --set=root --file /HvLoader.efi\n    chainloader /HvLoader.efi lxhvloader.dll MSHV_ROOT=\\\\Windows MSHV_ENABLE=TRUE MSHV_SCHEDULER_TYPE=ROOT MSHV_X2APIC_POLICY=ENABLE MSHV_SEV_SNP=TRUE MSHV_LOAD_OPTION=INCLUDETRACEMETADATA=1\n    boot\n    search --no-floppy --fs-uuid '"$boot_uuid"' --set=root\n    linux $bootprefix/$mariner_linux_mshv $mariner_cmdline_mshv $systemd_cmdline root=$rootdevice\n    if [ -f $bootprefix/$mariner_initrd_mshv ]; then\n    initrd $bootprefix/$mariner_initrd_mshv\n    fi\n}\n\nmenuentry "CBL-Mariner"@'  /boot/grub2/grub.cfg
```

Reboot the system:

```sudo reboot now```

# Install general build dependencies

```sudo dnf install -y git vim golang rust build-essential protobuf-compiler protobuf-devel expect openssl-devel clang-devel libseccomp-devel parted qemu-img btrfs-progs-devel device-mapper-devel cmake fuse-devel kata-packages-uvm-build```


# Deploy the containerd fork for Confidential Containers on AKS

Note: This step can be skipped if your environment was set up through `az aks create`

We currently use a [forked version](https://github.com/microsoft/confidential-containers-containerd/tree/tardev-v1.7.7) of `containerd`. This containerd version is  based on stock containerd with patches to support the Confidential Containers on AKS use case.

This containerd version will be present when previously deploying an environment through `az aks create`. On other environments, remove the conflicting stock `containerd` and install the forked `containerd`:
```sudo dnf remove -y moby-containerd```
```sudo dnf install -y moby-containerd-cc```

## Optional: Build and deploy the containerd fork from scratch

```
git clone --depth 1 --branch tardev-v1.7.7 https://github.com/microsoft/confidential-containers-containerd.git
pushd confidential-containers-containerd/
GODEBUG=1 make
popd
```

Overwrite existing containerd binary, restart service:
```
if [ -f /usr/bin/containerd ]; then
  sudo mv /usr/bin/containerd /usr/bin/containerd.bak
fi
sudo cp confidential-containers-containerd/bin/containerd /usr/bin/containerd

sudo systemctl restart containerd
```

# Add Kata handler configuration snippets to containerd configuration

Note: This step can be skipped if your environment was set up through `az aks create`

Edit `/etc/containerd/config.toml` to append the configuration with the following contents:

```
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
```

Restart containerd:

```sudo systemctl restart containerd```

# Use Kata tooling to build the Kata host and guest components

If the instructions are not being followed based on its parent repository having being cloned on the system, clone the kata-containers repository:
```git clone --depth 1 --branch mahuber/reproducible-builds https://github.com/microsoft/kata-containers.git```

```
pushd kata-containers/tools/osbuilder/node-builder/azure-linux
 CONF_PODS=y ./host_builder.sh
./host_builder.sh
 CONF_PODS=y ./guest_builder.sh
./host_builder.sh
 CONF_PODS=y ./uvm_builder.sh
./uvm_builder.sh
```

# Install the built components

In this step, we move the build artifacts to proper places and eventually restart containerd so that the new Kata(-CC) configuration files are loaded.

```
pushd kata-containers/tools/osbuilder/node-builder/azure-linux
sudo  CONF_PODS=y ./host_deploy.sh
sudo ./host_deploy.sh
sudo CONF_PODS=y ./uvm_deploy.sh
sudo ./uvm_deploy.sh
popd
```

# Run Kata Confidential Containers

## Run via OCI

Use e.g. `crictl` to schedule containers, referencing either the Kata or Kata-CC handlers.

## Run via Kubernetes

If your environment was set up through `az aks create` the respective node is ready to run Kata or Kata Confidential Containers as AKS Kubernetes pods. In any other case, you can set up your own experimental Kubernetes cluster as well.

Next, apply your own runtime classes from the machine that has your kubeconfig file, e.g., for `kata-cc`:
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

kubectl apply -f runtimeClass-kata-cc.yaml runtimeClass-kata.yaml
```

And label your node appropriately:
```
kubectl label node <nodename>  katacontainers.io/kata-runtime=true
```

# Build attestation scenarios
The build artifacts include a IGVM file and a so-called reference measurement file (unsigned). The IGVM file is being loaded into memory measured by the AMD SEV-SNP PSP (when a Confidental Container is started). With this and with the Kata security policy feature, attestation scenarios can be built: the reference measurement (often referred to as 'endorsement') can, for example, be signed by a trusted party (such as Microsoft in Confidential Containers on AKS) and be compared with the actual measurement part of the attestation report. The latter can be retrieved through respective system calls inside the UVM.

An example for an attestation scenario through Microsoft Azure Attestation is presented in [Attestation in Confidential containers on Azure Container Instances](https://learn.microsoft.com/en-us/azure/container-instances/confidential-containers-attestation-concepts).
Documentation for leveraging the Kata security policy feature can be found in public documentation in [Security policy for Confidential Containers on Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/confidential-computing/confidential-containers-aks-security-policy).
