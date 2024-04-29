#
# SPDX-License-Identifier: Apache-2.0
#
all: clean package uvm

all-confpods: clean package-confpods uvm-confpods

package:
	./package_build.sh

package-confpods:
	CONF_PODS=yes ./package_build.sh

uvm:
	./uvm_build.sh

uvm-confpods:
	CONF_PODS=yes ./uvm_build.sh

clean:
	./clean.sh

clean-confpods:
	CONF_PODS=yes ./clean.sh

deploy:
	./package_install.sh
	./uvm_install.sh

deploy-confpods:
	CONF_PODS=yes ./package_install.sh
	CONF_PODS=yes ./uvm_install.sh
