# shellcheck shell=bats

load "${MAIN_BASH_IT_DIR?}/test/test_helper.bash"

function local_setup_file() {
	setup_libs "helpers"
	load "${BASH_IT?}/plugins/available/misc.plugin.bash"
}

@test 'plugins misc: wol()' {
	readonly localhost='127.0.0.1'
	run ips
	assert_success
	assert_line "$localhost"
}
