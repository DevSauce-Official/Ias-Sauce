# Install CSI driver with Helm 3

## Prerequisites
 - [install Helm](https://helm.sh/docs/intro/quickstart/#install-helm)

### Tips
 - make controller only run on master node: `--set controller.runOnMaster=true`
 - enable `fsGroupPolicy` on a k8s 1.20+ cluster: `--set feature.enableFSGroupPolicy=true`
 - set replica of controller as `1`: `--set controller.replicas=1` (only applied for NFS protocol)
 - specify different cloud config secret for the driver:
   - `--set controller.cloudConfigSecretName`
   - `--set controller.cloudConfigSecretNamesapce`
   - `--set node.cloudConfigSecretName`
   - `--set node.cloudConfigSecretNamesapce`
 - switch to `mcr.azk8s.cn` repository in Azure China: `--set image.baseRepo=mcr.azk8s.cn`

### install latest version
```console
helm repo add azurefile-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/charts
helm install azurefile-csi-driver azurefile-csi-driver/azurefile-csi-driver --namespace kube-system
```

### install a specific version
```console
helm repo add azurefile-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/charts
helm install azurefile-csi-driver azurefile-csi-driver/azurefile-csi-driver --namespace kube-system --version v1.4.0
```

### install on RedHat/CentOS
```console
helm install azurefile-csi-driver azurefile-csi-driver/azurefile-csi-driver --namespace kube-system --set linux.distro=fedora
```

### install driver with customized driver name, deployment name
> only supported from `v1.5.0`+
 - following example would install a driver with name `file2`
```console
helm install azurefile2-csi-driver azurefile-csi-driver/azurefile-csi-driver --namespace kube-system --set driver.name="file2.csi.azure.com" --set controller.name="csi-azurefile2-controller" --set rbac.name=azurefile2 --set serviceAccount.controller=csi-azurefile2-controller-sa --set serviceAccount.node=csi-azurefile2-node-sa --set linux.dsName=csi-azurefile2-node --set windows.dsName=csi-azurefile2-node-win --set node.livenessProbe.healthPort=39613
```

### search for all available chart versions
```console
helm search repo -l azurefile-csi-driver
```

## uninstall CSI driver
```console
helm uninstall azurefile-csi-driver -n kube-system
```

## latest chart configuration

The following table lists the configurable parameters of the latest Azure File CSI Driver chart and default values.

| Parameter                                         | Description                                                | Default                                                           |
|---------------------------------------------------|------------------------------------------------------------|-------------------------------------------------------------------|
| `driver.name`                                     | alternative driver name                                    | `file.csi.azure.com` |
| `driver.customUserAgent`                          | custom userAgent               | `` |
| `driver.userAgentSuffix`                          | userAgent suffix               | `OSS-helm` |
| `feature.enableFSGroupPolicy`                     | enable `fsGroupPolicy` on a k8s 1.20+ cluster(only applied for NFS protocol)              | `false`                      |
| `image.baseRepo`                                  | base repository of driver images                           | `mcr.microsoft.com`                      |
| `image.azurefile.repository`                      | azurefile-csi-driver docker image                          | `/k8s/csi/azurefile-csi`                            |
| `image.azurefile.tag`                             | azurefile-csi-driver docker image tag                      | `latest`                                                            |
| `image.azurefile.pullPolicy`                      | azurefile-csi-driver image pull policy                     | `IfNotPresent`                                                      |
| `image.csiProvisioner.repository`                 | csi-provisioner docker image                               | `/oss/kubernetes-csi/csi-provisioner`              |
| `image.csiProvisioner.tag`                        | csi-provisioner docker image tag                           | `v2.2.2`                                                            |
| `image.csiProvisioner.pullPolicy`                 | csi-provisioner image pull policy                          | `IfNotPresent`                                                      |
| `image.csiAttacher.repository`                    | csi-attacher docker image                                  | `/oss/kubernetes-csi/csi-attacher`                 |
| `image.csiAttacher.tag`                           | csi-attacher docker image tag                              | `v3.3.0`                                                            |
| `image.csiAttacher.pullPolicy`                    | csi-attacher image pull policy                             | `IfNotPresent`                                                      |
| `image.csiResizer.repository`                     | csi-resizer docker image                                   | `/oss/kubernetes-csi/csi-resizer`                  |
| `image.csiResizer.tag`                            | csi-resizer docker image tag                               | `v1.3.0`                                                            |
| `image.csiResizer.pullPolicy`                     | csi-resizer image pull policy                              | `IfNotPresent`                                                      |
| `image.livenessProbe.repository`                  | liveness-probe docker image                                | `/oss/kubernetes-csi/livenessprobe`                |
| `image.livenessProbe.tag`                         | liveness-probe docker image tag                            | `v2.4.0`                                                            |
| `image.livenessProbe.pullPolicy`                  | liveness-probe image pull policy                           | `IfNotPresent`                                                      |
| `image.nodeDriverRegistrar.repository`            | csi-node-driver-registrar docker image                     | `/oss/kubernetes-csi/csi-node-driver-registrar`    |
| `image.nodeDriverRegistrar.tag`                   | csi-node-driver-registrar docker image tag                 | `v2.3.0`                                                            |
| `image.nodeDriverRegistrar.pullPolicy`            | csi-node-driver-registrar image pull policy                | `IfNotPresent`                                                      |
| `imagePullSecrets`                                | Specify docker-registry secret names as an array           | [] (does not add image pull secrets to deployed pods)             |
| `customLabels`                                    | Custom labels to add into metadata                         | `{}`                                                                |
| `serviceAccount.create`                           | whether create service account of csi-azurefile-controller, csi-azurefile-node, and snapshot-controller| `true`                                                    |
| `serviceAccount.controller`                       | name of service account for csi-azurefile-controller       | `csi-azurefile-controller-sa`                                  |
| `serviceAccount.node`                             | name of service account for csi-azurefile-node             | `csi-azurefile-node-sa`                                        |
| `serviceAccount.snapshotController`               | name of service account for csi-snapshot-controller        | `csi-snapshot-controller-sa`                                   |
| `rbac.create`                                     | whether create rbac for this driver     | `true`                                                              |
| `rbac.name`                                       | driver name in rbac role                | `true`                                                         |
| `controller.name`                                 | name of driver deployment                  | `csi-azurefile-controller`
| `controller.cloudConfigSecretName`                | cloud config secret name of controller driver               | `azure-cloud-provider`
| `controller.cloudConfigSecretNamespace`           | cloud config secret namespace of controller driver          | `kube-system`
| `controller.replicas`                             | replicas of csi-azurefile-controller                    | `2`                                                                 |
| `controller.hostNetwork`                          | `hostNetwork` setting on controller driver(could be disabled if controller does not depend on MSI setting)                            | `true`                                                            | `true`, `false`
| `controller.metricsPort`                          | metrics port of csi-azurefile-controller                   |`29614`                                                        |
| `controller.livenessProbe.healthPort `            | health check port for liveness probe                   | `29612` |
| `controller.runOnMaster`                          | run controller on master node                                                          |`false`                                                           |
| `controller.attachRequired`                       | enable attach/detach (only valid for vhd disk feature)                                            |`false`                                                           |
| `controller.logLevel`                             | controller driver log level                                                          |`5`                                                           |
| `controller.kubeconfig`                           | configure kubeconfig path on controller node                | '' (empty, use InClusterConfig by default)
| `controller.tolerations`                          | controller pod tolerations                            |                                                              |
| `node.cloudConfigSecretName`                      | cloud config secret name of node driver               | `azure-cloud-provider`
| `node.cloudConfigSecretNamespace`                 | cloud config secret namespace of node driver          | `kube-system`
| `node.maxUnavailable`                             | `maxUnavailable` value of driver node daemonset                            | `1`
| `node.metricsPort`                                | metrics port of csi-azurefile-node                         |`29615`                                                       |
| `node.livenessProbe.healthPort `                  | health check port for liveness probe                   | `29613` |
| `node.logLevel`                                   | node driver log level                                                          |`5`                                                           |
| `snapshot.enabled`                                | whether enable snapshot feature                            | `false`                                                        |
| `snapshot.image.csiSnapshotter.repository`        | csi-snapshotter docker image                               | `/oss/kubernetes-csi/csi-snapshotter`         |
| `snapshot.image.csiSnapshotter.tag`               | csi-snapshotter docker image tag                           | `v3.0.3`                                                       |
| `snapshot.image.csiSnapshotter.pullPolicy`        | csi-snapshotter image pull policy                          | `IfNotPresent`                                                 |
| `snapshot.image.csiSnapshotController.repository` | snapshot-controller docker image                           | `/oss/kubernetes-csi/snapshot-controller`     |
| `snapshot.image.csiSnapshotController.tag`        | snapshot-controller docker image tag                       | `v3.0.3`                                                       |
| `snapshot.image.csiSnapshotController.pullPolicy` | snapshot-controller image pull policy                      | `IfNotPresent`                                                 |
| `snapshot.snapshotController.name`                | snapshot controller name                                   | `csi-snapshot-controller`                                                           |
| `snapshot.snapshotController.replicas`            | the replicas of snapshot-controller                        | `1`                                                          |
| `linux.enabled`                                   | whether enable linux feature                               | `true`                                                              |
| `linux.dsName`                                    | name of driver daemonset on linux                             |`csi-azurefile-node`                                                         |
| `linux.dnsPolicy`                                 | dnsPolicy setting of driver daemonset on linux                             | `Default` (available values: `Default`, `ClusterFirst`, `ClusterFirstWithHostNet`, `None`)
| `linux.kubelet`                                   | configure kubelet directory path on Linux agent node node                  | `/var/lib/kubelet`                                                |
| `linux.kubeconfig`                                | configure kubeconfig path on Linux agent node                | '' (empty, use InClusterConfig by default)                                            |
| `linux.distro`                                    | configure ssl certificates for different Linux distribution(available values: `debian`, `fedora`)                  |
| `linux.tolerations`                               | linux node driver tolerations                            |
| `windows.enabled`                                 | whether enable windows feature                             | `true`                                                             |
| `windows.dsName`                                  | name of driver daemonset on windows                             |`csi-azurefile-node-win`                                                         |
| `windows.kubelet`                                 | configure kubelet directory path on Windows agent node                | `'C:\var\lib\kubelet'`                                            |
| `windows.kubeconfig`                              | configure kubeconfig path on Windows agent node                | `'C:\k\config'`                                            |
| `windows.tolerations`                             | windows node driver tolerations                            |                                                              |

## troubleshooting
 - Add `--wait -v=5 --debug` in `helm install` command to get detailed error
 - Use `kubectl describe` to acquire more info
