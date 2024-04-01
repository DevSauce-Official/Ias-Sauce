#!/bin/bash

install_igvm()
{
  if [ -d igvm-tooling ];then
    echo "igvm-tooling folder already exists, assuming tool is already installed"
    return
  fi

  # the igvm tool on mariner will soon be installed through dnf via kata-packages-uvm-build
  IGVM_VER=$(curl -sL "https://api.github.com/repos/microsoft/igvm-tooling/releases/latest" | jq -r .tag_name | sed 's/^v//')
  curl -sL "https://github.com/microsoft/igvm-tooling/archive/refs/tags/${IGVM_VER}.tar.gz" | tar --no-same-owner -xz
  pushd igvm-tooling-${IGVM_VER}
  pip3 install --no-deps ./
  popd
  mv igvm-tooling-${IGVM_VER} igvm-tooling
}
