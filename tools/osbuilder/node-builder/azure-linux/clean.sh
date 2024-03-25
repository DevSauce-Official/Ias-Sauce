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
sudo -E PATH=$PATH make clean
popd

# clean tardev-snapshotter artifacts for confpods
pushd src/tarfs
make clean
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

popd
