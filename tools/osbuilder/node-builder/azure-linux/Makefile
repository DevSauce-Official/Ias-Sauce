# Copyright (c) 2024 Microsoft Corporation
#
# SPDX-License-Identifier: Apache-2.0
#
.PHONY: all
all: package uvm

.PHONY: all-confpods
all-confpods: package-confpods uvm-confpods

.PHONY: package
package:
	./package_build.sh

.PHONY: package-confpods
package-confpods:
	CONF_PODS=yes ./package_build.sh

.PHONY: uvm
uvm:
	./uvm_build.sh

.PHONY: uvm-confpods
uvm-confpods:
	CONF_PODS=yes ./uvm_build.sh

.PHONY: clean
clean:
	./clean.sh

.PHONY: clean-confpods
clean-confpods:
	CONF_PODS=yes ./clean.sh

.PHONY: deploy
deploy: deploy-package deploy-uvm

.PHONY: deploy-package
deploy-package:
	./package_install.sh

.PHONY: deploy-uvm
deploy-uvm:
	./uvm_install.sh

.PHONY: deploy-confpods
deploy-confpods: deploy-confpods-package deploy-confpods-uvm

.PHONY: deploy-confpods-package
deploy-confpods-package:
	CONF_PODS=yes ./package_install.sh

.PHONY: deploy-confpods-uvm
deploy-confpods-uvm:
	CONF_PODS=yes ./uvm_install.sh
