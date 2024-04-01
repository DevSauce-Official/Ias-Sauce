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

if [ "${CONF_PODS}" == "yes" ]; then
  cp -S .bak -b src/utarfs/target/release/utarfs /usr/sbin/mount.tar
  cp -S .bak -b src/overlay/target/release/kata-overlay /usr/bin/
  cp -S .bak -b src/tardev-snapshotter/target/release/tardev-snapshotter /usr/bin/
  cp -S .bak -b src/tardev-snapshotter/tardev-snapshotter.service /usr/lib/systemd/system/

  cp -S .bak -b src/runtime/kata-monitor "${debugging_binary_path}"
  cp -S .bak -b src/runtime/kata-runtime "${debugging_binary_path}"
  cp -S .bak -b src/runtime/kata-collect-data.sh "${debugging_binary_path}"
  cp -S .bak -b src/runtime/containerd-shim-kata-v2 "${shim_binary_path}"/"${shim_binary_name}"

  cp -S .bak -b src/runtime/config/"${shim_config_file_name}" "${shim_config_path}"
  cp -S .bak -b src/runtime/config/"${shim_dbg_config_file_name}" "${shim_config_path}"

  systemctl enable tardev-snapshotter && systemctl daemon-reload && systemctl restart tardev-snapshotter
else
  cp -S .bak -b src/runtime/kata-monitor "${debugging_binary_path}"
  cp -S .bak -b src/runtime/kata-runtime "${debugging_binary_path}"
  cp -S .bak -b src/runtime/kata-collect-data.sh "${debugging_binary_path}"
  cp -S .bak -b src/runtime/containerd-shim-kata-v2 "${shim_binary_path}"/"${shim_binary_name}"

  cp -S .bak -b src/runtime/config/"${shim_config_file_name}" "${shim_config_path}"

  systemctl daemon-reload && systemctl restart containerd
fi

popd
