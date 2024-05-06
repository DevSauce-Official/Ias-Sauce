#!/usr/bin/env bash
#
# Copyright (c) 2024 Microsoft Corporation
#
# SPDX-License-Identifier: Apache-2.0

if [ "${CONF_PODS}" == "yes" ]; then
	deploy_path_prefix="/opt/confidential-containers"
	uvm_path="${deploy_path_prefix}/share/kata-containers"
	img_file_name="kata-containers.img"
	igvm_file_name="kata-containers-igvm.img"
	igvm_dbg_file_name="kata-containers-igvm-debug.img"
	uvm_measurement_file_name="igvm-measurement.cose"
	uvm_dbg_measurement_file_name="igvm-debug-measurement.cose"
	shim_config_path="${deploy_path_prefix}/share/defaults/kata-containers"
	shim_config_file_name="configuration-clh-snp.toml"
	shim_dbg_config_file_name="configuration-clh-snp-debug.toml"
	debugging_binaries_path="${deploy_path_prefix}/bin"
	shim_binary_path="/usr/local/bin"
	shim_binary_name="containerd-shim-kata-cc-v2"
else
	deploy_path_prefix="/usr"
	uvm_path="/var/cache/kata-containers/osbuilder-images/kernel-uvm"
	initrd_file_name="kata-containers-initrd.img"
	shim_config_path="${deploy_path_prefix}/share/defaults/kata-containers"
	shim_config_file_name="configuration-clh.toml"
	debugging_binaries_path="${deploy_path_prefix}/local/bin"
	shim_binary_path="${deploy_path_prefix}/local/bin"
	shim_binary_name="containerd-shim-kata-v2"
fi

kernel_binary_location="/usr/share/cloud-hypervisor/vmlinux.bin"
virtiofsd_binary_location="/usr/libexec/virtiofsd-rs"

set_uvm_kernel_vars() {
	UVM_KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}' kernel-uvm-devel)
	UVM_KERNEL_RELEASE=$(rpm -q --queryformat '%{RELEASE}' kernel-uvm-devel)
	UVM_KERNEL_HEADER_DIR="/usr/src/linux-headers-${UVM_KERNEL_VERSION}-${UVM_KERNEL_RELEASE}"
}
