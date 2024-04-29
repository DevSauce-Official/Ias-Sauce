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

mkdir -p "${shim_config_path}"
mkdir -p "${debugging_binaries_path}"
mkdir -p "${shim_binary_path}"

if [ "${CONF_PODS}" == "yes" ]; then
	cp -a -S .bak -b src/utarfs/target/release/utarfs /usr/sbin/mount.tar
	cp -a -S .bak -b src/overlay/target/release/kata-overlay /usr/bin/
	cp -a -S .bak -b src/tardev-snapshotter/target/release/tardev-snapshotter /usr/bin/
	cp -a -S .bak -b src/tardev-snapshotter/tardev-snapshotter.service /usr/lib/systemd/system/

	cp -a -S .bak -b src/runtime/config/"${shim_dbg_config_file_name}" "${shim_config_path}"

	systemctl enable tardev-snapshotter && systemctl daemon-reload && systemctl restart tardev-snapshotter
fi

cp -a -S .bak -b src/runtime/kata-monitor "${debugging_binaries_path}"
cp -a -S .bak -b src/runtime/kata-runtime "${debugging_binaries_path}"
cp -a -S .bak -b src/runtime/data/kata-collect-data.sh "${debugging_binaries_path}"
cp -a -S .bak -b src/runtime/containerd-shim-kata-v2 "${shim_binary_path}"/"${shim_binary_name}"

cp -a -S .bak -b src/runtime/config/"${shim_config_file_name}" "${shim_config_path}"

popd
