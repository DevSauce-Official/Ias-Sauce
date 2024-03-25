#
# SPDX-License-Identifier: Apache-2.0
#
all: host uvm

all-confpods: host-confpods uvm-confpods

host:
	./host_builder.sh

host-confpods:
	CONF_PODS=yes ./host_builder.sh

uvm:
	./uvm_builder.sh

uvm-confpods:
	CONF_PODS=yes ./uvm_builder.sh


clean:
