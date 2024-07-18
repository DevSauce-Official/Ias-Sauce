#!/usr/bin/env bats
#
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

load "${BATS_TEST_DIRNAME}/../../common.bash"
load "${BATS_TEST_DIRNAME}/tests_common.sh"

setup() {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"
	[ "${KATA_HYPERVISOR}" == "fc" ] && skip "test not working see: ${fc_limitations}"

	get_pod_config_dir
	inject_secret_yaml_file="${pod_config_dir}/inject_secret.yaml"

	# Add policy to pod-secret.yaml.
	pod_secret_yaml_file="${pod_config_dir}/pod-secret.yaml"
	pod_secret_cmd="ls /tmp/secret-volume"
	pod_secret_policy_settings_dir="$(create_tmp_policy_settings_dir "${pod_config_dir}")"
	pod_secret_exec_command=(sh -c "${pod_secret_cmd}")
	add_exec_to_policy_settings "${pod_secret_policy_settings_dir}" "${pod_secret_exec_command[@]}"
	add_requests_to_policy_settings "${pod_secret_policy_settings_dir}" "ReadStreamRequest"
	auto_generate_policy "${pod_secret_policy_settings_dir}" "${pod_secret_yaml_file}"

	# Add policy to pod-secret-env.yaml.
	#
	# TODO: add support for specifying inject_secret.yaml in the genpolicy command line,
	#       and generate a proper policy instead of using the "allow all" policy here.
	pod_secret_env_yaml_file="${pod_config_dir}/pod-secret-env.yaml"
	pod_secret_env_cmd="printenv"
	pod_secret_env_exec_command=(sh -c "${pod_secret_env_cmd}")
	add_allow_all_policy_to_yaml "${pod_secret_env_yaml_file}"
}

@test "Credentials using secrets" {
	secret_name="test-secret"
	pod_name="secret-test-pod"
	second_pod_name="secret-envars-test-pod"

	# Create the secret
	kubectl create -f "${inject_secret_yaml_file}"

	# View information about the secret
	kubectl get secret "${secret_name}" -o yaml | grep "type: Opaque"

	# Create a pod that has access to the secret through a volume
	kubectl create -f "${pod_secret_yaml_file}"

	# Check pod creation
	kubectl wait --for=condition=Ready --timeout=$timeout pod "$pod_name"

	# List the files
	kubectl exec $pod_name -- "${pod_secret_exec_command[@]}" | grep -w "password"
	kubectl exec $pod_name -- "${pod_secret_exec_command[@]}" | grep -w "username"

	# Create a pod that has access to the secret data through environment variables
	kubectl create -f "${pod_secret_env_yaml_file}"

	# Check pod creation
	kubectl wait --for=condition=Ready --timeout=$timeout pod "$second_pod_name"

	# Display environment variables
	kubectl exec $second_pod_name -- "${pod_secret_env_exec_command[@]}" | grep -w "SECRET_USERNAME"
	kubectl exec $second_pod_name -- "${pod_secret_env_exec_command[@]}" | grep -w "SECRET_PASSWORD"
}

teardown() {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"
	[ "${KATA_HYPERVISOR}" == "fc" ] && skip "test not working see: ${fc_limitations}"

	# Debugging information
	kubectl describe "pod/$pod_name"
	kubectl describe "pod/$second_pod_name"

	kubectl delete pod "$pod_name" "$second_pod_name"
	kubectl delete secret "$secret_name"

	delete_tmp_policy_settings_dir "${pod_secret_policy_settings_dir}"
}
