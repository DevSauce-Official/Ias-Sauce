#!/bin/bash

set -e

test_agent_apis_dir="$(dirname "$(readlink -f "$0")")"
source "${test_agent_apis_dir}/../../common.bash"

usage()
{
	cat <<EOF

Usage: $script_name [<command>]

Summary: Test agent ttrpc apis using agent-ctl tool.

Description: Test agent exposed ttrpc api endpoints using agent-ctl tool.
A number of variations of the inputs are used to test an inidividual api
to validate success & failure code paths.

Commands:

  help   - Show usage.

Notes:
  - Currently, the script *does not support* running individual agent api tests.

EOF
}

run_tests() {
    info "Ruuning tests."
    bats "test-agent-apis.bats"
}

main()
{
	local cmd="${1:-}"

	case "$cmd" in
		help|-h|-help|--help) usage; exit 0;;
	esac

	run_tests
}

main "$@"
