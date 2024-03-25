#
# SPDX-License-Identifier: Apache-2.0
#
all: clean package uvm

all-confpods: clean package-confpods uvm-confpods

package:
    ./package_builder.sh

package-confpods:
    CONF_PODS=yes ./package_builder.sh

uvm:
    ./uvm_builder.sh

uvm-confpods:
    CONF_PODS=yes ./uvm_builder.sh

clean:
    ./clean.sh
