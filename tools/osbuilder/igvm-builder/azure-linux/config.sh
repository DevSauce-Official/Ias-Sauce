#!/bin/bash

# this is where the kernel-uvm package installation places bzImage, see SPEC file
bzimage_bin="/usr/share/cloud-hypervisor/bzImage"
root_hash_file="../root_hash.txt"

if [ ! -f "${root_hash_file}" ]; then
  echo "Could no find image root hash file '${root_hash_file}', aborting"
  exit 1
fi

# store root hash values to use in kernel command line
root_hash=$(sed -e 's/Root hash:\s*//g;t;d' "${root_hash_file}")
salt=$(sed -e 's/Salt:\s*//g;t;d' "${root_hash_file}")
data_blocks=$(sed -e 's/Data blocks:\s*//g;t;d' "${root_hash_file}")
data_block_size=$(sed -e 's/Data block size:\s*//g;t;d' "${root_hash_file}")
data_sectors_per_block=$((data_block_size / 512))
data_sectors=$((data_blocks * data_sectors_per_block))
hash_block_size=$(sed -e 's/Hash block size:\s*//g;t;d' "${root_hash_file}")

igvm_vars="-kernel $bzimage_bin -boot_mode x64 -vtl 0 -svme 1 -encrypted_page 1 -pvalidate_opt 1 -acpi igvm/acpi/acpi-clh/"

igvm_kernel_params_common="dm-mod.create=\"dm-verity,,,ro,0 ${data_sectors} verity 1 /dev/vda1 /dev/vda2 ${data_block_size} ${hash_block_size} ${data_blocks} 0 sha256 ${root_hash} ${salt}\" \
  root=/dev/dm-0 rootflags=data=ordered,errors=remount-ro ro rootfstype=ext4 panic=1 no_timer_check noreplace-smp systemd.unit=kata-containers.target systemd.mask=systemd-networkd.service \
  systemd.mask=systemd-networkd.socket agent.enable_signature_verification=false"
igvm_kernel_prod_params="${igvm_kernel_params_common} quiet"
igvm_kernel_debug_params="${igvm_kernel_params_common} console=hvc0 systemd.log_target=console agent.log=debug agent.debug_console agent.debug_console_vport=1026"
