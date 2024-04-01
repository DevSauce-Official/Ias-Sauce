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

agent_install_dir="${script_dir}/agent-install"

rootfs_make_flags="AGENT_SOURCE_BIN=${agent_install_dir}/usr/bin/kata-agent"

if [ "${CONF_PODS}" == "yes" ]; then
    rootfs_make_flags+=" AGENT_POLICY=yes CONF_GUEST=yes AGENT_POLICY_FILE=allow-set-policy.rego"
fi

if [ "${CONF_PODS}" == "yes" ]; then
    set_uvm_kernel_vars
    if [ -z "${UVM_KERNEL_HEADER_DIR}}" ]; then
        exit 1
    fi
fi

pushd "${repo_dir}"

pushd src/agent/
make install LIBC=gnu DESTDIR=${agent_install_dir}
popd

# build rootfs, include agent binary
pushd tools/osbuilder
# TODO requires sudo cause of dnf-installing packages into rootfs. As a suite, following commands require sudo as well as make clean
sudo -E PATH=$PATH make ${rootfs_make_flags} -B DISTRO=cbl-mariner rootfs
ROOTFS_PATH="$(readlink -f ./cbl-mariner_rootfs)"
popd

# add agent service files
sudo cp ${agent_install_dir}/usr/lib/systemd/system/kata-containers.target ${ROOTFS_PATH}/usr/lib/systemd/system/kata-containers.target
sudo cp ${agent_install_dir}/usr/lib/systemd/system/kata-agent.service ${ROOTFS_PATH}/usr/lib/systemd/system/kata-agent.service

if [ "${CONF_PODS}" == "yes" ]; then
    # tardev-snapshotter: tarfs kernel module/driver
    # - build tarfs kernel module
    pushd src/tarfs
    make KDIR=${UVM_KERNEL_HEADER_DIR}
    sudo make KDIR=${UVM_KERNEL_HEADER_DIR} KVER=${UVM_KERNEL_MODULE_VER} INSTALL_MOD_PATH=${ROOTFS_PATH} install
    popd

    # create dm-verity protected image based on rootfs
    pushd tools/osbuilder
    sudo -E PATH=$PATH make DISTRO=cbl-mariner MEASURED_ROOTFS=yes DM_VERITY_FORMAT=kernelinit image
    popd

    # create IGVM and UVM measurement files
    pushd tools/osbuilder
    sudo chmod o+r root_hash.txt
    make igvm DISTRO=cbl-mariner
    popd
else
    # create initrd based on rootfs
    pushd tools/osbuilder
    sudo -E PATH=$PATH make DISTRO=cbl-mariner TARGET_ROOTFS=${ROOTFS_PATH} initrd
    popd
fi

popd
