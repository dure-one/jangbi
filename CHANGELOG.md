# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

<!-- insertion marker -->
## Unreleased

<small>[Compare with latest](https://github.com/dure-one/jangbi/compare/cf31888b598023227446512a34039c2c9ac6e620...HEAD)</small>

### Added

- Add changelog automatically ([c8458e2](https://github.com/dure-one/jangbi/commit/c8458e2f3f95d6682607762eb25317705c9198a1) by nikescar).

### Fixed

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
