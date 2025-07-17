# shellcheck shell=bats

load "${MAIN_BASH_IT_DIR?}/test/test_helper.bash"

function local_setup_file() {
    setup_libs "helpers"
    load "${BASH_IT?}/plugins/available/os-aide.plugin.bash"
}

@test 'plugins os-aide: __os-aide_install()' {
    # Mock environment variables
    export INTERNET_AVAIL=0
    export PKGNAME="aide"
    export DMNNAME="net-aide"
    
    # Run the function
    run __os-aide_install
    
    # Check if aide package file exists
    assert_file_exists ./pkgs/aide_0.18.3-1+deb12u3_amd64.deb
    
    # Check if aide.pkgs file exists
    assert_file_exists ./pkgs/aide.pkgs
    
    # Check if aide database file was created
    assert_file_exists /var/lib/aide/aide.minimal.db.gz
    
    # Check success
    assert_success
}

@test 'plugins os-aide: __os-aide_configgen()' {
    # Setup environment
    export PKGNAME="aide"
    
    # Run the function
    run __os-aide_configgen
    
    # Check if /tmp/aide dir exists
    assert_dir_exists /tmp/aide
    
    # Check if /tmp/aide.diff file exists
    assert_file_exists /tmp/aide.diff
    
    # Check if diff file has content (since configs are different)
    assert [ -s /tmp/aide.diff ]
    
    # Function should return 1 since configs are different
    assert_failure
}

@test 'plugins os-aide: __os-aide_configapply()' {
    # Setup environment
    export PKGNAME="aide"
    
    # Run the function
    run __os-aide_configapply
    
    # Check if backup dir exists (with timestamp pattern)
    assert [ $(find /etc -name ".aide.*" -type d | wc -l) -eq 1 ]
    
    # Check if /tmp/aide.diff file was deleted
    assert_file_not_exists /tmp/aide.diff
    
    # Check success
    assert_success
}

@test 'plugins os-aide: __os-aide_download()' {
    # Setup environment
    export DMNNAME="net-aide"
    
    # Run the function
    run __os-aide_download
    
    # Check if pkgs/aide*.deb file exists
    assert_file_exists ./pkgs/aide_0.18.3-1+deb12u3_amd64.deb
    
    # Check if pkgs/aide.pkgs file exists
    assert_file_exists ./pkgs/aide.pkgs
    
    # Check success
    assert_success
}