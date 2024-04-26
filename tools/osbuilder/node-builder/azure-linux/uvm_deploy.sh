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

pushd "${repo_dir}"

pushd tools/osbuilder

mkdir -p "${uvm_path}"

if [ "${CONF_PODS}" == "yes" ]; then
	cp -a -S .bak -b "${img_file_name}" "${uvm_path}"
	cp -a -S .bak -b "${igvm_file_name}" "${uvm_path}"
	cp -a -S .bak -b "${igvm_dbg_file_name}" "${uvm_path}"
	cp -a -S .bak -b "${uvm_measurement_file_name}" "${uvm_path}"
	cp -a -S .bak -b "${uvm_dbg_measurement_file_name}" "${uvm_path}"
else
	cp -a -S .bak -b "${initrd_file_name}" "${uvm_path}"
fi
popd

popd
