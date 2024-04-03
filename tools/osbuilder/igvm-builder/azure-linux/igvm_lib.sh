#!/bin/bash

install_igvm()
{
	if [ -d ${igvm_extract_folder} ]; then
		echo "${igvm_extract_folder} folder already exists, assuming tool is already installed"
		return
	fi

	# the igvm tool on mariner will soon be installed through dnf via kata-packages-uvm-build
	# even though installing, we cannot delete the source folder as the ACPI tables are not being installed anywhere
	IGVM_VER=$(curl -sL "https://api.github.com/repos/microsoft/igvm-tooling/releases/latest" | jq -r .tag_name | sed 's/^v//')
	curl -sL "https://github.com/microsoft/igvm-tooling/archive/refs/tags/${IGVM_VER}.tar.gz" | tar --no-same-owner -xz
	mv igvm-tooling-${IGVM_VER} ${igvm_extract_folder}
	pushd ${igvm_extract_folder}/src
	pip3 install --no-deps ./
	popd
}
