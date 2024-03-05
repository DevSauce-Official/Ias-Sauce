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
source "$lib_file"

uvm_files_dir="${script_dir}/uvm-files"

agent_make_flags="LIBC=gnu OPENSSL_NO_VENDOR=Y"
agent_install_flags="DESTDIR=${uvm_files_dir}/agent"

if [ "${CONF_PODS}" == "yes" ]; then
    agent_make_flags+=" AGENT_POLICY=yes"
fi

pushd "${repo_dir}"

# kata-agent binary
pushd src/agent
make clean
rm -rf uvm-files
make ${agent_make_flags}
# installs binary and services files into uvm_files_dir
make install {$agent_install_flags}
popd

popd
