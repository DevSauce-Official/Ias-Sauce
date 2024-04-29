# Overview

This guide enables to reproduce and evaluate the underlying software stack for Confidential Containers on AKS using Azure Linux.
The underlying software stack referred to in this guide will stretch from containerd to lower layers, for instance, enabling to deploy Kata (Confidential) Containers via the OCI interface, or deploying a local kubelet, or leveraging AKS' Kubernetes solution.

# Pre-requirements

Reproduction can happen in various environments - the details here are omitted:
- Deploy an Azure Linux VM via `az vm create` using a [CC vm size SKU](https://learn.microsoft.com/en-us/azure/virtual-machines/dcasccv5-dcadsccv5-series)
  - Example: `az vm create --resource-group <rg_name> --name <vm_name> --os-disk-size-gb <e.g. 60> --public-ip-sku Standard --size <e.g. Standard_DC4as_cc_v5> --admin-username azureuser --ssh-key-values <ssh_pubkey> --image <MicrosoftCBLMariner:cbl-mariner:...> --security-type Standard`
- Deploy a [Confidential Containers for AKS cluster](https://learn.microsoft.com/en-us/azure/aks/deploy-confidential-containers-default-policy) via `az aks create`. Note, this way the bits built in this guide will already be present on the cluster's Azure Linux based nodes.
  - Deploy a debugging pod onto one of the nodes, SSH onto the node.
- Not validated: Install [Azure Linux](https://github.com/microsoft/azurelinux) on a bare metal machine supporting AMD SEV-SNP.

The following steps assume the user has direct console access on the environnment that was set up.

# Refresh the DNF cache
```sudo dnf -y makecache```

# Deploy required virtualization packages (e.g., VMM, kernel and Microsoft Hypervisor)

Note: This step can be skipped if your environment was set up through `az aks create`

Install relevant packages:
```sudo dnf -y install kata-packages-host```

Note: We currently use a [forked version](https://github.com/microsoft/confidential-containers-containerd/tree/tardev-v1.7.7) of `containerd` called `containerd-cc` which is installed as part of the `kata-packages-host` package. This containerd version is based on stock containerd with patches to support the Confidential Containers on AKS use case.

Edit the grub config to boot into the SEV SNP capable kernel upon next reboot:
```
boot_uuid=$(sudo grep -o -m 1 '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}' /boot/efi/boot/grub2/grub.cfg)

sudo sed -i -e 's@load_env -f \$bootprefix\/mariner.cfg@load_env -f \$bootprefix\/mariner-mshv.cfg\nload_env -f $bootprefix\/mariner.cfg\n@'  /boot/grub2/grub.cfg

sudo sed -i -e 's@menuentry "CBL-Mariner"@menuentry "Dom0" {\n    search --no-floppy --set=root --file /HvLoader.efi\n    chainloader /HvLoader.efi lxhvloader.dll MSHV_ROOT=\\\\Windows MSHV_ENABLE=TRUE MSHV_SCHEDULER_TYPE=ROOT MSHV_X2APIC_POLICY=ENABLE MSHV_SEV_SNP=TRUE MSHV_LOAD_OPTION=INCLUDETRACEMETADATA=1\n    boot\n    search --no-floppy --fs-uuid '"$boot_uuid"' --set=root\n    linux $bootprefix/$mariner_linux_mshv $mariner_cmdline_mshv $systemd_cmdline root=$rootdevice\n    if [ -f $bootprefix/$mariner_initrd_mshv ]; then\n    initrd $bootprefix/$mariner_initrd_mshv\n    fi\n}\n\nmenuentry "CBL-Mariner"@'  /boot/grub2/grub.cfg
```

Reboot the system:

```sudo reboot now```

# Add Kata handler configuration snippets to containerd configuration

Note: This step can be skipped if your environment was set up through `az aks create`.

An editor like `vim` may need to be installed, for example:
`sudo dnf -y install vim`

Edit `/etc/containerd/config.toml` to set following configuration:

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

# Install general build dependencies

```sudo dnf install -y git vim golang rust build-essential protobuf-compiler protobuf-devel expect openssl-devel clang-devel libseccomp-devel parted qemu-img btrfs-progs-devel device-mapper-devel cmake fuse-devel jq curl kata-packages-uvm-build```

### TODO: add kernel-uvm-devel to kata-packages-uvm-build, or kata-containers-cc-tools
If you intend to build the confpods UVM, install the following package:
```sudo dnf install -y kernel-uvm-devel``

## Optional: Build and deploy the containerd fork from scratch

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

# Use Kata tooling to build the Kata host and guest components

If these instructions are not being followed based on having cloned its hosting repository onto the system, clone the kata-containers repository:
```git clone --depth 1 --branch mahuber/reproducible-builds https://github.com/microsoft/kata-containers.git```

To build Azure Linux's kata-containers package components and UVM, run:
```
pushd kata-containers/tools/osbuilder/node-builder/azure-linux
make all
popd
```
To build the kata-containers-cc package components and UVM, run `make all-confpods`.
The `all` target runs the `clean[-confpods]`, `package[-confpods]` and `uvm[-confpods]` targets in a single step (the `uvm` target depends on the `package` target).

**Note:** By default, a UVM with Kata Agent enforcing a restrictive policy will be built, this requiring to generate valid pod security policy annotations using the `genpolicy` tool. While always recommended to do keep doing so, a UVM with a permissive security policy can be built by adapting the file `tools/osbuilder/node-builder/azure-linux/uvm_build.sh` and changing the `AGENT_POLICY_FILE` variable assignment to `allow-all.rego`

# Install the built components

In this step, we move the build artifacts to proper places and eventually restart containerd so that the new Kata(-CC) configuration files are loaded.
The following commands refer to having built the components and UVM for Azure Linux's kata-containers package in the prior step.
If you built the kata-containers-cc package components, call the `deploy-confpods` make target.

```
pushd kata-containers/tools/osbuilder/node-builder/azure-linux
sudo make deploy
popd
```

# Run Kata Confidential Containers

## Run via OCI

Use e.g. `crictl` (or `ctr`) to schedule Kata(-CC) containers, referencing either the Kata or Kata-CC handlers.

The following sets of commands serve as a general reference for installing `crictl` and setting up some basic CNI to run pods:
- Install `crictl`:

  `sudo dnf -y install cri-tools`

- Set up CNI, example:

  *TODO*

- Create a pod manifest (and apply policy), simple example:

  ```
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
  ```

- Run a Kata or Kata-CC pod with `crictl`:

  `sudo crictl runp -T 30s -r <kata/kata-cc> <path/to/pod.yaml>`

- Decommission pods:

  `sudo crictl pods`

  `sudo crictl stopp <pod_id>`

  `sudo crictl rmp <pod_id>`

Examples with `crictl`:
- `sudo ctr image pull --snapshotter=tardev docker.io/library/busybox:latest`
- `sudo ctr run --cni --runtime io.containerd.run.kata.v2 --runtime-config-path /usr/share/defaults/kata-containers/configuration.toml -t --rm docker.io/library/busybox:latest hello sh`
- `sudo ctr run --cni --runtime io.containerd.run.kata-cc.v2 --runtime-config-path /opt/confidential-containers/share/defaults/kata-containers/configuration-clh-snp.toml --snapshotter tardev -t --rm docker.io/library/busybox:latest hello sh`

For further usage we refer to the upstream `crictl` (or `ctr`) and CNI documentation.

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
