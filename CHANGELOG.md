# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

<!-- insertion marker -->
## Unreleased

<small>[Compare with latest](https://github.com/dure-one/jangbi/compare/cf31888b598023227446512a34039c2c9ac6e620...HEAD)</small>

### Added

- Add changelog automatically ([1ab178d](https://github.com/dure-one/jangbi/commit/1ab178d420cdd40acb0dc98c7156506176742e34) by nikescar).

### Fixed

- fix. stop at error on important task. continue at important task. ([fdc4c6f](https://github.com/dure-one/jangbi/commit/fdc4c6f02b287bf5ad201567e5e57ac8471ea369) by Woojae, Park).
- fix. remove systemd-run to daemon itself. ([11d4cbf](https://github.com/dure-one/jangbi/commit/11d4cbfcfea1572eb8baf12062c1d29e06b61991) by Woojae, Park).
- fix. replace bash-it vars on download func. ([00abf93](https://github.com/dure-one/jangbi/commit/00abf9397b6127b35ca714f692fc7c8ba593fc74) by Woojae, Park).
- fix. deb pkg file saved in root ([159148c](https://github.com/dure-one/jangbi/commit/159148ca58db3b0a6a68ab99ae6ff2dafc223f01) by Woojae, Park).
- fix. add missing libs. add docker test base. ([6f9e618](https://github.com/dure-one/jangbi/commit/6f9e6182ef5af2ef8e951365f5a039b651bce0ac) by Woojae, Park).
- fix. log splitting. readme docs. ([2747df0](https://github.com/dure-one/jangbi/commit/2747df0e2f6da8b0f1c911ddd58568d8631ef981) by Woojae, Park).
- fix. bash-it log prefix for each apps. ([f59d8e9](https://github.com/dure-one/jangbi/commit/f59d8e98eccdeaf6df010c7e1c051e1b6132a2fb) by Woojae, Park).
- fix. bugs with bash-it. ([96eb95f](https://github.com/dure-one/jangbi/commit/96eb95f6abc54c7b742e84b3a9f155ba9b76239e) by Woojae, Park).
- fix. run with bash_it. remove pkgs dl module. ([72b6c7a](https://github.com/dure-one/jangbi/commit/72b6c7a14d98b64f9ed551d93726eac09fb6ea4f) by Woojae, Park).
- fix. iptables, xtables. config values. log system. ([cf45beb](https://github.com/dure-one/jangbi/commit/cf45beb88f7adc79bd09f8fb428757c5395d0616) by Woojae, Park).
- fix. systemd install on call. remove some pkgs ([863c942](https://github.com/dure-one/jangbi/commit/863c9429ffad09e8678699b7da0cbcc1f3d517ff) by Woojae, Park).
- fix. replace submodule to direct files ([328d179](https://github.com/dure-one/jangbi/commit/328d179bf6375c92bb9ca06d606c96caf83cf362) by Woojae, Park).
- fix. add vendor submodules ([8a730c6](https://github.com/dure-one/jangbi/commit/8a730c63817b141617436ff686756dfff58bc5e6) by Woojae, Park).
- fix. typos ([aa278b3](https://github.com/dure-one/jangbi/commit/aa278b366d87150946e9a4820c7047665f6ba510) by Woojae, Park).
- fix. git tree command not working. replace to rm .git/worktress/-bash_it* ([cf3f6c8](https://github.com/dure-one/jangbi/commit/cf3f6c85aafb2cb561e838021e693c2221ba04f5) by Woojae, Park).
- fix. tests. ([7a61a84](https://github.com/dure-one/jangbi/commit/7a61a8491aaef120b90d2df3a7f2c8a68ccd09da) by Woojae, Park).
- fix. add tests ([2e35b32](https://github.com/dure-one/jangbi/commit/2e35b322b6e11078c1dd1390fadf6cb1441c7a0a) by Woojae, Park).
- fix. remove unused tests ([5cebfe0](https://github.com/dure-one/jangbi/commit/5cebfe06f6ee2a2ae1304fe1aab9381226904fb4) by Woojae, Park).
- fix. remove unused test ([41449da](https://github.com/dure-one/jangbi/commit/41449da8c15b9da7023af0c9f98811fef5527813) by Woojae, Park).
- fix: add stopspinng to .gitignore ([731e0b3](https://github.com/dure-one/jangbi/commit/731e0b3691d42860488a130916b137d4eec0a962) by Woojae, Park).
- fix: add msg to load_config, add iptables watch cmd ([4289fa2](https://github.com/dure-one/jangbi/commit/4289fa2cdcadd39a04c56ae1127019a3f0920e17) by Woojae, Park).
- fix: dnscryptproxy group, runtype ([ff643e1](https://github.com/dure-one/jangbi/commit/ff643e1e7d8b47aa784c8cd6cbb078c9bfd5a839) by Woojae, Park).
- fix: fix dnscrypt proxy pkg url and name ([9f0339d](https://github.com/dure-one/jangbi/commit/9f0339dcf21e23b4aa294973fd6c4b7dafff49a2) by Woojae, Park).
- fix: fix varname ([bcb623b](https://github.com/dure-one/jangbi/commit/bcb623b3b202e432cf2f36d7304df21976901de4) by Woojae, Park).
- fix: add -r option to systemd-run for non signaling processs, darkstat ([8847a58](https://github.com/dure-one/jangbi/commit/8847a58d441d9366ee915217a6708488d8e77d5f) by Woojae, Park).
- fix: change bg proc run with systemd-run ([429cc8f](https://github.com/dure-one/jangbi/commit/429cc8fc7a5965a27fe75d675ec92a226d4d9082) by Woojae, Park).
- fix: more descriptive log message for iptables ([f73ef12](https://github.com/dure-one/jangbi/commit/f73ef120b21b969fbb397fb43ffe46b87c8c59fa) by Woojae, Park).
- fix: change systemd start command to restart ([61b65e0](https://github.com/dure-one/jangbi/commit/61b65e045fb22ed13b02a239ba31676942e6e4d3) by Woojae, Park).
- fix: change bg proc run with disown ([72a5e8f](https://github.com/dure-one/jangbi/commit/72a5e8ff1c019510fec792829d9a0ff5deb6da4f) by Woojae, Park).
- fix: run minmon type process defach from tty ([80e5133](https://github.com/dure-one/jangbi/commit/80e5133cd68fc3490032632b68b561931f151405) by Woojae, Park).
- fix: maltrail, errors install, run ([7b0ee2e](https://github.com/dure-one/jangbi/commit/7b0ee2e674767ba1dcc5717ddd8f7bfbc5a5137a) by Woojae, Park).
- fix: change apt update only after 24 hours ([4d60ab3](https://github.com/dure-one/jangbi/commit/4d60ab3055d973e8c9ab71b9c0bf87aeaae37855) by Woojae, Park).
- fix: vector default config path ([96ac4a9](https://github.com/dure-one/jangbi/commit/96ac4a9036b1e4577a6c72768250a2e79c20d11f) by Woojae, Park).
- fix: change error message from log_info to log_error ([747a359](https://github.com/dure-one/jangbi/commit/747a359332fa989fd0b2d2322c327330805d6890) by Woojae, Park).
- fix: fix arp infs split error ([3a04a11](https://github.com/dure-one/jangbi/commit/3a04a1176d94229304e59e086d13ae63e08f507a) by Woojae, Park).
- fix: fix iptables load ([462154a](https://github.com/dure-one/jangbi/commit/462154adcfdd920d336036a7f1fa2bf07c2a1e8a) by Woojae, Park).
- fix: run order ([567d950](https://github.com/dure-one/jangbi/commit/567d95011c6a14f757c923dd165d5c0f26470fc4) by Woojae, Park).
- fix: indent error ([f63bbec](https://github.com/dure-one/jangbi/commit/f63bbec853caa01d00c6290909f390b6d8069416) by Woojae, Park).
- fix: darkstat, backup configs. dnsmasq, arptables ([ac24b0b](https://github.com/dure-one/jangbi/commit/ac24b0b284e6c4b1f0e73b4fab44e21b7b7c7b80) by Woojae, Park).
- fix: fix target infs for arptables ([fbab7f3](https://github.com/dure-one/jangbi/commit/fbab7f34328a8d06be0b873c40758b3aeb4b2318) by Woojae, Park).
- fix: dnsmasq, interface exsits check ([8bce4d2](https://github.com/dure-one/jangbi/commit/8bce4d26924fc04dbadf31afa98ed61af1cb5333) by Woojae, Park).
- fix: add netstate to error msg ([85f813e](https://github.com/dure-one/jangbi/commit/85f813e4eaeb6738750027580254da6596460a47) by Woojae, Park).
- fix: file contents may have carriage return ([1bffe9a](https://github.com/dure-one/jangbi/commit/1bffe9a3d1d7f16031d58930043e8fa5bc4d558c) by Woojae, Park).
- fix: the case for vars not ready ([becb07f](https://github.com/dure-one/jangbi/commit/becb07f293063199a1952daf79d7f06aeb11fef3) by Woojae, Park).
- fix: fix not loading some plugins on start ([98d0a01](https://github.com/dure-one/jangbi/commit/98d0a013cce4021322f1b5508c6e44077832963b) by Woojae, Park).
- fix: replace cat command to arrow mark ([ca3ae1c](https://github.com/dure-one/jangbi/commit/ca3ae1c838d9afb4fe4a45ce17eca1392e33ded8) by Woojae, Park).
- fix: put specific error msg ([b6cc7fe](https://github.com/dure-one/jangbi/commit/b6cc7fe5575ae36fcbbda67da71b71f2dac03358) by Woojae, Park).
- fix: fix systemd check setting for 3 scenario ([b283acd](https://github.com/dure-one/jangbi/commit/b283acd276bc52782083fec0275bfba996faddb9) by Woojae, Park).
- fix: dnsmasq net inf check error ([cb4e027](https://github.com/dure-one/jangbi/commit/cb4e027e48fabc688d9fa44261802949981b0ff9) by Woojae, Park).
- fix: dnsmasq net inf state check error ([5672f8f](https://github.com/dure-one/jangbi/commit/5672f8ff45eca50ed72ddc8025701d6878dcd2a1) by Woojae, Park).
- fix: add net-tools pkg for net-iptables ([cbbbb8f](https://github.com/dure-one/jangbi/commit/cbbbb8f98d9f317c34b90bfcb29beb30b648563f) by Woojae, Park).
- fix: iptables portforward parse error, aide warn for database_ie ([0614a2d](https://github.com/dure-one/jangbi/commit/0614a2d42616d526f3f642a42c9d0b6a1e8d4954) by Woojae, Park).
- fix: fix multiple interfaces support for dnsmasq ([8ab7a56](https://github.com/dure-one/jangbi/commit/8ab7a56c67ff914bfc36043f7663edd4a0e4e3d9) by Woojae, Park).
- fix: run os-systemd everytime ([cea126e](https://github.com/dure-one/jangbi/commit/cea126ee7df45fef37227add1d1f5bd245d65067) by Woojae, Park).
- fix: fix running in check, clean dnsmasq ([5f9fdf4](https://github.com/dure-one/jangbi/commit/5f9fdf4647767057aff03d6d2c28a215f2d32bc3) by Woojae, Park).
- fix: fix unexpected end of start of rc.local ([7c4c3db](https://github.com/dure-one/jangbi/commit/7c4c3db9f3dd8d83f9be22102f43aef3f9cb0b08) by Woojae, Park).
- fix: fix unnecessary part ([90cc626](https://github.com/dure-one/jangbi/commit/90cc626f12005a9c4ec9c054c093ee4abb0a8099) by Woojae, Park).
- fix: extrepo update ([7d72805](https://github.com/dure-one/jangbi/commit/7d72805358ef64b04014a0b29d083e43d6412846) by Woojae, Park).
- fix: change installation of offline packages to extrepo ([8464351](https://github.com/dure-one/jangbi/commit/8464351c48860d983a15863d81cbfdcfbd8cf457) by Woojae, Park).
- fix: dnsmasq fix. remove anydnsdqy. ([f0ab5db](https://github.com/dure-one/jangbi/commit/f0ab5db86f143ba48bc042119e3c47bb317dbb71) by Woojae, Park).
- fix: fix message printing ([5d15260](https://github.com/dure-one/jangbi/commit/5d15260a84c7002b3fab8e4d8d105f7640d7cbf2) by Woojae, Park).
- fix: fix varible check on start, fix root check ([7211493](https://github.com/dure-one/jangbi/commit/72114936c43e8fee40685f594697c8bdc131bcbd) by Woojae, Park).
- fix: iso download for pkgsdl arch fix ([4292c22](https://github.com/dure-one/jangbi/commit/4292c221bbdad509225dabb51952e24ae41d1dba) by Woojae, Park).
- fix: download firmware file on install process ([da67a29](https://github.com/dure-one/jangbi/commit/da67a2909211cd76b29094a0cb7060c72da7c917) by Woojae, Park).
- fix: change arch automatically on download ([b783518](https://github.com/dure-one/jangbi/commit/b7835188c8fda0f19fd5a00fd6b453ca426b9007) by Woojae, Park).
- fix: dnsmasq port error ([62b584d](https://github.com/dure-one/jangbi/commit/62b584dda49cb3286ca2ec4922b2d6e312689c63) by Woojae, Park).
- fix: fix few bugs ([bf68707](https://github.com/dure-one/jangbi/commit/bf68707b8edecacdc642dc3917df9d3764425bdf) by Woojae, Park).
- fix: fix bugs ([66d29c7](https://github.com/dure-one/jangbi/commit/66d29c7d88630f1f5d34cfe9ecbef89b78002494) by Woojae, Park).
- fix: fix indentation mismatch ([432a5d0](https://github.com/dure-one/jangbi/commit/432a5d0aa25790983ee3fc8b948cc475a8873286) by Woojae, Park).
- fix: fix typo ([203b9d0](https://github.com/dure-one/jangbi/commit/203b9d09027190ba1e1a5a2c28e576f43b83669c) by Woojae, Park).
- fix: fix type, fix error ([6281324](https://github.com/dure-one/jangbi/commit/628132414ce55063f1969337f0a0aa5f6a6fd172) by Woojae, Park).
- fix: fix some bugs ([5737bb3](https://github.com/dure-one/jangbi/commit/5737bb312c8a1b25269f4ab8233738dbd545929f) by Woojae, Park).

<!-- insertion marker -->
