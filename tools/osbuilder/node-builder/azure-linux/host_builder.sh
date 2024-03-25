#!/usr/bin/env bash
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
generic_runtime_make_flags="SKIP_GO_VERSION_CHECK=1 QEMUCMD= FCCMD= ACRNCMD= STRATOVIRTCMD= DEFAULT_HYPERVISOR=cloud-hypervisor
    DEFMEMSZ=256 DEFSTATICSANDBOXWORKLOADMEM=1792 DEFVIRTIOFSDAEMON={$virtiofsd_binary_location} PREFIX=${deploy_path_prefix}"

agent_make_flags="LIBC=gnu OPENSSL_NO_VENDOR=Y"

if [ "${CONF_PODS}" == "yes" ]; then
    agent_make_flags+=" AGENT_POLICY=yes"
fi


pushd "${repo_dir}"

if [ "${CONF_PODS}" == "yes" ]; then

    # tardev-snapshotter: utarfs binary
    pushd src/utarfs/
    make clean
    make all
    popd

    # tardev-snapshotter: kata-overlay binary
    pushd src/overlay/
    make clean
    make all
    popd

    # tardev-snapshotter: tardev-snapshotter binary for service
    pushd src/tardev-snapshotter/
    make clean
    make all
    popd
fi

# containerd-shim-kata-(cc-)v2 binary
pushd src/runtime/
make clean SKIP_GO_VERSION_CHECK=1
# TODO the Makefile is written in a way that regardless DEFSNPGUEST, the -snp/-tdx resp. non-snp/tdx configs are always created. Potential to only create -snp configs in the presence of DEFSNPGUEST
if [ "${CONF_PODS}" == "yes" ]; then
    make ${generic_runtime_make_flags} DEFSNPGUEST=true
else
    make ${generic_runtime_make_flags} DEFSTATICRESOURCEMGMT_CLH=true KERNELPARAMS="systemd.legacy_systemd_cgroup_controller=yes systemd.unified_cgroup_hierarchy=0" KERNELPATH_CLH="${kernel_binary_location}"
fi
popd

# containerd-shim-kata-(cc-)v2 config
pushd src/runtime/config/
if [ "${CONF_PODS}" == "yes" ]; then
    # create a debug config
    # TODO: Evaluate whether to integrate this into the makefile. Nobody has done this so far however
    cp "${shim_config_file_name}" "${shim_dbg_config_file_name}"
    sed -i "s|${igvm_file_name}|${igvm_dbg_file_name}|g" "${shim_dbg_config_file_name}"
    sed -i '/^#enable_debug =/s|^#||g' "${shim_dbg_config_file_name}"
    sed -i '/^#debug_console_enabled =/s|^#||g' "${shim_dbg_config_file_name}"
else
    # TODO: Convert kata to using an image instead of initrd, aligned with our Kata-CC image usage.
    # We currently use the default config snippet from upstream that defaults to IMAGEPATH/image for the config.
    # Once we shift to using an image for vanilla Kata, we can use IMAGEPATH to set the proper path (or better make sure the image file gets placed so that default values can be used).
    sed -i -e "s|image = .*$|initrd = \"${uvm_path}/${initrd_file_name}\"|" "${shim_config_file_name}"
fi
popd

# kata-agent binary
pushd src/agent/
make clean
make ${agent_make_flags}
popd

popd
