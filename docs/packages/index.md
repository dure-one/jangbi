# Plugins

jangbi-it plugins is a set of configure, install, check status of certain app for jangbi.


## Default Behavior

### install

install application and generate configuratiosn at /etc/{plugin_name}.

### uninstall

uninstall application and remove configurations.

### configgen

generate pre-configured configuration at /tmp/{plugin_name} and make diff compare to current configurations at /etc/{plugin_name}.

### configapply

apply diff patch generated from last operation at /tmp/{plugin_name}.diff to /etc/{plugin_name}

### check

check plugin vars in .configs exists, application installed, application is running.

### download

download necessary package files to install to ./pkgs directory.


