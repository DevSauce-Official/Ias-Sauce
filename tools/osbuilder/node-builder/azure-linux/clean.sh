#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o errtrace

[ -n "$DEBUG" ] && set -x

script_dir="$(dirname $(readlink -f $0))"
repo_dir="${script_dir}/../../../../"

lib_file="${script_dir}/../../scripts/lib.sh"
source "${lib_file}"

common_file="common.sh"
source "${common_file}"

agent_install_dir="${script_dir}/agent-install"

pushd "${repo_dir}"

# clean runtime, agent
pushd src/runtime/
make clean SKIP_GO_VERSION_CHECK=1
popd

pushd src/agent/
make clean
popd

rm -rf ${agent_install_dir}

# clean rootfs, image, initrd, igvm
pushd tools/osbuilder/
#sudo -E PATH=$PATH make clean
make clean
popd

if [ "${CONF_PODS}" == "yes" ]; then
    # clean tardev-snapshotter artifacts for confpods
    pushd src/tarfs
    set_uvm_kernel_vars
    if [ -n "${UVM_KERNEL_HEADER_DIR}" ]; then
        make clean KDIR=${UVM_KERNEL_HEADER_DIR}
    fi
    popd

    pushd src/utarfs/
    make clean
    popd

    pushd src/overlay/
    make clean
    popd

    pushd src/tardev-snapshotter/
    make clean
    popd
fi

popd
