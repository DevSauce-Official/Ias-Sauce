#!/bin/bash

set -o errexit
set -o pipefail
set -o errtrace

[ -n "$DEBUG" ] && set -x

script_dir="$(dirname $(readlink -f $0))"

# distro-specific config file
typeset -r CONFIG_SH="config.sh"

# Name of an optional distro-specific file which, if it exists, must implement the
# build_rootfs() function.
typeset -r LIB_SH="igvm_lib.sh"

build_igvm_distro()
{
  distro_config_dir="${script_dir}/${distro}"

  [ -d "${distro_config_dir}" ] || die "Not found configuration directory ${distro_config_dir}"

  # Source config.sh from distro
  igvm_config="${distro_config_dir}/${CONFIG_SH}"
  source "${igvm_config}"

  if [ -e "${distro_config_dir}/${LIB_SH}" ];then
    igvm_lib="${distro_config_dir}/${LIB_SH}"
    info "igvm_lib.sh file found. Loading content"
    source "${igvm_lib}"
  fi

  install_igvm

  echo ========================
  echo === BUILD KATA IGVM  ===
  echo ========================
  pushd igvm-tooling

  python3 igvm/igvmgen.py $igvm_vars -o kata-containers-igvm.img -measurement_file igvm-measurement.cose -append "$igvm_kernel_prod_params" -svn $SVN
  python3 igvm/igvmgen.py $igvm_vars -o kata-containers-igvm-debug.img -measurement_file igvm-debug-measurement.cose -append "$igvm_kernel_debug_params" -svn $SVN
  mv igvm-measurement.cose kata-containers-igvm.img igvm-debug-measurement.cose kata-containers-igvm-debug.img $OUT_DIR

  popd
}

echo ====================
echo === BUILD IGVM ===
echo ====================
distro="azure-linux"

while getopts ":o:s:" OPTIONS; do
  case "${OPTIONS}" in
    o ) OUT_DIR=$OPTARG ;;
    s ) SVN=$OPTARG ;;
    \? )
        echo "Error - Invalid Option: -$OPTARG" 1>&2
        exit 1
        ;;
    : )
        echo "Error - Invalid Option: -$OPTARG requires an argument" 1>&2
        exit 1
        ;;
  esac
done

echo "-- OUT_DIR -> $OUT_DIR"
echo "-- distro -> $distro"

if [ -n "$distro" ]; then
  build_igvm_distro
else
  die "distro must be specified"
fi
