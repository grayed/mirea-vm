# mirea-vm

This toolset helps to build virtual machines infrastructure
for students, based on OpenBSD.

Example configuration assumes having two auxiliary machines:
a gateway, named 'gw', and storage, named 'stor'.

Also, full control on MAC addressing and IP addressing is assumed.
In particular, the 10/8 network usage is hardcoded.
Almost everything else is tweakable, see below.

## Setting up

First, you need to install the ipv6calc package.

Then you should create the file `local.conf` in the same directory with `Makefile`.
Set any variables you need to change there; it will be included by `Makefile`.
You can use any value mentioned in `Makefile` up to the line
telling that there are no more customizable items.

Information about students should be put in files `groups/*.group'.
Those files are text ones with the following structure:

	NUMBER  LOGIN  PASSWORD  NAME

where `NUMBER` is ordinal number of student in group (must not change!),
`LOGIN` is his/her desired login name, `PASSWORD` is his/her password
in encrypted form (see [encrypt\(1\)](https://man.openbsd.org/encrypt.1))
and `NAME` is student's name of arbitrary form and length (spaces are allowed).
Here's an example:

	1 st23 $2b$08$jRgogpNzcr4Rtff2WnWx1uWK0G91GoNIxDfEuCcx5t18zxrRUZh1q John Doe
	2 st25 $2b$08$ck2jZYfY8cUtHe.yplMtROMiokBQ/9Hz3z9qereUsSSmgCN4hLsVK Anna Karenina
	4 st42 $2b$08$kWzw8zZaR6hOadWd61Vxy.Z.LIUAX8Qvf2reqDpE2pO5uovxHacAS Kernel McKusick

Note that login names are compound of 'st' prefix (could be changed via LOGIN_PREFIX)
and numeric ID. This ID is used e.g. to generate port numbers for incoming SSH connections.

Group files themselves must follow the following naming scheme:

	FLOW_YEAR_NUMBER.group

Here `FLOW` is one of the registered in `groups/flows.list` values.
`YEAR` is a two-digit number of group's year; it doesn't have any special meaning, and is used
only for distinction purposes.
`NUMBER` is just ordinal number of the group in the given year's flow.

Group files must reside in `groups` subdirectory.

The `site` subdirectory should contain files that will go in `siteXY.tgz`.
The `templates` subdirectory should contain skeleton files used to build actual configuration.
Feel free to modify files in both of them.

## Gateway

Runs DHCP server and nameserver. Also, it does SSH redirections to VMs via PF.
To build configuration for those, run:

	make gw

Look at the generated files, then apply configuration:

	make install-gw

By default, this will install:

* /etc/dhcpd.conf
* /etc/pf.vmredirs
* /var/nsd/zones/master/10.in-addr.arpa
* /var/nsd/zones/master/example.org

For the second one, it's assumed you have something like that in your
[/etc/pf.conf](https://man.openbsd.org/pf.conf.5):

	anchor "vmlan" in on egress proto tcp to (egress) {
	        include "/etc/pf.vmredirs"
	}
	pass in on egress tagged VM_SSH rtable 1

It's a good idea to have student VMs running in separate routing domain for safety purposes,
since students have full control over their machines and can send virtually anything to the network.

## Storage

Contains installation sets and answers, and serves them (e.g., over HTTP(S)).
To build those, run:

	make stor

If everything is good, put generated `FOO-install.conf` and `siteXY.tgz`
files in the place they belong:

	make install-stor

By default, this will put OpenBSD installer's answer files into `/instsrc/install`,
and the siteXY.tgz will go into `/instsrc/pub/OpenBSD/X.Y/amd64`; the index.txt
in the latter directory will be regenerated to make `siteXY.tgz` visible.

There is a script supplied, `sync.sh`, which is designed to be run from crontab
periodically to download current and previous OpenBSD release sets and packages
for given architecture.
After running the script first time (successfully), it'll be possible to run

	make install-tftp

which will setup TFTP daemon's directory. You'll need to repeat this step
after changing `${INST_RELEASE}`; make(1) will remind you about that.


## Twekable parameters

* `DHCPD_CONF_FILE` - where to install dhcpd(8) configuration file. Default is `/etc/dhcpd.conf`.
* `DNS_FORW_ZONE` - DNS zone to be filled. Default: `example.org`.
* `DNS_ZONES_DIR` - directory where to install DNS zone files. Default: `/var/nsd/zones/master`.
* `INST_ROOT` - directory where actual file and host configuration storage resides. Default: `/instsrc`.
* `INST_CONF_DIR` - directory where host configuration for autoinstall should be put. Default: `${INST_ROOT}/install`.
* `INST_RELEASE` - OS release to operate on. Default: `6.8` (subject to change in the future).
* `INST_ARCH` - OS architecture to operate on. Default: `amd64`.
* `IPV4_PREFIX` - defines IPv4 network for VMs. See also [Network layout](#network-layout). Default: 10.0.0.0/8. Note: only `/8` IPv4 prefixes are supported as of now.
* `IPV6_PREFIX` - defines IPv6 network for VMs. See also [Network layout](#network-layout). Default: fc00::/48. Note: IPv6 prefix length must be in 16..96 range, and must be a multiple of 16.
* `LOGIN_PREFIX` - prefix used for student logins. It's assumed that logins look like ${LOGIN_PREFIX}**ID**, where ID is unique. Can be set together with `LOGIN_SUFFIX`. See also `PF_PORT_BASE`. Default: `st`.
* `LOGIN_SUFFIX` - suffix used for student logins. It's assumed that logins look like **ID**${LOGIN_SUFFIX}, where ID is unique. Can be set together with `LOGIN_PREFIX`. See also `PF_PORT_BASE`. Default: empty.
* `MAC_PREFIX` - MAC address prefix used in DHCP server configuration. Must be in form of `ab:cd:`. Default: `0a:00:`.
* `PF_TAG` - PF tag to applied to incoming VM SSH connections on gateway. Default: `VM_SSH`.
* `PF_REDIR_FILE` - where to install generated PF rules file. Default: `/etc/pf.vmredirs`. Note: this file must be manually included in /etc/pf.conf, see [Gateway](#gateway).
* `PF_PORT_BASE` - starting port number used for redirecting SSH connections to VMs. Actual port number is calcuated by adding `PF_PORT_BASE` and user ID, see `LOGIN_PREFIX` and `LOGIN_SUFFIX`. Default: `22000`.
* `RSYNC_MIRROR` - defines source URI to be used by sync script. Default: `rsync://mirror.leaseweb.com/openbsd`.
* `TFTP_DIR` - chroot directory used by `[tftpd\(8\)](https://man.openbsd.org/tftpd.8)`.

You can set any of those values in `local.conf`.
Note: this file is included both by make- and shell-based components, so it must not contain spaces:

	DNS_FORW_ZONE=my.lan
	INST_RELEASE=6.9
	IPV4_PREFIX=10.0.0.0/8
	IPV6_PREFIX=fc00::/16
	LOGIN_PREFIX=st
	PF_PORT_BASE=12000
	PF_REDIR_FILE=/etc/pf.vmredirs

## Network layout

Pretend we have the above mentioned setup for KVM-based VMs.
There is only one flow defined, `cs`, and two groups of the same year: cs-20-1 and cs-20-2.
First group has two students, with logins st121 and st102.
Second group has one student, st89.
Also, imagine that `vm-gateway.my.lan` is set as DMZ on internet gateway, so all incoming connections come on its `vio0` network interface.

	[cs-20-1-1.my.lan]                    [ vm-gateway.my.lan ]
	[      st121     ]                    [pf.vmredirs is here]
	[      10.11.20.1]-----          vio1 [10.0.0.1           ]
	[fc00:0120:0101::] vio0\       -------[fc00:0000:0001::   ]
	                        \     /       [       192.168.1.42] vio0
	[cs-20-1-3.my.lan]       \   /        [ fd00:0123:4567::42]----------      [   Internet gateway   ]
	[      st102     ]        \ /                                        \     [       198.51.100.7/31]
	[      10.11.20.3]---------+                                          \    [ 2001:db8:9402::873/64]---{ Internet }
	[fc00:0120:0103::] vio0   / \                                          +---[192.168.1.1           ]
	                         /   \        [ vm-storage.my.lan ] rdomain 1 /    [fd00:0123:4567::1     ]
	[cs-20-2-1.my.lan]      /     \       [       192.168.1.49] vio1     /
	[       st89     ]     /       \      [ fd00:0123:4567::49]----------
	[      10.12.20.1]-----         ------[10.0.0.2           ]
	[fc00:0120:0201::] vio0          vio0 [fc00:0000:0002::   ]
	                            rdomain 0

Say, student `st89` tries to connect to his/her VM.
His/her ID is 89, so he/she should use TCP port 12102 on Internet gateway.
The TCP handshake request is transferred to `vm-gateway.my.lan` on the same port.
Here rules in `/etc/pf.vmredirs` are evaluated, resulting in further forwarding to normal SSH port on student's VM, `10.11.20.3`.
This IPv4 address can be decrypted the following way:

* **10.** - the configured IPv4 prefix;
* **1** - flow ID;
* **2** - group ordinal number (unique for the given flow and year);
* **.20** - year (2020);
* **.1** - student's ordinal number in group list.

The corresponding IPv6 address has similar scheme:

* **fc00:** - the configured IPv6 prefix;
* **01** - flow ID;
* **20** - year (2020);
* **:02** - group ordinal number (unique for the given flow and year);
* **01** - student's ordinal number in group list.

Note that ever given IPv6 addresses support hexadecimal digits, we use only decimals, for better readability.

As a convenience, utility VMs (e.g., vm-gateway and vm-storage) have corresponding numbers for flow ID, year and group ordinal numbers set to zero.
