---
title: Development
---

# Jangbi-it Development

Jangbi-it uses [Bash-it](https://bash-it.readthedocs.io/en/latest/development/) system overall. Differences are only few functions to override Bash-it's function.
You could find it from [janbi_it.sh](https://github.com/dure-one/jangbi/blob/main/jangbi_it.sh).

```bash
# enable jangbi-it
$ cd /opt/jangbi
$ source jangbi_it.sh

# show enalbed plugins
$ jangbi-it show plugins
Plugin               Enabled?   Description
base                 [ ]        base tools
misc                 [ ]        miscellaneous tools
net-darkstat         [x]        darkstat install configurations.
net-dnscryptproxy    [x]        dnscryptproxy install configurations.
net-dnsmasq          [x]        dnsmasq install configurations.
net-hostapd          [x]        hostapd install configurations.
net-ifupdown         [x]        network configurations.
net-iptables         [x]        iptables install configurations.
net-knockd           [ ]        knockd install configurations.
net-netplan          [ ]        netplan install configurations.
net-sshd             [x]        sshd install configurations.
net-wstunnel         [x]        wstunnel install configurations.
net-xtables          [x]        xtables install configurations.
os-aide              [x]        aide install configurations.
os-auditd            [x]        auditd install configurations.
os-conf              [x]        custom os configurations
os-disablebins       [x]        disable binaries.
os-firmware          [ ]        custom os firmware install in kernel.
os-kparams           [x]        custom kernel params in cmdline.
os-minmon            [x]        minmon install configurations.
os-redis             [x]        redis install configurations.
os-sysctl            [x]        sysctl install configurations.
os-systemd           [x]        setup systemd.
os-vector            [x]        vector install configurations.

# restart jangbi-it to reload src changes
$ jangbi-it restart
```

# Documentation

Jangb-it's documentation uses [mkdocs](https://www.mkdocs.org/).

```bash
# making environment
$ cd /opt/jangbi
$ python -m venv .
$ source bin/activate

# install documentation dependency
$ pip install -r requirements.txt

# build mkdocs.yml
$ mkdocs build

# server from localhost
$ mkdocs serve

# you could open web brwoser http://127.0.0.1:8000/jangbi/
```

# Jangbi init system

Because jangbi is running on every boot with rc.local. the init system will check enabled plugin's status and restart each plugin's daemon. 

# Plugin Development

Jangbi-it plugin uses [mkdocstrings](https://mkdocstrings.github.io/) for documentation within the script. you could find more info here. [syntax](https://pawamoy.github.io/shellman/usage/syntax/) / [tags](https://pawamoy.github.io/shellman/usage/tags/) / [example shell file](https://github.com/mkdocstrings/shell/blob/a01628c66558057650b6d42ca73897fa21bdf0eb/docs/examples/drag) / [example rendering](https://mkdocstrings.github.io/shell/?h=author#drag)

```bash
# enabling new plugin
$ janbi-it enable plugin new-plugin

```

## used bash system

* **[composure](https://github.com/erichs/composure?tab=readme-ov-file)** : function organize system.
* **[bash-it](https://bash-it.readthedocs.io/en/latest/)** : bash-it is base bash based system.
* **[slog](https://github.com/swelljoe/slog)** : init script wizard system.

## composure notations

```bash
cite about-plugin
about-plugin 'darkstat install configurations.'

function net-darkstat {
    about 'darkstat install configurations'
    group 'postnet'
    runtype 'minmon'
    deps  ''
    param '1: command'
    param '2: params'
    example '$ net-darkstat subcommand'
    local PKGNAME="darkstat"
    local DMNNAME="net-darkstat"
    BASH_IT_LOG_PREFIX="net-darkstat: "
...
}
```

### plugin's group

there are three group types.

* **prenet** : apps running before network initializes.
* **(net)** : reseved types for processing to initialize network.
* **postnet** : apps running after network initializes.

### plguin's runtype

* **systemd** : daemon managed by systemd.
* **[minmon](https://github.com/flo-at/minmon)** : daemon managed by minmon.
* **(none)** : non-daemonized plugins.

### plugin's deps
(in-development)

* **any-text**
* **(none)**
