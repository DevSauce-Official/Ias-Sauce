#!/usr/bin/env bash
#
# Copyright (c) 2024 Microsoft Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o errtrace

[ -n "$DEBUG" ] && set -x

CONF_PODS=${CONF_PODS:-no}

script_dir="$(dirname $(readlink -f $0))"
repo_dir="${script_dir}/../../../../"

lib_file="${script_dir}/../../scripts/lib.sh"
source "${lib_file}"

common_file="common.sh"
source "${common_file}"

# these options ensure we produce the proper CLH config file
runtime_make_flags="SKIP_GO_VERSION_CHECK=1 QEMUCMD= FCCMD= ACRNCMD= STRATOVIRTCMD= DEFAULT_HYPERVISOR=cloud-hypervisor
	DEFMEMSZ=256 DEFSTATICSANDBOXWORKLOADMEM=1792 DEFVIRTIOFSDAEMON=${virtiofsd_binary_location} PREFIX=${deploy_path_prefix}"

if [ "${CONF_PODS}" == "no" ]; then
	runtime_make_flags+=" DEFSTATICRESOURCEMGMT_CLH=true KERNELPATH_CLH=${kernel_binary_location}"
fi

# add BUILD_TYPE=debug to build a debug agent (result in significantly increased agent binary size)
# this will require to add same flag to the `make install` section for the agent in uvm_build.sh
agent_make_flags="LIBC=gnu OPENSSL_NO_VENDOR=Y"

if [ "${CONF_PODS}" == "yes" ]; then
	agent_make_flags+=" AGENT_POLICY=yes"
fi

pushd "${repo_dir}"

if [ "${CONF_PODS}" == "yes" ]; then

	# tardev-snapshotter: utarfs binary
	pushd src/utarfs/
	make all
	popd

	# tardev-snapshotter: kata-overlay binary
	pushd src/overlay/
	make all
	popd

	# tardev-snapshotter: tardev-snapshotter binary for service
	pushd src/tardev-snapshotter/
	make all
	popd
fi

# containerd-shim-kata-(cc-)v2 binary
pushd src/runtime/
if [ "${CONF_PODS}" == "yes" ]; then
	make ${runtime_make_flags}
else
	# cannot add the kernelparams above, quotation issue
	make ${runtime_make_flags} KERNELPARAMS="systemd.legacy_systemd_cgroup_controller=yes systemd.unified_cgroup_hierarchy=0"
fi
popd

# containerd-shim-kata-(cc-)v2 config
pushd src/runtime/config/
if [ "${CONF_PODS}" == "yes" ]; then
	# create a debug config
	cp "${shim_config_file_name}" "${shim_dbg_config_file_name}"
	sed -i "s|${igvm_file_name}|${igvm_dbg_file_name}|g" "${shim_dbg_config_file_name}"
	sed -i '/^#enable_debug =/s|^#||g' "${shim_dbg_config_file_name}"
	sed -i '/^#debug_console_enabled =/s|^#||g' "${shim_dbg_config_file_name}"
else
	# We currently use the default config snippet from upstream that defaults to IMAGEPATH/image for the config.
	# If we shift to using an image for vanilla Kata, we can use IMAGEPATH to set the proper path (or better make sure the image file gets placed so that default values can be used).
	sed -i -e "s|image = .*$|initrd = \"${uvm_path}/${initrd_file_name}\"|" "${shim_config_file_name}"
fi
popd

# kata-agent binary
pushd src/agent/
make ${agent_make_flags}
popd

popd
