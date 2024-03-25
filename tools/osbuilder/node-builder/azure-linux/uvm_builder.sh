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

dnf install -y kata-packages-uvm-build

if [ "${CONF_PODS}" == "yes" ]; then
    dnf install -y kernel-uvm-devel
fi

pushd "${repo_dir}"

pushd src/agent/
rm -rf ${agent_install_dir}
make install DESTDIR=${agent_install_dir}
popd

# build rootfs, include agent binary
pushd tools/osbuilder
sudo -E PATH=$PATH  make ${rootfs_make_flags} -B DISTRO=cbl-mariner rootfs
ROOTFS_PATH="$(sudo readlink -f ./cbl-mariner_rootfs)"
popd

# add agent service files
cp ${agent_install_dir}/usr/lib/systemd/system/kata-containers.target  ${ROOTFS_DIR}/usr/lib/systemd/system/kata-containers.target
cp ${agent_install_dir}/usr/lib/systemd/system/kata-agent.service ${ROOTFS_DIR}/usr/lib/systemd/system/kata-agent.service

if [ "${CONF_PODS}" == "yes" ]; then
    # tardev-snapshotter: tarfs kernel module/driver
    # - first, determine UVM kernel version, header information
    pushd /usr/src/$(ls /usr/src | grep linux-header | grep mshv)
    header_dir=$(basename $PWD)
    KERNEL_VER=${header_dir#"linux-headers-"}
    KERNEL_MODULE_VER=${KERNEL_VER%%-*}
    popd
    # - build tarfs kernel module
    pushd src/tarfs
    make KDIR=/usr/src/linux-headers-${KERNEL_VER}
    make KDIR=/usr/src/linux-headers-${KERNEL_VER} install
    KERNEL_MODULES_DIR=$PWD/_install/lib/modules/${KERNEL_MODULE_VER}
    KERNEL_MODULES_VER=$(basename $KERNEL_MODULES_DIR)
    popd
    # - install tarfs kernel module into rootfs
    MODULE_ROOTFS_DEST_DIR="${ROOTFS_PATH}/lib/modules"
    mkdir -p ${MODULE_ROOTFS_DEST_DIR}
    cp -a ${KERNEL_MODULES_DIR} "${MODULE_ROOTFS_DEST_DIR}/"
    depmod -a -b ${ROOTFS_PATH} ${KERNEL_MODULES_VER}

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
