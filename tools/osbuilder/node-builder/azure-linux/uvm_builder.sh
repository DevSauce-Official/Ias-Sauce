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
rm -rf ${agent_install_dir}
make install DESTDIR=${agent_install_dir}
popd

# build rootfs, include agent binary
pushd tools/osbuilder
sudo -E PATH=$PATH make ${rootfs_make_flags} -B DISTRO=cbl-mariner rootfs
ROOTFS_PATH="$(sudo readlink -f ./cbl-mariner_rootfs)"
popd

# add agent service files
cp ${agent_install_dir}/usr/lib/systemd/system/kata-containers.target  ${ROOTFS_DIR}/usr/lib/systemd/system/kata-containers.target
cp ${agent_install_dir}/usr/lib/systemd/system/kata-agent.service ${ROOTFS_DIR}/usr/lib/systemd/system/kata-agent.service

if [ "${CONF_PODS}" == "yes" ]; then
    # tardev-snapshotter: tarfs kernel module/driver
    # - build tarfs kernel module
    pushd src/tarfs
    make KDIR=${UVM_KERNEL_HEADER_DIR}
    make KDIR=${UVM_KERNEL_HEADER_DIR} install
    UVM_KERNEL_MODULES_DIR=$PWD/_install/lib/modules/${UVM_KERNEL_MODULE_VER}
    UVM_KERNEL_MODULES_VER=$(basename $UVM_KERNEL_MODULES_DIR)
    popd
    # - install tarfs kernel module into rootfs
    MODULE_ROOTFS_DEST_DIR="${ROOTFS_PATH}/lib/modules"
    mkdir -p ${MODULE_ROOTFS_DEST_DIR}
    cp -a ${UVM_KERNEL_MODULES_DIR} "${MODULE_ROOTFS_DEST_DIR}/"
    depmod -a -b ${ROOTFS_PATH} ${UVM_KERNEL_MODULES_VER}

    # create dm-verity protected image based on rootfs
    pushd tools/osbuilder
    sudo -E PATH=$PATH make DISTRO=cbl-mariner MEASURED_ROOTFS=yes DM_VERITY_FORMAT=kernelinit image
    popd

    # create IGVM and UVM measurement files
    pushd tools/osbuilder
    sudo -E PATH=$PATH make igvm
    popd
else
    # create initrd based on rootfs
    pushd tools/osbuilder
    sudo -E PATH=$PATH make DISTRO=cbl-mariner TARGET_ROOTFS=${ROOTFS_PATH} initrd
    popd
fi

popd
